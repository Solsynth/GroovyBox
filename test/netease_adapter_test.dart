import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_store.dart';
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

  /// Whether the minted URL is a paywalled track's 30-second trial, which the
  /// bridge marks with `freeTrialInfo` instead of refusing outright.
  bool trackPreviewOnly = false;

  /// One quality that answers a trial while the others answer the track, as
  /// an account without a subscription is answered for a VIP-quality master.
  String? trialLevel;

  /// Whether the trial flag arrives on a file that is the whole recording:
  /// `freeTrialInfo` describes the entitlement, not always the file.
  bool trialFlagOnFullFile = false;

  /// The scan states `/login/qr/check` walks through, one per call. The last
  /// value repeats if the list runs out.
  List<int> qrStates = [801, 802, 803];

  /// Whether the 803 answer carries the session in its body, or only on the
  /// `Set-Cookie` headers. Real builds differ.
  bool cookieInBodyOnly = true;

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

  /// An address shaped like the project's docs site: it answers every path
  /// with an HTML page, which is what makes it a wrong address rather than a
  /// broken response.
  String get docsUrl => '$baseUrl/docs';

  Future<void> close() => _server.close(force: true);

  /// Whether the request is for the docs-shaped address (any path under
  /// `/docs`), answered as a web page instead of the bridge's JSON.
  static bool _isDocs(HttpRequest request) =>
      request.uri.path.startsWith('/docs');

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    lastQuery[path] = request.uri.queryParameters;
    final response = request.response;
    // A docs site answers any path with a page; a bridge answers JSON.
    if (_isDocs(request)) {
      response.headers.contentType = ContentType.html;
      response.write('<!DOCTYPE html><title>Docs</title>');
      await response.close();
      return;
    }
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
          // Headers are immutable once the body starts, so the Set-Cookie has
          // to go on before the write.
          if (!cookieInBodyOnly) {
            response.headers.add(
              'set-cookie',
              'MUSIC_U=qr-cookie; Path=/; HttpOnly',
            );
          }
          response.write(
            jsonEncode({
              'code': 803,
              'cookie': cookieInBodyOnly ? 'MUSIC_U=qr-cookie' : '',
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
                // The listing carries id-only track ids, which is what the
                // holdings search filters the catalogue by.
                'trackIds': [
                  {'id': 101, 'v': 1},
                ],
                'coverImgUrl': 'https://p.example/cover.jpg',
                'creator': {'nickname': 'Someone'},
              },
              {
                'id': 2,
                'name': 'Collected',
                'userId': 99,
                'trackCount': 5,
                'trackIds': [
                  {'id': 17177324, 'v': 1},
                ],
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
        // One type per call, exactly as the bridge takes it: the store
        // search is built from three of these.
        final type = request.uri.queryParameters['type'] ?? '1';
        response.write(
          jsonEncode({
            'code': 200,
            'result': switch (type) {
              '10' => {
                'albums': [
                  {
                    'id': 21,
                    'name': 'Store Album',
                    'artist': {'id': 6, 'name': 'Someone Else'},
                    'picUrl': 'https://p.example/store.jpg',
                  },
                ],
              },
              '1000' => {
                'playlists': [
                  {
                    'id': 31,
                    'name': 'Store Playlist',
                    'trackCount': 12,
                    'creator': {'nickname': 'A Curator'},
                  },
                ],
              },
              _ => {
                'songs': [
                  _song(101, 'Song One'),
                  _song(17177324, 'Yellow', artist: 'Coldplay', ms: 266773),
                  // In no playlist and not hearted: the catalogue has it,
                  // this account does not.
                  _song(
                    555,
                    'Not In The Library',
                    album: 77,
                    albumName: 'Some Other Record',
                  ),
                ],
              },
            },
          }),
        );
      case '/likelist':
        response.write(
          jsonEncode({
            'code': 200,
            'ids': [101, 102],
          }),
        );
      case '/like':
      case '/album/sub':
      case '/playlist/subscribe':
      case '/playlist/tracks':
        response.write(jsonEncode({'code': 200}));
      case '/song/url/v1':
        if (_rejectUnsigned(request)) {
          response.write(jsonEncode({'code': 301}));
          await response.close();
          return;
        }
        final level = request.uri.queryParameters['level'];
        final trial =
            trackPreviewOnly ||
            (trialLevel != null && trialLevel == level) ||
            trialFlagOnFullFile;
        // What the file actually is, which is what tells a trial from the
        // track when the flag is set on both.
        final length = trial && !trialFlagOnFullFile ? 30000 : 216000;
        response.write(
          jsonEncode({
            'code': 200,
            'data': [
              {
                'id': 101,
                'url': trackPlayable
                    ? 'http://m.example/stream/101.mp3'
                    : null,
                'level': level,
                'time': length,
                if (trial) 'freeTrialInfo': {'start': 0, 'end': 30},
              },
            ],
          }),
        );
      case '/lyric':
        // One id has words, the other is a confirmable miss, so both the
        // "found" and "no such lyric" paths are exercised by the same fake.
        if (request.uri.queryParameters['id'] == '17177324') {
          response.write(
            jsonEncode({
              'code': 200,
              'lrc': {'lyric': '[00:01.00]Look at the stars'},
              'tlyric': {'lyric': '[00:01.00]看那繁星'},
            }),
          );
        } else {
          response.write(
            jsonEncode({
              'code': 200,
              'lrc': {'lyric': '[00:01.00]First line\n[00:04.50]Second line'},
              'tlyric': {'lyric': '[00:01.00]第一行\n[00:04.50]第二行'},
            }),
          );
        }
      case '/recommend/songs':
        response.write(
          jsonEncode({
            'code': 200,
            'data': {
              'dailySongs': [_song(301, 'Daily Pick')],
            },
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
  static Map<String, dynamic> _song(
    int id,
    String name, {
    String artist = 'An Artist',
    int ms = 216000,
    int album = 11,
    String albumName = 'An Album',
  }) => {
    'id': id,
    'name': name,
    'dt': ms,
    'no': 1,
    'ar': [
      {'id': 5, 'name': artist},
    ],
    'al': {
      'id': album,
      'name': albumName,
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

  test('the cookie is stored before 803 is announced', () async {
    // The screen cancels the poll the moment it sees 803 and completes the
    // login from the adapter's state. If the generator only assigned the
    // cookie after the yield, that cancel aborts it and the login fails with
    // "the server did not return a login session" — with a perfectly good
    // session sitting in the 803 body.
    server.signedInCookie = null;
    server.qrStates = [803];
    final adapter = NeteaseAdapter();
    final qr = adapter.loginSteps(server.baseUrl).single as QrLoginStep;
    await qr.prepare();

    late StreamSubscription<int> sub;
    final done = Completer<void>();
    sub = qr.poll().listen((state) {
      if (state != 803) return;
      sub.cancel();
      done.complete();
    });
    await done.future;

    final config = await adapter.completeLogin(server.baseUrl, const []);
    expect(config.auth['cookie'], 'MUSIC_U=qr-cookie');
  });

  test('a 803 whose cookie arrives only as Set-Cookie still signs in',
      () async {
    server.signedInCookie = null;
    server.qrStates = [803];
    // Some builds of the bridge put the session on the response headers
    // instead of the body field the docs describe.
    server.cookieInBodyOnly = false;
    final adapter = NeteaseAdapter();
    final qr = adapter.loginSteps(server.baseUrl).single as QrLoginStep;
    await qr.prepare();
    await qr.poll().drain<void>();

    final config = await adapter.completeLogin(server.baseUrl, const []);
    expect(config.auth['cookie'], 'MUSIC_U=qr-cookie');
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

    // The fake catalogue answers three rows for any term. "In your library"
    // keeps the two the account holds — one on a heart, one in a collected
    // playlist — and drops the third, which exists only in the service.
    final search = await source.search('Song One');
    expect(search.map((song) => song.id), ['101', '17177324']);

    // The wide question keeps all three: that is the set playback falls back
    // through, and the set Explore offers.
    final catalogue = await source.searchCatalogue('Song One');
    expect(catalogue.map((song) => song.id), ['101', '17177324', '555']);
  });

  test('the store search asks once per kind and maps every kind', () async {
    final source = signedIn();
    final found = await source.searchCatalog('Yellow');

    expect(found.songs.map((song) => song.id), ['101', '17177324', '555']);
    expect(found.albums.single.name, 'Store Album');
    expect(found.playlists.single.name, 'Store Playlist');
    expect(found.playlists.single.owner, 'A Curator');
    // The bridge takes one type per call, so three searches were made.
    expect(server.lastQuery['/cloudsearch']?['type'], '1000');
  });

  test('a store result is put in the account by the write its kind has', () async {
    final source = signedIn();

    expect(await source.addToLibrary(CatalogKind.songs, ['555']), 1);
    expect(server.lastQuery['/like']?['like'], 'true');
    expect(server.lastQuery['/like']?['id'], '555');

    expect(await source.addToLibrary(CatalogKind.albums, ['21']), 1);
    expect(server.lastQuery['/album/sub']?['t'], '1');
    expect(server.lastQuery['/album/sub']?['id'], '21');

    expect(await source.addToLibrary(CatalogKind.playlists, ['31']), 1);
    expect(server.lastQuery['/playlist/subscribe']?['t'], '1');
  });

  test('only the account’s own playlists can take a track', () async {
    final source = signedIn();

    final editable = await source.editablePlaylists();
    // The fake has one playlist the account created and one it collected;
    // NetEase refuses a write to the collected one, so it is not offered.
    expect(editable.map((playlist) => playlist.name), ['My list']);

    await source.addToPlaylist(editable.single, (await source.playlistSongs('1')).single);
    expect(server.lastQuery['/playlist/tracks']?['op'], 'add');
    expect(server.lastQuery['/playlist/tracks']?['pid'], '1');
    expect(server.lastQuery['/playlist/tracks']?['tracks'], '101');
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

  test('a paywalled track is refused as a preview, not played as one', () async {
    // The bridge mints a 30-second trial for a VIP track instead of refusing
    // it, and the only sign is `freeTrialInfo`: playing that URL as if it
    // were the track is the bug this guards.
    server.trackPreviewOnly = true;
    final source = signedIn();
    final song = (await source.playlistSongs('1')).single;

    await expectLater(
      source.resolveStreamUri(song),
      throwsA(
        isA<PreviewOnlyException>()
            .having(
              (e) => e.previewUri.toString(),
              'previewUri',
              'http://m.example/stream/101.mp3',
            )
            .having(
              (e) => e.messageKey,
              'messageKey',
              'libraryNeteasePreviewOnly',
            ),
      ),
    );
    // A refusal is not cached: the next play asks again instead of replaying
    // a trial forever after the account upgrades.
    server.trackPreviewOnly = false;
    expect(
      (await source.resolveStreamUri(song)).toString(),
      'http://m.example/stream/101.mp3',
    );
  });

  test(
    'a trial at one quality is re-minted at the next, not a paywall',
    () async {
      // The reported bug: an account without a subscription was handed a
      // trial for the VIP *quality*, though the same recording plays in full
      // at a lower one. Asking only for `exhigh` made an ordinary track look
      // paywalled.
      server.trialLevel = 'exhigh';
      final source = signedIn();
      final song = (await source.playlistSongs('1')).single;

      expect(
        (await source.resolveStreamUri(song)).toString(),
        'http://m.example/stream/101.mp3',
      );
      expect(server.lastQuery['/song/url/v1']?['level'], 'standard');
    },
  );

  test('a trial flag on the whole file is not a paywall', () async {
    // `freeTrialInfo` is what the bridge says about the account's privilege;
    // a full-length file has carried it too. The file's own length decides.
    server.trialFlagOnFullFile = true;
    final source = signedIn();
    final song = (await source.playlistSongs('1')).single;

    expect(
      (await source.resolveStreamUri(song)).toString(),
      'http://m.example/stream/101.mp3',
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

  test(
    'a path after the host is diagnosed, not reported as HTTP 404',
    () async {
      // The bridge mounts its routes at the root; a prefix like the `/api` a
      // proxy layout teaches reaches the server and answers 404.
      final adapter = NeteaseAdapter();
      final qr =
          adapter.loginSteps('${server.baseUrl}/api').single as QrLoginStep;
      await expectLater(
        qr.prepare(),
        throwsA(
          isA<LibraryException>().having(
            (e) => e.messageKey,
            'messageKey',
            'libraryNeteaseNotFound',
          ),
        ),
      );
    },
  );

  test(
    'an address that serves a web page is diagnosed as not the API',
    () async {
      // The docs site answers 200 to every path, so the HTML content type is
      // what separates it from a bridge.
      final adapter = NeteaseAdapter();
      final qr = adapter.loginSteps(server.docsUrl).single as QrLoginStep;
      await expectLater(
        qr.prepare(),
        throwsA(
          isA<LibraryException>().having(
            (e) => e.messageKey,
            'messageKey',
            'libraryNeteaseNotApi',
          ),
        ),
      );
    },
  );

  test('a query source finds words for a song the account does not hold',
      () async {
    final source = signedIn();

    final found = await source.findLyrics(
      const LyricsRequest(
        sourceId: 'local',
        id: 'file-1',
        title: 'Yellow',
        artist: 'Coldplay',
        duration: Duration(minutes: 4, seconds: 26),
      ),
    );

    expect(found.settled, isTrue);
    expect(found.result!.lyrics.synced, isTrue);
    expect(found.result!.lyrics.lines.first.text, 'Look at the stars');
    expect(found.result!.origin, LyricsOrigin.netease);
    // The catalogue was searched, and the chosen row's own id was asked for
    // it — not the id the request carried, which belongs to another library.
    expect(server.lastQuery['/cloudsearch']?['keywords'], 'Coldplay Yellow');
    expect(server.lastQuery['/lyric']?['id'], '17177324');
  });

  test('a catalogue miss the service confirmed is settled', () async {
    final source = signedIn();

    final found = await source.findLyrics(
      const LyricsRequest(
        sourceId: 'local',
        id: 'file-2',
        title: 'Nothing Like It',
        artist: 'Nobody',
        duration: Duration(minutes: 3),
      ),
    );

    // No row in the fake matches that title, so nothing is offered — and the
    // answer is a miss, not "could not ask".
    expect(found.result, isNull);
    expect(found.settled, isTrue);
  });

  test('an unreachable bridge is unsettled, so the miss is not cached',
      () async {
    final source =
        NeteaseAdapter().sourceFor(
              SourceConfig(
                id: 'netease-down',
                kind: LibraryKind.netease,
                baseUrl: 'http://127.0.0.1:1',
                displayName: 'Down',
                auth: const {'cookie': 'x'},
              ),
            )
            as NeteaseSource;
    final found = await source.findLyrics(
      const LyricsRequest(
        sourceId: 'a',
        id: 's1',
        title: 'Yellow',
        artist: 'Coldplay',
      ),
    );

    expect(found.result, isNull);
    expect(found.settled, isFalse);
  });

  test('a signed-out account does not offer the capability', () async {
    final source = NeteaseAdapter().sourceFor(
      config(''),
    ) as NeteaseSource;
    expect(source.canQueryLyrics, isFalse);
    expect((await source.findLyrics(
      const LyricsRequest(sourceId: 'a', id: 's1', title: 'Yellow'),
    )).settled, isFalse);
  });

  test("the picker's search returns rows with their words in them",
      () async {
    final source = signedIn();
    final rows = await source.searchLyrics('Yellow');

    expect(rows, isNotNull);
    final list = rows!;
    expect(list, isNotEmpty);
    expect(list.any((row) => row.origin == LyricsOrigin.netease), isTrue);
    // A row that came back without words is not offered: adopting it would
    // write an empty lyric over a working one.
    expect(list.every((row) => row.lyrics.lines.isNotEmpty), isTrue);
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
