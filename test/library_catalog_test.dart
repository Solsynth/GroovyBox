import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/track_identity.dart';
import 'package:groovy_box/player/player.dart';

({LibraryDatabase db, LibraryCatalog catalog}) _open() {
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return (db: db, catalog: LibraryCatalog(db));
}

LibrarySong _song({
  required String sourceId,
  required String id,
  String title = 'Yellow',
  String? artist = 'Coldplay',
  String? album,
  String? albumId,
  String? artId,
  Duration duration = const Duration(seconds: 266),
  String? mbid,
}) => LibrarySong(
  sourceId: sourceId,
  id: id,
  title: title,
  artist: artist,
  album: album,
  albumId: albumId,
  artId: artId,
  duration: duration,
  mbid: mbid,
);

void main() {
  test('adopting the same song twice keeps one track and one link', () async {
    final (:db, :catalog) = _open();

    final first = await catalog.adopt(_song(sourceId: 'a', id: 's1'));
    final second = await catalog.adopt(_song(sourceId: 'a', id: 's1'));

    expect(second, first);
    expect(await db.trackCount(), 1);
    expect(await db.linksOf(first), hasLength(1));
  });

  test('re-adopting refreshes metadata without changing identity', () async {
    final (:db, :catalog) = _open();
    final trackId = await catalog.adopt(_song(sourceId: 'a', id: 's1'));

    await catalog.adopt(
      _song(
        sourceId: 'a',
        id: 's1',
        album: 'Parachutes',
        albumId: 'al1',
        artId: 'art1',
      ),
    );

    final track = await (db.select(
      db.tracks,
    )..where((row) => row.id.equals(trackId))).getSingle();
    expect(track.album, 'Parachutes');
    final link = (await db.linksOf(trackId)).single;
    expect(link.albumExternalId, 'al1');
    expect(link.artId, 'art1');
  });

  test('a second source joins the same track and keeps its own id', () async {
    final (:db, :catalog) = _open();

    final onJellyfin = await catalog.adopt(_song(sourceId: 'jellyfin', id: 'm1'));
    final onSubsonic = await catalog.adopt(_song(sourceId: 'subsonic', id: 's9'));

    expect(onSubsonic, onJellyfin, reason: 'same song, two servers');
    expect(await db.trackCount(), 1);
    final links = await db.linksOf(onJellyfin);
    expect(links.map((link) => link.sourceId).toSet(), {
      'jellyfin',
      'subsonic',
    });
    expect(
      await db.trackIdForLink('subsonic', 's9'),
      onJellyfin,
      reason: 'each source keeps its own native id',
    );
  });

  test('different songs stay different tracks', () async {
    final (:db, :catalog) = _open();

    await catalog.adopt(_song(sourceId: 'a', id: 's1'));
    await catalog.adopt(_song(sourceId: 'a', id: 's2', title: 'Fix You'));

    expect(await db.trackCount(), 2);
  });

  test('a lyrics request adopts only what it knows', () async {
    final (:db, :catalog) = _open();

    final trackId = await catalog.requestTrackId(
      const LyricsRequest(
        sourceId: 'a',
        id: 's1',
        title: 'Yellow',
        artist: 'Coldplay',
      ),
    );
    expect(trackId, isPositive);

    // A later full read of the same song does not create a second track; it
    // fills in the album the request never carried.
    final same = await catalog.adopt(
      _song(sourceId: 'a', id: 's1', album: 'Parachutes'),
    );
    expect(same, trackId);
    final track = await (db.select(
      db.tracks,
    )..where((row) => row.id.equals(trackId))).getSingle();
    expect(track.album, 'Parachutes');
  });

  test('a thumbnail from a listing does not blank a full-sized cover', () async {
    final (:db, :catalog) = _open();
    await catalog.adopt(
      _song(sourceId: 'a', id: 's1', album: 'Parachutes', artId: 'full'),
    );

    await catalog.adopt(_song(sourceId: 'a', id: 's1'));

    final trackId = (await db.trackIdForLink('a', 's1'))!;
    final link = (await db.linksOf(trackId)).single;
    expect(link.artId, 'full', reason: 'absent metadata is not a value');
  });

  test('plays accumulate and the newest first ordering holds', () async {
    final (:db, :catalog) = _open();
    final first = await catalog.adopt(_song(sourceId: 'a', id: 's1'));
    final second = await catalog.adopt(
      _song(sourceId: 'a', id: 's2', title: 'Fix You'),
    );

    final morning = DateTime(2026, 1, 1, 8);
    await catalog.recordPlay(
      trackId: first,
      sourceId: 'a',
      startedAt: morning,
    );
    final later = await catalog.recordPlay(
      trackId: second,
      sourceId: 'a',
      startedAt: morning.add(const Duration(hours: 2)),
    );

    await catalog.updatePlay(
      later,
      listened: const Duration(seconds: 254),
      position: const Duration(seconds: 254),
      completed: true,
    );

    expect((await catalog.statsOf(first)).count, 1);
    final recent = await catalog.recentlyPlayed();
    expect(recent.map((entry) => entry.track.title), ['Fix You', 'Yellow']);
    expect(recent.first.link?.sourceId, 'a');
    expect(recent.first.playedAt, morning.add(const Duration(hours: 2)));
  });

  test('a play is updated in place rather than duplicated', () async {
    final (:db, :catalog) = _open();
    final trackId = await catalog.adopt(_song(sourceId: 'a', id: 's1'));
    final playId = await catalog.recordPlay(
      trackId: trackId,
      sourceId: 'a',
      startedAt: DateTime(2026, 1, 1),
    );

    await catalog.updatePlay(
      playId,
      listened: const Duration(seconds: 30),
      position: const Duration(seconds: 30),
      completed: false,
    );
    await catalog.updatePlay(
      playId,
      listened: const Duration(seconds: 266),
      position: const Duration(seconds: 266),
      completed: true,
    );

    final stats = await catalog.statsOf(trackId);
    expect(stats.count, 1);
    expect(stats.lastPlayedAt, DateTime(2026, 1, 1));
    final row = await db.select(db.playEvents).getSingle();
    expect(row.listenedMs, 266000);
    expect(row.completed, isTrue);
  });

  test('removing a source unlinks its songs and leaves the rest', () async {
    final (:db, :catalog) = _open();
    final shared = await catalog.adopt(_song(sourceId: 'a', id: 's1'));
    await catalog.adopt(_song(sourceId: 'b', id: 'other'));
    // The same song on a second server: unlinking one must not orphan it.
    await catalog.adopt(
      _song(sourceId: 'other', id: 'x1'),
    );

    await catalog.forgetSource('a');

    expect(await db.trackIdForLink('a', 's1'), isNull);
    expect(await db.trackIdForLink('b', 'other'), isNotNull);
    expect(
      await catalog.orphanCount(),
      0,
      reason: 'the track is still reachable through another link',
    );
    expect(shared, isPositive);
  });

  test('deleting a track takes its links, words and plays with it', () async {
    final (:db, :catalog) = _open();
    final trackId = await catalog.adopt(_song(sourceId: 'a', id: 's1'));
    await catalog.recordPlay(
      trackId: trackId,
      sourceId: 'a',
      startedAt: DateTime(2026, 1, 1),
    );

    await (db.delete(db.tracks)..where((row) => row.id.equals(trackId))).go();

    expect(await db.linksOf(trackId), isEmpty);
    expect(await db.select(db.playEvents).get(), isEmpty);
  });

  test('fingerprints ignore credits, case and a second of rounding', () {
    String key(String title, {String? artist, int seconds = 266}) =>
        trackFingerprint(
          title: title,
          artist: artist,
          duration: Duration(seconds: seconds),
        );

    expect(key('Yellow'), key('YELLOW'));
    expect(key('Yellow (Live)'), key('Yellow'));
    expect(key('Yellow - Live'), key('Yellow'));
    expect(key('Yellow - 2021 Remaster'), key('Yellow'));
    expect(key('Yellow - Remastered'), key('Yellow'));
    expect(key('Yellow', seconds: 267), key('Yellow'));
    expect(key('Yellow', artist: 'Coldplay'), isNot(key('Yellow')));
    expect(key('Yellow', seconds: 200), isNot(key('Yellow')));
    expect(
      key('Princess of China ft. Rihanna', artist: 'Coldplay'),
      key('Princess of China', artist: 'Coldplay ft. Rihanna'),
    );
    expect(
      key('Halo', artist: 'Beyoncé'),
      key('Halo', artist: 'Beyonce'),
    );
  });

  test('adopting tracks across duration bucket boundary matches canonical track', () async {
    final (:db, :catalog) = _open();

    // 199s is bucket 39 (199 ~/ 5), 201s is bucket 40 (201 ~/ 5)
    final first = await catalog.adopt(
      _song(sourceId: 'src1', id: 't1', duration: const Duration(seconds: 199)),
    );
    final second = await catalog.adopt(
      _song(sourceId: 'src2', id: 't2', duration: const Duration(seconds: 201)),
    );

    expect(second, first, reason: '2-second difference across bucket boundary should match');
    expect(await db.trackCount(), 1);
    expect(await db.linksOf(first), hasLength(2));
  });

  test('playback state recognizes the same track from a different source as current', () {
    final jellyfinSong = _song(
      sourceId: 'jellyfin',
      id: 'j1',
      title: 'Yellow - Remastered',
      artist: 'Coldplay',
      duration: const Duration(seconds: 266),
    );
    final subsonicSong = _song(
      sourceId: 'subsonic',
      id: 's2',
      title: 'Yellow',
      artist: 'Coldplay',
      duration: const Duration(seconds: 267),
    );

    final state = PlaybackState(
      queue: [jellyfinSong],
      currentIndex: 0,
      playing: true,
    );

    expect(state.isCurrentSong(jellyfinSong), isTrue, reason: 'exact source match');
    expect(state.isCurrentSong(subsonicSong), isTrue, reason: 'canonical match across sources');

    final differentSong = _song(
      sourceId: 'subsonic',
      id: 's3',
      title: 'Fix You',
      artist: 'Coldplay',
      duration: const Duration(seconds: 295),
    );
    expect(state.isCurrentSong(differentSong), isFalse);
  });

  test('sources with different titles but same MusicBrainz ID match canonical track', () async {
    final (:db, :catalog) = _open();

    const mbid = 'b10bbbfc-cf9e-42e0-be17-e2c3e1d52365';
    final sourceA = await catalog.adopt(
      _song(
        sourceId: 'jellyfin',
        id: 'jf-1',
        title: 'Song One',
        artist: 'Band A',
        mbid: mbid,
      ),
    );

    final sourceB = await catalog.adopt(
      _song(
        sourceId: 'subsonic',
        id: 'sub-2',
        title: 'Completely Different Title',
        artist: 'Different Artist Tag',
        mbid: mbid,
      ),
    );

    expect(sourceB, sourceA, reason: 'MusicBrainz ID guarantees deterministic match');
    expect(await db.trackCount(), 1);
    expect(await db.linksOf(sourceA), hasLength(2));
  });

  test('LibrarySong toJson and fromJson preserve all metadata', () {
    final song = _song(
      sourceId: 'src-1',
      id: 'item-99',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      albumId: 'alb-1',
      artId: 'cover-1',
      duration: const Duration(seconds: 354),
      mbid: 'mbid-123',
    );

    final json = song.toJson();
    final restored = LibrarySong.fromJson(json);

    expect(restored.sourceId, song.sourceId);
    expect(restored.id, song.id);
    expect(restored.title, song.title);
    expect(restored.artist, song.artist);
    expect(restored.album, song.album);
    expect(restored.albumId, song.albumId);
    expect(restored.artId, song.artId);
    expect(restored.duration, song.duration);
    expect(restored.mbid, song.mbid);
  });

  test('playback session saves and restores from database', () async {
    final (:db, :catalog) = _open();

    expect(await catalog.loadPlaybackSession(), isNull);

    final songs = [
      _song(sourceId: 's1', id: 't1', title: 'Song 1'),
      _song(sourceId: 's1', id: 't2', title: 'Song 2', duration: const Duration(seconds: 200)),
    ];

    await catalog.savePlaybackSession(
      queueJson: jsonEncode([for (final s in songs) s.toJson()]),
      currentIndex: 1,
      positionMs: 45000,
      durationMs: 200000,
      shuffle: true,
      repeatMode: 'all',
    );

    final session = await catalog.loadPlaybackSession();
    expect(session, isNotNull);
    expect(session!.currentIndex, 1);
    expect(session.positionMs, 45000);
    expect(session.durationMs, 200000);
    expect(session.shuffle, isTrue);
    expect(session.repeatMode, 'all');

    // Overwriting the session
    await catalog.savePlaybackSession(
      queueJson: '[{"sourceId":"s1","id":"t1","title":"Song 1","durationMs":266000}]',
      currentIndex: 0,
      positionMs: 12000,
      durationMs: 266000,
      shuffle: false,
      repeatMode: 'off',
    );

    final updated = await catalog.loadPlaybackSession();
    expect(updated, isNotNull);
    expect(updated!.currentIndex, 0);
    expect(updated.positionMs, 12000);
    expect(updated.shuffle, isFalse);
    expect(updated.repeatMode, 'off');
  });

  test('randomTracks returns playable songs known to database', () async {
    final (:db, :catalog) = _open();

    await catalog.adopt(_song(sourceId: 's1', id: 'track-a', title: 'Alpha'));
    await catalog.adopt(_song(sourceId: 's1', id: 'track-b', title: 'Beta'));
    await catalog.adopt(_song(sourceId: 's2', id: 'track-c', title: 'Gamma'));

    final random = await catalog.randomTracks(limit: 2);
    expect(random, hasLength(2));
    for (final song in random) {
      expect(song.title, anyOf('Alpha', 'Beta', 'Gamma'));
      expect(song.id, isNotEmpty);
    }
  });
}
