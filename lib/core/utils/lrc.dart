/// One timed line from an LRC lyrics file.
class LrcLine {
  const LrcLine(this.time, this.text);

  final Duration time;
  final String text;
}

/// Parses synced lyrics and finds the line that should be highlighted.
class LrcParser {
  static final _tag = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

  static List<LrcLine> parse(String input) {
    final lines = <LrcLine>[];
    for (final raw in input.split(RegExp(r'\r?\n'))) {
      final matches = _tag.allMatches(raw).toList();
      if (matches.isEmpty) continue;
      final text = raw.replaceAll(_tag, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3);
        var millis = 0;
        if (fraction != null) {
          millis = int.parse(fraction.padRight(3, '0').substring(0, 3));
        }
        lines.add(
          LrcLine(
            Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
            text,
          ),
        );
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  /// Returns -1 before the first timestamp.
  static int indexAt(List<LrcLine> lines, Duration position) {
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }
}
