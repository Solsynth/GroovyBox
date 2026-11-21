import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while a lyric sheet is open.
///
/// The plugin exposes a single switch, but more than one pane can be mounted
/// in one engine at once — the dock's lyric sheet while the player page keeps
/// a pane of its own in the widget tree — so the last pane to close is the
/// only one allowed to let the screen sleep again. Without the count, closing
/// the dock's sheet would dim the window the player page still fills.
///
/// The count is per engine: the mini player is a second isolate with its own
/// plugin instance, and the two would need a channel to share one.
abstract final class ScreenAwake {
  static int _holders = 0;

  /// Takes a hold and switches the wakelock on for the first one.
  static void acquire() {
    if (_holders++ > 0) return;
    // Fire and forget: a platform that refuses the call (web without a user
    // gesture, a build with no plugin) must not fail the pane that asked.
    unawaited(
      WakelockPlus.enable().catchError((Object error) {
        debugPrint('[ScreenAwake] Could not keep the screen on: $error');
      }),
    );
  }

  /// Drops a hold, releasing the wakelock when the last one goes.
  static void release() {
    if (_holders == 0) return;
    if (--_holders > 0) return;
    unawaited(
      WakelockPlus.disable().catchError((Object error) {
        debugPrint('[ScreenAwake] Could not release the screen: $error');
      }),
    );
  }
}
