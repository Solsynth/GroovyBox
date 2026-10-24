import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/screens/browse.dart';
import 'package:groovy_box/screens/playlists.dart';
import 'package:groovy_box/screens/queue.dart';
import 'package:groovy_box/screens/settings.dart';
import 'package:groovy_box/widgets/now_playing_dock.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovy_box/core/app.dart';

class _Fake extends LibrarySource {
  _Fake(this.id);
  @override
  final String id;
  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://$id',
    displayName: 'Alpha',
  );
  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;
  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://$id/${song.id}');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakePlayback extends Playback {
  _FakePlayback(this.initial);
  final PlaybackState initial;
  @override
  PlaybackState build() => initial;
}

const _song = LibrarySong(
  sourceId: 'a',
  id: 's1',
  title: 'A fairly long song title for the dock',
  duration: Duration(seconds: 240),
);

const _state = PlaybackState(
  queue: [_song],
  currentIndex: 0,
  duration: Duration(seconds: 240),
  position: Duration(seconds: 61),
);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required Size size,
  bool withSong = true,
  bool dock = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Fake('a')]),
        playbackProvider.overrideWith(
          () => _FakePlayback(withSong ? _state : const PlaybackState()),
        ),
        recentAlbumsProvider.overrideWith(() => _FakeAlbums()),
        playlistsProvider.overrideWith(() => _FakePlaylists()),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: Scaffold(
          body: dock
              ? Column(
                  children: [
                    Expanded(child: page),
                    const NowPlayingDock(),
                  ],
                )
              : page,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakeAlbums extends RecentAlbums {
  @override
  Future<List<LibraryAlbum>> build() async => const [
    LibraryAlbum(
      sourceId: 'a',
      id: '1',
      name: 'An album',
      artist: 'Artist',
      duration: Duration(minutes: 40),
    ),
  ];
}

class _FakePlaylists extends Playlists {
  @override
  Future<List<LibraryPlaylist>> build() async => const [
    LibraryPlaylist(
      sourceId: 'a',
      id: '1',
      name: 'A playlist',
      duration: Duration(minutes: 42),
      songCount: 12,
    ),
  ];
}

void main() {
  group('pages lay out at phone and wide widths', () {
    const phone = Size(420, 780);
    const wide = Size(1440, 900);

    for (final size in [phone, wide]) {
      final label = size.width > 1000 ? 'wide' : 'compact';

      testWidgets('browse — $label', (tester) async {
        await _pump(tester, const BrowseScreen(), size: size, dock: true);
        expect(find.text('Browse'), findsOneWidget);
        expect(find.text('Made for you'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('albums — $label', (tester) async {
        await _pump(tester, const AlbumsScreen(), size: size, dock: true);
        expect(find.text('Albums'), findsOneWidget);
        expect(find.text('An album'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('playlists — $label', (tester) async {
        await _pump(tester, const PlaylistsScreen(), size: size, dock: true);
        expect(find.text('A playlist'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('queue — $label', (tester) async {
        await _pump(tester, const QueueScreen(), size: size, dock: true);
        expect(find.text('Queue'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings — $label', (tester) async {
        await _pump(tester, const SettingsScreen(), size: size, dock: true);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Liquid glass'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('dock shows the scrubber only when wide', (tester) async {
    await _pump(
      tester,
      const SizedBox.shrink(),
      size: const Size(420, 780),
      dock: true,
    );
    expect(find.byType(Slider), findsNothing);

    await _pump(
      tester,
      const SizedBox.shrink(),
      size: const Size(1440, 900),
      dock: true,
    );
    expect(find.byType(Slider), findsOneWidget);
  });
}
