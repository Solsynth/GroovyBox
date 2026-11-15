import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/lrclib.dart';
import 'package:groovy_box/library/lyrics_query.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_resolver.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';

/// A library whose answer the test controls, and which counts its calls.
class _Library extends LibrarySource {
  _Library(this.answer);

  Lyrics? answer;
  bool throws = false;
  int calls = 0;

  @override
  String get id => 'a';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'a',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Home',
  );

  @override
  Future<Lyrics> lyrics(LibrarySong song) async {
    calls++;
    if (throws) throw const LibraryException('server is down');
    return answer ?? Lyrics.empty;
  }

  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// LRCLIB replaced by a fixed answer, so the test never leaves the machine.
class _FakeLrclib extends Lrclib {
  _FakeLrclib(this.lookup);

  final LyricsLookup lookup;
  int calls = 0;

  @override
  Future<LyricsLookup> findLyrics(LyricsRequest song) async {
    calls++;
    return lookup;
  }

  @override
  Future<List<LyricsCandidate>?> searchLyrics(String query) async => const [];
}

/// A second query source, so the chain's order and its "first timed answer
/// wins" rule can be tested without NetEase or a network.
class _SecondQuery implements LyricsQuerySource {
  _SecondQuery(this.lookup, this.origin);
  final LyricsLookup lookup;
  final LyricsOrigin origin;
  int calls = 0;

  @override
  Future<LyricsLookup> findLyrics(LyricsRequest song) async {
    calls++;
    return lookup;
  }

  @override
  Future<List<LyricsCandidate>?> searchLyrics(String query) async => const [];
}

const _song = LyricsRequest(
  sourceId: 'a',
  id: 's1',
  title: 'Yellow',
  artist: 'Coldplay',
  duration: Duration(seconds: 266),
);

const _libraryTimed = Lyrics(
  lines: [LyricLine(Duration(seconds: 2), 'library line')],
  synced: true,
);

const _libraryPlain = Lyrics(
  lines: [LyricLine(Duration.zero, 'library plain')],
  synced: false,
);

const _remoteTimed = Lyrics(
  lines: [LyricLine(Duration(seconds: 19), 'remote line')],
  synced: true,
);

const _remotePlain = Lyrics(
  lines: [LyricLine(Duration.zero, 'remote plain')],
  synced: false,
);

LyricsLookup _found(Lyrics lyrics) => LyricsLookup(
  result: LyricsHit(
    lyrics: lyrics,
    origin: LyricsOrigin.lrclib,
    id: 1,
  ),
  settled: true,
);

/// An in-memory library; the resolver's real one is on disk.
({LibraryDatabase db, LibraryCatalog catalog, LyricsStore store}) _open() {
  final db = LibraryDatabase(NativeDatabase.memory());
  return (db: db, catalog: LibraryCatalog(db), store: LyricsStore(db));
}

/// The track the shared [_song] resolves to, adopted the way a real lookup
/// adopts it.
Future<int> _trackOf(LibraryCatalog catalog) => catalog.requestTrackId(_song);

void main() {
  late _Library library;
  late LibraryDatabase db;
  late LibraryCatalog catalog;
  late LyricsStore cache;

  setUp(() {
    library = _Library(null);
    final opened = _open();
    db = opened.db;
    catalog = opened.catalog;
    cache = opened.store;
  });
  tearDown(() async => db.close());

  Future<Lyrics> resolve(
    _FakeLrclib lrclib, {
    bool refresh = false,
    List<LyricsQuerySource>? extra,
  }) => LyricsResolver(
    catalog: catalog,
    store: cache,
    queries: () => [lrclib, ...?extra],
    sourceFor: (_) => library,
  ).resolve(_song, refresh: refresh);

  test('a timed library lyric wins and is stored', () async {
    library.answer = _libraryTimed;
    final lrclib = _FakeLrclib(LyricsLookup.missing);

    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'library line');
    expect(lrclib.calls, 0, reason: 'a timed lyric needs no second opinion');
    expect((await cache.read(await _trackOf(catalog)))!.origin, LyricsOrigin.library);
  });

  test('an unsynced library lyric is replaced by a timed LRCLIB one', () async {
    library.answer = _libraryPlain;
    final lrclib = _FakeLrclib(_found(_remoteTimed));

    final lyrics = await resolve(lrclib);

    expect(lyrics.synced, isTrue);
    expect(lyrics.lines.single.text, 'remote line');
    expect((await cache.read(await _trackOf(catalog)))!.origin, LyricsOrigin.lrclib);
  });

  test('a plain LRCLIB answer does not displace the library block', () async {
    library.answer = _libraryPlain;
    final lrclib = _FakeLrclib(_found(_remotePlain));

    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'library plain');
    expect((await cache.read(await _trackOf(catalog)))!.origin, LyricsOrigin.library);
  });

  test('a dead library still gets LRCLIB lyrics', () async {
    library.throws = true;
    final lrclib = _FakeLrclib(_found(_remoteTimed));

    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'remote line');
  });

  test('the stored answer is used without touching the network', () async {
    library.answer = _libraryTimed;
    await resolve(_FakeLrclib(LyricsLookup.missing));

    library.answer = null;
    final lrclib = _FakeLrclib(_found(_remoteTimed));
    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'library line');
    expect(library.calls, 1);
    expect(lrclib.calls, 0);
  });

  test('a refresh ignores the stored answer and asks again', () async {
    library.answer = _libraryTimed;
    await resolve(_FakeLrclib(LyricsLookup.missing));
    await cache.remove(await _trackOf(catalog));

    library.answer = null;
    final lrclib = _FakeLrclib(_found(_remoteTimed));
    final lyrics = await resolve(lrclib, refresh: true);

    expect(lyrics.lines.single.text, 'remote line');
    expect(lrclib.calls, 1);
  });

  test('a confirmed miss is stored; an unanswered one is not', () async {
    await resolve(_FakeLrclib(LyricsLookup.missing));
    expect((await cache.read(await _trackOf(catalog)))!.origin, LyricsOrigin.none);
  });


  test('a manual adopt is stored as manual and survives an automatic refresh',
      () async {
    final lrclib = _FakeLrclib(_found(_remoteTimed));
    final resolver = LyricsResolver(
      catalog: catalog,
      store: cache,
      queries: () => [lrclib],
      sourceFor: (_) => library,
    );

    // The user picks different words by hand than the automatic chain chose.
    final manual = await resolver.adopt(
      _song,
      const Lyrics(
        lines: [LyricLine(Duration(seconds: 4), 'chosen words')],
        synced: true,
      ),
    );
    expect(manual.lines.single.text, 'chosen words');
    final trackId = await _trackOf(catalog);
    expect((await cache.read(trackId))!.origin, LyricsOrigin.manual);

    // The next play, and even a refresh, keeps the deliberate choice: the
    // stored answer is read before any network is touched.
    expect(lrclib.calls, 0);
    final replay = await resolver.resolve(_song);
    expect(replay.lines.single.text, 'chosen words');
    final reasked = await resolver.resolve(_song, refresh: true);
    expect(reasked.lines.single.text, 'remote line',
        reason: 'refresh is the explicit "these are wrong" path and must ask');
    expect((await cache.read(trackId))!.origin, LyricsOrigin.lrclib);
  });

  test('an unanswered miss is not stored', () async {
    await resolve(_FakeLrclib(LyricsLookup.unknown));
    expect(
      await cache.read(await _trackOf(catalog)),
      isNull,
      reason: 'an offline machine must ask again on the next play',
    );
  });

  test('a later query source answers when the first has nothing', () async {
    // The chain exists for exactly this: LRCLIB has no row for the song, but a
    // connected account can still find it.
    final second = _SecondQuery(
      LyricsLookup(result: LyricsHit(
        lyrics: _remoteTimed,
        origin: LyricsOrigin.netease,
        id: 9,
      ), settled: true),
      LyricsOrigin.netease,
    );

    final lyrics = await resolve(
      _FakeLrclib(LyricsLookup.missing),
      extra: [second],
    );

    expect(lyrics.lines.single.text, 'remote line');
    expect(second.calls, 1);
    // The stored row says where the words really came from.
    expect(
      (await cache.read(await _trackOf(catalog)))!.origin,
      LyricsOrigin.netease,
    );
  });

  test('a timed answer stops the chain; a plain one does not', () async {
    final plain = _SecondQuery(
      LyricsLookup(result: LyricsHit(
        lyrics: _remotePlain,
        origin: LyricsOrigin.netease,
      ), settled: true),
      LyricsOrigin.netease,
    );
    final timed = _SecondQuery(
      LyricsLookup(result: LyricsHit(
        lyrics: _remoteTimed,
        origin: LyricsOrigin.netease,
      ), settled: true),
      LyricsOrigin.netease,
    );

    await resolve(_FakeLrclib(LyricsLookup.missing), extra: [plain, timed]);

    // The plain row was kept as a fallback, so the timed row behind it was
    // still asked — and won.
    expect(plain.calls, 1);
    expect(timed.calls, 1);
    expect(
      (await cache.read(await _trackOf(catalog)))!.lyrics.synced,
      isTrue,
    );
  });

  test('a miss is only cached when every service confirmed it', () async {
    final unreachable = _SecondQuery(LyricsLookup.unknown, LyricsOrigin.netease);
    await resolve(_FakeLrclib(LyricsLookup.missing), extra: [unreachable]);

    expect(
      await cache.read(await _trackOf(catalog)),
      isNull,
      reason: 'one service could not answer, so the song may still have words',
    );
  });

  test('removing a source unlinks its songs but keeps their words', () async {
    library.answer = _libraryTimed;
    await resolve(_FakeLrclib(LyricsLookup.missing));
    final trackId = await _trackOf(catalog);

    await catalog.forgetSource('a');

    expect(await db.trackIdForLink('a', 's1'), isNull, reason: 'unlinked');
    expect(
      await cache.read(trackId),
      isNotNull,
      reason: 'the song and its words outlive the server that served them',
    );
    expect(await catalog.orphanCount(), 1);
  });
}
