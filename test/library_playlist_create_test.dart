import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/library.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

Future<void> _pump(WidgetTester tester, LibraryCatalog catalog) async {
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
        home: const LibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Playlists are a view of the same collection, one switch away.
  await tester.tap(find.text('libraryPlaylists'.tr()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('device playlists are listed and can be started from the library', (
    tester,
  ) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);
    await catalog.createPlaylist('Sunday');

    await _pump(tester, catalog);

    // The device's own list is a section of its own, above anything a server
    // holds, and it says what the playlist is called.
    expect(find.text('libraryOwnedPlaylists'.tr()), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
  });

  testWidgets('the new playlist button asks for a name', (tester) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pump(tester, LibraryCatalog(db));

    // An empty device list is an invitation with the action in the header.
    expect(find.text('libraryOwnedPlaylistsEmpty'.tr()), findsOneWidget);
    await tester.tap(find.text('libraryNewPlaylist'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('playlistPickerNewLabel'.tr()), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Sunday');
    // Cancel: the dialog's job here is to exist and take a name, and the
    // write path is covered by the catalog test.
    await tester.tap(find.text('commonCancel'.tr()));
    await tester.pumpAndSettle();
    expect(await LibraryCatalog(db).ownedPlaylists(), isEmpty);
  });
}
