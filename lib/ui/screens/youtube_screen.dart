import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_failure.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/media.dart';
import '../../data/services/youtube_track.dart';
import '../../state/providers.dart';
import '../playback.dart';
import '../widgets/forge_widgets.dart';

class YoutubeScreen extends ConsumerStatefulWidget {
  const YoutubeScreen({super.key});

  @override
  ConsumerState<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends ConsumerState<YoutubeScreen> {
  final _query = TextEditingController();
  List<YoutubeHit> _hits = const [];
  List<DownloadRecord> _saved = const [];
  bool _searching = false;
  bool _downloads = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _reloadSaved();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _reloadSaved() async {
    final saved = await ref.read(databaseProvider).downloads();
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _searching = true;
      _note = null;
      _downloads = false;
    });
    try {
      final hits = await ref.read(youtubeProvider).search(text);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
        _note = hits.isEmpty ? 'Nothing matched that search.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _note = error is AppFailure ? error.message : 'YouTube search did not answer.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfer = ref.watch(transferProvider).valueOrNull;
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YouTube', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search songs and videos',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(label: const Text('Explore'), selected: !_downloads, onSelected: (_) => setState(() => _downloads = false)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Downloads'),
                        selected: _downloads,
                        onSelected: (_) {
                          setState(() => _downloads = true);
                          _reloadSaved();
                        },
                      ),
                    ],
                  ),
                  if (transfer != null) ...[
                    const SizedBox(height: 10),
                    Text(transfer.label),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: transfer.fraction),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _downloads ? _downloadList() : _explore(settings),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'Dislike counts are estimates from Return YouTube Dislike. For personal listening. Please respect copyright and YouTube’s terms. Downloads stay on this phone.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _explore(AppSettings settings) {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_note != null) return Center(child: Text(_note!));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _hits.length,
      itemBuilder: (context, index) {
        final hit = _hits[index];
        return ListTile(
          leading: ArtworkView(url: hit.thumbnailUrl, radius: 12),
          title: Text(hit.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${hit.author} · ${formatDuration(hit.duration)}'),
              _VoteLine(videoId: hit.videoId),
            ],
          ),
          onTap: () => settings.youtubeAudioOnly ? _play(hit) : _watch(hit),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'audio':
                  _play(hit);
                case 'video':
                  _watch(hit);
                case 'save-audio':
                  _save(hit, audioOnly: true);
                case 'save-video':
                  _save(hit, audioOnly: false);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'audio', child: Text('Play audio')),
              PopupMenuItem(value: 'video', child: Text('Play video')),
              PopupMenuItem(value: 'save-audio', child: Text('Download audio')),
              PopupMenuItem(value: 'save-video', child: Text('Download video')),
            ],
          ),
        );
      },
    );
  }

  Widget _downloadList() {
    if (_saved.isEmpty) return const Center(child: Text('Downloads you keep will wait here, ready offline.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _saved.length,
      itemBuilder: (context, index) {
        final item = _saved[index];
        final hit = YoutubeHit(
          videoId: item.videoId,
          title: item.title,
          author: item.author,
          durationMs: item.durationMs,
          thumbnailUrl: item.thumbnailUrl,
        );
        return ListTile(
          leading: ArtworkView(url: item.thumbnailUrl, radius: 12),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${item.audioOnly ? 'Audio' : 'Video'} · ${formatBytes(item.bytes)} · On this phone'),
          onTap: () => item.audioOnly ? _play(hit, path: item.filePath) : _watch(hit),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(downloadsProvider).deleteDownload(item);
              await _reloadSaved();
            },
          ),
        );
      },
    );
  }

  Future<void> _play(YoutubeHit hit, {String? path}) {
    return playTracks(context, ref, [trackFromHit(hit, downloaded: path != null, downloadPath: path)], 0);
  }

  void _watch(YoutubeHit hit) {
    final settings = ref.read(settingsProvider);
    ref.read(videoLaunchProvider.notifier).open(
      VideoLaunch.youtube(
        youtubeId: hit.videoId,
        title: hit.title,
        subtitle: hit.author,
        dataSaver: settings.dataSaver,
      ),
    );
    context.push('/video');
  }

  Future<void> _save(YoutubeHit hit, {required bool audioOnly}) async {
    try {
      final settings = ref.read(settingsProvider);
      await ref.read(downloadsProvider).download(
        hit,
        audioOnly: audioOnly,
        audioQuality: settings.audioQuality,
        dataSaver: settings.dataSaver,
      );
      await _reloadSaved();
      if (mounted) showForgeMessage(context, 'Saved on this phone.');
    } catch (error) {
      if (!mounted) return;
      showForgeMessage(context, error is AppFailure ? error.message : 'That download stopped before it finished.');
    }
  }
}

class _VoteLine extends ConsumerStatefulWidget {
  const _VoteLine({required this.videoId});

  final String videoId;

  @override
  ConsumerState<_VoteLine> createState() => _VoteLineState();
}

class _VoteLineState extends ConsumerState<_VoteLine> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final votes = await ref.read(dislikeProvider).votes(widget.videoId);
    if (!mounted || votes == null) return;
    setState(() => _label = '${formatCount(votes.likes)} likes · ${formatCount(votes.dislikes)} dislikes');
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();
    return Text(label, style: Theme.of(context).textTheme.bodySmall);
  }
}
