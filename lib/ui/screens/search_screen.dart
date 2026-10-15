import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_failure.dart';
import '../../data/models/library.dart';
import '../../data/models/media.dart';
import '../../data/services/youtube_track.dart';
import '../../state/providers.dart';
import '../playback.dart';
import '../widgets/forge_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  String _text = '';
  List<YoutubeHit> _hits = const [];
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _searchYouTube() async {
    final text = _text.trim();
    if (text.isEmpty) return;
    setState(() => _searching = true);
    try {
      final hits = await ref.read(youtubeProvider).search(text);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _searching = false);
      showForgeMessage(context, error is AppFailure ? error.message : 'YouTube search did not answer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(libraryProvider).index.songs.where((track) => matchesQuery(track, _text)).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Title, artist, album, filename, lyrics',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                    onChanged: (value) => setState(() => _text = value),
                    onSubmitted: (_) => _searchYouTube(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if (_text.trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Search your shelves, then press go to look on YouTube too.'),
                    ),
                  if (songs.isNotEmpty) const SectionLabel('On this phone'),
                  for (var i = 0; i < songs.length; i++)
                    SongTile(
                      track: songs[i],
                      onTap: () => playTracks(context, ref, songs, i),
                      onMore: () => showTrackMenu(context, ref, songs[i]),
                    ),
                  if (_text.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: _searching ? null : _searchYouTube, child: const Text('Search YouTube')),
                    ),
                  if (_searching) const LinearProgressIndicator(),
                  if (_hits.isNotEmpty) const SectionLabel('YouTube'),
                  for (final hit in _hits)
                    ListTile(
                      leading: ArtworkView(url: hit.thumbnailUrl, radius: 12),
                      title: Text(hit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(hit.author),
                      onTap: () => playTracks(context, ref, [trackFromHit(hit)], 0),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
