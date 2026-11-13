import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library_sync/client.dart';
import 'package:groovy_box/library_sync/engine.dart';
import 'package:groovy_box/library_sync/store.dart';
import 'package:groovy_box/solarpass/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory Library Sync server: the last-write-wins rules the Go service
/// applies, kept just faithful enough to test the client's merge.
class _FakeServer {
  final Map<String, Map<String, dynamic>> tracks = {};
  final Map<String, Map<String, dynamic>> links = {};
  final Map<String, Map<String, dynamic>> lyrics = {};
  final Map<String, Map<String, dynamic>> plays = {};

  /// Every change list the client actually sent.
  final List<List<Map<String, dynamic>>> pushes = [];

  int rev = 0;

  /// Every link the server was ever sent, so a local link can be asserted absent.
  final List<Map<String, dynamic>> seenLinks = [];

  void push(List<Map<String, dynamic>> changes) {
    if (changes.isEmpty) return;
    pushes.add(changes);
    for (final change in changes) {
      rev++;
      final entity = change['entity'] as String?;
      final delete = change['kind'] == 'delete';
      final clock = delete
          ? DateTime.tryParse(change['deleted_at'] as String? ?? '')
          : null;
      switch (entity) {
        case 'track':
          final record = (change['track'] as Map).cast<String, dynamic>();
          if (delete) {
            tracks[record['fingerprint'] as String] = {
              'fingerprint': record['fingerprint'],
              'deleted_at': change['deleted_at'],
            };
            break;
          }
          tracks[record['fingerprint'] as String] = record;
        case 'link':
          final record = (change['link'] as Map).cast<String, dynamic>();
          seenLinks.add(record);
          final key = '${record['source_id']}\u0000${record['external_id']}';
          links[key] = record;
        case 'lyrics':
          final record = (change['lyrics'] as Map).cast<String, dynamic>();
          final key = record['track_fingerprint'] as String;
          lyrics[key] = delete
              ? {
                  'track_fingerprint': key,
                  'lines': '',
                  'synced': false,
                  'origin': 'none',
                  'fetched_at': change['deleted_at'],
                  'deleted_at': change['deleted_at'],
                }
              : record;
        case 'play':
          final record = (change['play'] as Map).cast<String, dynamic>();
          final key =
              '${record['track_fingerprint']}\u0000${record['started_at']}';
          final existing = plays[key];
          plays[key] = existing == null
              ? record
              : {
                  ...existing,
                  'listened_ms': _maxInt(
                    existing['listened_ms'] as int,
                    record['listened_ms'] as int,
                  ),
                  'position_ms': _maxInt(
                    existing['position_ms'] as int,
                    record['position_ms'] as int,
                  ),
                  'completed':
                      (existing['completed'] as bool) ||
                      (record['completed'] as bool),
                };
        case _:
          break;
      }
      // A tombstone clock that moved (a delete recorded after a live row) is
      // what a real server keeps; nothing else here needs revisioning.
      if (clock != null) continue;
    }
  }

  Map<String, dynamic> pull(int since) {
    final removed = <String, List<String>>{};
    final liveTracks = <Map<String, dynamic>>[];
    for (final record in tracks.values) {
      final deletedAt = record['deleted_at'] as String?;
      if (deletedAt != null) {
        removed
            .putIfAbsent('track', () => [])
            .add(
              jsonEncode({
                'fingerprint': record['fingerprint'],
                'deleted_at': deletedAt,
              }),
            );
        continue;
      }
      liveTracks.add(record);
    }
    final liveLyrics = <Map<String, dynamic>>[];
    for (final record in lyrics.values) {
      final deletedAt = record['deleted_at'] as String?;
      if (deletedAt != null) {
        removed
            .putIfAbsent('lyrics', () => [])
            .add(
              jsonEncode({
                'track_fingerprint': record['track_fingerprint'],
                'deleted_at': deletedAt,
              }),
            );
        continue;
      }
      liveLyrics.add(record);
    }
    return {
      'rev': rev,
      'has_more': false,
      'tracks': liveTracks,
      'links': [
        for (final record in links.values)
          if (record['deleted_at'] == null) record,
      ],
      'lyrics': liveLyrics,
      'plays': [for (final record in plays.values) record],
      'session': null,
      'settings': const <String, dynamic>{},
      'session_clock': null,
      'settings_clock': null,
      'removed': removed,
    };
  }

  /// One track is deleted by another device.
  void deleteTrack(String fingerprint, DateTime at) {
    rev++;
    tracks[fingerprint] = {
      'fingerprint': fingerprint,
      'deleted_at': at.toUtc().toIso8601String(),
    };
  }

  static int _maxInt(int a, int b) => a > b ? a : b;
}

class _ServerAdapter implements HttpClientAdapter {
  _ServerAdapter(this.server);

  final _FakeServer server;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/push')) {
      final body = (options.data as Map).cast<String, dynamic>();
      server.push((body['changes'] as List).cast<Map<String, dynamic>>());
      return _json({'rev': server.rev, 'rejected': const <int>[]});
    }
    if (path.endsWith('/pull')) {
      final since =
          int.tryParse('${options.uri.queryParameters['since']}') ?? 0;
      return _json(server.pull(since));
    }
    return _json({
      'rev': server.rev,
      'tracks': 0,
      'plays': 0,
      'device_count': 0,
      'last_device': '',
    });
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// One device: an in-memory database plus its own sync state.
class _Device {
  _Device._(this.deviceId, this.server, this.prefs) {
    db = LibraryDatabase(NativeDatabase.memory());
  }

  static Future<_Device> open(
    String deviceId,
    _FakeServer server,
    SharedPreferences prefs,
  ) async => _Device._(deviceId, server, prefs);

  final String deviceId;
  final _FakeServer server;
  final SharedPreferences prefs;
  late final LibraryDatabase db;

  LibraryCatalog get catalog => LibraryCatalog(db);
  LyricsStore get lyrics => LyricsStore(db);

  LibrarySyncStateStore get state =>
      LibrarySyncStateStore(prefs, deviceId: deviceId);

  LibrarySyncClient get client => LibrarySyncClient(
    dio: Dio()..httpClientAdapter = _ServerAdapter(server),
    baseUrl: 'http://sync.test',
  );

  LibrarySyncEngine engine() => LibrarySyncEngine(
    db: db,
    client: client,
    state: state,
    connectedSourceIds: () => const ['subsonic-1'],
    readSettings: () => const {'themeMode': 'system'},
    applySettings: (_) async {},
    invalidate: () {},
  );

  Future<SyncRunResult> run() => engine().run(session: const _Session());
}

/// A session that is never refreshed: the fake server never answers 401.
class _Session extends OAuthSession {
  const _Session() : super(accessToken: 'test-token');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late SharedPreferences prefs;
  late _Device deviceA;
  late _Device deviceB;

  setUp(() async {
    server = _FakeServer();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    deviceA = await _Device.open('dev-a', server, prefs);
    deviceB = await _Device.open('dev-b', server, prefs);
    addTearDown(() async {
      await deviceA.db.close();
      await deviceB.db.close();
    });
  });

  test('device B adopts the track, lyrics and play device A pushed', () async {
    final trackId = await deviceA.catalog.adopt(
      const LibrarySong(
        sourceId: 'subsonic-1',
        id: 'song-1',
        title: 'Yellow',
        artist: 'Coldplay',
        album: 'Parachutes',
        duration: Duration(seconds: 266),
      ),
    );
    await deviceA.lyrics.write(
      trackId,
      const Lyrics(
        lines: [LyricLine(Duration(seconds: 5), 'Look at the stars')],
        synced: true,
      ),
      origin: LyricsOrigin.library,
    );
    await deviceA.catalog.recordPlay(
      trackId: trackId,
      sourceId: 'subsonic-1',
      startedAt: DateTime.utc(2026, 1, 1, 10, 0, 0),
      listened: const Duration(seconds: 120),
      position: const Duration(seconds: 120),
      completed: true,
    );

    final resultA = await deviceA.run();
    expect(resultA.error, isNull, reason: resultA.error);

    final resultB = await deviceB.run();
    expect(resultB.error, isNull, reason: resultB.error);

    final tracks = await deviceB.db.select(deviceB.db.tracks).get();
    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Yellow');
    expect(tracks.single.artist, 'Coldplay');

    final stored = await deviceB.lyrics.read(tracks.single.id);
    expect(stored, isNotNull);
    expect(stored!.lyrics.lines.first.text, 'Look at the stars');

    final plays = await deviceB.db.select(deviceB.db.playEvents).get();
    expect(plays, hasLength(1));
    expect(plays.single.startedAt.toUtc(), DateTime.utc(2026, 1, 1, 10, 0, 0));
    expect(plays.single.completed, isTrue);
  });

  test('a second sync with nothing new writes nothing', () async {
    await deviceA.catalog.adopt(
      const LibrarySong(
        sourceId: 'subsonic-1',
        id: 'song-1',
        title: 'Yellow',
        artist: 'Coldplay',
        duration: Duration(seconds: 266),
      ),
    );
    await deviceA.run();
    await deviceB.run();

    final before = (await deviceB.db.select(deviceB.db.tracks).get()).single;
    final pushCount = server.pushes.length;

    await deviceB.run();
    await deviceB.run();

    final after = (await deviceB.db.select(deviceB.db.tracks).get()).single;
    expect(after.updatedAt, before.updatedAt);
    expect(server.pushes.length, pushCount);
  });

  test('a local-file link never reaches the server', () async {
    final trackId = await deviceA.catalog.adopt(
      const LibrarySong(
        sourceId: 'subsonic-1',
        id: 'song-1',
        title: 'Yellow',
        artist: 'Coldplay',
        duration: Duration(seconds: 266),
      ),
    );
    // A local link is written straight into the table: `kLocalSourceId` is
    // what a file imported into this device's storage is linked under.
    await deviceA.db
        .into(deviceA.db.trackLinks)
        .insert(
          TrackLinksCompanion.insert(
            trackId: trackId,
            sourceId: kLocalSourceId,
            externalId: '/Users/me/Music/yellow.mp3',
            linkedAt: DateTime.now(),
            lastSeenAt: DateTime.now(),
          ),
        );

    await deviceA.run();
    await deviceB.run();

    expect(
      server.seenLinks.where((link) => link['source_id'] == kLocalSourceId),
      isEmpty,
    );
    final links = await deviceB.db.select(deviceB.db.trackLinks).get();
    expect(links.where((link) => link.sourceId == kLocalSourceId), isEmpty);
  });

  test('a removed track is deleted locally and cascades', () async {
    final trackId = await deviceB.catalog.adopt(
      const LibrarySong(
        sourceId: 'subsonic-1',
        id: 'song-1',
        title: 'Yellow',
        artist: 'Coldplay',
        duration: Duration(seconds: 266),
      ),
    );
    await deviceB.lyrics.write(
      trackId,
      const Lyrics(
        lines: [LyricLine(Duration.zero, 'Look at the stars')],
        synced: true,
      ),
      origin: LyricsOrigin.library,
    );
    await deviceB.catalog.recordPlay(
      trackId: trackId,
      sourceId: 'subsonic-1',
      startedAt: DateTime.utc(2026, 1, 1, 10, 0, 0),
    );
    await deviceB.run();

    final fingerprint =
        (await deviceB.db.select(deviceB.db.tracks).get()).single.fingerprint;
    server.deleteTrack(fingerprint, DateTime.utc(2030, 1, 1));

    await deviceB.run();

    expect(await deviceB.db.select(deviceB.db.tracks).get(), isEmpty);
    expect(await deviceB.db.select(deviceB.db.lyricsEntries).get(), isEmpty);
    expect(await deviceB.db.select(deviceB.db.playEvents).get(), isEmpty);
  });
}
