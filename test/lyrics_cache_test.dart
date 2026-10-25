import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// An in-memory cache, so the suite never touches the device's real file.
/// [now] is mutable so a test can age a row without waiting a day.
Future<LyricsCache> _cache({DateTime Function()? now}) async {
  sqfliteFfiInit();
  return LyricsCache.open(
    path: inMemoryDatabasePath,
    factory: databaseFactoryFfi,
    clock: now ?? DateTime.now,
  );
}

Lyrics _timed() => const Lyrics(
  lines: [
    LyricLine(Duration(seconds: 3), 'ここに来た',
        pronunciation: 'koko ni kita', translation: 'Here I came'),
    LyricLine(Duration(seconds: 9), 'And I say'),
  ],
  synced: true,
  language: 'jpn',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round-trips lines, their layers and the language', () async {
    final cache = await _cache();
    addTearDown(cache.close);

    await cache.write('a', 's1', _timed(), origin: LyricsOrigin.library);
    final stored = await cache.read('a', 's1');

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
    final cache = await _cache();
    addTearDown(cache.close);

    await cache.write('a', 's1', _timed(), origin: LyricsOrigin.library);
    await cache.write(
      'a',
      's1',
      parseLrc('[00:01.00]only line'),
      origin: LyricsOrigin.lrclib,
    );

    expect(await cache.count(), 1);
    final stored = await cache.read('a', 's1');
    expect(stored!.origin, LyricsOrigin.lrclib);
    expect(stored.lyrics.lines.single.text, 'only line');
  });

  test('an empty answer is remembered, then expires', () async {
    var now = DateTime(2026, 1, 1);
    final cache = await _cache(now: () => now);
    addTearDown(cache.close);

    await cache.write('a', 's1', Lyrics.empty, origin: LyricsOrigin.none);
    expect((await cache.read('a', 's1'))!.origin, LyricsOrigin.none);

    // Mid-window the miss still stands; past it the row is re-asked, because
    // LRCLIB gains tracks over time and a miss is only a hint.
    now = now.add(LyricsCache.missTtl ~/ 2);
    expect(await cache.read('a', 's1'), isNotNull);
    now = now.add(LyricsCache.missTtl);
    expect(await cache.read('a', 's1'), isNull);
  });

  test('a real lyric never expires', () async {
    var now = DateTime(2026, 1, 1);
    final cache = await _cache(now: () => now);
    addTearDown(cache.close);

    await cache.write('a', 's1', _timed(), origin: LyricsOrigin.lrclib);
    now = now.add(const Duration(days: 900));
    expect((await cache.read('a', 's1'))!.lyrics.synced, isTrue);
  });

  test('removal is per song and per library', () async {
    final cache = await _cache();
    addTearDown(cache.close);

    await cache.write('a', 's1', _timed(), origin: LyricsOrigin.library);
    await cache.write('a', 's2', _timed(), origin: LyricsOrigin.library);
    await cache.write('b', 's1', _timed(), origin: LyricsOrigin.library);

    await cache.remove('a', 's1');
    expect(await cache.read('a', 's1'), isNull);
    expect(await cache.read('a', 's2'), isNotNull);

    await cache.removeSource('a');
    expect(await cache.count(), 1);
    expect(await cache.read('b', 's1'), isNotNull);
  });

  test('clearing empties every row', () async {
    final cache = await _cache();
    addTearDown(cache.close);

    await cache.write('a', 's1', _timed(), origin: LyricsOrigin.library);
    await cache.clear();
    expect(await cache.count(), 0);
  });
}
