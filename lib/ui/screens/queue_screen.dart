import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../playback.dart';
import '../widgets/forge_widgets.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playbackProvider).valueOrNull;
    final queue = snapshot?.queue ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (queue.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(playerProvider).clearQueue(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: queue.isEmpty
          ? const Center(child: Text('The queue is clear. Play a song and it will line up here.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: queue.length,
              onReorder: (from, to) {
                var target = to;
                if (target > from) target -= 1;
                ref.read(playerProvider).move(from, target);
              },
              itemBuilder: (context, index) {
                final track = queue[index];
                final current = snapshot?.index == index;
                final playing = snapshot?.playing ?? false;
                return ListTile(
                  key: ValueKey('${track.id}-$index'),
                  selected: current,
                  leading: ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, radius: 12),
                  title: Row(
                    children: [
                      if (current) ...[
                        PlayingBars(playing: playing, height: 14),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (current)
                        PlayToggleButton(
                          playing: playing,
                          size: 40,
                          onPressed: () {
                            final player = ref.read(playerProvider);
                            if (playing) {
                              player.pause();
                            } else {
                              player.play();
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => ref.read(playerProvider).removeAt(index),
                      ),
                    ],
                  ),
                  onTap: () => playTracks(context, ref, queue, index),
                );
              },
            ),
    );
  }
}
