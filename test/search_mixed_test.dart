import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
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

Future<void> _pump(WidgetTester tester) async {
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
        searchSongsProvider(
          'sunset',
        ).overrideWith((ref) async => const [_held]),
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
    // The held album is not offered back either.
    expect(find.text('On the Corner Where You Live'), findsNothing);
    expect(find.byTooltip('Add to library'), findsWidgets);
    // The rows are grouped under the store that sells them.
    expect(find.text('From Home'), findsOneWidget);
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
}
