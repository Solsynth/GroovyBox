import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/plugins/plugin_adapter.dart';
import 'package:groovy_box/library/plugins/plugin_host.dart';

import 'package:groovy_box/library/plugins/plugin_source.dart';
import 'package:groovy_box/library/source.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request with a canned body and records what was asked.
///
/// A real `Dio` over this adapter, rather than a fake host: the loop the host
/// drives — request, feed the answer back, call again — is what these tests are
/// about, and stubbing it would test the stub.
class _StubDio implements HttpClientAdapter {
  _StubDio(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;

  @override
  Future<String?> getTemporaryPath() async => root.path;
}

/// One installable plugin folder: a manifest on disk and its entry script.
Directory _pluginFolder({
  required String id,
  required String name,
  required String source,
  List<Map<String, Object?>> providers = const [],
}) {
  final dir = Directory.systemTemp.createTempSync('groovybox_plugin_');
  addTearDown(() => dir.deleteSync(recursive: true));
  File(p.join(dir.path, 'manifest.json')).writeAsStringSync(
    jsonEncode({
      'id': id,
      'name': name,
      'version': '1.2.3',
      'entry': 'main.js',
      'permissions': ['networkInternet'],
      'providers': providers,
    }),
  );
  File(p.join(dir.path, 'main.js')).writeAsStringSync(source);
  return dir;
}

/// A config as [PluginHost.connect] would store it.
SourceConfig _config(String pluginId, String providerId) => SourceConfig(
  id: 'plugin-1',
  kind: LibraryKind.plugin,
  baseUrl: pluginId,
  displayName: 'Kugou Music',
  auth: {'providerId': providerId},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;

  /// Boots a host against a fresh support directory.
  Future<PluginHost> boot({
    ResponseBody Function(RequestOptions)? respond,
  }) async {
    support = Directory.systemTemp.createTempSync('groovybox_support_');
    addTearDown(() => support.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(support);
    // The foundation remembers which plugins are mid-load in SharedPreferences
    // so an interrupted startup is not repeated: without the mock store, a
    // load fails with MissingPluginException before the JS ever runs.
    SharedPreferences.setMockInitialValues({});
    final client = Dio()
      ..httpClientAdapter = _StubDio(
        respond ??
            (options) => ResponseBody.fromString(
              '{"answer":"body for ${options.uri}"}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
      );
    final host = PluginHost(dio: client);
    PluginHost.instance = host;
    await host.boot();
    // The foundation's manager is a process-wide singleton: without this, the
    // next test would discover this one's plugins from a directory that is
    // already gone.
    addTearDown(() {
      host.controller.dispose();
      PluginHost.instance = null;
    });
    return host;
  }

  /// The adapter the last boot used, so a test can count its requests.
  _StubDio stubOf(PluginHost host) => host.dio.httpClientAdapter as _StubDio;

  const kSearchPlugin = '''
// Answers a request first, then maps the host's response: the shape every
// provider in plugins/ copies.
function search(args) {
  if (!args.__response) {
    return {http: {method: 'GET', url: 'https://example.test/s?q=' + encodeURIComponent(args.query)}};
  }
  var body = JSON.parse(args.__response.body);
  return {ok: true, songs: body.songs};
}
function streamUri(args) {
  if (!args.__response) {
    return {http: {method: 'GET', url: 'https://example.test/stream/' + args.song.id}};
  }
  var body = JSON.parse(args.__response.body);
  return {ok: true, url: body.url, headers: body.headers};
}
''';

  test('the host drives a plugin request loop and the source maps the answer',
      () async {
    final host = await boot(
      respond: (options) => ResponseBody.fromString(
        options.uri.path == '/s'
            ? jsonEncode({
                'songs': [
                  {
                    'id': '1',
                    'title': 'Yellow',
                    'artist': 'Coldplay',
                    'album': 'Parachutes',
                    'durationMs': 266000,
                  },
                ],
              })
            : jsonEncode({
                'url': 'https://cdn.test/a.mp3',
                'headers': {'Referer': 'https://example.test/'},
              }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final folder = _pluginFolder(
      id: 'dev.groovybox.example',
      name: 'Example',
      providers: [
        {
          'id': 'example',
          'name': 'Example Music',
          'functions': ['search', 'streamUri'],
        },
      ],
      source: kSearchPlugin,
    );
    expect(await host.installFromFolder(folder.path), isTrue);
    expect(host.providers, hasLength(1));
    expect(host.providers.single.providerId, 'example');

    final source = PluginSource(
      _config('dev.groovybox.example', 'example'),
      host: host,
    );

    final songs = await source.search('Yellow');
    // One function call turned into exactly one request: the host does not
    // re-send what it already has, and the loop ended at the first answer.
    expect(stubOf(host).requests, hasLength(1));
    expect(stubOf(host).requests.single.uri.queryParameters['q'], 'Yellow');
    expect(songs, hasLength(1));
    expect(songs.single.title, 'Yellow');
    expect(songs.single.artist, 'Coldplay');
    // The source id is the config's: everything the UI groups by it.
    expect(songs.single.sourceId, 'plugin-1');
    expect(songs.single.duration, const Duration(milliseconds: 266000));

    final uri = await source.resolveStreamUri(songs.single);
    expect(uri.toString(), 'https://cdn.test/a.mp3');
    // Headers a CDN gates on survive the resolve and reach playback.
    expect(source.streamHeaders(songs.single), {
      'Referer': 'https://example.test/',
    });
  });

  test('a plugin that never stops asking is cut off', () async {
    final host = await boot();
    final folder = _pluginFolder(
      id: 'dev.groovybox.loop',
      name: 'Loop',
      providers: [
        {
          'id': 'loop',
          'functions': ['search'],
        },
      ],
      source: '''
function search(args) {
  return {http: {method: 'GET', url: 'https://example.test/again'}};
}
''',
    );
    expect(await host.installFromFolder(folder.path), isTrue);

    final source = PluginSource(
      _config('dev.groovybox.loop', 'loop'),
      host: host,
    );
    await expectLater(
      source.search('x'),
      throwsA(
        isA<LibraryException>().having(
          (error) => error.messageKey,
          'messageKey',
          'libraryPluginTooManyRequests',
        ),
      ),
    );
    // The cap counts round trips, not attempts: eight requests were made and
    // the ninth answer is what is refused.
    expect(stubOf(host).requests, hasLength(8));
  });

  test('a preview answer becomes PreviewOnlyException', () async {
    final host = await boot(
      respond: (options) => ResponseBody.fromString(
        jsonEncode({'previewUrl': 'https://p.test/a'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final folder = _pluginFolder(
      id: 'dev.groovybox.paywall',
      name: 'Paywall',
      providers: [
        {
          'id': 'paywall',
          'functions': ['streamUri'],
        },
      ],
      source: '''
function streamUri(args) {
  return {ok: true, previewUrl: 'https://p.test/a'};
}
''',
    );
    expect(await host.installFromFolder(folder.path), isTrue);
    final source = PluginSource(
      _config('dev.groovybox.paywall', 'paywall'),
      host: host,
    );

    await expectLater(
      source.resolveStreamUri(
        const LibrarySong(
          sourceId: 'plugin-1',
          id: '9',
          title: 'Locked',
          duration: Duration(seconds: 30),
        ),
      ),
      throwsA(
        isA<PreviewOnlyException>().having(
          (error) => error.previewUri.toString(),
          'previewUri',
          'https://p.test/a',
        ),
      ),
    );
  });

  test('an undeclared function answers empty instead of failing', () async {
    final host = await boot();
    final folder = _pluginFolder(
      id: 'dev.groovybox.streamonly',
      name: 'Stream only',
      providers: [
        {
          'id': 'streamonly',
          'functions': ['streamUri'],
        },
      ],
      source: 'function streamUri(args) { return {ok: true, url: "https://x.test/a.mp3"}; }',
    );
    expect(await host.installFromFolder(folder.path), isTrue);
    final source = PluginSource(
      _config('dev.groovybox.streamonly', 'streamonly'),
      host: host,
    );

    // A two-function provider must not litter the landing page with failures:
    // the merged reads call every method.
    expect(await source.search('x'), isEmpty);
    expect(await source.albums(), isEmpty);
    expect(await source.recentlyAdded(), isEmpty);
    expect(await source.artists(), isEmpty);
    expect(await source.playlists(), isEmpty);
    expect(await source.digest(), isNull);
    expect(stubOf(host).requests, isEmpty);
  });

  test('connect stores the plugin id and the provider, and round-trips',
      () async {
    final host = await boot();
    final folder = _pluginFolder(
      id: 'dev.groovybox.auth',
      name: 'Auth',
      providers: [
        {
          'id': 'kugou',
          'name': 'Kugou Music',
          'requiresAuth': true,
          'functions': ['connect'],
        },
      ],
      source: '''
function connect(args) {
  return {ok: true, auth: {cookie: 'c1', user: args.username}};
}
''',
    );
    expect(await host.installFromFolder(folder.path), isTrue);
    final provider = host.providers.single;

    final config = await PluginAdapter(provider, host: host).connect(
      baseUrl: 'https://example.test',
      username: 'me',
      password: '',
    );
    expect(config.kind, LibraryKind.plugin);
    // The plugin's manifest id, not an address: it is how the host finds the
    // plugin again from a stored config.
    expect(config.baseUrl, 'dev.groovybox.auth');
    expect(config.displayName, 'Kugou Music');
    expect(config.auth, {'cookie': 'c1', 'user': 'me', 'providerId': 'kugou'});

    // A backup restores these, so the record has to survive the round trip.
    final restored = SourceConfig.fromJson(jsonDecode(jsonEncode(config.toJson())));
    expect(restored, isNotNull);
    expect(restored!.kind, LibraryKind.plugin);
    expect(restored.baseUrl, config.baseUrl);
    expect(restored.auth, config.auth);
  });

  test('a config whose plugin is gone reports itself missing', () async {
    final host = await boot();
    // No install: the config names a plugin this machine does not have.
    final source =
        librarySourceFromConfig(_config('dev.groovybox.absent', 'absent'))
            as ResolvedStreamSource;
    expect(source, isA<PluginSource>());

    Matcher missing() => throwsA(
      isA<LibraryException>().having(
        (error) => error.messageKey,
        'messageKey',
        'libraryPluginMissing',
      ),
    );
    await expectLater(source.search('x'), missing());
    await expectLater(source.albums(), missing());
    await expectLater(
      source.resolveStreamUri(
        const LibrarySong(
          sourceId: 'plugin-1',
          id: '1',
          title: 'x',
          duration: Duration.zero,
        ),
      ),
      missing(),
    );
    // Nothing was asked of the network for a plugin that is not installed.
    expect(stubOf(host).requests, isEmpty);
  });

  test('the md5 channel answers synchronously', () async {
    final host = await boot();
    final folder = _pluginFolder(
      id: 'dev.groovybox.md5',
      name: 'Digest',
      providers: [
        {
          'id': 'digest',
          'functions': ['search'],
        },
      ],
      source: '''
function search(args) {
  var hash = sendMessage('api:groovybox:md5', JSON.stringify({value: 'abc'}));
  return {ok: true, songs: [{id: hash, title: 'hashed', durationMs: 1000}]};
}
''',
    );
    expect(await host.installFromFolder(folder.path), isTrue);
    final source = PluginSource(
      _config('dev.groovybox.md5', 'digest'),
      host: host,
    );

    final songs = await source.search('x');
    // The signature Kugou documents, computed in Dart before the JS call
    // returned.
    expect(songs.single.id, '900150983cd24fb0d6963f7d28e17f72');
  });
}
