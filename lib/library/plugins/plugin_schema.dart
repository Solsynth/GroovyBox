/// The GroovyBox half of the plugin contract.
///
/// The runtime (`island_plugin_foundation`) owns `manifest.json`'s identity
/// fields — id, name, version, entry, permissions — and ignores everything
/// else. A GroovyBox plugin adds one key the runtime never reads:
///
/// ```json
/// "providers": [
///   {
///     "id": "kugou",
///     "name": "Kugou Music",
///     "requiresAuth": false,
///     "functions": ["search", "streamUri", "lyrics"]
///   }
/// ]
/// ```
///
/// Each entry becomes one connectable library. [functions] names the contract
/// functions the plugin implements; an omitted key means "all of them", so a
/// plugin that only streams stays a two-function file and the app answers its
/// other reads with emptiness instead of calling a function that does not
/// exist.
///
/// The JS entry point is synchronous — no `await`, no `fetch` — because every
/// network step belongs to the host: a function answers either its result
/// (`{ok: true, ...}` / `{ok: false, error}`) or a request to perform
/// (`{http: {method, url, headers?, body?}}`). The host performs the request,
/// calls the same function again with `args.__response` set to
/// `{status, headers, body}`, and repeats until the answer carries no `http`
/// key. A plugin that needs to remember something between round trips keeps it
/// in its own JS globals: the host re-sends `args` fresh on every call.
library;

import 'package:flutter/foundation.dart';

/// One connectable library a plugin contributes.
class PluginProvider {
  /// The manifest id of the plugin that owns this provider, e.g.
  /// `dev.groovybox.kugou`. Stored as [SourceConfig.baseUrl].
  final String pluginId;

  /// The provider's own id inside the plugin, e.g. `kugou`. Stored in
  /// [SourceConfig.auth] under `providerId`.
  final String providerId;

  /// The library's default display name.
  final String name;

  /// Whether connecting asks for an address, a username and a password.
  final bool requiresAuth;

  /// The contract functions this provider implements; empty means all.
  final Set<String> functions;

  /// The plugin's own version, for the settings row.
  final String version;

  const PluginProvider({
    required this.pluginId,
    required this.providerId,
    required this.name,
    required this.version,
    this.requiresAuth = false,
    this.functions = const {},
  });

  /// Whether [fn] is implemented, and therefore safe to call.
  bool declares(String fn) => functions.isEmpty || functions.contains(fn);

  /// Whether two providers name the same library.
  ///
  /// The setup picker holds one of these as its selected value, and
  /// `DropdownButtonFormField` compares values to decide what is selected.
  @override
  bool operator ==(Object other) =>
      other is PluginProvider &&
      other.pluginId == pluginId &&
      other.providerId == providerId;

  @override
  int get hashCode => Object.hash(pluginId, providerId);

  @override
  String toString() => 'PluginProvider($pluginId/$providerId, $name)';
}

/// Reads the `providers` key of a raw manifest.
///
/// Never throws: a manifest without the key, an unparsable entry, or a
/// duplicate [PluginProvider.providerId] is skipped and logged, because one
/// broken plugin must not take the library list down. Duplicates are dropped
/// rather than renamed: two providers of one plugin under the same id would
/// address the same state, and a stored config could not tell them apart.
List<PluginProvider> providersFromManifest({
  required String pluginId,
  required String version,
  required Map<String, dynamic> manifest,
}) {
  final raw = manifest['providers'];
  if (raw is! List) return const [];

  final providers = <PluginProvider>[];
  final seen = <String>{};
  for (final entry in raw) {
    if (entry is! Map) {
      debugPrint('[Plugin] $pluginId: skipping a provider that is not an object');
      continue;
    }
    final id = entry['id'];
    if (id is! String || id.isEmpty) {
      debugPrint('[Plugin] $pluginId: skipping a provider without an id');
      continue;
    }
    if (!seen.add(id)) {
      debugPrint('[Plugin] $pluginId: skipping duplicate provider "$id"');
      continue;
    }
    final name = entry['name'];
    final functions = entry['functions'];
    providers.add(
      PluginProvider(
        pluginId: pluginId,
        providerId: id,
        name: name is String && name.isNotEmpty ? name : id,
        version: version,
        requiresAuth: entry['requiresAuth'] == true,
        functions: functions is List
            ? {
                for (final fn in functions)
                  if (fn is String && fn.isNotEmpty) fn,
              }
            : const {},
      ),
    );
  }
  return providers;
}

/// The one host function a plugin needs besides its own JS: a synchronous
/// digest, because Kugou signs each tracker request with one and the plugin
/// cannot compute it (no `crypto` in the sandbox).
///
/// The channel name is the plugin's whole vocabulary: everything else — HTTP,
/// storage of login state — is the host's, driven through the call loop.
const kPluginMd5Channel = 'api:groovybox:md5';

/// Where a plugin writes diagnostics. The sandbox's own `console` collects
/// into a buffer nothing reads on desktop; this channel reaches the app log.
const kPluginLogChannel = 'api:groovybox:log';
