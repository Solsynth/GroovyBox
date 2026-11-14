
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/player_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Subsonic server: it can star a song but has no store of its own.
class _Server extends LibrarySource implements RatedSource {
  bool starred = false;
  int reads = 0;
  int writes = 0;

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
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  Future<bool> isFavourite(LibrarySong song) async {
    reads++;
    return starred;
  }

  @override
  Future<void> setFavourite(LibrarySong song, {required bool value}) async {
    writes++;
    starred = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError();
}

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState(
    queue: [
      LibrarySong(sourceId: 'a', id: 's1', title: 'Track', duration: Duration(seconds: 200)),
    ],
    currentIndex: 0,
    duration: Duration(seconds: 200),
    position: Duration(seconds: 30),
  );
}

Future<void> _pump(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([server]),
        playbackProvider.overrideWith(_Idle.new),
        libraryDatabaseProvider.overrideWithValue(null),
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
  testWidgets('a server without a store still gets the heart', (tester) async {
    final server = _Server();
    await _pump(tester, server);

    // The heart exists and asked the server once — it used to be gated behind
    // store capability, so this row had neither button at all. The playlist
    // button is also offered: this device owns playlists of its own, so it can
    // act even when the server has none to edit.
    expect(find.byTooltip('Favourite'), findsOneWidget);
    expect(server.reads, 1);
    expect(find.byTooltip('Add to playlist'), findsOneWidget);
  });

  testWidgets('tapping the heart writes and stays lit', (tester) async {
    final server = _Server();
    await _pump(tester, server);

    await tester.tap(find.byTooltip('Favourite'));
    await tester.pump();

    expect(server.writes, 1);
    expect(server.starred, isTrue);
    expect(find.byTooltip('Favourited'), findsOneWidget);
  });

  testWidgets('the bar sits under the transport, not above it', (tester) async {
    final server = _Server();
    await _pump(tester, server);

    final heart = tester.getRect(find.byTooltip('Favourite'));
    final play = tester.getRect(find.byTooltip('Play'));
    expect(
      heart.top,
      greaterThan(play.top),
      reason: 'the heart is part of the controls block, below the play button',
    );
  });
}
