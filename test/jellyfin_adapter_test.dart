import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/jellyfin_adapter.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';

/// Minimal Jellyfin surface: exactly the endpoints the adapter calls, with the
/// field names a real server sends.
class _FakeJellyfin {
  _FakeJellyfin(this._server);

  final HttpServer _server;
  bool rejectAuth = false;

  /// Reject the auth call the way Jellyfin 10.11 does when the client
  /// identity header is missing or malformed.
  bool rejectClientIdentity = false;

  /// Every request's headers, keyed by path.
  final Map<String, HttpHeaders> lastHeaders = {};

  static Future<_FakeJellyfin> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeJellyfin(server);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    lastHeaders[path] = request.headers;
    final response = request.response;
    response.headers.contentType = ContentType.json;

    if (path == '/Users/AuthenticateByName') {
      if (rejectClientIdentity) {
        response.statusCode = HttpStatus.badRequest;
        response.write(jsonEncode({'Message': 'Bad request.'}));
      } else if (rejectAuth) {
        response.statusCode = HttpStatus.unauthorized;
        response.write(jsonEncode({'Message': 'Invalid credentials.'}));
      } else {
        response.write(
          jsonEncode({
            'User': {'Id': 'u1', 'Name': 'me'},
            'AccessToken': 'tok',
            'ServerId': 'srv',
          }),
        );
      }
    } else if (path == '/Users/Me') {
      response.write(jsonEncode({'Id': 'u1', 'Name': 'me'}));
    } else if (path == '/Items') {
      final query = request.uri.queryParameters;
      response.write(
        jsonEncode({'Items': _itemsFor(query), 'TotalRecordCount': 2}),
      );
    } else {
      response.statusCode = HttpStatus.notFound;
      response.write(jsonEncode({'Message': 'not found'}));
    }
    await response.close();
  }

  List<Map<String, dynamic>> _itemsFor(Map<String, String> query) {
    if (query['IncludeItemTypes'] == 'MusicAlbum') {
      return [
        {
          'Id': 'al1',
          'Name': 'An Album',
          'AlbumArtist': 'An Artist',
          'RunTimeTicks': 3830000000,
          'ProductionYear': 2019,
          'ImageTags': {'Primary': 'tag'},
          'Genres': ['Electronic'],
        },
      ];
    }
    return [
      {
        'Id': 's1',
        'Name': 'A Song',
        'Album': 'An Album',
        'AlbumId': 'al1',
        'AlbumArtist': 'An Artist',
        'RunTimeTicks': 3830000000,
        'IndexNumber': 2,
        'ParentIndexNumber': 1,
        'Genres': ['Electronic'],
      },
    ];
  }
}

void main() {
  late _FakeJellyfin server;

  setUp(() async => server = await _FakeJellyfin.start());
  tearDown(() async => server.close());

  test('connect stores the token and the user id', () async {
    final config = await JellyfinAdapter().connect(
      baseUrl: server.baseUrl,
      username: 'me',
      password: 'secret',
    );

    expect(config.kind, LibraryKind.jellyfin);
    expect(config.auth['accessToken'], 'tok');
    expect(config.auth['userId'], 'u1');
    expect(config.auth['username'], 'me');
    expect(config.displayName, '127.0.0.1');
    expect(config.baseUrl, server.baseUrl);
  });

  test('rejects wrong credentials with a LibraryException', () async {
    server.rejectAuth = true;

    await expectLater(
      JellyfinAdapter().connect(
        baseUrl: server.baseUrl,
        username: 'me',
        password: 'wrong',
      ),
      throwsA(
        isA<LibraryException>()
            .having((e) => e.message, 'message', 'Wrong username or password.')
            .having((e) => e.code, 'code', 401),
      ),
    );
  });

  test('authenticates with the Authorization header Jellyfin 10.11 reads', () async {
    await JellyfinAdapter().connect(
      baseUrl: server.baseUrl,
      username: 'me',
      password: 'secret',
    );

    // 10.11 parses `Authorization: MediaBrowser ...` only and rejects the
    // legacy X-Emby pair, which used to make a correct password fail with 400.
    final auth = server.lastHeaders['/Users/AuthenticateByName']!;
    final header = auth.value(HttpHeaders.authorizationHeader).toString();
    expect(header, startsWith('MediaBrowser '));
    expect(header, contains('Client="GroovyBox"'));
    expect(header, contains('DeviceId="'));
    expect(auth.value('X-Emby-Authorization'), isNull);

    // The signed-in calls carry the token in the same header.
    final me = server.lastHeaders['/Users/Me'];
    if (me != null) {
      expect(
        me.value(HttpHeaders.authorizationHeader).toString(),
        contains('Token="tok"'),
      );
    }
  });

  test(
    'explains a rejected client identity instead of blaming the password',
    () async {
      server.rejectClientIdentity = true;

      await expectLater(
        JellyfinAdapter().connect(
          baseUrl: server.baseUrl,
          username: 'me',
          password: 'secret',
        ),
        throwsA(
          isA<LibraryException>().having(
            (e) => e.message,
            'message',
            contains('client identity'),
          ),
        ),
      );
    },
  );

  test('maps songs, durations and stream URLs', () async {
    final config = await JellyfinAdapter().connect(
      baseUrl: server.baseUrl,
      username: 'me',
      password: 'secret',
    );
    final source = JellyfinAdapter().sourceFor(config);

    final songs = await source.albumSongs('al1');
    expect(songs, hasLength(1));
    final song = songs.single;
    expect(song.sourceId, config.id);
    expect(song.duration, const Duration(minutes: 6, seconds: 23));
    expect(song.track, 2);
    expect(song.discNumber, 1);
    expect(song.genre, 'Electronic');
    expect(song.artist, 'An Artist');
    expect(song.albumId, 'al1');
    expect(song.artId, 'al1');

    final uri = source.streamUri(song).toString();
    expect(uri, contains('/Audio/s1/stream'));
    expect(uri, contains('api_key=tok'));

    final art = source.artworkUri(song.artId, size: 300).toString();
    expect(art, contains('/Items/al1/Images/Primary'));
    expect(art, contains('maxHeight=300'));
  });

  test('maps albums', () async {
    final config = await JellyfinAdapter().connect(
      baseUrl: server.baseUrl,
      username: 'me',
      password: 'secret',
    );
    final albums = await JellyfinAdapter().sourceFor(config).recentlyAdded();

    expect(albums, hasLength(1));
    expect(albums.single.name, 'An Album');
    expect(albums.single.year, 2019);
    expect(albums.single.artId, 'al1');
  });
}
