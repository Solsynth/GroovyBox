import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/setup.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// The window a routed page draws in, with a phone's status bar above it.
Future<void> _pumpApp(WidgetTester tester, {double statusBar = 0}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: statusBar);
  tester.view.viewPadding = FakeViewPadding(top: statusBar);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue(const []),
        libraryDatabaseProvider.overrideWithValue(null),
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

  await tester.tap(find.text('Connect a library').first);
  await tester.pumpAndSettle();
  expect(find.byType(SetupScreen), findsOneWidget);
}

void main() {
  // Setup is the only page pushed above the shell, so nothing above it has
  // spent the status bar's inset. Without its own `SafeArea` the headline drew
  // at the window's top edge, under the clock.
  testWidgets('setup starts below the status bar', (tester) async {
    await _pumpApp(tester, statusBar: 59);

    final headline = tester.getTopLeft(find.text('Connect a library').last);
    expect(
      headline.dy,
      greaterThanOrEqualTo(59),
      reason: 'the headline must clear the status bar',
    );
  });

  testWidgets('setup owns an opaque plane', (tester) async {
    await _pumpApp(tester);

    // A page that paints nothing of its own lets the page underneath show
    // through while the back-swipe drags it aside.
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SetupScreen),
        matching: find.byType(Scaffold),
      ),
    );
    final painted =
        scaffold.backgroundColor ??
        Theme.of(tester.element(find.byType(SetupScreen)))
            .scaffoldBackgroundColor;
    expect(painted.a, 1.0, reason: 'the page plane must be opaque');
  });
}
