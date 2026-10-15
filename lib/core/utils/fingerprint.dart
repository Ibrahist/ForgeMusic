/// Builds a stable identity for a song so copies can be collapsed.
String trackFingerprint({
  required String title,
  required String artist,
  required int durationMs,
}) {
  final bucket = (durationMs / 2000).round();
  return '${normalizeName(artist)}|${normalizeName(title)}|$bucket';
}

/// Lowercases, drops featured-artist asides, and keeps letters and digits.
String normalizeName(String input) {
  var value = input.toLowerCase();
  value = value.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
  value = value.replaceAll(RegExp(r'\b(feat|ft|featuring)\b.*$'), ' ');
  value = value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  return value;
}

/// Turns blank or placeholder media-store names into a friendly fallback.
String cleanMeta(String? value, {required String fallback}) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return fallback;
  switch (trimmed.toLowerCase()) {
    case '<unknown>':
    case 'unknown':
    case 'null':
      return fallback;
    default:
      return trimmed;
  }
}
