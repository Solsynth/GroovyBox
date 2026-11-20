import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

late _Idle _playback;

class _Idle extends Playback {
  final volumes = <double>[];

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    state = state.copyWith(volume: volume);
  }
}

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  LibraryDatabase? library,
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
        librarySourcesProvider.overrideWithValue(const []),
        libraryDatabaseProvider.overrideWithValue(library),
        playbackProvider.overrideWith(() {
          _playback = _Idle();
          return _playback;
        }),
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
  // Settings is one destination with one button per layout: the Browse header
  // on compact, the bottom of the rail on wide. A second gear in the tab
  // capsule was the same control twice.
  testWidgets('compact shell offers settings exactly once', (tester) async {
    await _pumpShell(tester, const Size(430, 860));
    expect(find.byIcon(Symbols.settings), findsOneWidget);
  });

  testWidgets('wide shell offers settings exactly once', (tester) async {
    await _pumpShell(tester, const Size(1400, 900));
    expect(find.byIcon(Symbols.settings), findsOneWidget);
  });

  testWidgets('settings reports what the local library knows', (tester) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);
    await catalog.adopt(
      const LibrarySong(
        sourceId: 'a',
        id: 's1',
        title: 'Yellow',
        artist: 'Coldplay',
        duration: Duration(seconds: 266),
      ),
    );

    await _pumpShell(tester, const Size(430, 860), library: db);
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    // The row is below the fold on a compact window, and the count arrives
    // from the database asynchronously.
    await tester.scrollUntilVisible(
      find.text('On this device'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    // The row reads the real database rather than a placeholder: one song,
    // still reachable through the source it came from.
    expect(find.textContaining('1 song known on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the AI translation row is off, and says what turns it on', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(430, 860));
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.scrollUntilVisible(
      find.text('Translate with Solink AI'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    // No account on this device, so the switch cannot be flipped and the row
    // names the step that would enable it instead of going quietly inert.
    final row = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Translate with Solink AI'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(row.value, isFalse);
    expect(row.onChanged, isNull);
    expect(
      find.text('Sign in with Solarpass under Solink to choose a model.'),
      findsOneWidget,
    );
  });

  testWidgets('settings drives the transport volume', (tester) async {
    await _pumpShell(tester, const Size(430, 860));
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    // The slider is the only volume handle in the app: the player page no
    // longer carries one, and the arrow keys nudge the same state. The
    // dashboard card above Appearance pushes it below the first frame, so
    // scroll to it before looking, as a user does on a phone window.
    await tester.scrollUntilVisible(
      find.text('Volume'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    await tester.drag(slider, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(_playback.volumes, isNotEmpty);
    expect(_playback.volumes.last, lessThan(100));
  });

  testWidgets('adding a library from settings allows navigating back', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(900, 900));
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    // The plugins card sits above the libraries card, so on a 900 px window
    // the button is below the fold and the lazy list has not built it yet.
    final addLibraryButton = find.text('Add library');
    await tester.scrollUntilVisible(
      addLibraryButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(addLibraryButton);
    await tester.pumpAndSettle();

    // Verify setup screen opened with Back and Cancel buttons
    expect(find.text('Connect a library'), findsOneWidget);
    final backButton = find.byTooltip('Back');
    expect(backButton, findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tapping Back returns to settings
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Add library'), findsOneWidget);
    expect(find.text('Connect a library'), findsNothing);
  });

  testWidgets('settings offers a library to play everything from', (
    tester,
  ) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          librarySourcesProvider.overrideWithValue(const []),
          libraryDatabaseProvider.overrideWithValue(db),
          localLibraryPathProvider.overrideWithValue('/tmp/groovy-box-test'),
          playbackProvider.overrideWith(() {
            _playback = _Idle();
            return _playback;
          }),
        ],
        child: MaterialApp.router(
          theme: createAppThemeSet().light,
          routerConfig: AppRouter().config(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    final row = find.text('Preferred library');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    // The row keeps the old rule as an entry of its own: a preference is a
    // choice, and "no preference" has to be choosable again.
    expect(find.text("The track's own library"), findsOneWidget);

    await tester.tap(find.text("The track's own library"));
    await tester.pumpAndSettle();
    // The local library is a source like any other, and the one a device-only
    // listener wants to prefer.
    expect(find.text('Local files'), findsWidgets);

    await tester.tap(find.text('Local files').last);
    await tester.pumpAndSettle();
    expect(prefs.getString('app_preferred_playback_source'), kLocalSourceId);
  });
}
