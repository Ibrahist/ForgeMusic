import 'dart:math' as math;

/// How loud a track should be once normalization is applied.
class GainPlan {
  const GainPlan({required this.volume, required this.enhancerDb});

  /// Linear player volume, from 0 to 1.
  final double volume;

  /// Extra Android loudness-enhancer gain in decibels.
  final double enhancerDb;

  static const unity = GainPlan(volume: 1, enhancerDb: 0);

  static GainPlan resolve({
    required double? replayGainDb,
    required bool enabled,
    required double fallbackDb,
  }) {
    if (!enabled) return unity;
    final replay = replayGainDb;
    if (replay == null) {
      return GainPlan(volume: 1, enhancerDb: fallbackDb.clamp(0, 12));
    }
    if (replay >= 0) {
      return GainPlan(volume: 1, enhancerDb: replay.clamp(0, 12));
    }
    final linear = math.pow(10, replay / 20).toDouble();
    return GainPlan(volume: linear.clamp(0.05, 1), enhancerDb: 0);
  }
}
