import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_failure.dart';
import '../../data/models/track.dart';
import '../../state/providers.dart';
import '../widgets/forge_widgets.dart';

class TagScreen extends ConsumerStatefulWidget {
  const TagScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends ConsumerState<TagScreen> {
  Track? _track;
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _album;
  late final TextEditingController _albumArtist;
  late final TextEditingController _genre;
  late final TextEditingController _year;
  late final TextEditingController _number;
  late final TextEditingController _disc;
  late final TextEditingController _lyrics;
  bool _saving = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _artist = TextEditingController();
    _album = TextEditingController();
    _albumArtist = TextEditingController();
    _genre = TextEditingController();
    _year = TextEditingController();
    _number = TextEditingController();
    _disc = TextEditingController();
    _lyrics = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final track = await ref.read(databaseProvider).trackById(widget.trackId);
    if (!mounted) return;
    if (track != null) {
      _track = track;
      _title.text = track.title;
      _artist.text = track.artist;
      _album.text = track.album;
      _albumArtist.text = track.albumArtist;
      _genre.text = track.genre;
      _year.text = track.year?.toString() ?? '';
      _number.text = track.trackNumber?.toString() ?? '';
      _disc.text = track.discNumber?.toString() ?? '';
      _lyrics.text = track.lyrics ?? '';
    }
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    for (final controller in [_title, _artist, _album, _albumArtist, _genre, _year, _number, _disc, _lyrics]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final track = _track;
    if (track == null) return;
    setState(() => _saving = true);
    try {
      final lyrics = _lyrics.text.trim();
      final updated = await ref.read(tagEditorProvider).save(
        track: track,
        title: _title.text,
        artist: _artist.text,
        album: _album.text,
        albumArtist: _albumArtist.text,
        genre: _genre.text,
        year: int.tryParse(_year.text.trim()),
        trackNumber: int.tryParse(_number.text.trim()),
        discNumber: int.tryParse(_disc.text.trim()),
        lyrics: lyrics.isEmpty ? null : lyrics,
      );
      await ref.read(playerProvider).replaceTrack(updated);
      if (mounted) {
        showForgeMessage(context, 'Tags saved.');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      showForgeMessage(context, error is AppFailure ? error.message : 'The tags could not be saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_track == null) {
      return const Scaffold(body: Center(child: Text('That song is no longer on the shelf.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit tags'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving' : 'Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field('Title', _title),
          _field('Artist', _artist),
          _field('Album', _album),
          _field('Album artist', _albumArtist),
          _field('Genre', _genre),
          _field('Year', _year, number: true),
          _field('Track number', _number, number: true),
          _field('Disc', _disc, number: true),
          _field('Lyrics', _lyrics, lines: 8),
          const SizedBox(height: 8),
          const Text('Leave a number blank to keep what is already written.'),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool number = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
