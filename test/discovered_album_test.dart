import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/metadata.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/screens/artists.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// A server with a store behind it: it holds the artist's one album and sells
/// the other one, which it can list tracks for.
class _Store extends LibrarySource implements ExtendableSource {
  _Store({this.storeHasTracks = true});

  /// A store that sells the record but cannot turn it into tracks: the case
  /// the lookup must not route to, because the page would open empty.
  final bool storeHasTracks;

  @override
  String get id => 'a';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'a',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://a',
    displayName: 'Alpha',
  );

  @override
  Future<List<LibraryArtist>> artists() async => const [
    LibraryArtist(sourceId: 'a', id: 'artist-1', name: 'Radiohead'),
  ];

  @override
  Future<List<LibraryAlbum>> artistAlbums(String artistId) async => const [
    LibraryAlbum(
      sourceId: 'a',
      id: 'album-1',
      name: 'OK Computer',
      artist: 'Radiohead',
      artistId: 'artist-1',
      duration: Duration(minutes: 53),
    ),
  ];

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async =>
      albumId != 'store-bends'
      ? const [
          LibrarySong(
            sourceId: 'a',
            id: 'ok-1',
            title: 'Airbag',
            artist: 'Radiohead',
            album: 'OK Computer',
            albumId: 'album-1',
            duration: Duration(minutes: 4),
          ),
        ]
      : storeHasTracks
      ? const [
          LibrarySong(
            sourceId: 'a',
            id: 'store-bends-1',
            title: 'Planet Telex',
            artist: 'Radiohead',
            album: 'The Bends',
            albumId: 'store-bends',
            duration: Duration(minutes: 4),
          ),
        ]
      : const [];

  /// What the account holds: the album the library already lists.
  @override
  Future<List<LibrarySong>> searchCatalogue(
    String query, {
    int limit = 40,
  }) async => [
    if (query.toLowerCase().contains('ok computer'))
      const LibrarySong(
        sourceId: 'a',
        id: 'ok-1',
        title: 'Airbag',
        artist: 'Radiohead',
        album: 'OK Computer',
        albumId: 'album-1',
        duration: Duration(minutes: 4),
      ),
  ];

  /// The store's answer: the record the library does not have, under a
  /// spelling the fleet's title does not share exactly.
  @override
  Future<CatalogSearch> searchCatalog(String query, {int limit = 25}) async =>
      CatalogSearch(
        songs: storeHasTracks ? await albumSongs('store-bends') : const [],
        albums: const [
          LibraryAlbum(
            sourceId: 'a',
            id: 'store-bends',
            name: 'The Bends',
            artist: 'Radiohead',
            duration: Duration(minutes: 48),
            year: 1995,
          ),
        ],
      );

  @override
  Future<int> addToLibrary(CatalogKind kind, List<String> ids) async => 1;

  @override
  Future<bool> isFavourite(LibrarySong song) async => false;

  @override
  Future<void> setFavourite(LibrarySong song, {required bool value}) async {}

  @override
  Future<void> addToPlaylist(
    LibraryPlaylist playlist,
    LibrarySong song,
  ) async {}

  @override
  Future<List<LibraryPlaylist>> editablePlaylists() async => const [];

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _artist = PulsarEntityMetadata(
  title: 'Radiohead',
  albums: [
    PulsarAlbumSummary(
      mbid: 'rg-2',
      title: 'The Bends',
      year: 1995,
      type: 'Album',
    ),
  ],
  releaseGroupCount: 9,
);

Future<void> _pump(WidgetTester tester, {bool storeHasTracks = true}) async {
  tester.view.physicalSize = const Size(1100, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = AppRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([
          _Store(storeHasTracks: storeHasTracks),
        ]),
        libraryDatabaseProvider.overrideWithValue(null),
        playbackProvider.overrideWith(_Idle.new),
        pulsarArtistProfileProvider(
          'Radiohead',
          language: 'en',
        ).overrideWith((ref) async => _artist),
      ],
      child: MaterialApp.router(
        theme: createAppThemeSet().light,
        routerConfig: router.config(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push(
    ArtistDetailRoute(
      sourceId: 'a',
      artistId: 'artist-1',
      artistName: 'Radiohead',
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a fleet-only record opens where a store can play it', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(ArtistDetailScreen), findsOneWidget);
    expect(find.text('The Bends'), findsOneWidget);

    await tester.tap(find.text('The Bends'));
    await tester.pumpAndSettle();

    // The page it opened is the store's copy: the record the device could not
    // open from the discography before, now playable from its own source.
    expect(find.byType(AlbumDetailScreen), findsOneWidget);
    expect(find.text('Planet Telex'), findsOneWidget);
  });

  testWidgets('a record nobody can list tracks for says so instead', (
    tester,
  ) async {
    await _pump(tester, storeHasTracks: false);

    await tester.tap(find.text('The Bends'));
    await tester.pumpAndSettle();

    // No empty album page: the tile is honest about the record being absent.
    expect(find.byType(AlbumDetailScreen), findsNothing);
    expect(
      find.text('None of your libraries has this record yet.'),
      findsOneWidget,
    );
  });
}
