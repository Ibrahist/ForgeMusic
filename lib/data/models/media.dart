class YoutubeHit {
  const YoutubeHit({
    required this.videoId,
    required this.title,
    required this.author,
    required this.durationMs,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String author;
  final int durationMs;
  final String? thumbnailUrl;

  Duration get duration => Duration(milliseconds: durationMs);
}

class LocalVideo {
  const LocalVideo({
    required this.id,
    required this.title,
    required this.uri,
    required this.durationMs,
    required this.sizeBytes,
    this.width = 0,
    this.height = 0,
    this.folder = '',
  });

  final String id;
  final String title;
  final String uri;
  final int durationMs;
  final int sizeBytes;
  final int width;
  final int height;
  final String folder;

  factory LocalVideo.fromMap(Map<dynamic, dynamic> map) {
    return LocalVideo(
      id: '${map['id']}',
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : 'Video',
      uri: map['uri'] as String? ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      folder: map['folder'] as String? ?? '',
    );
  }
}

class DownloadRecord {
  const DownloadRecord({
    required this.id,
    required this.videoId,
    required this.title,
    required this.author,
    required this.audioOnly,
    required this.filePath,
    required this.bytes,
    required this.createdMs,
    required this.durationMs,
    this.thumbnailUrl,
  });

  final String id;
  final String videoId;
  final String title;
  final String author;
  final bool audioOnly;
  final String filePath;
  final int bytes;
  final int createdMs;
  final int durationMs;
  final String? thumbnailUrl;

  factory DownloadRecord.fromMap(Map<String, Object?> map) {
    return DownloadRecord(
      id: map['id']! as String,
      videoId: map['video_id']! as String,
      title: map['title']! as String,
      author: map['author']! as String,
      audioOnly: map['audio_only'] == 1,
      filePath: map['file_path']! as String,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      createdMs: (map['created_ms'] as num).toInt(),
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnail_url'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'video_id': videoId,
    'title': title,
    'author': author,
    'audio_only': audioOnly ? 1 : 0,
    'file_path': filePath,
    'bytes': bytes,
    'created_ms': createdMs,
    'duration_ms': durationMs,
    'thumbnail_url': thumbnailUrl,
  };
}

class CacheEntry {
  const CacheEntry({
    required this.videoId,
    required this.kind,
    required this.bytes,
    required this.lastAccessMs,
    this.filePath,
    this.streamUrl,
    this.expiresMs,
  });

  final String videoId;
  final String kind;
  final String? filePath;
  final String? streamUrl;
  final int? expiresMs;
  final int bytes;
  final int lastAccessMs;

  String get id => '$videoId|$kind';

  bool get urlFresh {
    final expires = expiresMs;
    if (streamUrl == null || expires == null) return false;
    return expires > DateTime.now().millisecondsSinceEpoch;
  }

  factory CacheEntry.fromMap(Map<String, Object?> map) {
    return CacheEntry(
      videoId: map['video_id']! as String,
      kind: map['kind']! as String,
      filePath: map['file_path'] as String?,
      streamUrl: map['stream_url'] as String?,
      expiresMs: (map['expires_ms'] as num?)?.toInt(),
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      lastAccessMs: (map['last_access_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toMap() => {
    'video_id': videoId,
    'kind': kind,
    'file_path': filePath,
    'stream_url': streamUrl,
    'expires_ms': expiresMs,
    'bytes': bytes,
    'last_access_ms': lastAccessMs,
  };
}

class VideoLaunch {
  const VideoLaunch.local(this.video)
    : title = null,
      subtitle = null,
      youtubeId = null,
      dataSaver = false;

  const VideoLaunch.youtube({
    required this.youtubeId,
    required this.title,
    this.subtitle,
    this.dataSaver = false,
  }) : video = null;

  final LocalVideo? video;
  final String? title;
  final String? subtitle;
  final String? youtubeId;
  final bool dataSaver;
}
