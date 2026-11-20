import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
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
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'GroovyBox',
      packageName: 'dev.solsynth.groovybox',
      version: '2.0.0',
      buildNumber: '20',
      buildSignature: '',
    );
  });

  // The row used to render the raw placeholder: its copy has two slots (count
  // and size) while the call site passed one, and easy_localization fills only
  // as many slots as it is given.
  testWidgets('offline rows spell out their count and their size', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(430, 860));
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Saved answers'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('{}'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('about opens from settings and reports the installed build', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(430, 860));
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('About GroovyBox'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('About GroovyBox'));
    await tester.pumpAndSettle();

    expect(find.text('Version 2.0.0 · Build 20'), findsOneWidget);
    expect(find.text('2.0.0'), findsOneWidget);
    expect(find.text('dev.solsynth.groovybox'), findsOneWidget);

    // Don't ship a blank license page.
    await tester.scrollUntilVisible(
      find.text('Open source licenses'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Open source licenses'), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
