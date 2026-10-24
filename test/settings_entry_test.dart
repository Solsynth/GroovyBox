import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

Future<void> _pumpShell(WidgetTester tester, Size size) async {
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
}
