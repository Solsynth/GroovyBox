import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/player_screen.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends LibrarySource {
  @override
  String get id => 'a';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'a',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Home',
  );

  @override
  Future<Lyrics> lyrics(LibrarySong song) async => mergeLyricLayers(
    main: parseLrc('[00:03.00]ここに来た\n[00:09.00]And I say'),
    pronunciation: parseLrc('[00:03.00]koko ni kita\n[00:09.00]ando ai sei'),
    translation: parseLrc('[00:03.00]Here comes the sun\n[00:09.00]And I say'),
  );

  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Playback extends Playback {
  @override
  PlaybackState build() => const PlaybackState(
    queue: [
      LibrarySong(
        sourceId: 'a',
        id: 's1',
        title: 'Sunset Overdrive',
        artist: 'The Paper Kites',
        duration: Duration(seconds: 254),
      ),
    ],
    currentIndex: 0,
    duration: Duration(seconds: 254),
    position: Duration(seconds: 10),
  );
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // The library's answer is timed, so no network or disk is involved;
        // an absent cache keeps the test off the device's real database.
        libraryDatabaseProvider.overrideWithValue(null),
        librarySourcesProvider.overrideWithValue([_Source()]),
        playbackProvider.overrideWith(_Playback.new),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const PlayerScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(420, 860), const Size(1280, 900)]) {
    final label = size.width > 1000 ? 'wide' : 'compact';

    testWidgets('player swaps the cover for timed lyrics — $label', (
      tester,
    ) async {
      await _pump(tester, size);

      expect(find.byType(SongLyricsPane), findsNothing);
      expect(find.byType(LibraryArtwork), findsWidgets);

      await tester.tap(find.byTooltip('Show lyrics'));
      await tester.pumpAndSettle();

      expect(find.byType(SongLyricsPane), findsOneWidget);
      expect(find.text('ここに来た'), findsOneWidget);
      expect(find.text('koko ni kita'), findsOneWidget);
      expect(find.text('Here comes the sun'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Hide lyrics'));
      await tester.pumpAndSettle();
      expect(find.byType(SongLyricsPane), findsNothing);
    });
  }

  testWidgets('the queue takes the same slot as the words', (tester) async {
    await _pump(tester, const Size(420, 860));

    expect(find.byType(QueuePanel), findsNothing);
    await tester.tap(find.byTooltip('Show queue'));
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.byType(SongLyricsPane), findsNothing);

    // The slot holds one alternate: asking for the words hands it over.
    await tester.tap(find.byTooltip('Show lyrics'));
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsNothing);
    expect(find.byType(SongLyricsPane), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the panes cross rather than cut when the slot hands over', (
    tester,
  ) async {
    await _pump(tester, const Size(420, 860));

    await tester.tap(find.byTooltip('Show lyrics'));
    await tester.pumpAndSettle();

    // Queue and words are the same page in two shapes, so one gives way to the
    // other inside the slot instead of the slot closing and reopening. Both
    // are on screen for the length of the hand-off.
    await tester.tap(find.byTooltip('Show queue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.byType(SongLyricsPane), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.byType(SongLyricsPane), findsNothing);

    // Asking for the pane that is still leaving sends it back rather than
    // starting a second hand-off from the far end.
    await tester.tap(find.byTooltip('Show lyrics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SongLyricsPane), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(SongLyricsPane), findsOneWidget);
    expect(find.byType(QueuePanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a settled pane takes taps and drags, not the page behind it', (
    tester,
  ) async {
    await _pump(tester, const Size(420, 860));

    await tester.tap(find.byTooltip('Show queue'));
    await tester.pumpAndSettle();

    // The pane sits inside an IgnorePointer that is released when the morph
    // reaches its end. That progress comes from an eased curve, and an eased
    // curve stops at 0.9999997 rather than 1, so a strict comparison left the
    // whole pane transparent to the pointer: taps and drags fell through to
    // the page scroll behind it.
    expect(
      find.byType(QueuePanel).hitTestable(),
      findsOneWidget,
      reason: 'the queue must answer the pointer once the morph has settled',
    );
    final list = find.descendant(
      of: find.byType(QueuePanel),
      matching: find.byType(ListView),
    );
    expect(
      find.descendant(of: list, matching: find.byType(TrackRow)).first.hitTestable(),
      findsOneWidget,
    );

    // A drag over the queue scrolls the queue, not the page under it.
    final page = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final before = page.pixels;
    await tester.drag(list, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(page.pixels, before, reason: 'the page must not move');
  });
}
