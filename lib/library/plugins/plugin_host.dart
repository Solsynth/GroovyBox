import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:island_plugin_foundation/island_plugin_foundation.dart';
import 'package:path/path.dart' as p;

import '../http.dart';
import '../http_cache.dart';
import '../models.dart';
import '../source.dart';
import 'plugin_api.dart';
import 'plugin_schema.dart';

/// Whether this build can execute plugin JS at all.
///
/// The runtime is QuickJS on Android, Windows and Linux and JavaScriptCore on
/// iOS and macOS. On web the dependency's stub makes every call a silent
/// no-op, so a web build says plugins are unavailable instead of offering a
/// folder picker that installs something unable to run.
bool get pluginRuntimeSupported =>
    !kIsWeb &&
    (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux);

/// Owns the JS plugin runtime and drives its call contract.
///
/// Process-wide because the foundation's `PluginManager` and `JsBridge` are:
/// two hosts would load the same plugin folder twice into two sandboxes.
/// `PluginHost.instance` is null until [boot] has run, which is what lets
/// `librarySourceFromConfig` answer a plugin-backed config with a source that
/// reports itself missing instead of throwing at resolve time.
///
/// A plugin function never performs I/O. It answers either its result
/// (`{ok: true, ...}` / `{ok: false, error}`) or a request for the host to
/// make (`{http: {method, url, headers?, body?}}`); [call] performs it, hands
/// the answer back as `args.__response`, and calls the same function again.
/// That keeps every network step in Dart, where the timeout policy lives, and
/// keeps the JS side synchronous — which is all a sandbox can be.
class PluginHost extends ChangeNotifier {
  PluginHost({PluginController? controller, Dio? dio})
    : controller = controller ?? PluginController.instance,
      dio = dio ?? Dio();

  /// The host the app boots in `main`, or null when no runtime exists (a
  /// platform without one, or a test that has not built one).
  static PluginHost? instance;

  /// The foundation façade: discovery, lifecycle, sandbox APIs.
  final PluginController controller;

  /// The only HTTP a plugin gets.
  @visibleForTesting
  final Dio dio;

  /// The device's response cache, when it has one. Null in tests and on a
  /// platform without a database: a plugin read then always hits the network.
  ResponseCache? cache;

  /// The scope a plugin provider's answers are cached under: its plugin and
  /// provider ids, never its baseUrl — a manifest id is not an address.
  static String cacheScopeFor(String pluginId, String providerId) =>
      'plugin:$pluginId/$providerId';

  /// Providers discovered so far, in manifest order.
  List<PluginProvider> _providers = const [];

  /// One lock per plugin: a call sets the plugin's own globals before it
  /// invokes a function, so two providers of one plugin must not interleave
  /// across an awaited request.
  final Map<String, Future<void>> _locks = {};

  bool get supported => pluginRuntimeSupported;

  /// Every provider an installed plugin contributes.
  List<PluginProvider> get providers => _providers;

  /// Every discovered plugin, loaded or not, for the settings rows.
  List<PluginInstance> get installed => controller.pluginList;

  /// Whether the plugin a stored config names is installed.
  bool knows(String pluginId) => controller.plugins.containsKey(pluginId);

  /// Where installed plugins live on disk (`{appSupport}/plugins`).
  Future<String> pluginsDirectoryPath() => controller.resolvePluginsDirectoryPath();

  // ---- lifecycle ------------------------------------------------------------

  /// Registers the host API and loads every installed plugin.
  ///
  /// Never throws: a bad plugin, or a platform the runtime cannot start on,
  /// must not take the app's startup down. The foundation quarantines a plugin
  /// whose load crashed, and this leaves the registry empty rather than
  /// propagating.
  Future<void> boot() async {
    if (!supported) {
      _providers = const [];
      return;
    }
    try {
      controller.registerApi('groovybox', GroovyBoxPluginApi());
      await controller.initialize();
      await controller.loadAllAtStartup();
    } catch (error) {
      debugPrint('[Plugin] Boot failed: $error');
    }
    await _refresh();
    notifyListeners();
  }

  Future<void> reload() async {
    if (!supported) return;
    try {
      await controller.reload();
    } catch (error) {
      debugPrint('[Plugin] Reload failed: $error');
    }
    await _refresh();
    notifyListeners();
  }

  /// Installs a plugin by copying [path] into the app's plugins directory.
  ///
  /// Returns false when the folder has no `manifest.json` or the copy failed;
  /// the caller renders that as a failure, not as an exception.
  Future<bool> installFromFolder(String path) async {
    if (!supported) return false;
    bool installed = false;
    try {
      installed = await controller.installFromFolder(path);
      if (installed) await controller.loadAll();
    } catch (error) {
      debugPrint('[Plugin] Install failed: $error');
      installed = false;
    }
    await _refresh();
    notifyListeners();
    return installed;
  }

  Future<void> uninstall(String pluginId) async {
    if (!supported) return;
    try {
      await controller.uninstallPlugin(pluginId);
    } catch (error) {
      debugPrint('[Plugin] Uninstall failed: $error');
    }
    await _refresh();
    notifyListeners();
  }

  Future<void> setEnabled(String pluginId, bool enabled) async {
    if (!supported) return;
    try {
      if (enabled) {
        await controller.enablePlugin(pluginId);
        await controller.loadPlugin(pluginId);
      } else {
        controller.disablePlugin(pluginId);
      }
    } catch (error) {
      debugPrint('[Plugin] Could not toggle $pluginId: $error');
    }
    await _refresh();
    notifyListeners();
  }

  // ---- contract -------------------------------------------------------------

  /// Turns credentials into a stored config for [provider].
  ///
  /// A provider that declares `connect` gets the three values and answers with
  /// the login state to keep (`auth`); one that does not is connected straight
  /// away, because it has nothing to sign in to. Either way the stored config
  /// names the plugin as its address and the provider in `auth`, which is what
  /// [PluginSource] needs to find both again after a restart.
  Future<SourceConfig> connect(
    PluginProvider provider, {
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final auth = <String, String>{};
    if (provider.declares('connect')) {
      final answer = await call(
        pluginId: provider.pluginId,
        providerId: provider.providerId,
        fn: 'connect',
        args: {'baseUrl': baseUrl, 'username': username, 'password': password},
        baseUrl: baseUrl,
      );
      final returned = answer['auth'];
      if (returned is Map) {
        for (final entry in returned.entries) {
          final value = entry.value;
          if (value == null) continue;
          auth['${entry.key}'] = '$value';
        }
      }
    }
    return SourceConfig(
      id: newSourceId(LibraryKind.plugin),
      kind: LibraryKind.plugin,
      // The manifest id, not an address: it is how the host finds the plugin
      // again from a config that outlived this run.
      baseUrl: provider.pluginId,
      displayName: provider.name,
      auth: {...auth, 'providerId': provider.providerId},
    );
  }

  /// Calls [fn] on one provider's plugin and drives its request loop.
  ///
  /// [auth] and [baseUrl] are the stored credentials of the connection being
  /// served; they are published as the globals `__groovybox_auth__` and
  /// `__groovybox_config__` before every invocation, so a plugin reads its own
  /// login state synchronously without a credential API.
  ///
  /// Throws [LibraryException] when the plugin is not installed, when the
  /// function is not implemented, when the answer says `{ok: false}`, and when
  /// the loop runs past [maxRoundTrips].
  Future<Map<String, dynamic>> call({
    required String pluginId,
    required String providerId,
    required String fn,
    Map<String, dynamic> args = const {},
    Map<String, String> auth = const {},
    String baseUrl = '',
    int maxRoundTrips = 8,
    CachePolicy cachePolicy = CachePolicy.medium,
  }) => _serialized(pluginId, () async {
    final runtime = await _runtimeFor(pluginId);
    final exists = runtime.eval('typeof $fn === "function"');
    if (exists != true) {
      throw LibraryException(
        'The plugin does not implement $fn.',
        messageKey: 'libraryPluginFailed',
      );
    }

    runtime.setGlobal('__groovybox_auth__', auth);
    runtime.setGlobal('__groovybox_config__', {'baseUrl': baseUrl});

    var payload = <String, dynamic>{...args};
    var roundTrips = 0;
    while (true) {
      final answer = _invoke(runtime, fn, payload);
      final request = answer['http'];
      if (request is! Map) {
        if (answer['ok'] == false) {
          throw LibraryException(
            answer['error']?.toString() ?? 'The plugin failed.',
            messageKey: 'libraryPluginFailed',
          );
        }
        return answer;
      }
      if (roundTrips >= maxRoundTrips) {
        throw const LibraryException(
          'The plugin made too many requests.',
          messageKey: 'libraryPluginTooManyRequests',
        );
      }
      roundTrips++;
      payload = {
        ...payload,
        '__response': await _perform(
          request,
          scope: cacheScopeFor(pluginId, providerId),
          policy: cachePolicy,
        ),
      };
    }
  });

  /// Runs [body] after every earlier call on the same plugin has finished, so
  /// the `__groovybox_auth__` global one call sets cannot be read by another
  /// provider's function that resumed in between.
  Future<Map<String, dynamic>> _serialized(
    String pluginId,
    Future<Map<String, dynamic>> Function() body,
  ) async {
    final previous = _locks[pluginId] ?? Future<void>.value();
    final completer = Completer<void>();
    _locks[pluginId] = completer.future;
    await previous;
    try {
      return await body();
    } finally {
      completer.complete();
      if (identical(_locks[pluginId], completer.future)) {
        _locks.remove(pluginId);
      }
    }
  }

  /// The loaded runtime of [pluginId], loading it first when it is only
  /// discovered. A disabled, crashed or uninstalled plugin is a missing one.
  Future<JsRuntime> _runtimeFor(String pluginId) async {
    var instance = controller.plugins[pluginId];
    if (instance == null) {
      throw const LibraryException(
        'This plugin is not installed.',
        messageKey: 'libraryPluginMissing',
      );
    }
    if (instance.state != PluginState.active) {
      if (instance.state == PluginState.discovered) {
        await controller.loadPlugin(pluginId);
        instance = controller.plugins[pluginId];
      }
      final runtime = instance?.runtime;
      if (instance == null ||
          instance.state != PluginState.active ||
          runtime == null) {
        throw const LibraryException(
          'The plugin is not running.',
          messageKey: 'libraryPluginCrashed',
        );
      }
      return runtime;
    }
    final runtime = instance.runtime;
    if (runtime == null) {
      throw const LibraryException(
        'The plugin is not running.',
        messageKey: 'libraryPluginCrashed',
      );
    }
    return runtime;
  }

  /// One synchronous JS call, read back as JSON.
  ///
  /// The answer is wrapped in an array so it survives the boundary as JSON
  /// text whatever it is: the engine wrapper hands a bare object back as
  /// `[object Object]` on JavaScriptCore, and a bare string back as itself.
  /// `[value]` parses unambiguously, and `[null]` is a function that returned
  /// nothing at all.
  Map<String, dynamic> _invoke(
    JsRuntime runtime,
    String fn,
    Map<String, dynamic> payload,
  ) {
    final raw = runtime.eval('JSON.stringify([($fn)(${jsonEncode(payload)})])');
    // The engine wrapper parses JSON-shaped text on its own, so the answer
    // arrives as a list here and as a string on an engine that does not.
    Object? decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        throw const LibraryException(
          'The plugin failed.',
          messageKey: 'libraryPluginCrashed',
        );
      }
    }
    final answer = decoded is List && decoded.isNotEmpty ? decoded.first : null;
    if (answer is Map<String, dynamic>) return answer;
    if (answer is Map) {
      return answer.map((key, value) => MapEntry('$key', value));
    }
    throw const LibraryException(
      'The plugin failed.',
      messageKey: 'libraryPluginCrashed',
    );
  }

  /// Performs one request a plugin asked for, and describes the answer in the
  /// shape the plugin reads back: status, headers and a plain-text body.
  ///
  /// The body is never parsed here: Kuwo answers with a JavaScript object
  /// literal, and it is the plugin's own sandbox that decides how to read it.
  Future<Map<String, dynamic>> _perform(
    Map<dynamic, dynamic> request, {
    required String scope,
    required CachePolicy policy,
  }) async {
    final url = request['url'];
    if (url is! String || url.isEmpty) {
      throw const LibraryException(
        'The plugin asked for an address it did not give.',
        messageKey: 'libraryPluginFailed',
      );
    }
    final method = (request['method'] as String?)?.toUpperCase() ?? 'GET';
    final rawHeaders = request['headers'];
    final headers = <String, String>{
      if (rawHeaders is Map)
        for (final entry in rawHeaders.entries)
          if (entry.value != null) '${entry.key}': '${entry.value}',
    };

    final body = request['body'];
    final uri = Uri.tryParse(url);
    final cached = policy == CachePolicy.none ? null : cache;
    final key = cached == null || uri == null || method != 'GET'
        ? null
        : cacheKeyForUri(scope, method, uri);
    if (cached != null && key != null) {
      final hit = await cached.readPerformed(key, allowStale: false);
      if (hit != null) return hit;
      // A write makes every listing of this provider suspect; dropping them
      // all is cheaper than tracking which lists it touched.
      if (method != 'GET') await cached.invalidateScope(scope);
    }

    final Response<String> response;
    try {
      response = await dio.request<String>(
        url,
        data: body,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.plain,
          // A plugin reads the status itself: a 404 or a 403 is an answer it
          // may know how to handle, not a transport failure.
          validateStatus: (_) => true,
          // The same pair the Apple Music adapter uses: enough for a slow
          // provider, short enough that a dead one does not hang a read.
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
    } on DioException catch (error) {
      // The same rule a source's own client follows: a timeout is the network
      // being gone, and an expired answer beats an empty library.
      if (cached != null && key != null && _unreachable(error)) {
        final hit = await cached.readPerformed(key, allowStale: true);
        if (hit != null) return hit;
      }
      throw describeDioError(error);
    }

    final answer = {
      'status': response.statusCode ?? 0,
      'headers': {
        for (final entry in response.headers.map.entries)
          entry.key: entry.value.join(', '),
      },
      'body': response.data ?? '',
    };
    if (cached != null &&
        key != null &&
        (response.statusCode ?? 0) ~/ 100 == 2) {
      await cached.writePerformed(key, answer, policy);
    }
    return answer;
  }

  /// Whether a failure means the network is gone rather than the provider
  /// answering no. Mirrors the sources' own cache policy.
  static bool _unreachable(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.unknown => true,
    DioExceptionType.badResponse =>
      const {502, 503, 504}.contains(error.response?.statusCode),
    _ => false,
  };

  // ---- discovery ------------------------------------------------------------

  /// Re-reads the `providers` key of every discovered plugin.
  ///
  /// The foundation's manifest has no such field, so the raw file is read
  /// again here. A plugin whose manifest cannot be read contributes nothing
  /// and stays installed: its state, and why it failed, is the settings row's
  /// business, not the library list's.
  Future<void> _refresh() async {
    final providers = <PluginProvider>[];
    for (final instance in controller.pluginList) {
      final manifest = await _rawManifest(instance);
      if (manifest == null) continue;
      providers.addAll(
        providersFromManifest(
          pluginId: instance.manifest.id,
          version: instance.manifest.version,
          manifest: manifest,
        ),
      );
    }
    _providers = providers;
  }

  Future<Map<String, dynamic>?> _rawManifest(PluginInstance instance) async {
    try {
      final directory = instance.directoryPath;
      final String text;
      if (directory.startsWith('asset:')) {
        text = await rootBundle.loadString(
          '${directory.substring(6)}/manifest.json',
        );
      } else if (directory.isEmpty) {
        // An inline plugin has no folder and therefore no providers.
        return null;
      } else {
        text = await File(p.join(directory, 'manifest.json')).readAsString();
      }
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error) {
      debugPrint(
        '[Plugin] Could not read the manifest of ${instance.manifest.id}: $error',
      );
      return null;
    }
  }
}
