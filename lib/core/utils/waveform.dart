import 'dart:math' as math;

/// A stable, song-shaped bar pattern used by the seek bar.
List<double> syntheticPeaks(String seed, int count) {
  final random = math.Random(seed.hashCode);
  final raw = List<double>.generate(count, (index) {
    final t = index / count;
    final envelope = 0.38 + 0.62 * math.sin(math.pi * t);
    final noise = 0.42 + random.nextDouble() * 0.58;
    final phrase = 0.55 + 0.45 * math.sin(t * math.pi * (2 + (seed.hashCode.abs() % 3)));
    return (noise * phrase * envelope).clamp(0.12, 1.0);
  });
  return List<double>.generate(count, (index) {
    final left = raw[math.max(0, index - 1)];
    final mid = raw[index];
    final right = raw[math.min(count - 1, index + 1)];
    return (left + mid * 2 + right) / 4;
  });
}
