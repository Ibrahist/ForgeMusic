import 'track.dart';

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdMs,
    required this.updatedMs,
    this.artworkPath,
    this.trackCount = 0,
  });

  final String id;
  final String name;
  final int createdMs;
  final int updatedMs;
  final String? artworkPath;
  final int trackCount;

  factory Playlist.fromMap(Map<String, Object?> map) {
    return Playlist(
      id: map['id']! as String,
      name: map['name']! as String,
      createdMs: (map['created_ms'] as num).toInt(),
      updatedMs: (map['updated_ms'] as num).toInt(),
      artworkPath: map['artwork_path'] as String?,
      trackCount: (map['track_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HistoryEntry {
  const HistoryEntry({required this.track, required this.playedMs});

  final Track track;
  final int playedMs;
}

class QueueSnapshot {
  const QueueSnapshot({
    required this.ids,
    required this.index,
    required this.positionMs,
    required this.repeat,
    required this.shuffle,
  });

  final List<String> ids;
  final int index;
  final int positionMs;
  final String repeat;
  final bool shuffle;
}
