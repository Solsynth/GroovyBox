import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:groovy_box/library/track_identity.dart';

/// An in-memory library, so the suite never touches the device's real file.
/// [now] is mutable so a test can age a row without waiting a day.
({LibraryDatabase db, LyricsStore store}) _open({
  DateTime Function()? now,
}) {
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return (db: db, store: LyricsStore(db, clock: now ?? DateTime.now));
}

/// One track to hang lyrics on; the store only cares about its id. [id] is the
/// item's id on the source, so a second track needs its own.
Future<int> _track(
  LibraryDatabase db, {
  String id = 's1',
  String title = 'Yellow',
}) => db.resolveTrack(
  TrackIdentity(title: title, artist: 'Coldplay'),
  sourceId: 'a',
  externalId: id,
);

Lyrics _timed() => const Lyrics(
  lines: [
    LyricLine(
      Duration(seconds: 3),
      'ここに来た',
      pronunciation: 'koko ni kita',
      translation: 'Here I came',
    ),
    LyricLine(Duration(seconds: 9), 'And I say'),
  ],
  synced: true,
  language: 'jpn',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round-trips lines, their layers and the language', () async {
    final (:db, :store) = _open();
    final trackId = await _track(db);

    await store.write(trackId, _timed(), origin: LyricsOrigin.library);
    final stored = await store.read(trackId);

    expect(stored, isNotNull);
    expect(stored!.origin, LyricsOrigin.library);
    expect(stored.lyrics.synced, isTrue);
    expect(stored.lyrics.language, 'jpn');
    expect(stored.lyrics.lines, hasLength(2));
    expect(stored.lyrics.lines.first.at, const Duration(seconds: 3));
    expect(stored.lyrics.lines.first.text, 'ここに来た');
    expect(stored.lyrics.lines.first.pronunciation, 'koko ni kita');
    expect(stored.lyrics.lines.first.translation, 'Here I came');
    expect(stored.lyrics.lines.last.pronunciation, isNull);
  });

  test('a rewrite replaces the row instead of adding one', () async {
    final (:db, :store) = _open();
    final trackId = await _track(db);

    await store.write(trackId, _timed(), origin: LyricsOrigin.library);
    await store.write(
      trackId,
      parseLrc('[00:01.00]only line'),
      origin: LyricsOrigin.lrclib,
      remoteId: 42,
    );

    expect(await store.count(), 1);
    final stored = await store.read(trackId);
    expect(stored!.origin, LyricsOrigin.lrclib);
    expect(stored.lyrics.lines.single.text, 'only line');
  });

  test('an empty answer is remembered, then expires', () async {
    var now = DateTime(2026, 1, 1);
    final (:db, :store) = _open(now: () => now);
    final trackId = await _track(db);

    await store.write(trackId, Lyrics.empty, origin: LyricsOrigin.none);
    expect((await store.read(trackId))!.origin, LyricsOrigin.none);

    // Mid-window the miss still stands; past it the row is re-asked, because
    // LRCLIB gains tracks over time and a miss is only a hint.
    now = now.add(LyricsStore.missTtl ~/ 2);
    expect(await store.read(trackId), isNotNull);
    now = now.add(LyricsStore.missTtl);
    expect(await store.read(trackId), isNull);
  });

  test('a real lyric never expires', () async {
    var now = DateTime(2026, 1, 1);
    final (:db, :store) = _open(now: () => now);
    final trackId = await _track(db);

    await store.write(trackId, _timed(), origin: LyricsOrigin.lrclib);
    now = now.add(const Duration(days: 900));
    expect((await store.read(trackId))!.lyrics.synced, isTrue);
  });

  test('removal is per track, and clearing empties every row', () async {
    final (:db, :store) = _open();
    final first = await _track(db, id: 's1', title: 'Yellow');
    final second = await _track(db, id: 's2', title: 'Fix You');
    await store.write(first, _timed(), origin: LyricsOrigin.library);
    await store.write(second, _timed(), origin: LyricsOrigin.library);

    await store.remove(first);
    expect(await store.read(first), isNull);
    expect(await store.read(second), isNotNull);

    await store.clear();
    expect(await store.count(), 0);
  });

  test('a second source serving the same song reads the stored words', () async {
    final (:db, :store) = _open();
    final onServer = await db.resolveTrack(
      TrackIdentity(
        title: 'Yellow',
        artist: 'Coldplay',
        duration: const Duration(seconds: 266),
      ),
      sourceId: 'jellyfin',
      externalId: 'movie-1',
    );
    await store.write(onServer, _timed(), origin: LyricsOrigin.lrclib);

    // Same song, different server: the title is tagged differently and the
    // length is a second off, which is what a second scanner looks like.
    final onOtherServer = await db.resolveTrack(
      TrackIdentity(
        title: 'Yellow (Remastered 2011)',
        artist: 'coldplay',
        duration: const Duration(seconds: 267),
      ),
      sourceId: 'subsonic',
      externalId: 'song-9',
    );

    expect(onOtherServer, onServer, reason: 'one row per song, not per source');
    expect(
      (await store.read(onOtherServer))!.lyrics.lines,
      hasLength(2),
      reason: 'the words follow the song, not the server',
    );
  });
}
