import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import '../core/app_failure.dart';
import '../core/stream_agent.dart';
import '../core/utils/crossfade.dart';
import '../core/utils/replay_gain.dart';
import '../core/utils/skip_window.dart';
import '../data/db/app_database.dart';
import '../data/library_bus.dart';
import '../data/models/app_settings.dart';
import '../data/models/library.dart';
import '../data/models/playlist.dart';
import '../data/models/track.dart';
import '../data/services/discord_presence.dart';
import '../data/services/download_manager.dart';
import '../data/services/media_resolver.dart';
import '../data/services/sponsor_client.dart';
import 'player_snapshot.dart';

class _Deck {
  _Deck(this.player, this.enhancer, this.equalizer);

  final AudioPlayer player;
  final AndroidLoudnessEnhancer enhancer;
  final AndroidEqualizer equalizer;
  Track? track;
  GainPlan gain = GainPlan.unity;
  String? videoId;
  String? kind;
  bool offline = false;
  int? bits;
}

/// Plays the queue, keeps a notification, and hands songs across with a fade.
class ForgeAudioHandler extends BaseAudioHandler {
  ForgeAudioHandler({
    required AppDatabase database,
    required LibraryBus bus,
    required MediaResolver resolver,
    required DownloadManager downloads,
    required AppSettings settings,
  }) : _db = database,
       _bus = bus,
       _resolver = resolver,
       _downloads = downloads,
       _settings = settings {
    _left = _openDeck();
    _right = _openDeck();
    _live = _left;
    _listen(_left);
    _listen(_right);
  }

  final AppDatabase _db;
  final LibraryBus _bus;
  final MediaResolver _resolver;
  final DownloadManager _downloads;
  final SponsorClient _sponsor = SponsorClient();
  final DiscordPresence _discord = DiscordPresence();
  AppSettings _settings;
  List<SkipSegment> _segments = const [];
  String? _segmentFor;
  Duration? _skipArmedUntil;
  Duration? _previousPosition;
  String? _presenceTrack;
  bool? _presencePlaying;

  late final _Deck _left;
  late final _Deck _right;
  late _Deck _live;
  _Deck? _ghost;

  final _ui = BehaviorSubject<PlayerSnapshot>.seeded(PlayerSnapshot.empty);
  AudioSession? _session;
  Future<void> _chain = Future<void>.value();

  final List<Track> _queue = [];
  int _index = 0;
  RepeatMode _repeat = RepeatMode.off;
  bool _shuffle = false;
  List<String>? _linearIds;
  bool _shuffleDirty = false;
  bool _playing = false;
  bool _prepared = false;
  bool _loading = false;
  bool _fading = false;
  bool _fadeBusy = false;
  bool _ducked = false;
  bool _credited = false;
  bool _retried = false;
  bool _failing = false;
  bool _sleepEndOfTrack = false;
  bool _resumeAfterInterrupt = false;
  bool _askedNotification = false;
  int _errors = 0;
  int? _preloadedIndex;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _sleepGain = 1;
  String? _message;
  DateTime? _fadeStarted;
  DateTime? _sleepEnds;
  DateTime? _lastService;
  DateTime? _lastPersist;
  Timer? _clock;
  Timer? _sleepTimer;

  Stream<PlayerSnapshot> get snapshots => _ui.stream;

  PlayerSnapshot get snapshot => _ui.value;

  _Deck _openDeck() {
    final enhancer = AndroidLoudnessEnhancer();
    final equalizer = AndroidEqualizer();
    final player = AudioPlayer(
      userAgent: streamUserAgent,
      handleInterruptions: false,
      handleAudioSessionActivation: false,
      useProxyForRequestHeaders: false,
      audioPipeline: AudioPipeline(androidAudioEffects: [equalizer, enhancer]),
    );
    return _Deck(player, enhancer, equalizer);
  }

  _Deck get _spare => identical(_live, _left) ? _right : _left;

  Future<T> _sync<T>(Future<T> Function() job) {
    final done = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        done.complete(await job());
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    });
    return done.future;
  }

  @override
  Future<void> prepare() async {
    if (_prepared) return;
    _prepared = true;
    final session = await AudioSession.instance;
    _session = session;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen(_onInterrupt);
    session.becomingNoisyEventStream.listen((_) {
      unawaited(pause());
    });
    await _restore();
    _publish(structural: true);
  }

  Future<void> playTracks(List<Track> tracks, {int index = 0}) {
    return _sync(() => _playLoaded(tracks, index));
  }

  Future<void> _playLoaded(List<Track> tracks, int index) async {
    if (tracks.isEmpty) return;
    await prepare();
    await _askNotification();
    await _cancelFade();
    for (final track in tracks) {
      if (track.source == TrackSource.youtube) await _db.upsertTrack(track);
    }
    _queue
      ..clear()
      ..addAll(tracks);
    _index = index.clamp(0, tracks.length - 1);
    if (_shuffle) {
      final chosen = _queue[_index];
      final rest = [..._queue]..removeAt(_index);
      rest.shuffle(math.Random());
      _queue
        ..clear()
        ..add(chosen)
        ..addAll(rest);
      _index = 0;
      _linearIds = tracks.map((track) => track.id).toList();
      _shuffleDirty = false;
    }
    await _startCurrent(play: true);
  }

  Future<void> enqueue(List<Track> tracks) {
    return _sync(() async {
      if (tracks.isEmpty) return;
      for (final track in tracks) {
        if (track.source == TrackSource.youtube) await _db.upsertTrack(track);
      }
      _queue.addAll(tracks);
      if (_shuffle) _shuffleDirty = true;
      if (_queue.length == tracks.length) {
        _index = 0;
        await _startCurrent(play: true);
      } else {
        _broadcast();
        await _persist();
      }
    });
  }

  Future<void> playNext(Track track) {
    return _sync(() async {
      if (track.source == TrackSource.youtube) await _db.upsertTrack(track);
      final at = _queue.isEmpty ? 0 : (_index + 1).clamp(0, _queue.length);
      _queue.insert(at, track);
      if (_shuffle) _shuffleDirty = true;
      if (_queue.length == 1) {
        _index = 0;
        await _startCurrent(play: true);
      } else {
        _broadcast();
        await _persist();
      }
    });
  }

  Future<void> move(int from, int to) {
    return _sync(() async {
      if (from < 0 || to < 0 || from >= _queue.length || to >= _queue.length) return;
      final item = _queue.removeAt(from);
      _queue.insert(to, item);
      if (_index == from) {
        _index = to;
      } else if (from < _index && to >= _index) {
        _index -= 1;
      } else if (from > _index && to <= _index) {
        _index += 1;
      }
      if (_shuffle) _shuffleDirty = true;
      _broadcast();
      await _persist();
    });
  }

  Future<void> removeAt(int index) {
    return _sync(() async {
      if (index < 0 || index >= _queue.length) return;
      final current = index == _index;
      _queue.removeAt(index);
      if (_shuffle) _shuffleDirty = true;
      if (_queue.isEmpty) {
        await _cancelFade();
        await _live.player.pause();
        _playing = false;
        _index = 0;
        _live.track = null;
        mediaItem.add(null);
        queue.add(const []);
        _position = Duration.zero;
        await _persist();
        _publish(structural: true);
        return;
      }
      if (index < _index) _index -= 1;
      if (_index >= _queue.length) _index = _queue.length - 1;
      if (current) {
        await _cancelFade();
        await _startCurrent(play: _playing);
      } else {
        _broadcast();
        await _persist();
      }
    });
  }

  Future<void> clearQueue() {
    return _sync(() async {
      await _cancelFade();
      await _live.player.pause();
      _queue.clear();
      _index = 0;
      _playing = false;
      _live.track = null;
      _position = Duration.zero;
      mediaItem.add(null);
      queue.add(const []);
      await _persist();
      _publish(structural: true);
    });
  }

  Future<void> toggleShuffle() {
    return _sync(() async {
      if (_queue.isEmpty) {
        _shuffle = !_shuffle;
        _publish(structural: true);
        return;
      }
      if (!_shuffle) {
        _linearIds = _queue.map((track) => track.id).toList();
        _shuffleDirty = false;
        final current = _queue[_index];
        final rest = [..._queue]..removeAt(_index);
        rest.shuffle(math.Random());
        _queue
          ..clear()
          ..add(current)
          ..addAll(rest);
        _index = 0;
        _shuffle = true;
      } else {
        _shuffle = false;
        if (!_shuffleDirty && _linearIds != null) {
          final pool = {for (final track in _queue) track.id: track};
          final restored = <Track>[];
          for (final id in _linearIds!) {
            final track = pool.remove(id);
            if (track != null) restored.add(track);
          }
          restored.addAll(pool.values);
          final currentId = _queue[_index].id;
          _queue
            ..clear()
            ..addAll(restored);
          final found = _queue.indexWhere((track) => track.id == currentId);
          _index = found < 0 ? 0 : found;
        }
        _linearIds = null;
      }
      _broadcast();
      await _persist();
    });
  }

  Future<void> cycleRepeat() {
    return _sync(() async {
      _repeat = switch (_repeat) {
        RepeatMode.off => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.off,
      };
      await _live.player.setLoopMode(
        _repeat == RepeatMode.one ? LoopMode.one : LoopMode.off,
      );
      if (_repeat == RepeatMode.one) await _cancelFade();
      _publish(structural: true);
      await _persist();
    });
  }

  Future<void> setSleep(Duration? length, {bool endOfTrack = false}) {
    return _sync(() async {
      _sleepTimer?.cancel();
      _sleepEndOfTrack = endOfTrack && length == null;
      if (length == null) {
        _sleepEnds = null;
        _sleepGain = 1;
      } else {
        _sleepEnds = DateTime.now().add(length);
        _sleepEndOfTrack = false;
        _sleepTimer = Timer(length, () => unawaited(pause()));
        _startClock();
      }
      _publish(structural: true);
    });
  }

  Future<void> replaceTrack(Track track) {
    return _sync(() async {
      var changed = false;
      for (var i = 0; i < _queue.length; i++) {
        if (_queue[i].id == track.id) {
          _queue[i] = track;
          if (_live.track?.id == track.id) _live.track = track;
          changed = true;
        }
      }
      if (changed) _broadcast();
    });
  }

  Future<void> _applyEqualizer(_Deck deck) async {
    try {
      await deck.equalizer.setEnabled(_settings.equalizer);
    } catch (_) {
      return;
    }
    if (!_settings.equalizer || !Platform.isAndroid) return;
    AndroidEqualizerParameters params;
    try {
      params = await deck.equalizer.parameters.timeout(const Duration(seconds: 2));
    } catch (_) {
      return;
    }
    final gains = _settings.equalizerBands;
    final count = math.min(params.bands.length, gains.length);
    for (var i = 0; i < count; i++) {
      final gain = gains[i].clamp(params.minDecibels, params.maxDecibels).toDouble();
      try {
        await params.bands[i].setGain(gain);
      } catch (_) {}
    }
  }

  Future<void> applySettings(AppSettings settings) {
    return _sync(() async {
      _settings = settings;
      for (final deck in [_left, _right]) {
        final track = deck.track;
        if (track == null) continue;
        deck.gain = GainPlan.resolve(
          replayGainDb: track.replayGainDb,
          enabled: settings.normalize,
          fallbackDb: settings.normalizeGainDb,
        );
        await deck.enhancer.setTargetGain(deck.gain.enhancerDb);
        await deck.enhancer.setEnabled(deck.gain.enhancerDb > 0);
        await _applyEqualizer(deck);
        if (Platform.isAndroid) {
          try {
            await deck.player.setSkipSilenceEnabled(settings.skipSilence);
          } catch (_) {}
        }
      }
      _pushLevel(_live, _fading ? _fadeAmount(incoming: true) : 1);
      final ghost = _ghost;
      if (ghost != null) _pushLevel(ghost, _fadeAmount(incoming: false));
    });
  }

  @override
  Future<void> play() {
    return _sync(() async {
      await prepare();
      if (_queue.isEmpty) return;
      await _askNotification();
      if (_live.track == null) {
        await _startCurrent(play: true);
        return;
      }
      if (!await _activate()) {
        _message = 'Another app is using the sound right now.';
        _publish(structural: true);
        return;
      }
      await _live.player.play();
      _playing = true;
      _startClock();
      _publish(structural: true);
    });
  }

  @override
  Future<void> pause() => _sync(_pause);

  @override
  Future<void> stop() => pause();

  @override
  Future<void> seek(Duration position) {
    return _sync(() async {
      await _cancelFade();
      var target = position;
      final duration = _live.player.duration ?? _duration;
      if (target < Duration.zero) target = Duration.zero;
      if (duration != null && target > duration) target = duration;
      _position = target;
      await _live.player.seek(target);
      _publish(structural: true);
      await _persist();
    });
  }

  @override
  Future<void> skipToNext() {
    return _sync(() async {
      final next = _nextIndex();
      if (next == null) return;
      await _cancelFade();
      _index = next;
      await _startCurrent(play: true);
    });
  }

  @override
  Future<void> skipToPrevious() {
    return _sync(() async {
      if (_position > const Duration(seconds: 3)) {
        await _cancelFade();
        _position = Duration.zero;
        await _live.player.seek(Duration.zero);
        _publish(structural: true);
        return;
      }
      if (_queue.isEmpty) return;
      if (_index == 0 && _repeat != RepeatMode.all) {
        _position = Duration.zero;
        await _live.player.seek(Duration.zero);
        _publish(structural: true);
        return;
      }
      await _cancelFade();
      _index = _index == 0 ? _queue.length - 1 : _index - 1;
      await _startCurrent(play: true);
    });
  }

  @override
  Future<void> fastForward() => seek(_position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => seek(_position - const Duration(seconds: 10));

  Future<void> _startCurrent({required bool play}) async {
    if (_queue.isEmpty) return;
    _credited = false;
    _retried = false;
    _message = null;
    _preloadedIndex = null;
    _segments = const [];
    _segmentFor = null;
    _skipArmedUntil = null;
    _previousPosition = null;
    await _open(_live, _queue[_index], play: play);
    final current = _queue[_index];
    final videoId = current.youtubeId;
    if (_settings.sponsorBlock &&
        current.source == TrackSource.youtube &&
        videoId != null &&
        videoId.isNotEmpty) {
      unawaited(_loadSegments(videoId));
    }
    _playing = play;
    if (play) _startClock();
    _broadcast();
    await _persist();
  }

  Future<void> _open(
    _Deck deck,
    Track track, {
    Duration? at,
    required bool play,
    double level = 1,
  }) async {
    _loading = true;
    try {
      final resolved = await _resolver.resolveAudio(track, _settings);
      await deck.player.setAudioSource(
        resolved.source,
        initialPosition: at ?? Duration.zero,
      );
      deck.track = track;
      deck.videoId = resolved.cacheVideoId ?? track.youtubeId;
      deck.kind = resolved.cacheKind;
      deck.offline = resolved.onDevice;
      deck.bits = resolved.bitsPerSecond;
      deck.gain = GainPlan.resolve(
        replayGainDb: track.replayGainDb,
        enabled: _settings.normalize,
        fallbackDb: _settings.normalizeGainDb,
      );
      await deck.enhancer.setTargetGain(deck.gain.enhancerDb);
      await deck.enhancer.setEnabled(deck.gain.enhancerDb > 0);
      await _applyEqualizer(deck);
      if (Platform.isAndroid) {
        try {
          await deck.player.setSkipSilenceEnabled(_settings.skipSilence);
        } catch (_) {}
      }
      await deck.player.setLoopMode(
        identical(deck, _live) && _repeat == RepeatMode.one ? LoopMode.one : LoopMode.off,
      );
      _pushLevel(deck, level);
      if (play) {
        if (!await _activate()) {
          throw AppFailure('Another app is using the sound right now.');
        }
        await deck.player.play();
      }
      final chosen = resolved.cacheStream;
      final videoId = resolved.cacheVideoId;
      final kind = resolved.cacheKind;
      if (chosen != null && videoId != null && kind != null) {
        unawaited(
          _downloads.cacheStream(
            videoId: videoId,
            chosen: chosen,
            kind: kind,
            limitBytes: _settings.cacheLimitMb * 1024 * 1024,
          ),
        );
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _pause() async {
    _playing = false;
    await _live.player.pause();
    await _ghost?.player.pause();
    _publish(structural: true);
    await _persist();
  }

  Future<bool> _activate() async {
    final session = _session;
    if (session == null) return true;
    return session.setActive(true);
  }

  Future<void> _restore() async {
    final saved = await _db.loadQueue();
    if (saved == null || saved.ids.isEmpty) return;
    final tracks = <Track>[];
    for (final id in saved.ids) {
      final track = await _db.trackById(id);
      if (track != null) tracks.add(track);
    }
    if (tracks.isEmpty) return;
    _queue
      ..clear()
      ..addAll(tracks);
    _index = saved.index.clamp(0, _queue.length - 1);
    _repeat = RepeatMode.values.asNameMap()[saved.repeat] ?? RepeatMode.off;
    _shuffle = saved.shuffle;
    _shuffleDirty = _shuffle;
    _position = Duration(milliseconds: saved.positionMs);
    try {
      await _open(_live, _queue[_index], at: _position, play: false);
    } catch (_) {
      _message = 'The last song could not be restored.';
    }
    _playing = false;
    _broadcast();
  }

  void _listen(_Deck deck) {
    deck.player.playerStateStream.listen((state) {
      if (!identical(deck, _live) || _fading || _loading) return;
      if (state.playing && state.processingState == ProcessingState.ready) {
        _errors = 0;
        if (_message != null) {
          _message = null;
          _publish(structural: true);
        }
      }
      if (state.processingState == ProcessingState.completed) {
        unawaited(_sync(_onCompleted));
      }
    });
    deck.player.errorStream.listen((error) {
      if (!identical(deck, _live) || _loading) return;
      unawaited(_sync(() => _fail(error)));
    });
  }

  Future<void> _onCompleted() async {
    if (_fading || _loading || _queue.isEmpty) return;
    if (_sleepEndOfTrack) {
      _sleepEndOfTrack = false;
      _sleepEnds = null;
      await _pause();
      return;
    }
    if (_repeat == RepeatMode.one) {
      await _live.player.seek(Duration.zero);
      await _live.player.play();
      _playing = true;
      return;
    }
    final next = _nextIndex();
    if (next == null) {
      _playing = false;
      _publish(structural: true);
      await _persist();
      return;
    }
    _index = next;
    await _startCurrent(play: true);
  }

  Future<void> _fail(Object error) async {
    if (_failing) return;
    _failing = true;
    try {
      final track = _live.track;
      if (track != null && track.source == TrackSource.youtube && !_retried) {
        _retried = true;
        final kind = _live.kind;
        final videoId = track.youtubeId;
        if (kind != null && videoId != null) {
          await _resolver.invalidate(videoId, kind);
        }
        await _open(_live, track, at: _position, play: _playing);
        return;
      }
      _errors += 1;
      if (_errors >= 3) {
        _message = 'A few songs would not play, so Forgemusic stopped.';
        await _pause();
        return;
      }
      final next = _nextIndex();
      if (next == null) {
        _message = error is AppFailure ? error.message : 'This song would not play.';
        await _pause();
        return;
      }
      _index = next;
      _retried = false;
      await _startCurrent(play: true);
    } catch (inner) {
      _message = inner is AppFailure ? inner.message : 'This song would not play.';
      await _pause();
    } finally {
      _failing = false;
    }
  }

  void _startClock() {
    _clock ??= Timer.periodic(const Duration(milliseconds: 200), (_) => _onClock());
  }

  void _onClock() {
    if (_playing) {
      _position = _live.player.position;
      _duration = _live.player.duration ?? _duration;
    }
    _updateSleep();
    if (_playing && !_credited && _position >= const Duration(seconds: 20)) {
      _credited = true;
      final id = _live.track?.id;
      if (id != null) {
        unawaited(_db.addHistory(id).then((_) => _bus.ping()));
      }
    }
    _considerSponsor();
    if (_fading) _advanceFade();
    final now = DateTime.now();
    if (_playing &&
        (_lastPersist == null || now.difference(_lastPersist!) > const Duration(seconds: 5))) {
      _lastPersist = now;
      unawaited(_persist());
    }
    _publish(structural: false);
    if (_playing && !_fadeBusy && !_fading) {
      _fadeBusy = true;
      unawaited(_maybeCrossfade().whenComplete(() => _fadeBusy = false));
    }
  }

  Future<void> _maybeCrossfade() {
    return _sync(() async {
      if (_fading || _loading || _repeat == RepeatMode.one) return;
      final duration = _live.player.duration;
      if (duration == null) return;
      final position = _live.player.position;
      final hasNext = _nextIndex() != null;
      final remaining = duration - position;
      if (remaining > const Duration(seconds: 8) || remaining <= Duration.zero) return;
      if (_settings.crossfade && _settings.crossfadeMs > 0) {
        try {
          await _preload();
        } catch (_) {
          _preloadedIndex = null;
        }
      }
      final start = CrossfadeWindow.shouldStart(
        enabled: _settings.crossfade,
        crossfadeMs: _settings.crossfadeMs,
        alreadyFading: _fading,
        repeatOne: false,
        position: position,
        duration: duration,
        hasNext: hasNext,
      );
      if (start) await _beginFade();
    });
  }

  Future<void> _preload() async {
    final next = _nextIndex();
    if (next == null) return;
    if (_preloadedIndex == next && _spare.track?.id == _queue[next].id) return;
    await _open(_spare, _queue[next], play: false, level: 0);
    _preloadedIndex = next;
  }

  Future<void> _beginFade() async {
    final next = _nextIndex();
    if (next == null || _fading) return;
    if (_preloadedIndex != next) {
      try {
        await _preload();
      } catch (_) {
        return;
      }
    }
    if (_spare.track?.id != _queue[next].id) return;
    final previous = _live;
    final previousIndex = _index;
    _ghost = previous;
    _live = _spare;
    _index = next;
    _credited = false;
    _retried = false;
    _fading = true;
    _fadeStarted = DateTime.now();
    _position = _live.player.position;
    try {
      if (!await _activate()) {
        throw AppFailure('Another app is using the sound right now.');
      }
      await _live.player.play();
    } catch (_) {
      _live = previous;
      _index = previousIndex;
      _ghost = null;
      _fading = false;
      _fadeStarted = null;
      return;
    }
    _playing = true;
    _broadcast();
  }

  void _advanceFade() {
    final started = _fadeStarted;
    final ghost = _ghost;
    if (started == null || ghost == null) return;
    final span = _settings.crossfadeMs <= 0 ? 1 : _settings.crossfadeMs;
    final amount = DateTime.now().difference(started).inMilliseconds / span;
    if (amount >= 1) {
      unawaited(_sync(_finishFade));
      return;
    }
    _pushLevel(_live, CrossfadeCurve.incoming(amount));
    _pushLevel(ghost, CrossfadeCurve.outgoing(amount));
  }

  Future<void> _finishFade() async {
    final ghost = _ghost;
    _fading = false;
    _fadeStarted = null;
    _ghost = null;
    _preloadedIndex = null;
    if (ghost != null) {
      await ghost.player.pause();
      _pushLevel(ghost, 0);
    }
    _pushLevel(_live, 1);
    _publish(structural: true);
  }

  Future<void> _cancelFade() async {
    final ghost = _ghost;
    _fading = false;
    _fadeStarted = null;
    _ghost = null;
    _preloadedIndex = null;
    if (ghost != null) {
      await ghost.player.pause();
      _pushLevel(ghost, 0);
    }
    _pushLevel(_live, 1);
  }

  double _fadeAmount({required bool incoming}) {
    final started = _fadeStarted;
    if (!_fading || started == null) return incoming ? 1 : 0;
    final span = _settings.crossfadeMs <= 0 ? 1 : _settings.crossfadeMs;
    final amount = (DateTime.now().difference(started).inMilliseconds / span).clamp(0, 1).toDouble();
    return incoming ? CrossfadeCurve.incoming(amount) : CrossfadeCurve.outgoing(amount);
  }

  void _updateSleep() {
    final ends = _sleepEnds;
    if (ends == null || !_settings.sleepFade) {
      _sleepGain = 1;
      return;
    }
    final left = ends.difference(DateTime.now());
    const window = Duration(seconds: 12);
    if (left <= Duration.zero) {
      _sleepGain = 0;
    } else if (left < window) {
      _sleepGain = left.inMilliseconds / window.inMilliseconds;
    } else {
      _sleepGain = 1;
    }
  }

  void _pushLevel(_Deck deck, double fade) {
    final level = (deck.gain.volume * fade * _sleepGain * (_ducked ? 0.35 : 1)).clamp(0.0, 1.0);
    unawaited(deck.player.setVolume(level).then((_) {}, onError: (_, _) {}));
  }

  int? _nextIndex() {
    if (_queue.isEmpty) return null;
    if (_index < _queue.length - 1) return _index + 1;
    if (_repeat == RepeatMode.all) return 0;
    return null;
  }

  void _onInterrupt(AudioInterruptionEvent event) {
    if (event.begin) {
      if (event.type == AudioInterruptionType.duck) {
        _ducked = true;
        _pushLevel(_live, _fading ? _fadeAmount(incoming: true) : 1);
        return;
      }
      _resumeAfterInterrupt = _playing;
      unawaited(pause());
      return;
    }
    if (event.type == AudioInterruptionType.duck) {
      _ducked = false;
      _pushLevel(_live, _fading ? _fadeAmount(incoming: true) : 1);
      return;
    }
    if (_resumeAfterInterrupt) {
      _resumeAfterInterrupt = false;
      unawaited(play());
    }
  }

  Future<void> _askNotification() async {
    if (_askedNotification || !Platform.isAndroid) return;
    _askedNotification = true;
    await Permission.notification.request();
  }

  void _broadcast() {
    final items = _queue.map(_item).toList();
    queue.add(items);
    mediaItem.add(items.isEmpty ? null : items[_index.clamp(0, items.length - 1)]);
    _publish(structural: true);
  }

  MediaItem _item(Track track) {
    return MediaItem(
      id: track.id,
      title: track.title,
      album: track.album,
      artist: track.artist,
      duration: track.duration,
      artUri: _art(track),
      extras: _extras(track),
    );
  }

  Uri? _art(Track track) {
    final file = track.artworkPath;
    if (file != null && file.isNotEmpty) return Uri.file(file);
    final thumb = track.thumbnailUrl;
    if (thumb != null && thumb.startsWith('http')) return Uri.parse(thumb);
    final path = track.path;
    if (path != null && path.startsWith('content:')) return Uri.parse(path);
    return null;
  }

  Map<String, dynamic>? _extras(Track track) {
    final path = track.path;
    if ((track.artworkPath == null || track.artworkPath!.isEmpty) &&
        path != null &&
        path.startsWith('content:')) {
      return {'loadThumbnailUri': path};
    }
    return null;
  }

  Future<void> _persist() {
    return _db.saveQueue(
      QueueSnapshot(
        ids: _queue.map((track) => track.id).toList(),
        index: _queue.isEmpty ? 0 : _index,
        positionMs: _position.inMilliseconds,
        repeat: _repeat.name,
        shuffle: _shuffle,
      ),
    );
  }

  void _publish({required bool structural}) {
    final processing = _live.player.processingState;
    _ui.add(
      PlayerSnapshot(
        queue: List<Track>.unmodifiable(_queue),
        index: _queue.isEmpty ? 0 : _index,
        position: _position,
        duration: _duration ?? _live.player.duration,
        playing: _playing,
        buffering: processing == ProcessingState.buffering || processing == ProcessingState.loading,
        repeat: _repeat,
        shuffle: _shuffle,
        sleepEndsAt: _sleepEnds,
        sleepEndOfTrack: _sleepEndOfTrack,
        message: _message,
        offline: _live.track != null && _live.offline,
        streamBits: _live.bits,
      ),
    );
    if (structural) _sharePresence();
    final now = DateTime.now();
    if (!structural &&
        _lastService != null &&
        now.difference(_lastService!) < const Duration(seconds: 5)) {
      return;
    }
    _lastService = now;
    final serviceState = _queue.isEmpty
        ? AudioProcessingState.idle
        : processing == ProcessingState.buffering || processing == ProcessingState.loading
        ? AudioProcessingState.buffering
        : AudioProcessingState.ready;
    playbackState.add(
      PlaybackState(
        processingState: serviceState,
        playing: _playing,
        controls: [
          MediaControl.skipToPrevious,
          _playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        updatePosition: _position,
        bufferedPosition: _live.player.bufferedPosition,
        speed: _playing ? 1 : 0,
        queueIndex: _queue.isEmpty ? null : _index,
        repeatMode: switch (_repeat) {
          RepeatMode.off => AudioServiceRepeatMode.none,
          RepeatMode.one => AudioServiceRepeatMode.one,
          RepeatMode.all => AudioServiceRepeatMode.all,
        },
        shuffleMode: _shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
        errorMessage: _message,
      ),
    );
  }

  void _considerSponsor() {
    if (!_playing || !_settings.sponsorBlock || _fading || _loading) return;
    final videoId = _live.track?.youtubeId;
    if (videoId == null || _segmentFor != videoId) return;
    final previous = _previousPosition;
    final jumpedBack = previous != null && _position + const Duration(seconds: 1) < previous;
    _previousPosition = _position;
    if (jumpedBack) _skipArmedUntil = null;
    final armed = _skipArmedUntil;
    if (armed != null && _position < armed) return;
    _skipArmedUntil = null;
    final jump = nextSkip(_segments, _position);
    if (jump == null) return;
    _skipArmedUntil = jump;
    unawaited(seek(jump));
  }

  Future<void> _loadSegments(String videoId) async {
    final found = await _sponsor.segments(videoId);
    if (_live.track?.youtubeId != videoId) return;
    _segments = found;
    _segmentFor = videoId;
  }

  void _sharePresence() {
    final track = _live.track;
    final webhook = _settings.discordWebhook;
    if (!_settings.discordShare || webhook.trim().isEmpty || track == null) return;
    if (_presenceTrack == track.id && _presencePlaying == _playing) return;
    _presenceTrack = track.id;
    _presencePlaying = _playing;
    unawaited(
      _discord.update(
        webhook: webhook,
        title: track.title,
        artist: track.artist,
        album: track.album,
        playing: _playing,
      ),
    );
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return const [
        MediaItem(id: 'forge:songs', title: 'Songs', playable: false),
        MediaItem(id: 'forge:albums', title: 'Albums', playable: false),
        MediaItem(id: 'forge:playlists', title: 'Playlists', playable: false),
      ];
    }
    if (parentMediaId == 'forge:songs') {
      return (await _db.allTracks()).map(_item).toList();
    }
    if (parentMediaId == 'forge:albums') {
      final albums = groupAlbums(await _db.allTracks());
      return [
        for (final album in albums)
          MediaItem(
            id: 'forge:album:${album.key}',
            title: album.name,
            artist: album.artist,
            playable: false,
          ),
      ];
    }
    if (parentMediaId.startsWith('forge:album:')) {
      final key = parentMediaId.substring('forge:album:'.length);
      final album = groupAlbums(await _db.allTracks()).where((item) => item.key == key).firstOrNull;
      if (album == null) return const [];
      return album.tracks.map(_item).toList();
    }
    if (parentMediaId == 'forge:playlists') {
      final lists = await _db.playlists();
      return [
        for (final playlist in lists)
          MediaItem(id: 'forge:playlist:${playlist.id}', title: playlist.name, playable: false),
      ];
    }
    if (parentMediaId.startsWith('forge:playlist:')) {
      final id = parentMediaId.substring('forge:playlist:'.length);
      return (await _db.playlistTracks(id)).map(_item).toList();
    }
    return const [];
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) {
    return _sync(() async {
      if (mediaId == 'forge:songs') {
        final tracks = await _db.allTracks();
        if (tracks.isEmpty) return;
        await _playLoaded(tracks, 0);
        return;
      }
      if (mediaId.startsWith('forge:album:')) {
        final key = mediaId.substring('forge:album:'.length);
        final album = groupAlbums(await _db.allTracks()).where((item) => item.key == key).firstOrNull;
        if (album == null || album.tracks.isEmpty) return;
        await _playLoaded(album.tracks, 0);
        return;
      }
      if (mediaId.startsWith('forge:playlist:')) {
        final id = mediaId.substring('forge:playlist:'.length);
        final tracks = await _db.playlistTracks(id);
        if (tracks.isEmpty) return;
        await _playLoaded(tracks, 0);
        return;
      }
      final track = await _db.trackById(mediaId);
      if (track == null) return;
      if (track.source == TrackSource.local && track.album.trim().isNotEmpty) {
        final artist = track.albumArtist.trim().isEmpty ? track.artist : track.albumArtist;
        final album = groupAlbums(await _db.allTracks())
            .where((item) => item.name == track.album && item.artist == artist)
            .firstOrNull;
        if (album != null && album.tracks.isNotEmpty) {
          final index = album.tracks.indexWhere((item) => item.id == track.id);
          await _playLoaded(album.tracks, index < 0 ? 0 : index);
          return;
        }
      }
      await _playLoaded([track], 0);
    });
  }

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final tracks = await _db.allTracks();
    return tracks
        .where(
          (track) =>
              track.title.toLowerCase().contains(needle) || track.artist.toLowerCase().contains(needle),
        )
        .take(50)
        .map(_item)
        .toList();
  }
}
