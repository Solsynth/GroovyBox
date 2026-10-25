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
        lyricsCacheProvider.overrideWithValue(null),
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

    // The chrome sits against the window edge rather than in a row above the
    // body, and the body itself starts at that same edge — nothing was
    // reserved for a header.
    final close = tester.getRect(find.byTooltip('Close'));
    final lyrics = tester.getRect(find.byTooltip('Show lyrics'));
    expect(close.top, lessThan(12));
    expect(lyrics.top, lessThan(12));
    expect(lyrics.right, greaterThan(1240));

    // The body is laid out against the whole window, so the artwork is
    // centred in it. A header row would have pushed the centre down by half
    // its height.
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
    expect(art.center.dy, moreOrLessEquals(900 / 2, epsilon: 24));
  });
}
