import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/skip_window.dart';

const _categories = [
  'sponsor',
  'selfpromo',
  'intro',
  'outro',
  'interaction',
  'music_offtopic',
];

/// Loads public SponsorBlock skip ranges. Failures stay quiet.
class SponsorClient {
  SponsorClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  final Map<String, List<SkipSegment>> _cache = {};

  Future<List<SkipSegment>> segments(String videoId) async {
    final cached = _cache[videoId];
    if (cached != null) return cached;
    try {
      final uri = Uri.https('sponsor.ajay.app', '/api/skipSegments', {
        'videoID': videoId,
        'categories': jsonEncode(_categories),
      });
      final response = await _http
          .get(uri, headers: const {'User-Agent': 'Forgemusic/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 404) {
        _cache[videoId] = const [];
        return const [];
      }
      if (response.statusCode != 200) return const [];
      final parsed = parseSponsorSegments(jsonDecode(response.body));
      _cache[videoId] = parsed;
      return parsed;
    } catch (_) {
      return const [];
    }
  }
}
