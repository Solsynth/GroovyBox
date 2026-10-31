import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/now_playing_dock.dart';
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
  Future<Lyrics> lyrics(LibrarySong song) async => parseLrc('''
[00:03.00]Here comes the sun
[00:09.00]And I say
''');

  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The real transport owns a media-kit player; the dock only needs its state,
/// so seeking is recorded here instead of reaching for one.
class _Playback extends Playback {
  Duration? sought;

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
  );

  @override
  Future<void> seek(Duration position) async {
    sought = position;
    state = state.copyWith(position: position);
  }
}

void main() {
  testWidgets('the dock lyrics sheet follows the position', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final playback = _Playback();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // The library's answer is timed, so no network or disk is involved;
          // an absent database keeps the test off the device's real one.
          libraryDatabaseProvider.overrideWithValue(null),
          librarySourcesProvider.overrideWithValue([_Source()]),
          playbackProvider.overrideWith(() => playback),
        ],
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: NowPlayingDock(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SongLyricsPane), findsNothing);
    await tester.tap(find.byTooltip('Show lyrics'));
    await tester.pumpAndSettle();

    expect(find.byType(SongLyricsPane), findsOneWidget);
    expect(find.text('Here comes the sun'), findsOneWidget);
    expect(find.text('And I say'), findsOneWidget);

    await playback.seek(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    // The line being sung is heavier and fuller; the earlier one dims.
    TextStyle styleOf(String text) => tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text(text),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(styleOf('And I say').fontWeight, FontWeight.w800);
    expect(styleOf('Here comes the sun').fontWeight, FontWeight.w700);
    expect(
      styleOf('And I say').color!.a,
      greaterThan(styleOf('Here comes the sun').color!.a),
    );

    // A line is a seek target.
    await tester.tap(find.text('Here comes the sun'));
    await tester.pumpAndSettle();
    expect(playback.sought, const Duration(seconds: 3));

    await tester.tap(find.byTooltip('Hide lyrics'));
    await tester.pumpAndSettle();
    expect(find.byType(SongLyricsPane), findsNothing);
  });
}
