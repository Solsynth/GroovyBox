import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lrclib.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_resolver.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  final LrclibLookup lookup;
  int calls = 0;

  @override
  Future<LrclibLookup> find(LyricsRequest song) async {
    calls++;
    return lookup;
  }
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

LrclibLookup _found(Lyrics lyrics) => LrclibLookup(
  result: LrclibResult(lyrics: lyrics, id: 1),
  settled: true,
);

/// An in-memory database; the resolver's real cache is on disk.
Future<LyricsCache> _cache() async {
  sqfliteFfiInit();
  return LyricsCache.open(
    path: inMemoryDatabasePath,
    factory: databaseFactoryFfi,
  );
}

void main() {
  late _Library library;
  late LyricsCache cache;

  setUp(() async {
    library = _Library(null);
    cache = await _cache();
  });
  tearDown(() async => cache.close());

  Future<Lyrics> resolve(
    _FakeLrclib lrclib, {
    bool refresh = false,
  }) => LyricsResolver(
    cache: cache,
    lrclib: lrclib,
    sourceFor: (_) => library,
  ).resolve(_song, refresh: refresh);

  test('a timed library lyric wins and is stored', () async {
    library.answer = _libraryTimed;
    final lrclib = _FakeLrclib(LrclibLookup.missing);

    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'library line');
    expect(lrclib.calls, 0, reason: 'a timed lyric needs no second opinion');
    expect((await cache.read('a', 's1'))!.origin, LyricsOrigin.library);
  });

  test('an unsynced library lyric is replaced by a timed LRCLIB one', () async {
    library.answer = _libraryPlain;
    final lrclib = _FakeLrclib(_found(_remoteTimed));

    final lyrics = await resolve(lrclib);

    expect(lyrics.synced, isTrue);
    expect(lyrics.lines.single.text, 'remote line');
    expect((await cache.read('a', 's1'))!.origin, LyricsOrigin.lrclib);
  });

  test('a plain LRCLIB answer does not displace the library block', () async {
    library.answer = _libraryPlain;
    final lrclib = _FakeLrclib(_found(_remotePlain));

    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'library plain');
    expect((await cache.read('a', 's1'))!.origin, LyricsOrigin.library);
  });

  test('a dead library still gets LRCLIB lyrics', () async {
    library.throws = true;
    final lrclib = _FakeLrclib(_found(_remoteTimed));

    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'remote line');
  });

  test('the stored answer is used without touching the network', () async {
    library.answer = _libraryTimed;
    await resolve(_FakeLrclib(LrclibLookup.missing));

    library.answer = null;
    final lrclib = _FakeLrclib(_found(_remoteTimed));
    final lyrics = await resolve(lrclib);

    expect(lyrics.lines.single.text, 'library line');
    expect(library.calls, 1);
    expect(lrclib.calls, 0);
  });

  test('a refresh ignores the stored answer and asks again', () async {
    library.answer = _libraryTimed;
    await resolve(_FakeLrclib(LrclibLookup.missing));
    await cache.remove('a', 's1');

    library.answer = null;
    final lrclib = _FakeLrclib(_found(_remoteTimed));
    final lyrics = await resolve(lrclib, refresh: true);

    expect(lyrics.lines.single.text, 'remote line');
    expect(lrclib.calls, 1);
  });

  test('a confirmed miss is stored; an unanswered one is not', () async {
    await resolve(_FakeLrclib(LrclibLookup.missing));
    expect((await cache.read('a', 's1'))!.origin, LyricsOrigin.none);

    await cache.clear();
    await resolve(_FakeLrclib(LrclibLookup.unknown));
    expect(
      await cache.read('a', 's1'),
      isNull,
      reason: 'an offline machine must ask again on the next play',
    );
  });

  test('forgetting a library drops only its rows', () async {
    library.answer = _libraryTimed;
    await resolve(_FakeLrclib(LrclibLookup.missing));
    await cache.write(
      'other',
      's1',
      _libraryTimed,
      origin: LyricsOrigin.library,
    );

    await LyricsResolver(
      cache: cache,
      lrclib: _FakeLrclib(LrclibLookup.missing),
    ).forgetSource('a');

    expect(await cache.read('a', 's1'), isNull);
    expect(await cache.read('other', 's1'), isNotNull);
  });
}
