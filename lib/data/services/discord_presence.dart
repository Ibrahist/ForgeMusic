import 'dart:convert';

import 'package:http/http.dart' as http;

/// True when [raw] is a Discord incoming webhook the user created.
bool discordWebhookAllowed(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host != 'discord.com' && host != 'discordapp.com') return false;
  final parts = uri.path.split('/').where((part) => part.isNotEmpty).toList();
  return parts.length >= 4 && parts[0] == 'api' && parts[1] == 'webhooks';
}

/// Posts now-playing to a channel webhook and edits that same message.
///
/// Android apps cannot set the Discord profile badge. This only updates a
/// webhook the listener created.
class DiscordPresence {
  DiscordPresence({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  String? _webhook;
  String? _messageId;

  Future<void> update({
    required String webhook,
    required String title,
    required String artist,
    required String album,
    required bool playing,
  }) async {
    final target = _root(webhook);
    if (!discordWebhookAllowed(target)) return;
    if (_webhook != target) {
      _webhook = target;
      _messageId = null;
    }
    final payload = jsonEncode({
      'embeds': [
        {
          'title': title,
          'description': [
            artist,
            if (album.trim().isNotEmpty) album,
            playing ? 'Playing' : 'Paused',
          ].join(' · '),
          'footer': {'text': 'Forgemusic'},
        },
      ],
    });
    try {
      final existing = _messageId;
      if (existing != null) {
        final patched = await _patch('$target/messages/$existing', payload);
        if (patched) return;
        _messageId = null;
      }
      final created = await _http
          .post(
            Uri.parse('$target?wait=true'),
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': 'Forgemusic/1.0',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 8));
      if (created.statusCode < 200 || created.statusCode >= 300) return;
      final body = jsonDecode(created.body);
      if (body is Map && body['id'] != null) {
        _messageId = '${body['id']}';
      }
    } catch (_) {}
  }

  Future<bool> _patch(String url, String payload) async {
    final response = await _http
        .patch(
          Uri.parse(url),
          headers: const {
            'Content-Type': 'application/json',
            'User-Agent': 'Forgemusic/1.0',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 8));
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  String _root(String webhook) {
    final trimmed = webhook.trim();
    if (trimmed.endsWith('/')) return trimmed.substring(0, trimmed.length - 1);
    return trimmed;
  }
}
