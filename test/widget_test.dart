import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
