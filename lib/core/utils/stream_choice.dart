/// A playback choice reduced to the numbers the picker needs.
class RatedStream<T> {
  const RatedStream({
    required this.value,
    required this.bitsPerSecond,
    this.qualityRank = 0,
  });

  final T value;
  final int bitsPerSecond;
  final int qualityRank;
}

/// Picks a stream for full quality or data saver.
T pickPreferred<T>(
  List<RatedStream<T>> items, {
  required bool dataSaver,
  int? maxBits,
}) {
  if (items.isEmpty) {
    throw StateError('No streams to choose from.');
  }
  final sorted = [...items]..sort((a, b) {
    final byQuality = a.qualityRank.compareTo(b.qualityRank);
    if (byQuality != 0) return byQuality;
    return a.bitsPerSecond.compareTo(b.bitsPerSecond);
  });
  if (!dataSaver) return sorted.last.value;
  if (maxBits == null) return sorted.first.value;
  final under = sorted
      .where((item) => item.bitsPerSecond > 0 && item.bitsPerSecond <= maxBits)
      .toList();
  if (under.isEmpty) return sorted.first.value;
  return under.last.value;
}
