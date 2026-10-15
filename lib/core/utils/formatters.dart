String formatDuration(Duration duration) {
  final negative = duration.isNegative;
  final total = duration.inSeconds.abs();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final clock = hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
      : '$minutes:${seconds.toString().padLeft(2, '0')}';
  return negative ? '-$clock' : clock;
}

String formatRemaining(Duration total, Duration position) {
  final left = total - position;
  if (left <= Duration.zero) return '-0:00';
  return '-${formatDuration(left)}';
}

String formatCount(int value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs < 1000) return '$value';
  if (abs < 1000000) {
    final scaled = abs / 1000;
    final text = scaled >= 10 ? scaled.toStringAsFixed(0) : scaled.toStringAsFixed(1);
    return '$sign${text.replaceAll(RegExp(r'\.0$'), '')}K';
  }
  final scaled = abs / 1000000;
  final text = scaled >= 10 ? scaled.toStringAsFixed(0) : scaled.toStringAsFixed(1);
  return '$sign${text.replaceAll(RegExp(r'\.0$'), '')}M';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 5) return 'Still listening';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 22) return 'Good evening';
  return 'Late session';
}
