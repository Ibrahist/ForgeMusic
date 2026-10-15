import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/db/app_database.dart';
import '../data/library_bus.dart';
import '../data/models/app_settings.dart';
import '../data/models/library.dart';
import '../data/models/media.dart';
import '../data/models/playlist.dart';
import '../data/models/track.dart';
import '../data/services/artist_alerts.dart';
import '../data/services/artwork_store.dart';
import '../data/services/device_bridge.dart';
import '../data/services/dislike_client.dart';
import '../data/services/download_manager.dart';
import '../data/services/sponsor_client.dart';
import '../data/services/library_scanner.dart';
import '../data/services/lyrics_client.dart';
import '../data/services/media_resolver.dart';
import '../data/services/tag_editor.dart';
import '../data/services/youtube_service.dart';
import '../data/settings_store.dart';
import '../player/forge_audio_handler.dart';
import '../player/player_snapshot.dart';
import '../ui/theme/forge_theme.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('The database is opened before the app starts.');
});

final libraryBusProvider = Provider<LibraryBus>((ref) {
  final bus = LibraryBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

final initialSettingsProvider = Provider<AppSettings>((ref) => AppSettings.defaults);

final artworkProvider = Provider<ArtworkStore>((ref) => ArtworkStore());

final youtubeProvider = Provider<YoutubeService>((ref) {
  final service = YoutubeService();
  ref.onDispose(service.close);
  return service;
});

final downloadsProvider = Provider<DownloadManager>((ref) {
  return DownloadManager(ref.watch(databaseProvider), ref.watch(youtubeProvider));
});

final resolverProvider = Provider<MediaResolver>((ref) {
  return MediaResolver(
    ref.watch(databaseProvider),
    ref.watch(youtubeProvider),
    ref.watch(downloadsProvider),
  );
});

final playerProvider = Provider<ForgeAudioHandler>((ref) {
  throw StateError('The player is started before the app starts.');
});

final deviceProvider = Provider<DeviceBridge>((ref) => DeviceBridge());

final sponsorProvider = Provider<SponsorClient>((ref) => SponsorClient());

final dislikeProvider = Provider<DislikeClient>((ref) => DislikeClient());

final artistAlertsProvider = Provider<ArtistAlerts>((ref) {
  return ArtistAlerts(
    ref.watch(databaseProvider),
    ref.watch(youtubeProvider),
    ref.watch(deviceProvider),
  );
});

final lyricsProvider = Provider<LyricsClient>((ref) => LyricsClient());

final tagEditorProvider = Provider<TagEditor>((ref) {
  return TagEditor(ref.watch(databaseProvider), ref.watch(libraryBusProvider));
});

final scannerProvider = Provider<LibraryScanner>((ref) {
  return LibraryScanner(
    database: ref.watch(databaseProvider),
    bus: ref.watch(libraryBusProvider),
    artwork: ref.watch(artworkProvider),
  );
});

final playbackProvider = StreamProvider<PlayerSnapshot>((ref) {
  return ref.watch(playerProvider).snapshots;
});

final transferProvider = StreamProvider<TransferProgress?>((ref) {
  return ref.watch(downloadsProvider).progress;
});

class LibraryState {
  const LibraryState({
    required this.index,
    required this.playlists,
    required this.history,
    required this.scanning,
    this.message,
  });

  final LibraryIndex index;
  final List<Playlist> playlists;
  final List<HistoryEntry> history;
  final bool scanning;
  final String? message;

  static const empty = LibraryState(
    index: LibraryIndex.empty,
    playlists: [],
    history: [],
    scanning: false,
  );

  LibraryState copyWith({
    LibraryIndex? index,
    List<Playlist>? playlists,
    List<HistoryEntry>? history,
    bool? scanning,
    String? message,
    bool clearMessage = false,
  }) {
    return LibraryState(
      index: index ?? this.index,
      playlists: playlists ?? this.playlists,
      history: history ?? this.history,
      scanning: scanning ?? this.scanning,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    final sub = ref.read(libraryBusProvider).stream.listen((_) {
      unawaited(reload());
    });
    ref.onDispose(sub.cancel);
    Future<void>.microtask(() async {
      await reload();
      await _maybeAutoScan();
    });
    return LibraryState.empty;
  }

  Future<void> reload({String? message, bool? scanning, bool clearMessage = false}) async {
    final db = ref.read(databaseProvider);
    final tracks = await db.allTracks();
    final folders = await db.folders();
    final playlists = await db.playlists();
    final history = await db.recentHistory();
    state = LibraryState(
      index: LibraryIndex.fromTracks(tracks, folders: folders),
      playlists: playlists,
      history: history,
      scanning: scanning ?? state.scanning,
      message: clearMessage ? null : (message ?? state.message),
    );
    unawaited(_noteArtists(tracks));
  }

  Future<void> _noteArtists(List<Track> tracks) async {
    try {
      await ref.read(artistAlertsProvider).check(tracks);
    } catch (_) {}
  }

  Future<void> scan() async {
    state = state.copyWith(scanning: true, clearMessage: true);
    try {
      final result = await ref.read(scannerProvider).scan(ref.read(settingsProvider));
      await reload(scanning: false, message: result.summary);
    } catch (error) {
      await reload(
        scanning: false,
        message: error is Exception ? '$error' : 'The scan stopped early. Try it again.',
      );
    }
  }

  Future<void> _maybeAutoScan() async {
    final hasLocal = state.index.songs.any((track) => track.source == TrackSource.local);
    if (hasLocal || state.scanning) return;
    try {
      final granted = await Permission.audio.isGranted || await Permission.storage.isGranted;
      if (!granted) return;
    } catch (_) {
      return;
    }
    await scan();
  }
}

final libraryProvider = NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(AppSettings next) async {
    state = next;
    await ref.read(settingsStoreProvider).save(next);
    await ref.read(playerProvider).applySettings(next);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class AccentController extends Notifier<Color> {
  @override
  Color build() => ForgeColors.ember;

  void apply(Color color) => state = tuneAccent(color);

  void reset() => state = ForgeColors.ember;
}

final accentProvider = NotifierProvider<AccentController, Color>(AccentController.new);

class VideoLaunchController extends Notifier<VideoLaunch?> {
  @override
  VideoLaunch? build() => null;

  void open(VideoLaunch launch) => state = launch;
}

final videoLaunchProvider = NotifierProvider<VideoLaunchController, VideoLaunch?>(
  VideoLaunchController.new,
);
