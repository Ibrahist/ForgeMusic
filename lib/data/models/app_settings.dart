import 'package:flutter/material.dart';

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
    required this.cacheYoutube,
    required this.cacheLimitMb,
    required this.minDurationSec,
    required this.includeNonMusic,
    required this.sleepFade,
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
  final bool cacheYoutube;
  final int cacheLimitMb;
  final int minDurationSec;
  final bool includeNonMusic;
  final bool sleepFade;

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
    cacheYoutube: true,
    cacheLimitMb: 512,
    minDurationSec: 30,
    includeNonMusic: false,
    sleepFade: true,
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
    bool? cacheYoutube,
    int? cacheLimitMb,
    int? minDurationSec,
    bool? includeNonMusic,
    bool? sleepFade,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      crossfade: crossfade ?? this.crossfade,
      crossfadeMs: crossfadeMs ?? this.crossfadeMs,
      skipSilence: skipSilence ?? this.skipSilence,
      normalize: normalize ?? this.normalize,
      normalizeGainDb: normalizeGainDb ?? this.normalizeGainDb,
      youtubeAudioOnly: youtubeAudioOnly ?? this.youtubeAudioOnly,
      dataSaver: dataSaver ?? this.dataSaver,
      cacheYoutube: cacheYoutube ?? this.cacheYoutube,
      cacheLimitMb: cacheLimitMb ?? this.cacheLimitMb,
      minDurationSec: minDurationSec ?? this.minDurationSec,
      includeNonMusic: includeNonMusic ?? this.includeNonMusic,
      sleepFade: sleepFade ?? this.sleepFade,
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
    'cacheYoutube': cacheYoutube,
    'cacheLimitMb': cacheLimitMb,
    'minDurationSec': minDurationSec,
    'includeNonMusic': includeNonMusic,
    'sleepFade': sleepFade,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.dark,
      dynamicColor: json['dynamicColor'] as bool? ?? true,
      crossfade: json['crossfade'] as bool? ?? false,
      crossfadeMs: (json['crossfadeMs'] as num?)?.toInt() ?? 5000,
      skipSilence: json['skipSilence'] as bool? ?? false,
      normalize: json['normalize'] as bool? ?? false,
      normalizeGainDb: (json['normalizeGainDb'] as num?)?.toDouble() ?? 4,
      youtubeAudioOnly: json['youtubeAudioOnly'] as bool? ?? true,
      dataSaver: json['dataSaver'] as bool? ?? false,
      cacheYoutube: json['cacheYoutube'] as bool? ?? true,
      cacheLimitMb: (json['cacheLimitMb'] as num?)?.toInt() ?? 512,
      minDurationSec: (json['minDurationSec'] as num?)?.toInt() ?? 30,
      includeNonMusic: json['includeNonMusic'] as bool? ?? false,
      sleepFade: json['sleepFade'] as bool? ?? true,
    );
  }
}
