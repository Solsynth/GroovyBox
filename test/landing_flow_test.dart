import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/browse.dart';
import 'package:groovy_box/screens/setup.dart';
import 'package:groovy_box/screens/settings.dart';
import 'package:groovy_box/shell/shell_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// A fresh install: no server, no imported files, a working database.
Future<void> _pumpFreshInstall(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        // No path: the local library exists only once storage is resolved,
        // which is `main`'s job. The page's nudge must not depend on it.
        localLibraryPathProvider.overrideWithValue(null),
        playbackProvider.overrideWith(_Idle.new),
      ],
      child: MaterialApp.router(
        theme: createAppThemeSet().light,
        routerConfig: AppRouter().config(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a fresh install lands in the library, not on setup', (
    tester,
  ) async {
    await _pumpFreshInstall(tester, const Size(430, 900));

    // The shell is the root: browsing, tabs and settings are all reachable
    // before any server exists.
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(BrowseScreen), findsOneWidget);
    expect(find.byType(SetupScreen), findsNothing);
    expect(find.byIcon(Symbols.settings), findsOneWidget);
  });

  testWidgets('browse suggests connecting a server or importing files', (
    tester,
  ) async {
    await _pumpFreshInstall(tester, const Size(430, 900));

    expect(find.text('Add some music'), findsOneWidget);
    expect(find.text('Connect a library'), findsOneWidget);
    expect(find.text('Import files'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the suggestion opens setup and can come back', (tester) async {
    await _pumpFreshInstall(tester, const Size(430, 900));

    await tester.tap(find.text('Connect a library'));
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsOneWidget);
    // Adding a library is never a dead end: it was pushed over the shell.
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsNothing);
    expect(find.byType(BrowseScreen), findsOneWidget);
  });

  testWidgets('settings offers importing files on this device', (tester) async {
    await _pumpFreshInstall(tester, const Size(430, 900));

    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Import music files'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Import music files'), findsOneWidget);
    expect(
      find.textContaining('Copy audio files from this device'),
      findsOneWidget,
    );
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
