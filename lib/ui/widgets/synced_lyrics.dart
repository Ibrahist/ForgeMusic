import 'package:flutter/material.dart';

import '../../core/utils/lrc.dart';
import '../theme/forge_theme.dart';

/// Highlights the current synced line and keeps it in view.
class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.synced,
    required this.position,
    this.plain,
    this.expanded = false,
  });

  final String? synced;
  final String? plain;
  final Duration position;
  final bool expanded;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final _scroll = ScrollController();
  int _shown = -2;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reveal();
  }

  void _reveal() {
    final lines = _lines();
    if (lines == null || !widget.expanded) return;
    final current = LrcParser.indexAt(lines, widget.position);
    if (current == _shown) return;
    _shown = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || current < 0) return;
      final target = (current * 64.0) - 80;
      final max = _scroll.position.maxScrollExtent;
      _scroll.animateTo(
        target.clamp(0, max),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  List<LrcLine>? _lines() {
    final synced = widget.synced;
    if (synced == null || synced.trim().isEmpty) return null;
    final lines = LrcParser.parse(synced);
    if (lines.isEmpty) return null;
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    if (lines != null) {
      final current = LrcParser.indexAt(lines, widget.position);
      if (!widget.expanded) {
        final text = current >= 0 ? lines[current].text : lines.first.text;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      }
      return SizedBox(
        height: 280,
        child: ListView.builder(
          controller: _scroll,
          itemCount: lines.length,
          itemExtent: 64,
          itemBuilder: (context, index) {
            final active = index == current;
            return Center(
              child: Text(
                lines[index].text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: active ? Theme.of(context).colorScheme.primary : ForgeColors.mist,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            );
          },
        ),
      );
    }
    final plain = widget.plain;
    if (plain == null || plain.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Lyrics will sit here once they are found.'),
      );
    }
    if (!widget.expanded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(plain, textAlign: TextAlign.center),
    );
  }
}
