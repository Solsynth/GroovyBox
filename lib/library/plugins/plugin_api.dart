import 'dart:convert';

import 'package:crypto/crypto.dart' show md5;
import 'package:flutter/foundation.dart';
import 'package:island_plugin_foundation/island_plugin_foundation.dart';

import 'plugin_schema.dart';

/// The two synchronous host calls a GroovyBox plugin may make.
///
/// Deliberately tiny: all HTTP belongs to `PluginHost.call`, so a plugin has
/// no request API to misuse, no timeout of its own to get wrong, and every
/// provider shares the host's policy. What is left is a digest (Kugou signs
/// each tracker request with one and the sandbox has no `crypto`) and a log
/// line.
///
/// Both answer in place, which is what the engines do: `sendMessage`'s return
/// value is handed straight back to JS on JavaScriptCore and QuickJS alike, so
/// a plugin can use the result in the same expression.
class GroovyBoxPluginApi extends PluginApi {
  GroovyBoxPluginApi({@visibleForTesting this.onLog});

  /// Where log lines go. Defaults to `debugPrint`; a test can capture them.
  final void Function(String pluginId, String level, String message)? onLog;

  /// A plugin connects to the internet by streaming. The existing permission
  /// says exactly that ("Make unauthenticated requests to arbitrary internet
  /// hosts"), and it is what the host checks before it registers this API at
  /// all — a plugin without it gets no md5 and no log, and its manifest is
  /// what the user read before installing it.
  @override
  Set<PluginPermission> get requiredPermissions => const {
    PluginPermission.networkInternet,
  };

  @override
  void register(PluginContext context, JsRuntime runtime) {
    runtime.onMessage(kPluginMd5Channel, (dynamic raw) {
      final args = context.decode(raw);
      final value = args['value'];
      if (value == null) return '';
      // `md5.convert` wants bytes: the sign the provider documents is over the
      // ASCII of the hash, so this is the identity encoding, not UTF-16.
      return md5.convert(utf8.encode('$value')).toString();
    });

    runtime.onMessage(kPluginLogChannel, (dynamic raw) {
      final args = context.decode(raw);
      final level = args['level']?.toString() ?? 'log';
      final message = args['message']?.toString() ?? '';
      final write = onLog;
      if (write != null) {
        write(context.pluginId, level, message);
      } else {
        debugPrint('[plugin:${context.pluginId}] $level: $message');
      }
      return null;
    });
  }
}
