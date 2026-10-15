import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgemusic/data/models/track.dart';
import 'package:forgemusic/ui/screens/home_screen.dart';
import 'package:forgemusic/ui/theme/forge_theme.dart';
import 'package:forgemusic/ui/widgets/forge_widgets.dart';

void main() {
  testWidgets('empty shelves invite a scan and skip duplicates', (tester) async {
    var scanned = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: forgeTheme(Brightness.dark, ForgeColors.ember),
        home: Scaffold(
          body: EmptyShelves(
            onScan: () => scanned = true,
            onYouTube: () {},
          ),
        ),
      ),
    );

    expect(find.text('Your shelves are quiet'), findsOneWidget);
    expect(
      find.text(
        'Pick a folder and Forgemusic will line the songs up, skipping duplicates.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Scan this phone'));
    await tester.pump();
    expect(scanned, isTrue);
  });

  testWidgets('a tap on the waveform seeks into the song', (tester) async {
    Duration? sought;
    await tester.pumpWidget(
      MaterialApp(
        theme: forgeTheme(Brightness.dark, ForgeColors.ember),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: WaveformSeekBar(
                seed: 'night-drive',
                position: Duration.zero,
                duration: const Duration(seconds: 100),
                onSeek: (value) => sought = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(WaveformSeekBar));
    await tester.pump();
    expect(sought, isNotNull);
    expect(sought!.inMilliseconds, greaterThan(0));
  });

  test('song titles stay on the surface color', () {
    final theme = forgeTheme(Brightness.dark, ForgeColors.ember);
    expect(theme.textTheme.displaySmall?.fontFamily, 'Instrument Sans');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Instrument Sans');
    expect(theme.textTheme.bodyMedium?.color, ForgeColors.paper);
    expect(theme.textTheme.titleMedium?.color, ForgeColors.paper);
    expect(theme.textTheme.bodySmall?.color, ForgeColors.mist);
  });

  testWidgets('the current song stays visible on the now playing card', (tester) async {
    var opened = false;
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: forgeTheme(Brightness.dark, ForgeColors.ember),
        home: Scaffold(
          body: NowPlayingCard(
            track: Track(
              id: 'night-drive',
              source: TrackSource.local,
              title: 'Night Drive',
              artist: 'Ada',
              album: 'Night',
              albumArtist: 'Ada',
              genre: 'Pop',
              durationMs: 180000,
              sizeBytes: 1000,
              addedMs: 1,
              fingerprint: 'night-drive',
            ),
            playing: true,
            position: const Duration(seconds: 20),
            duration: const Duration(minutes: 3),
            onOpen: () => opened = true,
            onToggle: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Night Drive'));
    expect(title.style?.color, ForgeColors.paper);

    await tester.tap(find.text('Night Drive'));
    await tester.pump();
    expect(opened, isTrue);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(toggled, isTrue);
  });

  testWidgets('the play control stays filled while a song plays', (tester) async {
    final theme = forgeTheme(Brightness.dark, ForgeColors.ember);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: PlayToggleButton(playing: true, onPressed: _noop),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.pause_rounded));
    expect(icon.color, theme.colorScheme.onPrimary);
    expect(icon.color, isNot(theme.colorScheme.surface));

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(child: PlayingBars(playing: true, height: 18)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PlayingBars)), const Size(18, 18));
  });
}

void _noop() {}
