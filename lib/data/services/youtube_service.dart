import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/app_failure.dart';
import '../../core/utils/stream_choice.dart';
import '../models/app_settings.dart';
import '../models/media.dart';
import 'lyrics_client.dart';

/// A stream Forgemusic can play or save.
class ChosenStream {
  const ChosenStream({
    required this.info,
    required this.audioOnly,
    required this.hls,
  });

  final StreamInfo info;
  final bool audioOnly;
  final bool hls;

  Uri get url => info.url;

  int get bytes => info.size.totalBytes;

  String get extension {
    final name = info.container.name.toLowerCase();
    if (name.contains('webm')) return 'webm';
    if (name.contains('mp3')) return 'mp3';
    if (name.contains('m4a')) return 'm4a';
    if (name.contains('mp4')) return audioOnly ? 'm4a' : 'mp4';
    return audioOnly ? 'm4a' : 'mp4';
  }
}

/// Searches YouTube and picks a stream that matches the current quality.
class YoutubeService {
  YoutubeService({YoutubeExplode? client}) : _yt = client ?? YoutubeExplode();

  final YoutubeExplode _yt;
  final Map<String, Future<StreamManifest>> _manifests = {};

  Future<List<YoutubeHit>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final page = await _yt.search.search(trimmed);
      return page
          .take(16)
          .map(
            (video) => YoutubeHit(
              videoId: video.id.value,
              title: video.title,
              author: video.author,
              durationMs: video.duration?.inMilliseconds ?? 0,
              thumbnailUrl: video.thumbnails.highResUrl,
            ),
          )
          .toList();
    } catch (_) {
      throw AppFailure('YouTube search did not answer. Check the connection and try again.');
    }
  }

  Future<ChosenStream> chooseAudio(String videoId, {required AudioQuality quality}) async {
    final manifest = await _manifest(videoId);
    final audioOnly = manifest.audioOnly.toList();
    if (audioOnly.isNotEmpty) {
      final chosen = pickPreferred(
        audioOnly
            .map(
              (stream) => RatedStream(
                value: stream,
                bitsPerSecond: stream.bitrate.bitsPerSecond,
              ),
            )
            .toList(),
        dataSaver: quality.capsBitrate,
        maxBits: quality.maxBits,
      );
      return ChosenStream(info: chosen, audioOnly: true, hls: false);
    }
    final muxed = manifest.muxed.toList();
    if (muxed.isNotEmpty) {
      final chosen = pickPreferred(
        muxed
            .map(
              (stream) => RatedStream(
                value: stream,
                bitsPerSecond: stream.bitrate.bitsPerSecond,
              ),
            )
            .toList(),
        dataSaver: quality.capsBitrate,
        maxBits: quality.maxBits,
      );
      return ChosenStream(info: chosen, audioOnly: false, hls: false);
    }
    throw AppFailure('This YouTube video has no playable audio streams.');
  }

  /// The newest public upload for an artist name, used to baseline a follow.
  Future<({String? channelId, String? videoId, String? title})> newestUpload(String artist) async {
    final trimmed = artist.trim();
    if (trimmed.isEmpty) return (channelId: null, videoId: null, title: null);
    try {
      final page = await _yt.search.search(trimmed);
      if (page.isEmpty) return (channelId: null, videoId: null, title: null);
      return newestByChannel(page.first.channelId.value);
    } catch (_) {
      return (channelId: null, videoId: null, title: null);
    }
  }

  Future<({String? channelId, String? videoId, String? title})> newestByChannel(String channelId) async {
    try {
      final uploads = await _yt.channels.getUploadsFromPage(channelId);
      if (uploads.isEmpty) return (channelId: channelId, videoId: null, title: null);
      final video = uploads.first;
      return (channelId: channelId, videoId: video.id.value, title: video.title);
    } catch (_) {
      return (channelId: channelId, videoId: null, title: null);
    }
  }

  Future<ChosenStream> chooseVideo(String videoId, {required bool dataSaver}) async {
    final manifest = await _manifest(videoId);
    final muxed = manifest.muxed.toList();
    if (muxed.isNotEmpty) {
      final pool = dataSaver
          ? muxed.where((stream) => stream.videoQuality.index <= VideoQuality.medium360.index).toList()
          : muxed;
      final usable = pool.isEmpty ? muxed : pool;
      final chosen = pickPreferred(
        usable
            .map(
              (stream) => RatedStream(
                value: stream,
                bitsPerSecond: stream.bitrate.bitsPerSecond,
                qualityRank: stream.videoQuality.index,
              ),
            )
            .toList(),
        dataSaver: dataSaver,
      );
      return ChosenStream(info: chosen, audioOnly: false, hls: false);
    }
    final hls = manifest.hls.whereType<VideoStreamInfo>().toList();
    if (hls.isEmpty) {
      throw AppFailure('This video has no picture stream. Try audio only.');
    }
    final pool = dataSaver
        ? hls.where((stream) => stream.videoQuality.index <= VideoQuality.medium360.index).toList()
        : hls;
    final usable = pool.isEmpty ? hls : pool;
    final chosen = pickPreferred(
      usable
          .map(
            (stream) => RatedStream(
              value: stream,
              bitsPerSecond: stream.bitrate.bitsPerSecond,
              qualityRank: stream.videoQuality.index,
            ),
          )
          .toList(),
      dataSaver: dataSaver,
    );
    return ChosenStream(info: chosen, audioOnly: false, hls: true);
  }

  Stream<List<int>> bytes(StreamInfo info) => _yt.videos.streamsClient.get(info);

  Future<LyricsResult?> captions(String videoId) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      var tracks = manifest.getByLanguage('en', format: ClosedCaptionFormat.vtt);
      if (tracks.isEmpty) {
        tracks = manifest.getByLanguage('en', format: ClosedCaptionFormat.vtt, autoGenerated: true);
      }
      if (tracks.isEmpty && manifest.tracks.isNotEmpty) {
        tracks = [manifest.tracks.first];
      }
      if (tracks.isEmpty) return null;
      final track = await _yt.videos.closedCaptions.get(tracks.first);
      if (track.captions.isEmpty) return null;
      final synced = track.captions.map((line) {
        final text = line.text.replaceAll('\n', ' ').trim();
        return '${_stamp(line.offset)} $text';
      }).join('\n');
      final plain = track.captions
          .map((line) => line.text.replaceAll('\n', ' ').trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
      return LyricsResult(plain: plain, synced: synced);
    } catch (_) {
      return null;
    }
  }

  Future<StreamManifest> _manifest(String videoId) {
    final pending = _manifests[videoId];
    if (pending != null) return pending;
    final future = _yt.videos.streamsClient.getManifest(videoId);
    _manifests[videoId] = future;
    future.whenComplete(() => _manifests.remove(videoId));
    return future;
  }

  String _stamp(Duration time) {
    final minutes = time.inMinutes.toString().padLeft(2, '0');
    final seconds = time.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hundredths = (time.inMilliseconds.remainder(1000) / 10).floor().toString().padLeft(2, '0');
    return '[$minutes:$seconds.$hundredths]';
  }

  void close() => _yt.close();
}
