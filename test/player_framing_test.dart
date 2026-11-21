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
  Future<Lyrics> lyrics(LibrarySong song) async => Lyrics.empty;

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

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
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

/// The painted square, not the background that blurs the whole page: the wide
/// body sizes the art with [AspectRatio], the compact one with a box.
Size _artworkSize(WidgetTester tester) => tester
    .getRect(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is SizedBox || w is AspectRatio,
            ),
            matching: find.byType(LibraryArtwork),
          )
          .first,
    )
    .size;

void main() {
  testWidgets('the scrubber spans exactly the artwork, at both morph ends', (
    tester,
  ) async {
    await _pump(tester);

    // Cover end.
    final cover = _artworkSize(tester);
    final scrubber = tester.getSize(find.byType(Slider));
    expect(scrubber.width, moreOrLessEquals(cover.width, epsilon: 0.5));

    await tester.tap(find.byTooltip('Show lyrics'));
    await tester.pumpAndSettle();

    // Lyrics end: the frame grew for the words, but the ruler stays the
    // artwork's width rather than the frame's.
    final coverUnderWords = _artworkSize(tester);
    final scrubberUnderWords = tester.getSize(find.byType(Slider));
    expect(
      scrubberUnderWords.width,
      moreOrLessEquals(coverUnderWords.width, epsilon: 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the controls float over the body instead of taking a row', (
    tester,
  ) async {
    await _pump(tester);

    // The chrome floats over the body rather than sitting in a row above it,
    // and it keeps a small inset from the window edges so a button is not
    // cropped by the glass. Both clusters share the inset, so the two ends
    // of the bar read as one row. The left cluster leads with the mini
    // window's button on the desktop, so the *cluster's* left edge — not the
    // close button's — carries the inset.
    final close = tester.getRect(find.byTooltip('Close'));
    final lyrics = tester.getRect(find.byTooltip('Show lyrics'));
    expect(close.top, lessThan(32));
    expect(lyrics.top, moreOrLessEquals(close.top, epsilon: 0.5));
    final art = tester.getRect(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is SizedBox || w is AspectRatio,
            ),
            matching: find.byType(LibraryArtwork),
          )
          .first,
    );

    // The body is centred in the room the floating corner controls leave, not
    // in the whole window: they take no row, so their runway is paid for once
    // and the leftover split above and below. The cover's top edge has to
    // clear the buttons, and its centre sits in the middle of what is left —
    // the way the compact page centres its own column.
    const topInset = SolSpace.lg + 48; // the corner inset plus a button
    const bottomInset = SolSpace.xxxl; // the page's own margin
    expect(art.top, greaterThan(close.bottom));
    expect(
      art.center.dy,
      moreOrLessEquals((topInset + 900 - bottomInset) / 2, epsilon: 1),
    );
  });
}
