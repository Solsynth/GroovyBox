import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/netease_adapter.dart';
import 'package:groovy_box/library/source.dart';

/// Minimal NetEase bridge surface: exactly the endpoints the adapter calls,
/// with the field names a real NeteaseCloudMusicApi deployment sends.
class _FakeNetease {
  _FakeNetease(this._server);

  final HttpServer _server;

  /// The cookie the fake accepted at login; reads without it answer 301.
  String? signedInCookie;

  /// Whether the minted stream URL is a playable one.
  bool trackPlayable = true;

  /// Every request's query, keyed by path — the assertions read these.
  final Map<String, Map<String, String>> lastQuery = {};

  static Future<_FakeNetease> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeNetease(server);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    lastQuery[path] = request.uri.queryParameters;
    final response = request.response;
    response.headers.contentType = ContentType.json;

    switch (path) {
      case '/login/cellphone':
        final phoneQuery = request.uri.queryParameters;
        if (phoneQuery['phone'] == '5550100' &&
            phoneQuery['password'] == 'secret') {
          signedInCookie = 'MUSIC_U=fake-cookie';
          response.write(
            jsonEncode({
              'code': 200,
              'cookie': 'MUSIC_U=fake-cookie',
              'profile': {'nickname': 'Someone', 'userId': 42},
            }),
          );
        } else {
          response.write(jsonEncode({'code': 502, 'msg': '密码错误'}));
        }
      case '/login':
        final query = request.uri.queryParameters;
        if (query['email'] == 'me@163.com' && query['password'] == 'secret') {
          signedInCookie = 'MUSIC_U=fake-cookie';
          response.write(
            jsonEncode({
              'code': 200,
              'cookie': 'MUSIC_U=fake-cookie',
              'profile': {'nickname': 'Mail', 'userId': 7},
            }),
          );
        } else {
          response.write(jsonEncode({'code': 502, 'msg': '密码错误'}));
        }
      case '/user/account':
        if (_rejectUnsigned(request)) {
          response.write(jsonEncode({'code': 301}));
          await response.close();
          return;
        }
        response.write(
          jsonEncode({'code': 200, 'profile': {'userId': 42}}),
        );
      case '/user/playlist':
        if (_rejectUnsigned(request)) {
          response.write(jsonEncode({'code': 301}));
          await response.close();
          return;
        }
        response.write(
          jsonEncode({
            'code': 200,
            'playlist': [
              {
                'id': 1,
                'name': 'My list',
                'userId': 42,
                'trackCount': 2,
                'coverImgUrl': 'https://p.example/cover.jpg',
                'creator': {'nickname': 'Someone'},
              },
              {
                'id': 2,
                'name': 'Collected',
                'userId': 99,
                'trackCount': 5,
              },
            ],
          }),
        );
      case '/playlist/track/all':
        if (_rejectUnsigned(request)) {
          response.write(jsonEncode({'code': 301}));
          await response.close();
          return;
        }
        response.write(
          jsonEncode({
            'code': 200,
            'songs': [_song(101, 'Song One')],
          }),
        );
      case '/album/sublist':
        response.write(
          jsonEncode({
            'code': 200,
            'data': [
              {
                'id': 11,
                'name': 'An Album',
                'size': 10,
                'publishTime': 1609459200000,
                'artist': {'id': 5, 'name': 'An Artist'},
                'picUrl': 'https://p.example/al.jpg',
              },
            ],
          }),
        );
      case '/album':
        response.write(
          jsonEncode({
            'code': 200,
            'album': {
              'id': 11,
              'name': 'An Album',
              'artist': {'id': 5, 'name': 'An Artist'},
              'picUrl': 'https://p.example/al.jpg',
              'songs': [_song(201, 'Album Song')],
            },
          }),
        );
      case '/artist/sublist':
        response.write(
          jsonEncode({
            'code': 200,
            'data': [
              {
                'id': 5,
                'name': 'An Artist',
                'picUrl': 'https://p.example/ar.jpg',
              },
            ],
          }),
        );
      case '/artist/album':
        response.write(
          jsonEncode({
            'code': 200,
            'hotAlbums': [
              {
                'id': 12,
                'name': 'Another Album',
                'size': 8,
                'artist': {'id': 5, 'name': 'An Artist'},
              },
            ],
          }),
        );
      case '/cloudsearch':
        response.write(
          jsonEncode({
            'code': 200,
            'result': {'songs': [_song(101, 'Song One')]},
          }),
        );
      case '/likelist':
        response.write(
          jsonEncode({'code': 200, 'ids': [101, 102]}),
        );
      case '/like':
        final query = request.uri.queryParameters;
        final liked = query['like'] == 'true';
        response.write(
          jsonEncode({
            'code': liked ? 200 : 200,
            if (!liked) 'playlistId': null,
          }),
        );
      case '/song/url/v1':
        if (_rejectUnsigned(request)) {
          response.write(jsonEncode({'code': 301}));
          await response.close();
          return;
        }
        response.write(
          jsonEncode({
            'code': 200,
            'data': [
              {
                'id': 101,
                'url': trackPlayable
                    ? 'http://m.example/stream/101.mp3'
                    : null,
                'level': request.uri.queryParameters['level'],
              },
            ],
          }),
        );
      case '/lyric':
        response.write(
          jsonEncode({
            'code': 200,
            'lrc': {'lyric': '[00:01.00]First line\n[00:04.50]Second line'},
            'tlyric': {'lyric': '[00:01.00]第一行\n[00:04.50]第二行'},
          }),
        );
      case '/recommend/songs':
        response.write(
          jsonEncode({
            'code': 200,
            'data': {'dailySongs': [_song(301, 'Daily Pick')]},
          }),
        );
      case '/personalized':
        response.write(jsonEncode({'code': 200, 'result': []}));
      default:
        response.statusCode = HttpStatus.notFound;
        response.write(jsonEncode({'code': 404}));
    }
    await response.close();
  }

  bool _rejectUnsigned(HttpRequest request) =>
      signedInCookie == null ||
      !(request.uri.queryParameters['cookie'] ?? '').contains(signedInCookie!);

  /// One song, in the shape `/playlist/track/all` and `/cloudsearch` answer
  /// with (`ar`/`al`, `dt` — the newer field names).
  static Map<String, dynamic> _song(int id, String name) => {
    'id': id,
    'name': name,
    'dt': 216000,
    'no': 1,
    'ar': [
      {'id': 5, 'name': 'An Artist'},
    ],
    'al': {
      'id': 11,
      'name': 'An Album',
      'picUrl': 'https://p.example/song.jpg',
    },
  };
}

void main() {
  late _FakeNetease server;
  setUp(() async {
    server = await _FakeNetease.start();
    server.trackPlayable = true;
    // The config()-based tests construct a source directly; the fake has to
    // recognise the cookie they carry without a connect() first.
    server.signedInCookie = 'MUSIC_U=fake-cookie';
  });
  tearDown(() => server.close());

  SourceConfig config(String cookie) => SourceConfig(
    id: 'netease-test',
    kind: LibraryKind.netease,
    baseUrl: server.baseUrl,
    displayName: 'Someone',
    auth: {'cookie': cookie},
  );

  test('connect signs in with a phone number and stores the cookie', () async {
    final config = await NeteaseAdapter().connect(
      baseUrl: server.baseUrl,
      username: '+1 5550100',
      password: 'secret',
    );
    expect(config.kind, LibraryKind.netease);
    expect(config.baseUrl, server.baseUrl);
    expect(config.auth['cookie'], 'MUSIC_U=fake-cookie');
    expect(config.displayName, 'Someone');
    expect(server.lastQuery['/login/cellphone']?['countrycode'], '1');
    expect(server.lastQuery['/login/cellphone']?['phone'], '5550100');
  });

  test('connect signs in with an email', () async {
    final config = await NeteaseAdapter().connect(
      baseUrl: server.baseUrl,
      username: 'me@163.com',
      password: 'secret',
    );
    expect(config.auth['cookie'], 'MUSIC_U=fake-cookie');
    expect(server.lastQuery['/login'], isNotNull);
    expect(server.lastQuery['/login/cellphone'], isNull);
  });

  test('connect surfaces a refused sign-in', () async {
    await expectLater(
      NeteaseAdapter().connect(
        baseUrl: server.baseUrl,
        username: '5550100',
        password: 'wrong',
      ),
      throwsA(
        isA<LibraryException>().having(
          (e) => e.message,
          'message',
          contains('密码错误'),
        ),
      ),
    );
  });

  test('maps songs, playlists and albums onto the neutral models', () async {
    final source = NeteaseAdapter().sourceFor(config('MUSIC_U=fake-cookie'));

    final playlists = await source.playlists();
    expect(playlists, hasLength(2));
    expect(playlists.first.name, 'My list');
    expect(playlists.first.songCount, 2);
    expect(playlists.first.artId, 'https://p.example/cover.jpg');

    final songs = await source.playlistSongs('1');
    expect(songs, hasLength(1));
    final song = songs.single;
    expect(song.sourceId, 'netease-test');
    expect(song.id, '101');
    expect(song.title, 'Song One');
    expect(song.artist, 'An Artist');
    expect(song.artistId, '5');
    expect(song.album, 'An Album');
    expect(song.albumId, '11');
    expect(song.duration, const Duration(minutes: 3, seconds: 36));
    expect(song.artId, 'https://p.example/song.jpg');

    final albums = await source.albums();
    expect(albums, hasLength(1));
    expect(albums.single.name, 'An Album');
    expect(albums.single.artist, 'An Artist');
    expect(albums.single.year, 2021);

    final albumSongs = await source.albumSongs('11');
    expect(albumSongs.single.title, 'Album Song');

    final artists = await source.artists();
    expect(artists.single.name, 'An Artist');
    expect(artists.single.artId, 'https://p.example/ar.jpg');

    final search = await source.search('Song One');
    expect(search.single.id, '101');
  });

  test('reads carry the session cookie', () async {
    final source = NeteaseAdapter().sourceFor(config('MUSIC_U=fake-cookie'));
    await source.playlistSongs('1');
    expect(
      server.lastQuery['/playlist/track/all']?['cookie'],
      contains('MUSIC_U=fake-cookie'),
    );
  });

  test('the daily mix arrives as a landing shelf', () async {
    final source =
        NeteaseAdapter().sourceFor(config("MUSIC_U=fake-cookie"))
            as NeteaseSource;
    final shelves = await source.landingShelves();
    expect(shelves, hasLength(1));
    expect(shelves.single.songs.single.title, 'Daily Pick');
  });

  test('favourites read and write the red-heart list', () async {
    final source =
        NeteaseAdapter().sourceFor(config('MUSIC_U=fake-cookie'))
            as NeteaseSource;
    final song = (await source.playlistSongs('1')).single;

    expect(await source.isFavourite(song), isTrue);
    await source.setFavourite(song, value: false);
    expect(server.lastQuery['/like']?['like'], 'false');
    expect(server.lastQuery['/like']?['id'], '101');
  });

  test('playback resolves a minted URL, and caches it', () async {
    final source =
        NeteaseAdapter().sourceFor(config('MUSIC_U=fake-cookie'))
            as NeteaseSource;
    final song = (await source.playlistSongs('1')).single;

    final uri = await source.resolveStreamUri(song);
    expect(uri.toString(), 'http://m.example/stream/101.mp3');
    expect(server.lastQuery['/song/url/v1']?['id'], '101');
    expect(server.lastQuery['/song/url/v1']?['level'], 'exhigh');

    // The second call must not reach the server again: the fake answers 301
    // once the cookie is dropped, so a re-request would throw.
    server.signedInCookie = null;
    final again = await source.resolveStreamUri(song);
    expect(again, uri);
  });

  test('an unplayable track is a refusal, not a network failure', () async {
    server.trackPlayable = false;
    final source =
        NeteaseAdapter().sourceFor(config('MUSIC_U=fake-cookie'))
            as NeteaseSource;
    final song = (await source.playlistSongs('1')).single;
    await expectLater(
      source.resolveStreamUri(song),
      throwsA(
        isA<LibraryException>().having(
          (e) => e.messageKey,
          'messageKey',
          'libraryNeteaseUnavailable',
        ),
      ),
    );
  });

  test('lyrics merge the translation layer', () async {
    final source =
        NeteaseAdapter().sourceFor(config('MUSIC_U=fake-cookie'))
            as NeteaseSource;
    final song = (await source.playlistSongs('1')).single;
    final lyrics = await source.lyrics(song);
    expect(lyrics.synced, isTrue);
    expect(lyrics.lines.first.text, 'First line');
    expect(lyrics.lines.first.translation, '第一行');
  });

  test('an expired session answers as signed-out', () async {
    final source = NeteaseAdapter().sourceFor(config('MUSIC_U=stale'));
    await expectLater(
      source.playlists(),
      throwsA(
        isA<LibraryException>().having(
          (e) => e.messageKey,
          'messageKey',
          'libraryNeteaseSignedOut',
        ),
      ),
    );
  });
}
