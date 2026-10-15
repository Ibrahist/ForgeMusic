import 'package:flutter_test/flutter_test.dart';
import 'package:forgemusic/core/utils/formatters.dart';
import 'package:forgemusic/core/utils/skip_window.dart';
import 'package:forgemusic/core/utils/stream_choice.dart';
import 'package:forgemusic/data/models/app_settings.dart';
import 'package:forgemusic/data/services/discord_presence.dart';

void main() {
  test('sponsor skip jumps to the end and leaves the tail alone', () {
    final segments = [
      const SkipSegment(
        start: Duration(seconds: 10),
        end: Duration(seconds: 20),
        category: 'sponsor',
      ),
    ];
    expect(nextSkip(segments, const Duration(seconds: 12)), const Duration(seconds: 20));
    expect(nextSkip(segments, const Duration(seconds: 9)), isNull);
    expect(nextSkip(segments, const Duration(milliseconds: 19400)), isNull);
  });

  test('sponsor json keeps skip segments only', () {
    final parsed = parseSponsorSegments([
      {
        'category': 'intro',
        'actionType': 'skip',
        'segment': [0, 8.5],
      },
      {
        'category': 'sponsor',
        'actionType': 'mute',
        'segment': [30, 40],
      },
      {
        'category': 'poi',
        'actionType': 'poi',
        'segment': [1, 2],
      },
    ]);
    expect(parsed, hasLength(1));
    expect(parsed.single.category, 'intro');
    expect(parsed.single.end, const Duration(milliseconds: 8500));
    expect(parseSponsorSegments(null), isEmpty);
  });

  test('dislike json reads like and dislike estimates', () {
    final votes = parseVoteCounts({
      'id': 'abc',
      'likes': 1200,
      'dislikes': 34,
      'rating': 4.2,
      'viewCount': 9000,
    });
    expect(votes?.likes, 1200);
    expect(votes?.dislikes, 34);
    expect(parseVoteCounts({'likes': 'nope'}), isNull);
    expect(formatCount(1200), '1.2K');
    expect(formatCount(34), '34');
  });

  test('balanced audio stays under 160 kbps and saver keeps its cache key', () {
    final audio = [
      const RatedStream(value: 'low', bitsPerSecond: 48000),
      const RatedStream(value: 'mid', bitsPerSecond: 128000),
      const RatedStream(value: 'high', bitsPerSecond: 256000),
    ];
    expect(
      pickPreferred(audio, dataSaver: AudioQuality.balanced.capsBitrate, maxBits: AudioQuality.balanced.maxBits),
      'mid',
    );
    expect(AudioQuality.saver.cacheKind, 'audio-saver');
    expect(AudioQuality.highest.cacheKind, 'audio');
    expect(AudioQuality.balanced.cacheKind, 'audio');

    final stored = AppSettings.fromJson({'dataSaver': true});
    expect(stored.audioQuality, AudioQuality.saver);
    expect(stored.dataSaver, isTrue);
    final highest = AppSettings.defaults.copyWith(audioQuality: AudioQuality.highest);
    expect(highest.dataSaver, isFalse);
    expect(highest.copyWith(audioQuality: AudioQuality.saver).dataSaver, isTrue);
  });

  test('discord updates only accept a channel webhook', () {
    expect(
      discordWebhookAllowed('https://discord.com/api/webhooks/123/abc'),
      isTrue,
    );
    expect(
      discordWebhookAllowed('https://discordapp.com/api/webhooks/123/abc'),
      isTrue,
    );
    expect(discordWebhookAllowed('https://example.com/api/webhooks/123/abc'), isFalse);
    expect(discordWebhookAllowed('http://discord.com/api/webhooks/123/abc'), isFalse);
    expect(discordWebhookAllowed('not a url'), isFalse);
  });
}
