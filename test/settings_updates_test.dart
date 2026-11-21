import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/core/update_preferences.dart';
import 'package:groovy_box/core/updates.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_release_feed.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

Future<ProviderContainer> _pumpSettings(
  WidgetTester tester,
  ReleaseFeed feed, {
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(store),
      librarySourcesProvider.overrideWithValue(const []),
      libraryDatabaseProvider.overrideWithValue(null),
      playbackProvider.overrideWith(_Idle.new),
      releaseFeedProvider.overrideWithValue(feed),
      appTargetProvider.overrideWith(
        (ref) async => const AppTarget(
          platform: 'macos',
          architecture: 'arm64',
          osVersion: '15.1',
          version: '2.0.0+21',
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  return container;
}

Future<void> _scrollToUpdates(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Latest release'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'GroovyBox',
      packageName: 'dev.solsynth.groovybox',
      version: '2.0.0',
      buildNumber: '21',
      buildSignature: '',
    );
  });

  testWidgets('the section reports the published release and its channel', (
    tester,
  ) async {
    final release = FakeReleaseFeed.build();
    await _pumpSettings(tester, FakeReleaseFeed(release: release));
    await _scrollToUpdates(tester);

    // Section labels are drawn uppercased.
    expect(find.text('UPDATES'), findsOneWidget);
    expect(find.text('Latest release'), findsOneWidget);
    // Name and version on one line, both from the feed rather than a constant.
    expect(find.text('GroovyBox 2.1  ·  2.1.0+24'), findsOneWidget);
    // The picker says `stable` as a word, in the row and in the closed
    // control; the feed's own channels appear once it opens.
    expect(find.text('Stable'), findsNWidgets(2));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a check with nothing newer says so instead of opening a sheet', (
    tester,
  ) async {
    final feed = FakeReleaseFeed(release: FakeReleaseFeed.build(), updateAvailable: false);
    await _pumpSettings(tester, feed);
    await _scrollToUpdates(tester);

    await tester.tap(find.text('Check now'));
    await tester.pumpAndSettle();

    expect(feed.checks, 1);
    expect(find.text('This is the latest release.'), findsOneWidget);
    expect(find.text('Release page'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer release opens the sheet with its notes and download', (
    tester,
  ) async {
    final feed = FakeReleaseFeed(
      release: FakeReleaseFeed.build(),
      updateAvailable: true,
    );
    await _pumpSettings(tester, feed);
    await _scrollToUpdates(tester);

    await tester.tap(find.text('Check now'));
    await tester.pumpAndSettle();

    expect(find.text('GroovyBox 2.1'), findsOneWidget);
    expect(find.text('2.1.0+24'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('2.0.0+21'), findsOneWidget);
    // 42 MiB, formatted by the app's own size helper.
    expect(find.text('42.0 MB'), findsOneWidget);
    // Markdown rendered, not echoed: the bold run lands as its own span, so
    // the asterisks are gone and the words are present.
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('is back.'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed check reports the failure and opens nothing', (
    tester,
  ) async {
    await _pumpSettings(tester, FakeReleaseFeed(fails: true));
    await _scrollToUpdates(tester);

    expect(find.text('Solsynth Express did not answer.'), findsOneWidget);

    await tester.tap(find.text('Check now'));
    await tester.pumpAndSettle();

    expect(find.text('Could not reach the release feed.'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a product with no channel says so, and offers no check', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      FakeReleaseFeed(publishedChannels: const []),
    );
    await tester.scrollUntilVisible(
      find.text('No release channel yet'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Check now'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unpublished build says why, and offers no check', (
    tester,
  ) async {
    await _pumpSettings(tester, FakeReleaseFeed(configured: false));
    await tester.scrollUntilVisible(
      find.text('Not wired to a product'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Check now'), findsNothing);
    expect(find.text('Release channel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning the switch off stops the row from asking the feed', (
    tester,
  ) async {
    final feed = FakeReleaseFeed(release: FakeReleaseFeed.build());
    final container = await _pumpSettings(tester, feed);
    await _scrollToUpdates(tester);

    expect(find.text('GroovyBox 2.1  ·  2.1.0+24'), findsOneWidget);

    await tester.tap(find.text('Look for updates at launch'));
    await tester.pumpAndSettle();

    expect(container.read(updateChecksEnabledProvider), isFalse);
    expect(find.text('Update checks are off.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
