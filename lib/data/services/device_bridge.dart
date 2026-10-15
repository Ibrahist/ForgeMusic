import 'package:flutter/services.dart';

import '../../core/app_failure.dart';
import '../models/media.dart';

/// Talks to Android for videos, volume, and keeping the screen awake.
class DeviceBridge {
  DeviceBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.forgemusic/device');

  final MethodChannel _channel;

  Future<List<LocalVideo>> videos() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('queryVideos');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((row) => LocalVideo.fromMap(row))
          .where((video) => video.uri.isNotEmpty)
          .toList();
    } on PlatformException catch (error) {
      throw AppFailure(error.message ?? 'Videos are not available yet.');
    } on MissingPluginException {
      return const [];
    }
  }

  Future<double> volume() async {
    try {
      final value = await _channel.invokeMethod<num>('getVolume');
      return (value ?? 0).toDouble().clamp(0, 1);
    } catch (_) {
      return 0;
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod<void>('setVolume', {'volume': volume.clamp(0, 1)});
    } catch (_) {}
  }

  Future<void> keepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {'on': on});
    } catch (_) {}
  }
}
