import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lrclib.dart';
import 'package:groovy_box/library/lyrics.dart';

/// A stand-in for lrclib.net: exactly the two endpoints the client calls.
class _FakeLrclib {
  _FakeLrclib(this._server);

  final HttpServer _server;

  /// Set to make every request answer 429 with this many seconds.
  int? rateLimitSeconds;

  /// Set to fail the connection instead of answering.
  bool offline = false;

  final List<Uri> requests = [];

  static Future<_FakeLrclib> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeLrclib(server);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  /// The `/api/get` answer, keyed by nothing: one fixed record per test.
  Map<String, Object?>? exact;
  List<Map<String, Object?>> searchResults = [];

  Future<void> _handle(HttpRequest request) async {
    requests.add(request.uri);
    final response = request.response;

    if (offline) {
      await response.close();
      return;
    }
    if (rateLimitSeconds case final seconds?) {
      response.statusCode = HttpStatus.tooManyRequests;
      response.headers.set('retry-after', '$seconds');
      response.write(jsonEncode({'statusCode': 429}));
      await response.close();
      return;
    }

    response.headers.contentType = ContentType.json;
    switch (request.uri.path) {
      case '/api/get':
        final record = exact;
        if (record == null) {
          response.statusCode = HttpStatus.notFound;
          response.write(jsonEncode({'statusCode': 404, 'name': 'TrackNotFound'}));
        } else {
          response.write(jsonEncode(record));
        }
      case '/api/search':
        response.write(jsonEncode(searchResults));
      default:
        response.statusCode = HttpStatus.notFound;
        response.write('{}');
    }
    await response.close();
  }
}

Map<String, Object?> _record({
  int id = 1,
  String track = 'Yellow',
  String artist = 'Coldplay',
  double duration = 267,
  String? synced,
  String? plain,
  bool instrumental = false,
}) => {
  'id': id,
  'name': track,
  'trackName': track,
  'artistName': artist,
  'albumName': 'Parachutes',
  'duration': duration,
  'instrumental': instrumental,
  'hasWordSync': false,
  'plainLyrics': plain,
  'syncedLyrics': synced,
};

const _song = LyricsRequest(
  sourceId: 'a',
  id: 's1',
  title: 'Yellow',
  artist: 'Coldplay',
  duration: Duration(seconds: 266),
);

Future<Lrclib> _client(_FakeLrclib fake) async => Lrclib(
  dio: Dio(
    BaseOptions(
      baseUrl: fake.baseUrl,
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
    ),
  ),
);

void main() {
  // No widget binding here on purpose: it installs an HttpOverrides that
  // answers every request with 400, which would hide what this suite tests.
  late _FakeLrclib fake;
  setUp(() async => fake = await _FakeLrclib.start());
  tearDown(() => fake.close());

  test('an exact hit returns the timed lyric and skips the search', () async {
    fake.exact = _record(synced: '[00:19.16] Look at the stars\n[00:24.09] You');
    final lookup = await (await _client(fake)).find(_song);

    expect(lookup.settled, isTrue);
    expect(lookup.result!.id, 1);
    expect(lookup.result!.lyrics.synced, isTrue);
    expect(lookup.result!.lyrics.lines.first.text, 'Look at the stars');
    expect(
      fake.requests.map((uri) => uri.path),
      ['/api/get'],
      reason: 'the exact endpoint answered, so no search is needed',
    );
    // The library's duration is rounded down and sent as whole seconds.
    expect(fake.requests.single.queryParameters['duration'], '266');
  });

  test('a miss falls through to search and picks the matching runtime',
      () async {
    fake.searchResults = [
      _record(id: 7, track: 'Yellow', duration: 200, synced: '[00:01.00] live'),
      _record(id: 8, track: 'Yellow', duration: 266, synced: '[00:01.00] yes'),
    ];
    final lookup = await (await _client(fake)).find(_song);

    expect(lookup.result!.id, 8);
    expect(fake.requests.map((uri) => uri.path), ['/api/get', '/api/search']);
  });

  test('a search hit outside the runtime tolerance is rejected', () async {
    fake.searchResults = [
      _record(id: 7, duration: 200, synced: '[00:01.00] a different take'),
    ];
    final lookup = await (await _client(fake)).find(_song);

    expect(lookup.result, isNull);
    expect(lookup.settled, isTrue);
  });

  test('a timed record beats a plain one at the same duration', () async {
    fake.searchResults = [
      _record(id: 1, duration: 266, plain: 'plain words'),
      _record(id: 2, duration: 267, synced: '[00:01.00] timed words'),
    ];
    final lookup = await (await _client(fake)).find(_song);

    expect(lookup.result!.lyrics.synced, isTrue);
    expect(lookup.result!.lyrics.lines.single.text, 'timed words');
  });

  test('an instrumental is an answer, not a failure', () async {
    fake.exact = _record(instrumental: true);
    final lookup = await (await _client(fake)).find(_song);

    expect(lookup.result, isNull);
    expect(lookup.settled, isTrue);
  });

  test('a plain-only record becomes an unsynced lyric with its breaks', () async {
    fake.exact = _record(plain: 'First verse\n\nSecond verse\n\n');
    final lookup = await (await _client(fake)).find(_song);

    expect(lookup.result!.lyrics.synced, isFalse);
    expect(
      lookup.result!.lyrics.lines.map((line) => line.text),
      ['First verse', '', 'Second verse'],
    );
  });

  test('a timeout is unsettled, so it is not cached as a miss', () async {
    fake.offline = true;
    final lookup = await (await _client(fake)).find(_song);

    expect(lookup.result, isNull);
    expect(lookup.settled, isFalse);
  });

  test('a rate limit blocks later requests instead of retrying into it',
      () async {
    fake.rateLimitSeconds = 30;
    final lrclib = await _client(fake);

    final first = await lrclib.find(_song);
    expect(first.settled, isFalse);
    expect(fake.requests, hasLength(1));

    // While the window is still open nothing is sent, and the caller is told
    // the answer is unknown rather than missing.
    fake.rateLimitSeconds = null;
    final second = await lrclib.find(_song);
    expect(second.settled, isFalse);
    expect(fake.requests, hasLength(1));

    // The exact endpoint failing on the limit also stops the search.
    expect(fake.requests.single.path, '/api/get');
  });

  test('a song without an artist is not asked about', () async {
    final lookup = await (await _client(fake)).find(
      const LyricsRequest(sourceId: 'a', id: 's1', title: 'Untitled'),
    );

    expect(lookup.result, isNull);
    expect(fake.requests, isEmpty);
  });

  test('requests keep the documented gap between them', () async {
    fake.exact = _record(synced: '[00:01.00] a');
    final lrclib = await _client(fake);

    final watch = Stopwatch()..start();
    await lrclib.find(_song);
    await lrclib.find(
      const LyricsRequest(
        sourceId: 'a',
        id: 's2',
        title: 'Yellow',
        artist: 'Coldplay',
      ),
    );
    watch.stop();

    expect(
      watch.elapsed,
      greaterThanOrEqualTo(Lrclib.requestGap),
      reason: 'the second request waits out the gap',
    );
  });
}
