import 'dart:math' as math;

/// Equal-power fade so the handoff between two songs stays even.
class CrossfadeCurve {
  static double incoming(double t) => math.sin(_clamp(t) * math.pi / 2);

  static double outgoing(double t) => math.cos(_clamp(t) * math.pi / 2);

  static double _clamp(double t) => t.clamp(0, 1).toDouble();
}

/// Decides when the next song should start overlapping the current one.
class CrossfadeWindow {
  static bool shouldStart({
    required bool enabled,
    required int crossfadeMs,
    required bool alreadyFading,
    required bool repeatOne,
    required Duration position,
    required Duration? duration,
    required bool hasNext,
  }) {
    if (!enabled || crossfadeMs <= 0 || alreadyFading || repeatOne || !hasNext) {
      return false;
    }
    final total = duration;
    if (total == null || total <= Duration.zero) return false;
    final remaining = total - position;
    return remaining <= Duration(milliseconds: crossfadeMs) &&
        remaining > Duration.zero;
  }
}
