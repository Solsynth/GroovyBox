/// The user's update preferences, and the launch-time check that acts on
/// them.
///
/// Kept apart from [updates.dart] so the network client has no Riverpod
/// dependency: `updates.dart` is callable from a plain function or a test, and
/// this file is what turns it into the app's behaviour.
library;

import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/updates.dart';
import 'package:groovy_box/widgets/release_sheet.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:solsynth_express/api.dart';

const _kUpdateChannelKey = 'app_update_channel';
const _kUpdateChecksKey = 'app_update_checks';
const _kLastKnownVersionKey = 'app_last_known_version';

/// Whether the app looks for a new release at launch.
///
/// On by default: the check is one request, it is skipped entirely when the
/// build carries no product id, and the sheet only appears when a release is
/// actually newer than what is installed.
class UpdateChecksEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kUpdateChecksKey) ?? true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kUpdateChecksKey, enabled);
  }
}

final updateChecksEnabledProvider =
    NotifierProvider<UpdateChecksEnabled, bool>(UpdateChecksEnabled.new);

/// The release channel this install follows.
class UpdateChannel extends Notifier<String> {
  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_kUpdateChannelKey) ??
      kDefaultUpdateChannel;

  Future<void> set(String channel) async {
    state = channel;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kUpdateChannelKey, channel);
  }
}

final updateChannelProvider = NotifierProvider<UpdateChannel, String>(
  UpdateChannel.new,
);

/// The release feed. Overridden by tests; the live one talks to Solsynth
/// Express.
final releaseFeedProvider = Provider<ReleaseFeed>(
  (ref) => const SolsynthExpressFeed(),
);

/// The build identity, resolved once: it is a handful of platform-channel
/// reads and both the launch check and the settings row read the same answer.
final appTargetProvider = FutureProvider<AppTarget?>(
  (ref) => resolveAppTarget(),
);

/// What the settings row says about the newest release.
///
/// Kept as data rather than an `AsyncError` so the row can tell the three
/// states apart: a release, a channel with nothing published, and a feed that
/// did not answer. Refetched when the channel, the switch or the build
/// identity changes.
final latestReleaseProvider = FutureProvider<LatestRelease>((ref) async {
  if (!ref.watch(updateChecksEnabledProvider)) {
    return const LatestRelease.unavailable();
  }
  final channel = ref.watch(updateChannelProvider);
  final target = await ref.watch(appTargetProvider.future);
  try {
    return LatestRelease(
      await ref
          .watch(releaseFeedProvider)
          .latest(channel: channel, target: target),
    );
  } catch (error) {
    debugPrint('[Updates] Latest release unavailable: $error');
    return const LatestRelease.failed();
  }
});

/// The answer to "what is the newest release on this channel".
@immutable
class LatestRelease {
  const LatestRelease(this.release) : failed = false, unavailable = false;
  const LatestRelease.failed() : release = null, failed = true,
        unavailable = false;
  const LatestRelease.unavailable() : release = null, failed = false,
        unavailable = true;

  final DistributionReleaseInfo? release;

  /// The feed threw; the row says so instead of claiming an empty channel.
  final bool failed;

  /// Update checks are off, so nothing was asked.
  final bool unavailable;
}

/// The channels the publisher exposes, for the picker.
final releaseChannelsProvider = FutureProvider<List<DistributionChannel>>(
  (ref) => ref.watch(releaseFeedProvider).channels(),
);

/// Where the release sheet is shown. A function so the launch check can be
/// tested without a widget tree; the app passes the router's navigator.
typedef NavigatorContextResolver = Future<BuildContext?> Function();

/// Runs the once-per-launch update check.
///
/// Three cases, in order:
///
/// 1. The stored version differs from the running one — the app was upgraded,
///    so the release notes for what is now installed are shown and the new
///    version recorded.
/// 2. No stored version — a first run, which records the version and shows
///    nothing: a brand-new install has no "what changed".
/// 3. Otherwise the feed is asked whether something newer exists.
///
/// Silent on every failure by construction: the feed logs and returns null.
///
/// [resolveContext] is where a release sheet is shown, and returning null
/// skips the sheet while still recording what was checked — which is what a
/// test asserts, and what a launch with no window yet does.
Future<void> runLaunchUpdateCheck(
  ProviderContainer container, {
  required NavigatorContextResolver resolveContext,
}) async {
  if (!container.read(updateChecksEnabledProvider)) return;
  final prefs = container.read(sharedPreferencesProvider);
  final target = await container.read(appTargetProvider.future);
  if (target == null) return;

  final previous = prefs.getString(_kLastKnownVersionKey);
  if (previous == null || previous.isEmpty) {
    await prefs.setString(_kLastKnownVersionKey, target.version);
    return;
  }

  if (previous != target.version) {
    await prefs.setString(_kLastKnownVersionKey, target.version);
    final channel = container.read(updateChannelProvider);
    final DistributionReleaseInfo? release;
    try {
      release = await container
          .read(releaseFeedProvider)
          .latest(channel: channel, target: target);
    } catch (error) {
      debugPrint('[Updates] Latest release unavailable: $error');
      return;
    }
    if (release == null) return;
    final context = await resolveContext();
    if (context == null || !context.mounted) return;
    await ReleaseSheet.show(
      context,
      release: release,
      currentVersion: previous,
      updateAvailable: false,
    );
    return;
  }

  final check = await container
      .read(releaseFeedProvider)
      .check(
    target,
    channel: container.read(updateChannelProvider),
    // The launch check has no BuildContext; the platform's own locale is the
    // same one easy_localization starts from, and only picks which translation
    // of the release notes the server sends back.
    locale: PlatformDispatcher.instance.locale.toLanguageTag(),
  );
  if (check == null || !check.updateAvailable) return;
  final context = await resolveContext();
  if (context == null || !context.mounted) return;
  await ReleaseSheet.show(
    context,
    release: check.release,
    currentVersion: check.currentVersion,
  );
}

/// The root navigator's context, waiting for the shell to build.
///
/// The check starts from `runApp`'s provider scope, so it can outrun the
/// router; a release sheet needs a context that exists, and five seconds is
/// past any first frame this app has.
Future<BuildContext?> appNavigatorContext(ProviderContainer container) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final context = container.read(routerProvider).navigatorKey.currentContext;
    if (context != null && context.mounted) return context;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return null;
}
