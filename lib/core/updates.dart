/// Update checks against Solsynth Express, the release feed the apps in the
/// network publish through.
///
/// Only the package's data layer is used — [SolsynthExpressApi] and its
/// release models. The package's bundled sheet is written against a different
/// Material library and pulls a fork of `window_manager`; GroovyBox draws its
/// own sheet from the same models (`widgets/release_sheet.dart`), so the app
/// keeps one theme, one windowing stack, and one set of translations.
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:solsynth_express/api.dart';

/// Where the release feed lives.
const kDistributionApiBaseUrl = String.fromEnvironment(
  'DISTRIBUTION_API_BASE_URL',
  defaultValue: 'https://dx.solsynth.dev/api',
);

/// The distribution product this build is published under.
///
/// GroovyBox's own product on the publisher account. Baked in so a stock
/// build checks the right feed; `--dart-define=DISTRIBUTION_PRODUCT_ID=<uuid>`
/// overrides it for a staging product.
const kGroovyBoxProductId = '03605b4d-c25c-4380-9cb5-87e47c6997ab';
const kDistributionProductId = String.fromEnvironment(
  'DISTRIBUTION_PRODUCT_ID',
  defaultValue: kGroovyBoxProductId,
);

/// The channel a build follows unless the user picks another.
const kDefaultUpdateChannel = 'stable';

/// What this process is, in the terms the release feed compares against.
///
/// Resolved once per process: it is read from platform channels that answer
/// from static facts, and the launch check and the settings row must agree.
@immutable
class AppTarget {
  const AppTarget({
    required this.platform,
    required this.architecture,
    required this.osVersion,
    required this.version,
  });

  /// `android`, `ios`, `macos`, `linux` or `windows`.
  final String platform;

  /// The feed's spelling: `arm64`, `amd64`, `armeabi-v7a`, `x86_64`, `x86`.
  final String architecture;

  /// Best-effort OS version for telemetry; empty when the platform refused.
  final String osVersion;

  /// `2.0.0+21`, the shape Express tags its releases with.
  final String version;

  bool get isSupported => platform.isNotEmpty && architecture.isNotEmpty;
}

/// The running build's identity, or null on a platform the feed does not
/// publish for and wherever a platform channel fails. An update check is
/// never worth failing a launch over.
Future<AppTarget?> resolveAppTarget() async {
  if (kIsWeb) return null;
  try {
    final platform = _platformName();
    final architecture = await _currentArchitecture();
    final info = await PackageInfo.fromPlatform();
    final target = AppTarget(
      platform: platform,
      architecture: architecture,
      osVersion: await _currentOSVersion(),
      version: '${info.version}+'
          '${canonicalBuildNumber(info.buildNumber, platform, architecture)}',
    );
    return target.isSupported ? target : null;
  } catch (error) {
    debugPrint('[Updates] Could not read the build identity: $error');
    return null;
  }
}

String _platformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.macOS => 'macos',
  TargetPlatform.linux => 'linux',
  TargetPlatform.windows => 'windows',
  TargetPlatform.fuchsia => '',
};

/// Strips the ABI offset Flutter's Gradle plugin adds to `--split-per-abi`
/// Android builds, so a split APK's code compares against the release tag.
///
/// The tool adds 1000 for armeabi-v7a, 2000 for arm64 and 4000 for x86_64 to
/// the build number; `package_info_plus` reports that overridden value while
/// releases are tagged with the canonical one. A code below the offset comes
/// from a build that was not split, and is returned unchanged.
@visibleForTesting
String canonicalBuildNumber(
  String buildNumber,
  String platform,
  String architecture,
) {
  final parsed = int.tryParse(buildNumber);
  if (parsed == null) return buildNumber;
  if (platform != 'android') return buildNumber;
  final offset = switch (architecture) {
    'armeabi-v7a' => 1000,
    'arm64' => 2000,
    'x86_64' => 4000,
    _ => 0,
  };
  if (offset == 0 || parsed < offset) return buildNumber;
  return '${parsed - offset}';
}

Future<String> _currentArchitecture() async {
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    for (final abi in info.supportedAbis) {
      switch (abi) {
        case 'arm64-v8a':
          return 'arm64';
        case 'armeabi-v7a':
          return 'armeabi-v7a';
        case 'x86_64':
          return 'x86_64';
        case 'x86':
          return 'x86';
      }
    }
    return '';
  }
  if (Platform.isWindows) {
    final value =
        Platform.environment['PROCESSOR_ARCHITEW6432'] ??
        Platform.environment['PROCESSOR_ARCHITECTURE'];
    return switch (value?.toUpperCase()) {
      'AMD64' || 'X86_64' => 'amd64',
      'ARM64' => 'arm64',
      null => 'amd64',
      final other => other.toLowerCase(),
    };
  }
  // Apple silicon is the only arm64 target Express publishes for the two
  // Darwin platforms, and Linux builds ship as amd64 AppImages.
  if (Platform.isMacOS || Platform.isIOS) return 'arm64';
  if (Platform.isLinux) return 'amd64';
  return '';
}

Future<String> _currentOSVersion() async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) return (await deviceInfo.androidInfo).version.release;
    if (Platform.isIOS) return (await deviceInfo.iosInfo).systemVersion;
    if (Platform.isMacOS) return (await deviceInfo.macOsInfo).osRelease;
    if (Platform.isLinux) return (await deviceInfo.linuxInfo).version ?? '';
    if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      return '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';
    }
  } catch (error) {
    debugPrint('[Updates] OS version unavailable: $error');
  }
  return '';
}

/// Whether this build names a product to check against.
bool get distributionIsConfigured => kDistributionProductId.trim().isNotEmpty;

/// The feed client, or null when this build carries no product id — the
/// normal state of a local `flutter run`.
SolsynthExpressApi? distributionApi() {
  if (!distributionIsConfigured) return null;
  return SolsynthExpressApi(
    baseUrl: kDistributionApiBaseUrl,
    productId: kDistributionProductId,
  );
}

/// What the feed said about this build.
@immutable
class ReleaseCheck {
  const ReleaseCheck({
    required this.release,
    required this.currentVersion,
    required this.updateAvailable,
  });

  final DistributionReleaseInfo release;
  final String currentVersion;

  /// True when [release] is newer than the build asking.
  final bool updateAvailable;
}

/// What the app asks of the release feed.
///
/// An interface so the settings surface and the launch check can be driven
/// from a test: the real implementation talks to Solsynth Express, and a fake
/// answers instantly with the same models.
abstract class ReleaseFeed {
  const ReleaseFeed();

  /// Whether a product id is compiled in. False is the normal state of a
  /// local `flutter run`, and the settings row explains it rather than
  /// showing a picker that could never fetch anything.
  bool get isConfigured;

  Future<ReleaseCheck?> check(
    AppTarget target, {
    required String channel,
    String? locale,
  });

  Future<DistributionReleaseInfo?> latest({
    required String channel,
    AppTarget? target,
  });

  Future<List<DistributionChannel>> channels();
}

/// The live feed.
class SolsynthExpressFeed extends ReleaseFeed {
  const SolsynthExpressFeed();

  SolsynthExpressApi get api => distributionApi()!;

  @override
  bool get isConfigured => distributionIsConfigured;

  @override
  Future<ReleaseCheck?> check(
    AppTarget target, {
    required String channel,
    String? locale,
  }) async {
    if (!distributionIsConfigured) return null;
    final api = this.api;
    try {
      final result = await api.checkForUpdate(
        currentVersion: target.version,
        platform: target.platform,
        architecture: target.architecture,
        channel: channel,
        clientVersion: target.version,
        osVersion: target.osVersion.isEmpty ? null : target.osVersion,
        locale: locale,
      );
      final release = result.release;
      if (release == null) return null;
      return ReleaseCheck(
        release: release,
        currentVersion: result.currentVersion,
        updateAvailable: result.updateAvailable,
      );
    } catch (error) {
      // A feed that is down is not the user's problem until they ask; the
      // caller decides whether to surface the null.
      debugPrint('[Updates] Check failed: $error');
      return null;
    }
  }

  /// Null when the channel genuinely holds no release; a transport failure
  /// throws, so the settings row can tell "nothing published" from "the feed
  /// is down". Callers that must not fail (the launch check) catch it.
  ///
  /// A channel nobody has created yet answers 404 with an error body rather
  /// than an empty page, which reads here as "nothing published" — the state
  /// every new product is in before its first release.
  @override
  Future<DistributionReleaseInfo?> latest({
    required String channel,
    AppTarget? target,
  }) async {
    try {
      return await api.fetchLatestRelease(
        channel: channel,
        platform: target?.platform,
        architecture: target?.architecture,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<DistributionChannel>> channels() async {
    if (!distributionIsConfigured) return const [];
    try {
      return await api.listChannels();
    } catch (error) {
      debugPrint('[Updates] Channels unavailable: $error');
      return const [];
    }
  }
}
