import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/http_cache.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/subsonic_adapter.dart';

/// A Subsonic server whose answers and whose very existence a test controls.
class _Server {
  _Server._(this._server, this._db);

  HttpServer _server;
  final LibraryDatabase _db;

  /// Requests that actually reached the socket.
  int requests = 0;

  /// Non-200 makes every read a refusal, which must never be answered from
  /// the cache.
  int status = 200;

  static Future<_Server> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final db = LibraryDatabase(NativeDatabase.memory());
    final fake = _Server._(server, db);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  SourceConfig get config => SourceConfig(
    id: 'home',
    kind: LibraryKind.subsonic,
    baseUrl: baseUrl,
    displayName: 'Home',
    auth: {'username': 'u', 'token': 't', 'salt': 's'},
  );

  Future<void> _handle(HttpRequest request) async {
    requests++;
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'subsonic-response': {
          'status': status == 200 ? 'ok' : 'failed',
          if (status == 200)
            'album': {
              'id': 'a1',
              'name': 'Parachutes',
              'artist': 'Coldplay',
              'song': [
                {
                  'id': 's1',
                  'title': 'Yellow',
                  'artist': 'Coldplay',
                  'album': 'Parachutes',
                  'duration': 266,
                },
              ],
            },
        },
      }),
    );
    await request.response.close();
  }

  /// Nothing listens on the address any more: the network is gone.
  Future<void> goOffline() => _server.close(force: true);

  Future<void> close() async {
    await _server.close(force: true);
    await _db.close();
  }

  ResponseCache cache() => ResponseCache(_db);

  /// Makes the stored answer look expired without deleting it, which is the
  /// state a device that was offline for a while is actually in.
  Future<void> expireEverything() async {
    final rows = await _db.select(_db.httpCache).get();
    for (final row in rows) {
      await _db.putCachedResponse(
        HttpCacheRow(
          key: row.key,
          body: row.body,
          storedAt: row.storedAt,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          stale: row.stale,
        ),
      );
    }
  }
}

void main() {
  test('a fresh answer is not asked for twice', () async {
    final server = await _Server.start();
    addTearDown(server.close);
    final source = SubsonicSource(server.config, cache: server.cache());

    await source.albumSongs('a1');
    final second = await source.albumSongs('a1');

    expect(second.single.title, 'Yellow');
    expect(server.requests, 1);
  });

  test('an expired listing survives the server going away', () async {
    final server = await _Server.start();
    addTearDown(server.close);
    final source = SubsonicSource(server.config, cache: server.cache());

    await source.albumSongs('a1');
    await server.expireEverything();
    await server.goOffline();

    final offline = await source.albumSongs('a1');
    expect(offline.single.id, 's1');
    expect(offline.single.album, 'Parachutes');
  });

  test('a refusal is never answered from disk', () async {
    final server = await _Server.start();
    addTearDown(server.close);
    final source = SubsonicSource(server.config, cache: server.cache());

    await source.albumSongs('a1');
    await server.expireEverything();
    server.status = 500;

    await expectLater(
      source.albumSongs('a1'),
      throwsA(isA<LibraryException>()),
    );
  });

  test('the cache key ignores credentials and keeps the request', () {
    final a = cacheKeyForUri(
      'home',
      'get',
      Uri.parse('https://music.example.com/rest/getAlbum?id=a1&t=x&s=y&u=z'),
    );
    final b = cacheKeyForUri(
      'home',
      'GET',
      Uri.parse('https://music.example.com/rest/getAlbum?id=a1&t=q&s=r&u=w'),
    );
    expect(a, b);
    expect(a, contains('id=a1'));
    expect(a, contains('home'));
    expect(a, isNot(contains('t=')));
  });

  test('a write drops the answers the library had stored', () async {
    final server = await _Server.start();
    addTearDown(server.close);
    final cache = server.cache();
    final source = SubsonicSource(server.config, cache: cache);

    await source.albumSongs('a1');
    expect((await cache.totals()).count, 1);

    await source.setFavourite(
      const LibrarySong(
        sourceId: 'home',
        id: 's1',
        title: 'Yellow',
        duration: Duration(seconds: 266),
      ),
      value: true,
    );
    expect((await cache.totals()).count, 0);
  });

  test('the device reports a library as offline, not empty', () async {
    final server = await _Server.start();
    addTearDown(server.close);
    final scopes = <String>[];
    final cache = ResponseCache(server._db, onServedStale: scopes.add);
    final source = SubsonicSource(server.config, cache: cache);

    await source.albumSongs('a1');
    await server.expireEverything();
    await server.goOffline();
    await source.albumSongs('a1');

    expect(scopes, ['home']);
  });
}
