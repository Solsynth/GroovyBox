import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/about.dart';
import 'package:groovy_box/screens/settings.dart';
import 'package:groovy_box/widgets/now_playing_dock.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Playing extends Playback {
  @override
  PlaybackState build() => const PlaybackState(
    queue: [
      LibrarySong(
        sourceId: 'a',
        id: 's1',
        title: 'Sunset Overdrive',
        duration: Duration(seconds: 254),
      ),
    ],
    currentIndex: 0,
    duration: Duration(seconds: 254),
  );
}

Future<void> _pumpApp(WidgetTester tester, Size size) async {
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
        libraryDatabaseProvider.overrideWithValue(null),
        localLibraryPathProvider.overrideWithValue(null),
        playbackProvider.overrideWith(_Playing.new),
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

/// Scrolls [page] until [target] is on screen.
Future<void> _scrollTo(WidgetTester tester, Finder page, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.descendant(of: page, matching: find.byType(Scrollable)),
  );
  await tester.pumpAndSettle();
}

/// The end of a page's scroll must land above the floating chrome, not under
/// it: the dock is what covers the page, and the clearance is the shell's to
/// publish rather than each page's to remember.
void _expectClearOfDock(WidgetTester tester, Finder lastRow) {
  final row = tester.getRect(lastRow);
  final dock = tester.getRect(find.byType(NowPlayingDock));
  expect(
    row.bottom,
    lessThanOrEqualTo(dock.top),
    reason:
        'the last row (${row.bottom}) must not sit under the dock '
        '(${dock.top})',
  );
}

Future<void> _openAbout(WidgetTester tester) async {
  await tester.tap(find.byIcon(Symbols.settings));
  await tester.pumpAndSettle();
  await _scrollTo(
    tester,
    find.byType(SettingsScreen),
    find.text('About GroovyBox'),
  );
  await tester.tap(find.text('About GroovyBox'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in [
    ('compact', const Size(430, 860)),
    ('wide', const Size(1440, 900)),
  ]) {
    testWidgets('settings ends clear of the dock — $label', (tester) async {
      await _pumpApp(tester, size);
      await tester.tap(find.byIcon(Symbols.settings));
      await tester.pumpAndSettle();

      // The last thing on the page: the streams footnote.
      final footer = find.textContaining('GroovyBox streams from');
      await _scrollTo(tester, find.byType(SettingsScreen), footer);
      _expectClearOfDock(tester, footer);
    });

    testWidgets('about ends clear of the dock — $label', (tester) async {
      await _pumpApp(tester, size);
      await _openAbout(tester);

      final credit = find.textContaining('Made by');
      await _scrollTo(tester, find.byType(AboutScreen), credit);
      _expectClearOfDock(tester, credit);
    });
  }
}
