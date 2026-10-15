import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/skip_window.dart';

/// Asks Return YouTube Dislike for estimated like and dislike counts.
class DislikeClient {
  DislikeClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  final Map<String, VoteCounts?> _cache = {};

  Future<VoteCounts?> votes(String videoId) async {
    if (_cache.containsKey(videoId)) return _cache[videoId];
    try {
      final uri = Uri.https('returnyoutubedislikeapi.com', '/votes', {
        'videoId': videoId,
      });
      final response = await _http
          .get(uri, headers: const {'User-Agent': 'Forgemusic/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 404 ||
          response.statusCode == 400 ||
          response.statusCode == 429) {
        _cache[videoId] = null;
        return null;
      }
      if (response.statusCode != 200) return null;
      final parsed = parseVoteCounts(jsonDecode(response.body));
      _cache[videoId] = parsed;
      return parsed;
    } catch (_) {
      return null;
    }
  }
}
