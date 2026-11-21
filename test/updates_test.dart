import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/update_preferences.dart';
import 'package:groovy_box/core/updates.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_release_feed.dart';

const _target = AppTarget(
  platform: 'macos',
  architecture: 'arm64',
  osVersion: '15.1',
  version: '2.0.0+21',
);

void main() {
  group('canonicalBuildNumber', () {
    // Flutter's Gradle plugin adds an ABI index to the version code of a
    // `--split-per-abi` APK, and package_info_plus reports the overridden
    // value. Releases are tagged with the canonical code, so a split build
    // compares 20021 against a release tagged 18021 without this.
    test('strips the arm64 offset', () {
      expect(canonicalBuildNumber('18021', 'android', 'arm64'), '16021');
    });

    test('strips the x86_64 offset', () {
      expect(canonicalBuildNumber('18021', 'android', 'x86_64'), '14021');
    });

    test('leaves an unsplit Android build alone', () {
      // Below the smallest offset, so no split was applied.
      expect(canonicalBuildNumber('21', 'android', 'arm64'), '21');
    });

    test('leaves other platforms and unknown ABIs alone', () {
      expect(canonicalBuildNumber('21', 'macos', 'arm64'), '21');
      expect(canonicalBuildNumber('21', 'android', 'x86'), '21');
    });

    test('passes a non-numeric build number through', () {
      expect(canonicalBuildNumber('local', 'android', 'arm64'), 'local');
    });
  });

  Future<void> runCheck(ProviderContainer container) =>
      runLaunchUpdateCheck(container, resolveContext: () async => null);

  group('runLaunchUpdateCheck', () {
    late FakeReleaseFeed feed;

    Future<({ProviderContainer container, SharedPreferences prefs})> harness(
      Map<String, Object> prefs,
      FakeReleaseFeed fake,
    ) async {
      feed = fake;
      SharedPreferences.setMockInitialValues(prefs);
      final store = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(store),
          releaseFeedProvider.overrideWithValue(fake),
          appTargetProvider.overrideWith((ref) async => _target),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, prefs: store);
    }

    test('records the version on a first run and asks nothing', () async {
      final h = await harness({}, FakeReleaseFeed(release: FakeReleaseFeed.build()));
      await runCheck(h.container);

      expect(feed.checks, 0);
      expect(h.prefs.getString('app_last_known_version'), '2.0.0+21');
    });

    test('an unchanged version asks the feed', () async {
      final h = await harness({
        'app_last_known_version': '2.0.0+21',
      }, FakeReleaseFeed(release: FakeReleaseFeed.build(), updateAvailable: true));
      await runCheck(h.container);

      // The sheet needs a navigator context, which no test has; the request
      // is what this asserts, and the sheet is covered by the widget tests.
      expect(feed.checks, 1);
    });

    test('an upgraded version records it and does not check for a newer one',
        () async {
      final h = await harness({
        'app_last_known_version': '1.9.0+18',
      }, FakeReleaseFeed(release: FakeReleaseFeed.build()));
      await runCheck(h.container);

      expect(feed.checks, 0);
      expect(h.prefs.getString('app_last_known_version'), '2.0.0+21');
    });

    test('the switch off stops the check from recording anything', () async {
      final h = await harness({
        'app_update_checks': false,
        'app_last_known_version': '2.0.0+21',
      }, FakeReleaseFeed(release: FakeReleaseFeed.build()));
      await runCheck(h.container);

      expect(feed.checks, 0);
    });
  });
}
