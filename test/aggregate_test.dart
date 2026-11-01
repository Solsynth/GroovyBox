import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/aggregate.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';

/// A source that answers `recentlyAdded` and throws everywhere else.
class _FakeSource extends LibrarySource {
  _FakeSource(this.id, this._albums, {this.failure, this.songs = const []});

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
}
