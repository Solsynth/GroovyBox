import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/dashboard_layout.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/explore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake extends LibrarySource {
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

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

Future<SharedPreferences> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Fake()]),
        playbackProvider.overrideWith(_Idle.new),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const ExploreScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  testWidgets('the dashboard folds a section and remembers it by page', (
    tester,
  ) async {
    final prefs = await _pump(tester);

    // Recently added is a shelf with something in it; friends is silent
    // without a session, so it is not drawn at all.
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('Friends are listening'), findsNothing);

    await tester.tap(find.text('Recently added'));
    await tester.pumpAndSettle();

    // Remembered under the dashboard's namespace, not the library's.
    expect(
      prefs.getStringList('app_collapsed_sections'),
      contains('dashboard:recentlyAdded'),
    );
    expect(find.text('Made for you'), findsOneWidget);
  });

  testWidgets('a removed section can be restored from the customize sheet', (
    tester,
  ) async {
    final prefs = await _pump(tester);
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(ExploreScreen)),
    ).read(dashboardLayoutProvider.notifier);
    await notifier.hide(DashboardSections.recentlyAdded);
    await tester.pumpAndSettle();

    expect(find.text('Recently added'), findsNothing);

    await tester.tap(find.byTooltip('Customize dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard sections'), findsOneWidget);
    expect(find.text('Recently added'), findsOneWidget);

    // The switch beside that row turns it back on.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Recently added'),
          matching: find.byType(Row),
        ).first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    // The switch wrote the change already; closing the sheet is the page
    // behind it answering. The sheet itself still lists the shelf, so the
    // assertion is that the layout no longer hides it.
    expect(
      jsonDecode(prefs.getString('app_dashboard_layout')!)['hidden'] ??
          const <String>[],
      isNot(contains('recentlyAdded')),
    );
    await tester.tapAt(const Offset(10, 10)); // dismisses the sheet
    await tester.pumpAndSettle();
    expect(find.text('Recently added'), findsOneWidget);
  });
}
