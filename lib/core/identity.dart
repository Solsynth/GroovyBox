/// Who GroovyBox says it is when it speaks HTTP.
library;

import 'package:flutter/foundation.dart';

/// The product name, as servers and their admin surfaces expect to see it.
///
/// Matches the Jellyfin `Client` / `Device` fields and the `c` parameter of
/// Subsonic; one spelling for every integration.
const String kAppName = 'GroovyBox';

/// The marketing version from `pubspec.yaml`.
///
/// A constant rather than a `package_info_plus` read: that plugin would add a
/// platform channel to every client construction for a string only three
/// services look at. Keep it in step with `pubspec.yaml`.
const String kAppVersion = '2.0.0';

String get _platformLabel {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}

/// The `User-Agent` every client sends: `GroovyBox/2.0.0 (macOS)`.
///
/// Stargate records the user agent that obtained a session and Solian lists it
/// as the device name, so this is how a person recognises — and revokes — a
/// GroovyBox session. Left unset, the request carries `Dart/<sdk> (dart:io)`
/// instead, which is indistinguishable from any other Dart tool.
String get appUserAgent => '$kAppName/$kAppVersion ($_platformLabel)';
