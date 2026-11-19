import '../http_cache.dart';
import '../source.dart';
import 'plugin_host.dart';
import 'plugin_schema.dart';
import 'plugin_source.dart';

/// One installed plugin provider, as a connectable library.
///
/// The bridge between the adapter contract and [PluginHost]: connecting asks
/// the plugin's optional `connect` for the login state to keep, and a stored
/// config is turned back into a [PluginSource] against the same host.
///
/// Only ever offered when a host exists (`pluginProvidersProvider` is empty
/// otherwise), so [host] is non-null here; [PluginSource] still treats a host
/// that lost its plugin as a missing library rather than a crash.
class PluginAdapter implements LibraryAdapter {
  PluginAdapter(this.provider, {required this.host});

  final PluginProvider provider;
  final PluginHost host;


  /// Offered wherever a host exists: whether the platform can run plugins at
  /// all is [pluginRuntimeSupported], decided before the picker is built.
  @override
  bool get isAvailable => true;
  @override
  LibraryKind get kind => LibraryKind.plugin;

  /// A provider that declares `connect` takes the same three fields a Subsonic
  /// server does; one that does not is connected with nothing typed.
  @override
  bool get needsCredentials => provider.requiresAuth;

  @override
  Future<SourceConfig> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) => host.connect(
    provider,
    baseUrl: baseUrl,
    username: username,
    password: password,
  );

  @override
  LibrarySource sourceFor(SourceConfig config, {ResponseCache? cache}) =>
      PluginSource(
        config,
        host: host,
        // A config whose plugin is gone (uninstalled, or a backup restored
        // onto a machine without it) reports itself missing, never a crash at
        // resolve time.
        missing: !host.knows(config.baseUrl),
      );
}
