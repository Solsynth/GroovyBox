import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/search.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A server with a store behind it: it holds one song and can offer others.
class _Store extends LibrarySource implements ExtendableSource {
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
  Future<CatalogSearch> searchCatalog(String query, {int limit = 20}) async =>
      CatalogSearch(
        songs: const [
          // The one the library already has, offered again by the store.
          LibrarySong(
            sourceId: 'a',
            id: 'catalog-heard',
            title: 'Sunset Overdrive',
            artist: 'The Paper Kites',
            duration: Duration(seconds: 254),
          ),
          LibrarySong(
            sourceId: 'a',
            id: 'catalog-new',
            title: 'Sunset Overdrive (Live)',
            artist: 'The Paper Kites',
            duration: Duration(seconds: 260),
          ),
        ],
        albums: const [
          LibraryAlbum(
            sourceId: 'a',
            id: 'album-new',
            name: 'On the Corner Where You Live',
            duration: Duration(minutes: 44),
          ),
        ],
      );

  @override
  Future<List<LibrarySong>> searchCatalogue(
    String query, {
    int limit = 40,
  }) async => const [];

  @override
  Future<int> addToLibrary(CatalogKind kind, List<String> ids) async => 1;

  @override
  Future<bool> isFavourite(LibrarySong song) async => false;

  @override
  Future<void> setFavourite(LibrarySong song, {required bool value}) async {}

  @override
  Future<void> addToPlaylist(LibraryPlaylist playlist, LibrarySong song) async {}

  @override
  Future<List<LibraryPlaylist>> editablePlaylists() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError();
}

/// A playlist page with nothing in it: this suite is about search rows.
class _NoPlaylistSongs extends PlaylistSongs {
  @override
  Future<List<LibrarySong>> build(LibraryRef playlist) async => const [];
}

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// The library's own answer: one song, the same one the store also offers.
const _held = LibrarySong(
  sourceId: 'a',
  id: 'held',
  title: 'Sunset Overdrive',
  artist: 'The Paper Kites',
  album: 'On the Corner Where You Live',
  duration: Duration(seconds: 254),
);

/// A second store under the app's own account kind: two connections answer one
/// query, which is what a fold heading cannot attribute correctly.
class _SecondStore extends _Store {
  @override
  String get id => 'b';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'b',
    kind: LibraryKind.netease,
    baseUrl: 'https://netease.example.com',
    displayName: 'NetEase Cloud Music',
  );

  @override
  Future<CatalogSearch> searchCatalog(String query, {int limit = 20}) async =>
      CatalogSearch(
        songs: const [
          LibrarySong(
            sourceId: 'b',
            id: 'netease-song',
            title: 'NetEase Only',
            artist: 'Someone',
            duration: Duration(seconds: 200),
          ),
        ],
        albums: const [
          LibraryAlbum(
            sourceId: 'b',
            id: 'netease-album',
            name: 'NetEase Record',
            artist: 'Someone',
            duration: Duration(minutes: 40),
          ),
        ],
        playlists: const [
          LibraryPlaylist(
            sourceId: 'b',
            id: 'netease-list',
            name: 'NetEase List',
            duration: Duration(minutes: 30),
            songCount: 9,
          ),
        ],
      );

  @override
  Future<List<LibrarySong>> searchCatalogue(
    String query, {
    int limit = 40,
  }) async => const [];
}

/// Pumps the page inside the real router, so a store row can be followed to the
/// page it opens.
Future<void> _pumpRouted(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Store(), _SecondStore()]),
        playbackProvider.overrideWith(_Idle.new),
        libraryDatabaseProvider.overrideWithValue(null),
        searchSongsProvider.overrideWith(
          (ref, query) async => const <LibrarySong>[],
        ),
        searchGroupsProvider.overrideWith(
          (ref, query) async => const LibraryGroups(),
        ),
        playlistSongsProvider.overrideWith2((_) => _NoPlaylistSongs()),
      ],
      child: MaterialApp.router(
        theme: createAppThemeSet().light,
        routerConfig: AppRouter().config(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The router starts on Explore; search is its own tab.
  await tester.tap(find.byIcon(Symbols.search).last);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  List<LibrarySong> held = const [_held],
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Store()]),
        playbackProvider.overrideWith(_Idle.new),
        libraryDatabaseProvider.overrideWithValue(null),
        searchSongsProvider('sunset').overrideWith((ref) async => held),
        searchGroupsProvider.overrideWith(
          (ref, query) async => const LibraryGroups(),
        ),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const SearchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Library tab answers only what the libraries hold', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // The two tabs sit under the field, and Library is the one open.
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    // The held track is here; nothing the store offers is. That separation is
    // the point of the split: a store row under "Library" is the bug the
    // tabs exist to fix.
    expect(find.text('Sunset Overdrive'), findsOneWidget);
    expect(find.text('Sunset Overdrive (Live)'), findsNothing);
    expect(find.byTooltip('Add to library'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Explore tab offers what the library does not have', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    // The store's offer of the held track is dropped, not repeated: Explore
    // is only music the user can still add.
    expect(find.text('Sunset Overdrive'), findsNothing);
    expect(find.text('Sunset Overdrive (Live)'), findsOneWidget);
    // The held album is not offered back either — the library holds it by its
    // group search, even though none of its rows matched the query.
    expect(find.text('On the Corner Where You Live'), findsNothing);
    expect(find.byTooltip('Add to library'), findsWidgets);
    // Each row names the store it would come from, so two connections
    // answering one query cannot look like one store's hits.
    expect(find.textContaining('Home'), findsWidgets);
  });

  testWidgets('adding a store result says so instead of offering again', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to library').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.check_circle_rounded), findsWidgets);
  });

  testWidgets('the Library tab splits artists, albums and tracks into folds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          librarySourcesProvider.overrideWithValue([_Store()]),
          playbackProvider.overrideWith(_Idle.new),
          libraryDatabaseProvider.overrideWithValue(null),
          searchSongsProvider(
            'sunset',
          ).overrideWith((ref) async => const [_held]),
          searchGroupsProvider.overrideWith(
            (ref, query) async => LibraryGroups(
              artists: const [
                LibraryArtist(sourceId: 'a', id: 'ar1', name: 'The Paper Kites'),
              ],
              albums: const [
                LibraryAlbum(
                  sourceId: 'a',
                  id: 'al1',
                  name: 'On the Corner Where You Live',
                  duration: Duration.zero,
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Three kinds, three headings — the artist the query named is a row, not
    // a handful of their songs under one undifferentiated list.
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Tracks'), findsOneWidget);
    // The act appears twice on purpose: once as the artist card, once under
    // the album it made. What must not happen is nine of their tracks and no
    // row naming them.
    expect(find.text('The Paper Kites'), findsNWidgets(2));
    expect(find.text('On the Corner Where You Live'), findsOneWidget);

    // A section folds: the row goes away and the heading stays.
    await tester.tap(find.text('Tracks'));
    await tester.pumpAndSettle();
    expect(find.text('Sunset Overdrive'), findsNothing);
    expect(find.text('Tracks'), findsOneWidget);
  });

  testWidgets('each Explore row names the store it would come from', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          librarySourcesProvider.overrideWithValue([_Store(), _SecondStore()]),
          playbackProvider.overrideWith(_Idle.new),
          libraryDatabaseProvider.overrideWithValue(null),
          searchSongsProvider.overrideWith((ref, query) async => const [_held]),
          searchGroupsProvider.overrideWith(
            (ref, query) async => const LibraryGroups(),
          ),
        ],
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    // Two stores, one query: the second store's rows must not be labelled
    // with the first store's name. A heading over a merged block cannot tell
    // them apart; the row can, because the row carries its own source.
    expect(find.textContaining('NetEase Cloud Music'), findsWidgets);
    expect(find.textContaining('Home'), findsOneWidget);
    expect(find.text('NetEase Only'), findsOneWidget);
    expect(find.text('Sunset Overdrive (Live)'), findsOneWidget);
  });

  testWidgets('a store album or playlist opens its own page', (tester) async {
    await _pumpRouted(tester);
    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    // The playlists fold lists the store's collection, and tapping it opens
    // the playlist page rather than silently doing nothing — the reported
    // defect: a searched NetEase playlist could not be opened at all.
    expect(find.text('NetEase List'), findsOneWidget);
    await tester.tap(find.text('NetEase List'));
    await tester.pumpAndSettle();
    // The page it landed on is the playlist's: the fake has no tracks, so it
    // states that instead of falling back to the search page.
    expect(find.text('This playlist is empty'), findsOneWidget);
    expect(find.text('Sunset Overdrive (Live)'), findsNothing);
  });

  testWidgets('Explore searches albums and playlists, not just tracks', (
    tester,
  ) async {
    await _pump(
      tester,
      held: const [
        // No album, so the store's record is not filtered out as one the
        // library already holds.
        LibrarySong(
          sourceId: 'a',
          id: 'held',
          title: 'Sunset Overdrive',
          artist: 'The Paper Kites',
          duration: Duration(seconds: 254),
        ),
      ],
    );
    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    // One query answers three kinds, and each gets its own fold so a record is
    // not buried under the songs that mention it.
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('On the Corner Where You Live'), findsOneWidget);
    expect(find.text('Sunset Overdrive (Live)'), findsOneWidget);
  });
}
