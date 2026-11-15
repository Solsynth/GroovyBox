import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/netease_adapter.dart';
import 'package:groovy_box/library/source.dart';

/// A 1x1 transparent PNG as a `data:` URL — what the bridge's `qrimg` is,
/// without the bytes a real QR would carry.
const _kQrDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// Minimal NetEase bridge surface: exactly the endpoints the adapter calls,
/// with the field names a real NeteaseCloudMusicApi deployment sends.
class _FakeNetease {
  _FakeNetease(this._server);

  final HttpServer _server;

  /// The cookie the fake accepted at login; reads without it answer 301.
  String? signedInCookie;

  /// Whether the minted stream URL is a playable one.
  bool trackPlayable = true;

  /// The scan states `/login/qr/check` walks through, one per call. The last
  /// value repeats if the list runs out.
  List<int> qrStates = [801, 802, 803];

  /// Every request's query, keyed by path — the assertions read these.
  final Map<String, Map<String, String>> lastQuery = {};

  int _qrChecks = 0;

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
      case '/login/qr/key':
        response.write(
          jsonEncode({
            'code': 200,
            'data': {'unikey': 'qr-key'},
          }),
        );
      case '/login/qr/create':
        response.write(
          jsonEncode({
            'code': 200,
            'data': {
              'qrurl': 'https://music.163.com/login?codekey=qr-key',
              'qrimg': _kQrDataUrl,
            },
          }),
        );
      case '/login/qr/check':
        final index = _qrChecks < qrStates.length
            ? _qrChecks
            : qrStates.length - 1;
        _qrChecks++;
        final state = qrStates[index];
        if (state == 803) {
          signedInCookie = 'MUSIC_U=qr-cookie';
          response.write(
            jsonEncode({
              'code': 803,
              'cookie': 'MUSIC_U=qr-cookie',
              'message': '授权登陆成功',
            }),
          );
        } else {
          response.write(
            jsonEncode({
              'code': state,
              'message': switch (state) {
                801 => '等待扫码',
                802 => '授权中',
                800 => '二维码不存在或已过期',
                _ => '',
              },
            }),
          );
        }
      case '/user/account':
        if (_rejectUnsigned(request)) {
          response.write(jsonEncode({'code': 301}));
          await response.close();
          return;
        }
        response.write(
          jsonEncode({
            'code': 200,
            'profile': {'userId': 42, 'nickname': 'Someone'},
          }),
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
        response.write(jsonEncode({'code': 200}));
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
    server.qrStates = [801, 802, 803];
    // The config()-based tests construct a source directly; the fake has to
    // recognise the cookie they carry without a login first.
    server.signedInCookie = 'MUSIC_U=qr-cookie';
  });
  tearDown(() => server.close());

  SourceConfig config(String cookie) => SourceConfig(
    id: 'netease-test',
    kind: LibraryKind.netease,
    baseUrl: server.baseUrl,
    displayName: 'Someone',
    auth: {'cookie': cookie},
  );

  NeteaseSource signedIn() =>
      NeteaseAdapter().sourceFor(config('MUSIC_U=qr-cookie')) as NeteaseSource;

  /// Drives the QR flow to completion: mint the code, then consume the poll
  /// stream, which sets the cookie on the adapter.
  Future<SourceConfig> completeQr(NeteaseAdapter adapter) async {
    final steps = adapter.loginSteps(server.baseUrl);
    final qr = steps.single as QrLoginStep;
    expect(await qr.prepare(), _kQrDataUrl);
    await qr.poll().drain<void>();
    return adapter.completeLogin(server.baseUrl, steps);
  }

  test('login is a QR step, not a password form', () {
    final adapter = NeteaseAdapter();
    expect(adapter, isA<InteractiveLoginAdapter>());
    // Nothing is typed into a username or password field.
    expect(adapter.needsCredentials, isFalse);

    final step = adapter.loginSteps(server.baseUrl).single;
    expect(step, isA<QrLoginStep>());
    expect(step.id, 'qr');
  });

  test('the QR flow stores the session cookie and names the account', () async {
    server.signedInCookie = null;
    final config = await completeQr(NeteaseAdapter());

    expect(config.kind, LibraryKind.netease);
    expect(config.baseUrl, server.baseUrl);
    expect(config.auth['cookie'], 'MUSIC_U=qr-cookie');
    expect(config.displayName, 'Someone');

    // The unikey was minted, rendered and then polled.
    expect(server.lastQuery['/login/qr/key'], isNotNull);
    expect(server.lastQuery['/login/qr/create']?['key'], 'qr-key');
    expect(server.lastQuery['/login/qr/create']?['qrimg'], 'true');
    expect(server.lastQuery['/login/qr/check']?['key'], 'qr-key');
  });

  test('an expired code ends the login as an error', () async {
    server.signedInCookie = null;
    server.qrStates = [800];
    final adapter = NeteaseAdapter();
    final qr = adapter.loginSteps(server.baseUrl).single as QrLoginStep;
    await qr.prepare();
    await expectLater(
      qr.poll().drain<void>(),
      throwsA(
        isA<LibraryException>().having(
          (e) => e.messageKey,
          'messageKey',
          'libraryNeteaseQrExpired',
        ),
      ),
    );
  });

  test('completing without a scan refuses to store a source', () async {
    final adapter = NeteaseAdapter();
    await expectLater(
      adapter.completeLogin(server.baseUrl, adapter.loginSteps(server.baseUrl)),
      throwsA(
        isA<LibraryException>().having(
          (e) => e.messageKey,
          'messageKey',
          'libraryNeteaseNoCookie',
        ),
      ),
    );
  });

  test('maps songs, playlists and albums onto the neutral models', () async {
    final source = signedIn();

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
    final source = signedIn();
    await source.playlistSongs('1');
    expect(
      server.lastQuery['/playlist/track/all']?['cookie'],
      contains('MUSIC_U=qr-cookie'),
    );
  });

  test('the daily mix arrives as a landing shelf', () async {
    final shelves = await signedIn().landingShelves();
    expect(shelves, hasLength(1));
    expect(shelves.single.songs.single.title, 'Daily Pick');
  });

  test('favourites read and write the red-heart list', () async {
    final source = signedIn();
    final song = (await source.playlistSongs('1')).single;

    expect(await source.isFavourite(song), isTrue);
    await source.setFavourite(song, value: false);
    expect(server.lastQuery['/like']?['like'], 'false');
    expect(server.lastQuery['/like']?['id'], '101');
  });

  test('playback resolves a minted URL, and caches it', () async {
    final source = signedIn();
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
    final source = signedIn();
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
    final source = signedIn();
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
