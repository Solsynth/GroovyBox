import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/apple_adapter.dart';
import 'package:groovy_box/library/apple_kit.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/apple_player.dart';

/// A MusicKit that answers what a signed-in account would.
class _FakeMusicKit implements MusicKitClient {
  bool authorized = true;
  String token = 'dev-token';
  String userTokenValue = 'user-token';
  final queued = <List<Map<String, dynamic>>>[];
  final queuedAs = <String>[];
  final sought = <Duration>[];
  Duration clock = Duration.zero;
  bool playing = false;

  @override
  Future<bool> requestAuthorization() async => authorized;

  @override
  Future<String> developerToken() async => token;

  @override
  Future<String> userToken(String developerToken) async => userTokenValue;

  @override
  Future<void> setQueue(
    List<Map<String, dynamic>> items, {
    int startingAt = 0,
    String itemType = 'songs',
  }) async {
    queued.add(items);
    queuedAs.add(itemType);
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> seek(Duration position) async {
    sought.add(position);
    clock = position;
  }

  @override
  Future<Duration> playbackTime() async => clock;

  @override
  Stream<ApplePlayerStatus> get status => const Stream.empty();

  @override
  Stream<int> get queueIndex => const Stream.empty();

  @override
  Stream<AppleQueueEntry> get currentTrack => const Stream.empty();

  @override
  Future<void> skipNext() async {}

  @override
  Future<void> skipPrevious() async {}

  @override
  Stream<AppleQueue> get queue => const Stream.empty();
}

/// A minimal Apple Music API: the endpoints the adapter calls, with the field
/// names the service sends.
class _FakeApple {
  _FakeApple(this._server);

  final HttpServer _server;

  /// Reject every read the way an account without a subscription does.
  bool forbid = false;
  final Map<String, String> lastAuthorization = {};

  static Future<_FakeApple> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeApple(server);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    lastAuthorization[request.uri.path] =
        request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    request.response.headers.contentType = ContentType.json;

    if (forbid) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write('{"errors":[{"status":"403"}]}');
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    final body = switch (path) {
      '/v1/me/library/artists' => _artists(),
      '/v1/me/library/recently-added' => _recentlyAdded(),
      '/v1/me/library/albums' => _albums(),
      final p
          when p.startsWith('/v1/me/library/albums/') &&
              p.endsWith('/tracks') =>
        _albumTracks(),
      '/v1/me/library/songs' => _songs(),
      '/v1/me/library/search' => _search(),
      '/v1/me/library/playlists' => _playlists(),
      '/v1/me/recommendations' => _recommendations(),
      '/v1/me/recommendations/mix-1/contents' => _mixContents(),
      '/v1/me/history/heavy-rotation' => _heavyRotation(),
      _ => null,
    };
    if (body == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('{"errors":[{"status":"404"}]}');
    } else {
      request.response.write(jsonEncode(body));
    }
    await request.response.close();
  }

  Map<String, dynamic> _artists() => {
    'data': [
      {
        'id': 'r.1',
        'type': 'library-artists',
        'attributes': {'name': 'Orville Peck'},
      },
    ],
    'meta': {'total': 1},
  };

  Map<String, dynamic> _recentlyAdded() => {
    'data': [
      _albumResource('l.1', 'Bronco', added: '2022-08-06T02:18:57Z'),
      // Recently-added mixes playlists in; the adapter must drop them.
      {
        'id': 'p.1',
        'type': 'library-playlists',
        'attributes': {
          'name': 'A-team',
          'playParams': {'id': 'p.1', 'kind': 'playlist', 'isLibrary': true},
        },
      },
    ],
  };

  Map<String, dynamic> _albums() => {
    'data': [_albumResource('l.1', 'Bronco')],
    'meta': {'total': 1},
  };

  Map<String, dynamic> _albumTracks() => {
    'data': [
      _songResource('i.1', 'Daytona Sand'),
      _songResource('i.2', 'The Curse of the Blackened Eye'),
    ],
  };

  Map<String, dynamic> _songs() => {
    'data': [_songResource('i.1', 'Daytona Sand')],
    // Apple pages every collection and reports its size: the digest reads
    // that instead of paging the library to count it.
    'meta': {'total': 842},
  };

  /// One container whose contents are stations, and one whose title is a
  /// `{stringForDisplay}` map — both shapes this account actually gets.
  Map<String, dynamic> _recommendations() => {
    'data': [
      {
        'id': 'mix-1',
        'type': 'personal-recommendation',
        'attributes': {
          'title': {'stringForDisplay': 'Stations for you'},
          'resourceTypes': ['stations'],
        },
        'relationships': {
          'contents': {'href': '/v1/me/recommendations/mix-1/contents'},
        },
      },
      {
        'id': 'mix-2',
        'type': 'personal-recommendation',
        'attributes': {
          'title': 'Recent',
          'resourceTypes': ['albums'],
        },
        'relationships': {
          'contents': {'href': '/v1/me/recommendations/mix-2/contents'},
        },
      },
    ],
    'meta': {'total': 2},
  };

  Map<String, dynamic> _mixContents() => {
    'data': [
      {
        'id': 'ra.1',
        'type': 'stations',
        'attributes': {
          'name': 'Mirror Mirror Radio',
          'isLive': false,
          'mediaKind': 'audio',
          'url': 'https://music.apple.com/cn/station/x/ra.1',
          'playParams': {
            'format': 'tracks',
            'id': 'ra.1',
            'kind': 'radioStation',
          },
        },
      },
    ],
  };

  Map<String, dynamic> _heavyRotation() => {
    'data': [
      {
        'id': 'l.album-1',
        'type': 'library-albums',
        'attributes': {'name': 'An album'},
      },
      {
        'id': 'ra.2',
        'type': 'stations',
        'attributes': {
          'name': 'A station',
          'url': 'https://music.apple.com/cn/station/y/ra.2',
          'playParams': {'id': 'ra.2', 'kind': 'radioStation'},
        },
      },
    ],
  };

  Map<String, dynamic> _search() => {
    'results': {
      'library-songs': {
        'data': [_songResource('i.1', 'Daytona Sand')],
      },
    },
  };

  Map<String, dynamic> _playlists() => {
    'data': [
      {
        'id': 'p.1',
        'type': 'library-playlists',
        'attributes': {
          'name': 'A-team',
          'playParams': {'id': 'p.1', 'kind': 'playlist', 'isLibrary': true},
        },
      },
    ],
  };

  static Map<String, dynamic> _albumResource(
    String id,
    String name, {
    String? added,
  }) => {
    'id': id,
    'type': 'library-albums',
    'attributes': {
      'name': name,
      'artistName': 'Orville Peck',
      'trackCount': 2,
      'releaseDate': '2022-02-11',
      'genreNames': ['Country', 'Music'],
      'artwork': {
        'width': 1200,
        'height': 1200,
        'url': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/x.jpg/{w}x{h}bb.jpg',
      },
      'playParams': {'id': id, 'kind': 'album', 'isLibrary': true},
      'dateAdded': ?added,
    },
  };

  static Map<String, dynamic> _songResource(String id, String name) => {
    'id': id,
    'type': 'library-songs',
    'attributes': {
      'name': name,
      'artistName': 'Orville Peck',
      'albumName': 'Bronco',
      'discNumber': 1,
      'trackNumber': id == 'i.1' ? 1 : 2,
      'durationInMillis': 195160,
      'releaseDate': '2022-02-11',
      'genreNames': ['Country', 'Music'],
      'artwork': {
        'width': 1200,
        'height': 1200,
        'url': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/x.jpg/{w}x{h}bb.jpg',
      },
      'playParams': {
        'id': id,
        'kind': 'song',
        'isLibrary': true,
        'catalogId': '1607593874',
      },
    },
  };
}

void main() {
  late _FakeApple server;
  late _FakeMusicKit kit;

  setUp(() async {
    server = await _FakeApple.start();
    kit = _FakeMusicKit();
  });
  tearDown(() async => server.close());

  SourceConfig connected() => SourceConfig(
    id: 'apple-1',
    kind: LibraryKind.appleMusic,
    baseUrl: server.baseUrl,
    displayName: 'Apple Music',
    auth: {'developerToken': 'dev-token', 'userToken': 'user-token'},
  );

  test('connect stores both tokens and proves the account reads', () async {
    final config = await AppleMusicAdapter(
      musicKit: kit,
      apiRoot: server.baseUrl,
    ).connect(baseUrl: '', username: '', password: '');

    expect(config.kind, LibraryKind.appleMusic);
    expect(config.auth['developerToken'], 'dev-token');
    expect(config.auth['userToken'], 'user-token');
    expect(config.displayName, 'Apple Music');
    expect(config.id, startsWith('appleMusic-'));
    // The one read connect performs went out with the developer token.
    expect(
      server.lastAuthorization['/v1/me/library/artists'],
      'Bearer dev-token',
    );
  });

  test('refuses to connect when authorization is denied', () async {
    kit.authorized = false;

    await expectLater(
      AppleMusicAdapter(musicKit: kit)
          .connect(baseUrl: '', username: '', password: ''),
      throwsA(
        isA<LibraryException>().having(
          (e) => e.messageKey,
          'messageKey',
          'libraryAppleMusicDenied',
        ),
      ),
    );
  });

  test('maps library songs, albums and their art', () async {
    final source = AppleMusicSource(connected());

    final songs = await source.albumSongs('l.1');
    expect(songs, hasLength(2));
    expect(songs.first.title, 'Daytona Sand');
    expect(songs.first.artist, 'Orville Peck');
    expect(songs.first.album, 'Bronco');
    expect(songs.first.duration, const Duration(milliseconds: 195160));
    expect(songs.first.track, 1);
    expect(songs.first.year, 2022);
    // Apple's genre list ends with "Music", which is not a genre.
    expect(songs.first.genre, 'Country');

    final albums = await source.albums();
    expect(albums.single.name, 'Bronco');
    expect(albums.single.songCount, 2);

    // Recently added drops the playlists mixed into the same list.
    final recent = await source.recentlyAdded();
    expect(recent.single.id, 'l.1');
  });

  test('resizes a cover by substituting its size template', () async {
    final source = AppleMusicSource(connected());
    final uri = source.artworkUri(
      'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/x.jpg/{w}x{h}bb.jpg',
      size: 480,
    );

    expect(uri.toString(), contains('/480x480bb.jpg'));
    expect(uri.toString(), isNot(contains('{w}')));
    expect(
      // A station's track reports this handle; it parses, but only the
      // system player can load it, so no fetchable cover may come of it.
      source.artworkUri('musickit://artwork/transient/600x600?id=abc'),
      isNull,
    );
  });

  test('search reads the library search endpoint', () async {
    final source = AppleMusicSource(connected());
    final songs = await source.search('Daytona');

    expect(songs.single.id, 'i.1');
    expect(
      server.lastAuthorization['/v1/me/library/search'],
      'Bearer dev-token',
    );
  });

  test('a forbidden account reports the subscription, not a crash', () async {
    server.forbid = true;
    final source = AppleMusicSource(connected());

    await expectLater(
      source.albums(),
      throwsA(
        isA<LibraryException>()
            .having((e) => e.code, 'code', 403)
            .having(
              (e) => e.messageKey,
              'messageKey',
              'libraryAppleMusicSubscription',
            ),
      ),
    );
  });

  test(
    'queue items carry the resource shape the system player decodes',
    () async {
      final song = LibrarySong(
        sourceId: 'apple-1',
        id: 'i.1',
        title: 'Daytona Sand',
        artist: 'Orville Peck',
        album: 'Bronco',
        duration: const Duration(milliseconds: 195160),
      );

      final item = AppleMusicSource(connected()).platformResource(song);
      expect(item['id'], 'i.1');
      expect(item['type'], 'songs');
      final attributes = item['attributes'] as Map<String, dynamic>;
      expect(attributes['name'], 'Daytona Sand');
      expect(attributes['durationInMillis'], 195160);
      expect((attributes['playParams'] as Map)['isLibrary'], isTrue);
    },
  );

  test('the player bridge hands the run to the system player', () async {
    final songs = [
      for (var i = 0; i < 3; i++)
        LibrarySong(
          sourceId: 'apple-1',
          id: 'i.$i',
          title: 'Daytona Sand $i',
          duration: const Duration(minutes: 3),
        ),
    ];
    var positions = <Duration>[];
    final bridge = ApplePlayer(
      kit,
      onStatus: (_) {},
      onPosition: positions.add,
      onAdvance: (_) {},
      onTrack: (_) {},
      sourceFor: (_) => AppleMusicSource(connected()),
    );

    // Everything from the current track on, so the system has somewhere to
    // advance to instead of stopping at the end of a one-item queue.
    await bridge.open(songs, 1);
    expect(kit.queued.single.map((item) => item['id']), ['i.1', 'i.2']);

    await bridge.seek(const Duration(seconds: 42));
    expect(kit.sought.single, const Duration(seconds: 42));
    expect(positions.last, const Duration(seconds: 42));
    bridge.dispose();
  });

  test('a seek keeps a running track playing', () async {
    final song = LibrarySong(
      sourceId: 'apple-1',
      id: 'i.1',
      title: 'Daytona Sand',
      duration: const Duration(minutes: 3),
    );
    final bridge = ApplePlayer(
      kit,
      onStatus: (_) {},
      onPosition: (_) {},
      onAdvance: (_) {},
      onTrack: (_) {},
      sourceFor: (_) => AppleMusicSource(connected()),
    );
    await bridge.open([song], 0);
    expect(kit.playing, isTrue);

    // Seeking pauses the system player; a drag of the scrubber must not stop
    // the music.
    await bridge.seek(const Duration(seconds: 30));
    expect(kit.playing, isTrue);
    bridge.dispose();
  });

  test(
    'recommendations become shelves, and stations survive a round trip',
    () async {
      final source = AppleMusicSource(connected());
      final shelves = await source.landingShelves();

      // Only the container whose contents are stations yields a shelf; the
      // album one points at an endpoint this fake does not serve.
      expect(shelves, hasLength(1));
      final shelf = shelves.single;
      expect(shelf.title, 'Stations for you');
      expect(shelf.songs.single.isRadio, isTrue);

      // A station is written to the saved session and read back, so everything
      // the platform player needs has to survive JSON.
      final restored = LibrarySong.fromJson(shelf.songs.single.toJson());
      expect(restored.isRadio, isTrue);
      expect(restored.radioUrl, 'https://music.apple.com/cn/station/x/ra.1');
      final resource = source.platformResource(restored);
      expect(resource?['type'], 'stations');
      expect(
        (resource?['attributes'] as Map)['playParams'],
        containsPair('kind', 'radioStation'),
      );
    },
  );

  test('the digest reports the library size', () async {
    final digest = await AppleMusicSource(connected()).digest();

    expect(digest?.libraryTracks, 842);
    expect(digest?.subtitle, 'Apple Music');
  });

  test('a station is queued as a station, alone', () async {
    final station = LibrarySong(
      sourceId: 'apple-1',
      id: 'ra.1',
      title: 'Mirror Mirror Radio',
      duration: Duration.zero,
      isRadio: true,
      radioUrl: 'https://music.apple.com/cn/station/x/ra.1',
      radioPlayParams: const {'kind': 'radioStation', 'id': 'ra.1'},
    );
    final bridge = ApplePlayer(
      kit,
      onStatus: (_) {},
      onPosition: (_) {},
      onAdvance: (_) {},
      onTrack: (_) {},
      sourceFor: (_) => AppleMusicSource(connected()),
    );
    await bridge.open([station], 0);
    expect(kit.queuedAs.single, 'stations');
    expect(kit.queued.single.single['id'], 'ra.1');
    bridge.dispose();
  });
}
