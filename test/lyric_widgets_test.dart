import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/widgets/lyric_widgets.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'KaraokeSweepText uses plain Text when inactive and CustomPaint when active',
    (tester) async {
      const text = 'どんな未来を勝者に選んで歩いていくのだろう';
      const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w800);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: KaraokeSweepText(
                text: text,
                style: style,
                isActive: false,
                progress: 0.0,
              ),
            ),
          ),
        ),
      );

      expect(find.text(text), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KaraokeSweepText),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: KaraokeSweepText(
                text: text,
                style: style,
                isActive: true,
                progress: 0.45,
              ),
            ),
          ),
        ),
      );

      expect(find.text(text), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KaraokeSweepText),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'InterludeDotsItem expands when active and collapses to zero when inactive',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InterludeDotsItem(isActive: true, progress: 0.95),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(InterludeDotsItem)).height,
        greaterThan(20),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InterludeDotsItem(isActive: false, progress: 1.0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(InterludeDotsItem)).height, 0);
    },
  );

  testWidgets(
    'LyricsView drives active karaoke/interlude via ValueNotifier without errors and seeks on tap',
    (tester) async {
      final position = ValueNotifier<Duration>(const Duration(seconds: 1));
      addTearDown(position.dispose);

      Duration? sought;
      const lyrics = Lyrics(
        synced: true,
        lines: [
          LyricLine(
            Duration(seconds: 5),
            'ここに来た',
            pronunciation: 'koko ni kita',
            translation: 'Here comes the sun',
          ),
          LyricLine(Duration(seconds: 10), 'And I say'),
          LyricLine(Duration(seconds: 15), 'It is all right'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 500,
              child: LyricsView(
                lyrics: lyrics,
                positionListenable: position,
                onSeek: (target) => sought = target,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At 1s, leading interlude [0s..5s] is active and expanded.
      expect(find.byType(InterludeDotsItem), findsOneWidget);
      expect(
        tester.getSize(find.byType(InterludeDotsItem)).height,
        greaterThan(20),
      );

      // Advance into first vocal line: interlude collapses and first line becomes active.
      position.value = const Duration(seconds: 6);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(InterludeDotsItem)).height, 0);
      expect(find.text('ここに来た'), findsOneWidget);
      expect(find.text('koko ni kita'), findsOneWidget);
      expect(find.text('Here comes the sun'), findsOneWidget);

      // High-frequency progress ticks inside the same line repaint smoothly.
      position.value = const Duration(seconds: 7, milliseconds: 500);
      await tester.pump();
      position.value = const Duration(seconds: 8, milliseconds: 200);
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Tapping a line seeks to its start timestamp.
      await tester.tap(find.text('And I say'));
      await tester.pumpAndSettle();
      expect(sought, const Duration(seconds: 10));
    },
  );

  testWidgets(
    'a line grows into the active size and the interlude collapses, neither on one frame',
    (tester) async {
      final position = ValueNotifier<Duration>(Duration.zero);
      addTearDown(position.dispose);
      const lyrics = Lyrics(
        synced: true,
        lines: [
          LyricLine(Duration(seconds: 6), 'first line words'),
          LyricLine(Duration(seconds: 20), 'second line words'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 500,
              child: LyricsView(lyrics: lyrics, positionListenable: position),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double rowHeight(String text) => tester
          .getSize(
            find
                .ancestor(
                  of: find.text(text),
                  matching: find.byType(LyricLineItem),
                )
                .first,
          )
          .height;
      // The leading indicator, not the gap between the two lines (which also
      // gets one): the two are found top-down, and only the first is active.
      double interludeHeight() =>
          tester.getSize(find.byType(InterludeDotsItem).first).height;

      // The vocal line at its active size, with the interlude gone.
      position.value = const Duration(seconds: 7);
      await tester.pumpAndSettle();
      final activeRow = rowHeight('first line words');
      expect(interludeHeight(), 0);

      // Back before the vocals: the line at its idle size and the leading
      // interlude showing.
      position.value = Duration.zero;
      await tester.pumpAndSettle();
      final idleLine = rowHeight('first line words');
      final idleInterlude = interludeHeight();
      expect(idleLine, lessThan(activeRow));
      expect(idleInterlude, greaterThan(20));

      // Vocals arrive: the line grows and the dots collapse, both across
      // frames. A snapped row would already sit at its end size on the first.
      position.value = const Duration(seconds: 7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rowHeight('first line words'), greaterThan(idleLine));
      expect(rowHeight('first line words'), lessThan(activeRow));
      expect(interludeHeight(), greaterThan(0));
      expect(interludeHeight(), lessThan(idleInterlude));

      await tester.pumpAndSettle();
      expect(rowHeight('first line words'), closeTo(activeRow, 1));
      expect(interludeHeight(), 0);
    },
  );

  testWidgets(
    'LyricsView hides pronunciation and translation when toggled off',
    (tester) async {
      const lyrics = Lyrics(
        lines: [
          LyricLine(
            Duration.zero,
            '静かに消えていく思い出',
            pronunciation: 'shizuka ni kiete iku omoide',
            translation: 'Quietly disappearing memories',
          ),
        ],
        synced: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: LyricsView(
              lyrics: lyrics,
              position: Duration.zero,
              showPronunciation: false,
              showTranslation: false,
            ),
          ),
        ),
      );

      expect(find.text('静かに消えていく思い出'), findsOneWidget);
      expect(find.text('shizuka ni kiete iku omoide'), findsNothing);
      expect(find.text('Quietly disappearing memories'), findsNothing);
    },
  );
}
