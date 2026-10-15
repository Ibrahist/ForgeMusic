/// One file sitting in the YouTube cache.
class CacheItem {
  const CacheItem({
    required this.id,
    required this.bytes,
    required this.lastAccessMs,
  });

  final String id;
  final int bytes;
  final int lastAccessMs;
}

/// Drops the least recently used files until a new download fits.
class CachePolicy {
  static List<String> evict({
    required List<CacheItem> items,
    required int incomingBytes,
    required int limitBytes,
  }) {
    if (limitBytes <= 0) return items.map((item) => item.id).toList();
    final sorted = [...items]
      ..sort((a, b) => a.lastAccessMs.compareTo(b.lastAccessMs));
    var used = items.fold<int>(0, (sum, item) => sum + item.bytes) + incomingBytes;
    final drop = <String>[];
    for (final item in sorted) {
      if (used <= limitBytes) break;
      drop.add(item.id);
      used -= item.bytes;
    }
    return drop;
  }
}
