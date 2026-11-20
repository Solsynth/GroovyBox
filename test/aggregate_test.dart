import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/aggregate.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';

/// A source that answers the reads these tests exercise and throws everywhere
/// else.
class _FakeSource extends LibrarySource {
  _FakeSource(
    this.id,
    this._albums, {
    this.failure,
    this.songs = const [],
  });

  @override
  final String id;
  final List<LibraryAlbum> _albums;
  final List<LibrarySong> songs;
  final Object? failure;

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://$id.example.com',
    displayName: id,
  );

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) async {
    if (failure != null) throw failure!;
    return _albums;
  }

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async {
    if (failure != null) throw failure!;
    return songs;
  }

  @override
  Future<List<LibrarySong>> playlistSongs(String playlistId) async {
    if (failure != null) throw failure!;
    return songs;
  }

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    if (failure != null) throw failure!;
    return songs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

LibraryAlbum _album(String sourceId, String id) => LibraryAlbum(
  sourceId: sourceId,
  id: id,
  name: id,
  duration: Duration.zero,
);

void main() {
  test('merges sources in order and reports the failing one', () async {
    final failures = <String, Object>{};
    final aggregator = LibraryAggregator(
      [
        _FakeSource('a', [_album('a', 'a1'), _album('a', 'a2')]),
        _FakeSource('b', const [], failure: const LibraryException('down')),
      ],
      onFailure: (sourceId, error) => failures[sourceId] = error,
    );

    final albums = await aggregator.recentlyAdded();

    expect(albums.map((album) => album.id), ['a1', 'a2']);
    expect(failures.keys, ['b']);
    expect((failures['b']! as LibraryException).message, 'down');
  });

  test('keeps source order with both sources answering', () async {
    final aggregator = LibraryAggregator([
      _FakeSource('a', [_album('a', 'a1')]),
      _FakeSource('b', [_album('b', 'b1')]),
    ]);

    final albums = await aggregator.recentlyAdded();

    expect(albums.map((album) => album.sourceId), ['a', 'b']);
  });

  test('rethrows when every source failed', () async {
    final aggregator = LibraryAggregator([
      _FakeSource('a', const [], failure: const LibraryException('a down')),
      _FakeSource('b', const [], failure: const LibraryException('b down')),
    ]);

    await expectLater(
      aggregator.recentlyAdded(),
      throwsA(
        isA<LibraryException>().having((e) => e.message, 'message', 'a down'),
      ),
    );
  });

  test('an empty source list returns nothing and never fails', () async {
    expect(await LibraryAggregator(const []).recentlyAdded(), isEmpty);
  });

  test('search deduplicates identical songs across sources', () async {
    final songFromA = LibrarySong(
      sourceId: 'a',
      id: 's1',
      title: 'Song Alpha - Remastered',
      artist: 'Band Beta',
      duration: const Duration(seconds: 200),
    );
    final songFromB = LibrarySong(
      sourceId: 'b',
      id: 's2',
      title: 'Song Alpha',
      artist: 'Band Beta',
      duration: const Duration(seconds: 200),
    );
    final songUnique = LibrarySong(
      sourceId: 'b',
      id: 's3',
      title: 'Song Gamma',
      artist: 'Band Beta',
      duration: const Duration(seconds: 180),
    );

    final aggregator = LibraryAggregator([
      _FakeSource('a', const [], songs: [songFromA]),
      _FakeSource('b', const [], songs: [songFromB, songUnique]),
    ]);

    final results = await aggregator.search('Song');
    expect(results, hasLength(2));
    expect(results.first.id, 's1');
    expect(results.last.id, 's3');
  });

  test('the wide search asks each source for its catalogue', () async {
    // Playback and the Explore tab need the set a library can *reach*, not
    // just what the account owns: a cloud account's own search answers its
    // whole service and its holdings search is a filtered subset of it.
    final source = _WideSource('a');
    final aggregator = LibraryAggregator([source]);

    final reachable = await aggregator.searchCatalogue('Song');
    expect(source.asked, ['catalogue:Song']);
    expect(reachable.map((song) => song.id), ['catalogue-hit']);

    // The library question stays on the holdings read.
    final held = await aggregator.search('Song');
    expect(source.asked, ['catalogue:Song', 'holdings:Song']);
    expect(held.map((song) => song.id), ['holdings-hit']);
  });

  /// One song per read, so a test can tell which read adopted what.
  ({LibrarySong album, LibrarySong playlist, LibrarySong search, LibrarySong random})
  oneOfEach(String sourceId) => (
    album: LibrarySong(
      sourceId: sourceId,
      id: 'album-song',
      title: 'From an album',
      duration: const Duration(seconds: 200),
    ),
    playlist: LibrarySong(
      sourceId: sourceId,
      id: 'playlist-song',
      title: 'From a playlist',
      duration: const Duration(seconds: 200),
    ),
    search: LibrarySong(
      sourceId: sourceId,
      id: 'search-hit',
      title: 'From search',
      duration: const Duration(seconds: 200),
    ),
    random: LibrarySong(
      sourceId: sourceId,
      id: 'recommendation',
      title: 'Recommended',
      duration: const Duration(seconds: 200),
    ),
  );

  test('only reads of what the library holds are adopted', () async {
    // Search answers the whole cloud catalogue and "random" answers a
    // recommendation: adopting either fills the device's own library with
    // tracks the user never added, which then turn up in its random draw and
    // its "on this device" count. Album and playlist listings are what the
    // account actually has, so those are adopted.
    final adopted = <String>[];
    final source = _FakeSource('a', const []);
    final songs = oneOfEach('a');
    final aggregator = LibraryAggregator(
      [_CountingSource(source, songs)],
      onSongs: (songs) => adopted.addAll(songs.map((song) => song.id)),
    );

    await aggregator.albumSongs('album');
    await aggregator.playlistSongs('playlist');
    await aggregator.search('query');
    await aggregator.randomSongs(size: 5);

    expect(adopted, ['album-song', 'playlist-song']);
  });
}

/// One source whose four song reads each answer a different song, so the
/// adoption test can tell which read a row came from.
class _CountingSource extends LibrarySource {
  _CountingSource(this._inner, this._songs);

  final _FakeSource _inner;
  final ({
    LibrarySong album,
    LibrarySong playlist,
    LibrarySong search,
    LibrarySong random,
  })
  _songs;

  @override
  String get id => _inner.id;

  @override
  SourceConfig get config => _inner.config;

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) =>
      _inner.recentlyAdded(limit: limit);

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async => [_songs.album];

  @override
  Future<List<LibrarySong>> playlistSongs(String playlistId) async => [
    _songs.playlist,
  ];

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async => [
    _songs.search,
  ];

  @override
  Future<List<LibrarySong>> randomSongs({int size = 40}) async => [
    _songs.random,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A source whose two searches answer differently, and which records which
/// one was asked: the whole point of the holdings/catalogue split.
class _WideSource extends LibrarySource implements CatalogueSource {
  _WideSource(this.id);

  @override
  final String id;

  final List<String> asked = [];

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.netease,
    baseUrl: 'https://$id.example.com',
    displayName: id,
  );

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    asked.add('holdings:$query');
    return [
      LibrarySong(
        sourceId: id,
        id: 'holdings-hit',
        title: 'Owned',
        duration: const Duration(seconds: 200),
      ),
    ];
  }

  @override
  Future<List<LibrarySong>> searchCatalogue(
    String query, {
    int limit = 40,
  }) async {
    asked.add('catalogue:$query');
    return [
      LibrarySong(
        sourceId: id,
        id: 'catalogue-hit',
        title: 'Reachable',
        duration: const Duration(seconds: 200),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

