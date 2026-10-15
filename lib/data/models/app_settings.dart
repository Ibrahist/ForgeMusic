import 'package:flutter/material.dart';

/// How large a YouTube audio stream Forgemusic should ask for.
enum AudioQuality { saver, balanced, highest }

extension AudioQualityChoice on AudioQuality {
  /// Saver and balanced cap the bitrate. Highest takes the largest stream.
  bool get capsBitrate => this != AudioQuality.highest;

  int? get maxBits => switch (this) {
    AudioQuality.saver => 64000,
    AudioQuality.balanced => 160000,
    AudioQuality.highest => null,
  };

  /// Saver keeps its own cache key. Balanced reuses the full-quality cache
  /// so streams saved before this setting still open offline.
  String get cacheKind => this == AudioQuality.saver ? 'audio-saver' : 'audio';

  String get label => switch (this) {
    AudioQuality.saver => 'Saver',
    AudioQuality.balanced => 'Balanced',
    AudioQuality.highest => 'Highest',
  };
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.dynamicColor,
    required this.crossfade,
    required this.crossfadeMs,
    required this.skipSilence,
    required this.normalize,
    required this.normalizeGainDb,
    required this.youtubeAudioOnly,
    required this.dataSaver,
    required this.audioQuality,
    required this.cacheYoutube,
    required this.cacheLimitMb,
    required this.minDurationSec,
    required this.includeNonMusic,
    required this.sleepFade,
    required this.sponsorBlock,
    required this.canvasMotion,
    required this.discordWebhook,
    required this.discordShare,
  });

  final ThemeMode themeMode;
  final bool dynamicColor;
  final bool crossfade;
  final int crossfadeMs;
  final bool skipSilence;
  final bool normalize;
  final double normalizeGainDb;
  final bool youtubeAudioOnly;
  final bool dataSaver;
  final AudioQuality audioQuality;
  final bool cacheYoutube;
  final int cacheLimitMb;
  final int minDurationSec;
  final bool includeNonMusic;
  final bool sleepFade;
  final bool sponsorBlock;
  final bool canvasMotion;
  final String discordWebhook;
  final bool discordShare;

  static const defaults = AppSettings(
    themeMode: ThemeMode.dark,
    dynamicColor: true,
    crossfade: false,
    crossfadeMs: 5000,
    skipSilence: false,
    normalize: false,
    normalizeGainDb: 4,
    youtubeAudioOnly: true,
    dataSaver: false,
    audioQuality: AudioQuality.highest,
    cacheYoutube: true,
    cacheLimitMb: 512,
    minDurationSec: 30,
    includeNonMusic: false,
    sleepFade: true,
    sponsorBlock: true,
    canvasMotion: true,
    discordWebhook: '',
    discordShare: false,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? dynamicColor,
    bool? crossfade,
    int? crossfadeMs,
    bool? skipSilence,
    bool? normalize,
    double? normalizeGainDb,
    bool? youtubeAudioOnly,
    bool? dataSaver,
    AudioQuality? audioQuality,
    bool? cacheYoutube,
    int? cacheLimitMb,
    int? minDurationSec,
    bool? includeNonMusic,
    bool? sleepFade,
    bool? sponsorBlock,
    bool? canvasMotion,
    String? discordWebhook,
    bool? discordShare,
  }) {
    var quality = audioQuality ?? this.audioQuality;
    var saver = dataSaver ?? this.dataSaver;
    if (audioQuality != null) {
      saver = audioQuality == AudioQuality.saver;
    } else if (dataSaver != null) {
      if (dataSaver) {
        quality = AudioQuality.saver;
      } else if (quality == AudioQuality.saver) {
        quality = AudioQuality.highest;
      }
    }
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      crossfade: crossfade ?? this.crossfade,
      crossfadeMs: crossfadeMs ?? this.crossfadeMs,
      skipSilence: skipSilence ?? this.skipSilence,
      normalize: normalize ?? this.normalize,
      normalizeGainDb: normalizeGainDb ?? this.normalizeGainDb,
      youtubeAudioOnly: youtubeAudioOnly ?? this.youtubeAudioOnly,
      dataSaver: saver,
      audioQuality: quality,
      cacheYoutube: cacheYoutube ?? this.cacheYoutube,
      cacheLimitMb: cacheLimitMb ?? this.cacheLimitMb,
      minDurationSec: minDurationSec ?? this.minDurationSec,
      includeNonMusic: includeNonMusic ?? this.includeNonMusic,
      sleepFade: sleepFade ?? this.sleepFade,
      sponsorBlock: sponsorBlock ?? this.sponsorBlock,
      canvasMotion: canvasMotion ?? this.canvasMotion,
      discordWebhook: discordWebhook ?? this.discordWebhook,
      discordShare: discordShare ?? this.discordShare,
    );
  }

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'dynamicColor': dynamicColor,
    'crossfade': crossfade,
    'crossfadeMs': crossfadeMs,
    'skipSilence': skipSilence,
    'normalize': normalize,
    'normalizeGainDb': normalizeGainDb,
    'youtubeAudioOnly': youtubeAudioOnly,
    'dataSaver': dataSaver,
    'audioQuality': audioQuality.name,
    'cacheYoutube': cacheYoutube,
    'cacheLimitMb': cacheLimitMb,
    'minDurationSec': minDurationSec,
    'includeNonMusic': includeNonMusic,
    'sleepFade': sleepFade,
    'sponsorBlock': sponsorBlock,
    'canvasMotion': canvasMotion,
    'discordWebhook': discordWebhook,
    'discordShare': discordShare,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final named = AudioQuality.values.asNameMap()[json['audioQuality'] as String?];
    final legacySaver = json['dataSaver'] as bool? ?? false;
    final quality = named ?? (legacySaver ? AudioQuality.saver : AudioQuality.highest);
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.dark,
      dynamicColor: json['dynamicColor'] as bool? ?? true,
      crossfade: json['crossfade'] as bool? ?? false,
      crossfadeMs: (json['crossfadeMs'] as num?)?.toInt() ?? 5000,
      skipSilence: json['skipSilence'] as bool? ?? false,
      normalize: json['normalize'] as bool? ?? false,
      normalizeGainDb: (json['normalizeGainDb'] as num?)?.toDouble() ?? 4,
      youtubeAudioOnly: json['youtubeAudioOnly'] as bool? ?? true,
      dataSaver: quality == AudioQuality.saver,
      audioQuality: quality,
      cacheYoutube: json['cacheYoutube'] as bool? ?? true,
      cacheLimitMb: (json['cacheLimitMb'] as num?)?.toInt() ?? 512,
      minDurationSec: (json['minDurationSec'] as num?)?.toInt() ?? 30,
      includeNonMusic: json['includeNonMusic'] as bool? ?? false,
      sleepFade: json['sleepFade'] as bool? ?? true,
      sponsorBlock: json['sponsorBlock'] as bool? ?? true,
      canvasMotion: json['canvasMotion'] as bool? ?? true,
      discordWebhook: json['discordWebhook'] as String? ?? '',
      discordShare: json['discordShare'] as bool? ?? false,
    );
  }
}
