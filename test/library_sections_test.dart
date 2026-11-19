import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/library.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
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

class _FakeSource extends LibrarySource {
  @override
  final String id = 'a';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'a',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://a',
    displayName: 'Alpha',
  );

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, LibraryCatalog catalog) async {
  tester.view.physicalSize = const Size(1100, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLibraryProvider.overrideWithValue(null),
        libraryCatalogProvider.overrideWithValue(catalog),
        librarySourcesProvider.overrideWithValue([_FakeSource()]),
        recentAlbumsProvider.overrideWith(() => _FakeAlbums()),
        playbackProvider.overrideWith(_IdlePlayback.new),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const LibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a section folds on its header and the fold is remembered', (
    tester,
  ) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);
    await catalog.createPlaylist('Sunday');

    await _pump(tester, catalog);

    expect(find.text('An album'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);

    // Folding the album shelf leaves its name behind as the way back.
    await tester.tap(find.text('Recently added'));
    await tester.pumpAndSettle();
    expect(find.text('An album'), findsNothing);
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);

    // Remembered: the preference is the fold, not a widget's mood. The key
    // is namespaced by page, so the dashboard's own folds never move one of
    // these.
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('app_collapsed_sections'),
      contains('library:albums'),
    );

    // And it opens again from the same place.
    await tester.tap(find.text('Recently added'));
    await tester.pumpAndSettle();
    expect(find.text('An album'), findsOneWidget);
    expect(
      prefs.getStringList('app_collapsed_sections'),
      isNot(contains('library:albums')),
    );
  });
}
