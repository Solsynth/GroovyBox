import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LyricsView hides pronunciation and translation when toggled off',
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

    Widget buildView({
      required bool showPronunciation,
      required bool showTranslation,
    }) {
      return MaterialApp(
        home: Material(
          child: LyricsView(
            lyrics: lyrics,
            position: Duration.zero,
            showPronunciation: showPronunciation,
            showTranslation: showTranslation,
          ),
        ),
      );
    }

    // 1. Both enabled (default)
    await tester.pumpWidget(
      buildView(showPronunciation: true, showTranslation: true),
    );

    expect(find.text('静かに消えていく思い出'), findsOneWidget);
    expect(find.text('shizuka ni kiete iku omoide'), findsOneWidget);
    expect(find.text('Quietly disappearing memories'), findsOneWidget);

    // 2. Pronunciation disabled
    await tester.pumpWidget(
      buildView(showPronunciation: false, showTranslation: true),
    );

    expect(find.text('静かに消えていく思い出'), findsOneWidget);
    expect(find.text('shizuka ni kiete iku omoide'), findsNothing);
    expect(find.text('Quietly disappearing memories'), findsOneWidget);

    // 3. Translation disabled
    await tester.pumpWidget(
      buildView(showPronunciation: true, showTranslation: false),
    );

    expect(find.text('静かに消えていく思い出'), findsOneWidget);
    expect(find.text('shizuka ni kiete iku omoide'), findsOneWidget);
    expect(find.text('Quietly disappearing memories'), findsNothing);

    // 4. Both disabled
    await tester.pumpWidget(
      buildView(showPronunciation: false, showTranslation: false),
    );

    expect(find.text('静かに消えていく思い出'), findsOneWidget);
    expect(find.text('shizuka ni kiete iku omoide'), findsNothing);
    expect(find.text('Quietly disappearing memories'), findsNothing);
  });
}
