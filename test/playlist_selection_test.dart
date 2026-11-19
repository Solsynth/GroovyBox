import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/owned_playlist.dart';
import 'package:groovy_box/widgets/track_selection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

const _songs = [
  LibrarySong(
    sourceId: 'a',
    id: 's1',
    title: 'Yellow',
    artist: 'Coldplay',
    duration: Duration(seconds: 266),
  ),
  LibrarySong(
    sourceId: 'a',
    id: 's2',
    title: 'Sunday',
    artist: 'Sondre Lerche',
    duration: Duration(seconds: 200),
  ),
];

Future<LibraryCatalog> _catalogWithPlaylist() async {
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = LibraryCatalog(db);
  final playlist = await catalog.createPlaylist('Sunday drive');
  await catalog.addToOwnedPlaylist(playlist.id, _songs);
  return catalog;
}

Future<void> _pump(WidgetTester tester, LibraryCatalog catalog, int id) async {
  tester.view.physicalSize = const Size(1100, 2200);
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
        playbackProvider.overrideWith(_IdlePlayback.new),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: OwnedPlaylistDetailScreen(playlistId: id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a device playlist names itself in the hero', (tester) async {
    final catalog = await _catalogWithPlaylist();
    final id = (await catalog.ownedPlaylists()).single.id;

    await _pump(tester, catalog, id);

    // The hero is the page's heading; the list of rows names tracks, not the
    // collection, so the name has to come from here.
    expect(find.text('Sunday drive'), findsOneWidget);
  });

  testWidgets('selection removes several tracks in one go', (tester) async {
    final catalog = await _catalogWithPlaylist();
    final id = (await catalog.ownedPlaylists()).single.id;
    await _pump(tester, catalog, id);

    await tester.tap(find.byTooltip('playlistsSelectMode'.tr()));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionCheckbox), findsNWidgets(2));

    await tester.tap(find.byType(SelectionCheckbox).first);
    await tester.pumpAndSettle();
    expect(find.text('playlistSelectionCount'.plural(1)), findsOneWidget);

    await tester.tap(find.byTooltip('playlistSelectionRemove'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('commonRemove'.tr()));
    await tester.pumpAndSettle();

    // One entry is gone, the other keeps its place.
    final entries = await catalog.ownedPlaylistEntryRows(id);
    expect(entries, hasLength(1));
    expect(entries.single.$2.title, 'Sunday');
    expect(find.byType(SelectionCheckbox), findsNothing);
  });
}
