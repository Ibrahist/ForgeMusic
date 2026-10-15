import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../state/providers.dart';

class EqualizerPreset {
  const EqualizerPreset(this.name, this.bands);

  final String name;
  final List<double> bands;
}

const equalizerPresets = [
  EqualizerPreset('Flat', equalizerFlat),
  EqualizerPreset('Bass', [6, 4, 1, 0, 0]),
  EqualizerPreset('Vocal', [-1, 0, 3, 4, 1]),
  EqualizerPreset('Treble', [0, 0, 1, 4, 6]),
  EqualizerPreset('Rock', [5, 3, -1, 3, 5]),
];

Future<void> showEqualizerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const EqualizerSheet(),
  );
}

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final bands = settings.equalizerBands;
    final selected = _matchingPreset(bands);

    Future<void> save(AppSettings next) => ref.read(settingsProvider.notifier).update(next);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equalizer', style: Theme.of(context).textTheme.headlineSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shape the sound'),
              value: settings.equalizer,
              onChanged: (value) => save(settings.copyWith(equalizer: value)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in equalizerPresets)
                  ChoiceChip(
                    label: Text(preset.name),
                    selected: settings.equalizer && selected == preset.name,
                    onSelected: settings.equalizer
                        ? (_) => save(settings.copyWith(equalizer: true, equalizerBands: List<double>.of(preset.bands)))
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < bands.length; i++)
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(equalizerBandLabels[i], style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Slider(
                      value: bands[i].clamp(-12, 12).toDouble(),
                      min: -12,
                      max: 12,
                      divisions: 24,
                      label: '${bands[i].round()} dB',
                      onChanged: settings.equalizer
                          ? (value) {
                              final next = List<double>.of(bands);
                              next[i] = value;
                              save(settings.copyWith(equalizerBands: next));
                            }
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${bands[i].round()} dB',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String? _matchingPreset(List<double> bands) {
  for (final preset in equalizerPresets) {
    if (preset.bands.length != bands.length) continue;
    var same = true;
    for (var i = 0; i < bands.length; i++) {
      if ((preset.bands[i] - bands[i]).abs() > 0.6) {
        same = false;
        break;
      }
    }
    if (same) return preset.name;
  }
  return null;
}
