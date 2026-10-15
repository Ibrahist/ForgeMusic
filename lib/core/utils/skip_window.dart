/// A segment SponsorBlock says to jump over.
class SkipSegment {
  const SkipSegment({
    required this.start,
    required this.end,
    required this.category,
  });

  final Duration start;
  final Duration end;
  final String category;
}

const sponsorGrace = Duration(milliseconds: 750);

/// Returns the end of a skip segment when [position] is inside it.
///
/// The last [grace] of a segment is left alone so a seek does not repeat.
Duration? nextSkip(
  List<SkipSegment> segments,
  Duration position, {
  Duration grace = sponsorGrace,
}) {
  for (final segment in segments) {
    final tail = segment.end - grace;
    if (tail <= segment.start) continue;
    if (position >= segment.start && position < tail) return segment.end;
  }
  return null;
}

/// Reads SponsorBlock skip segments. Other action types are ignored.
List<SkipSegment> parseSponsorSegments(Object? json) {
  if (json is! List) return const [];
  final segments = <SkipSegment>[];
  for (final item in json) {
    if (item is! Map) continue;
    final action = item['actionType'];
    if (action != null && action != 'skip') continue;
    final raw = item['segment'];
    if (raw is! List || raw.length < 2) continue;
    final start = _seconds(raw[0]);
    final end = _seconds(raw[1]);
    if (start == null || end == null || end <= start) continue;
    segments.add(
      SkipSegment(
        start: Duration(milliseconds: (start * 1000).round()),
        end: Duration(milliseconds: (end * 1000).round()),
        category: '${item['category'] ?? 'sponsor'}',
      ),
    );
  }
  segments.sort((a, b) => a.start.compareTo(b.start));
  return segments;
}

double? _seconds(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

/// Like and dislike estimates from Return YouTube Dislike.
class VoteCounts {
  const VoteCounts({required this.likes, required this.dislikes});

  final int likes;
  final int dislikes;
}

VoteCounts? parseVoteCounts(Object? json) {
  if (json is! Map) return null;
  final likes = json['likes'];
  final dislikes = json['dislikes'];
  if (likes is! num || dislikes is! num) return null;
  return VoteCounts(likes: likes.round(), dislikes: dislikes.round());
}
