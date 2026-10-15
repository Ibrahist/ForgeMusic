import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/app_settings.dart';
import '../../state/providers.dart';
import '../widgets/forge_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    Future<void> save(AppSettings next) => ref.read(settingsProvider.notifier).update(next);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _Heading('Look'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (value) => save(settings.copyWith(themeMode: value.first)),
          ),
          SwitchListTile(
            title: const Text('Colors from the cover'),
            subtitle: const Text('The room picks up the album art.'),
            value: settings.dynamicColor,
            onChanged: (value) => save(settings.copyWith(dynamicColor: value)),
          ),
          const _Heading('Listening'),
          SwitchListTile(
            title: const Text('Crossfade'),
            value: settings.crossfade,
            onChanged: (value) => save(settings.copyWith(crossfade: value, crossfadeMs: value && settings.crossfadeMs == 0 ? 5000 : settings.crossfadeMs)),
          ),
          if (settings.crossfade)
            _SliderRow(
              label: 'Fade length',
              valueLabel: '${(settings.crossfadeMs / 1000).round()}s',
              value: (settings.crossfadeMs / 1000).clamp(1, 12).toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (value) => save(settings.copyWith(crossfadeMs: value.round() * 1000)),
            ),
          SwitchListTile(
            title: const Text('Skip silence'),
            value: settings.skipSilence,
            onChanged: (value) => save(settings.copyWith(skipSilence: value)),
          ),
          SwitchListTile(
            title: const Text('Even out the volume'),
            subtitle: const Text('Uses replay gain when a song has it.'),
            value: settings.normalize,
            onChanged: (value) => save(settings.copyWith(normalize: value)),
          ),
          if (settings.normalize)
            _SliderRow(
              label: 'Boost when no replay gain',
              valueLabel: '${settings.normalizeGainDb.round()} dB',
              value: settings.normalizeGainDb.clamp(0, 12),
              min: 0,
              max: 12,
              divisions: 12,
              onChanged: (value) => save(settings.copyWith(normalizeGainDb: value)),
            ),
          SwitchListTile(
            title: const Text('Fade out the sleep timer'),
            value: settings.sleepFade,
            onChanged: (value) => save(settings.copyWith(sleepFade: value)),
          ),
          const _Heading('YouTube'),
          SwitchListTile(
            title: const Text('Play audio only'),
            subtitle: const Text('A tap plays the song. Video is still in the menu.'),
            value: settings.youtubeAudioOnly,
            onChanged: (value) => save(settings.copyWith(youtubeAudioOnly: value)),
          ),
          SwitchListTile(
            title: const Text('Data saver'),
            subtitle: const Text('Picks a smaller stream, around 64 kbps for audio.'),
            value: settings.dataSaver,
            onChanged: (value) => save(settings.copyWith(dataSaver: value)),
          ),
          SwitchListTile(
            title: const Text('Keep a cache'),
            value: settings.cacheYoutube,
            onChanged: (value) => save(settings.copyWith(cacheYoutube: value)),
          ),
          _SliderRow(
            label: 'Cache limit',
            valueLabel: '${settings.cacheLimitMb} MB',
            value: settings.cacheLimitMb.clamp(128, 1024).toDouble(),
            min: 128,
            max: 1024,
            divisions: 7,
            onChanged: (value) => save(settings.copyWith(cacheLimitMb: value.round())),
          ),
          const _Heading('Library'),
          _SliderRow(
            label: 'Skip songs shorter than',
            valueLabel: '${settings.minDurationSec}s',
            value: settings.minDurationSec.clamp(0, 180).toDouble(),
            min: 0,
            max: 180,
            divisions: 18,
            onChanged: (value) => save(settings.copyWith(minDurationSec: value.round())),
          ),
          SwitchListTile(
            title: const Text('Include ringtones and other audio'),
            value: settings.includeNonMusic,
            onChanged: (value) => save(settings.copyWith(includeNonMusic: value)),
          ),
          ListTile(
            title: const Text('Scan again'),
            subtitle: const Text('Rebuild the shelves and skip duplicates.'),
            onTap: () => ref.read(libraryProvider.notifier).scan(),
          ),
          ListTile(
            title: const Text('Clear the YouTube cache'),
            onTap: () async {
              final ok = await _confirm(context, 'Clear the cache?', 'Downloads you saved are kept.');
              if (!ok) return;
              await ref.read(downloadsProvider).clearCache();
              if (context.mounted) showForgeMessage(context, 'The cache is clear.');
            },
          ),
          ListTile(
            title: const Text('Allow tag editing'),
            subtitle: const Text('Android asks for all-files access so tags can be written.'),
            onTap: () async {
              final status = await Permission.manageExternalStorage.request();
              if (!context.mounted) return;
              if (!status.isGranted) await openAppSettings();
              if (context.mounted) {
                showForgeMessage(
                  context,
                  status.isGranted ? 'Tag editing is allowed.' : 'Open settings and allow all files if the write was refused.',
                );
              }
            },
          ),
          const SizedBox(height: 12),
          const Text('Forgemusic 1.0'),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Clear')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(valueLabel),
            ],
          ),
        ),
        Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }
}
