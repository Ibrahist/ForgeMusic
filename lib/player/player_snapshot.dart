import '../data/models/track.dart';

/// What the screens need to know about the player right now.
class PlayerSnapshot {
  const PlayerSnapshot({
    required this.queue,
    required this.index,
    required this.position,
    required this.duration,
    required this.playing,
    required this.buffering,
    required this.repeat,
    required this.shuffle,
    required this.sleepEndsAt,
    required this.sleepEndOfTrack,
    this.message,
    this.offline = false,
    this.streamBits,
  });

  final List<Track> queue;
  final int index;
  final Duration position;
  final Duration? duration;
  final bool playing;
  final bool buffering;
  final RepeatMode repeat;
  final bool shuffle;
  final DateTime? sleepEndsAt;
  final bool sleepEndOfTrack;
  final String? message;
  final bool offline;
  final int? streamBits;

  static const empty = PlayerSnapshot(
    queue: [],
    index: 0,
    position: Duration.zero,
    duration: null,
    playing: false,
    buffering: false,
    repeat: RepeatMode.off,
    shuffle: false,
    sleepEndsAt: null,
    sleepEndOfTrack: false,
  );

  Track? get track {
    if (queue.isEmpty) return null;
    final safe = index.clamp(0, queue.length - 1);
    return queue[safe];
  }

  Duration? get sleepRemaining {
    final ends = sleepEndsAt;
    if (ends == null) return null;
    final left = ends.difference(DateTime.now());
    if (left.isNegative) return Duration.zero;
    return left;
  }
}
