import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A library that has nothing at first and answers after [publish].
class _Source extends LibrarySource {
  Lyrics answer = Lyrics.empty;

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
  Future<Lyrics> lyrics(LibrarySong song) async => answer;

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
  );
}

Future<void> _pump(WidgetTester tester, _Source source) async {
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([source]),
        playbackProvider.overrideWith(_Playback.new),
        // No cache: this test is about what the pane does when the network
        // is the only source of an answer.
        libraryDatabaseProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const Scaffold(body: SongLyricsPane()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty answer offers a retry that fetches again', (
    tester,
  ) async {
    final source = _Source();
    await _pump(tester, source);

    expect(find.text('No lyrics for this track'), findsOneWidget);
    expect(find.text('Ask again'), findsOneWidget);

    // The server gains the lyrics between the two attempts.
    source.answer = parseLrc('[00:03.00]Here comes the sun');
    await tester.tap(find.text('Ask again'));
    await tester.pumpAndSettle();

    expect(find.text('Here comes the sun'), findsOneWidget);
    expect(find.text('No lyrics for this track'), findsNothing);
  });
}
