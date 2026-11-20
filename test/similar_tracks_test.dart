import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/aggregate.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';

/// A source whose only answer is a similar-tracks list; every other read is
/// the base class's default or unimplemented.
class _SimilarSource extends LibrarySource implements SimilarSource {
  _SimilarSource(this.id, this.answers, {this.failure});

  @override
  final String id;
  final List<LibrarySong> answers;
  final Object? failure;

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://$id.example.com',
    displayName: id,
  );

  @override
  Future<List<LibrarySong>> similarSongs(
    LibrarySong song, {
    int limit = 30,
  }) async {
    if (failure != null) throw failure!;
    return answers;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

LibrarySong _song(String id, {String title = 'Track'}) => LibrarySong(
  sourceId: 'a',
  id: id,
  title: title,
  duration: const Duration(seconds: 200),
);

void main() {
  test('the seed is never in its own similar list', () async {
    final seed = _song('seed', title: 'Seed');
    final aggregator = LibraryAggregator([
      _SimilarSource('a', [
        _song('x', title: 'Neighbour X'),
        _song('y', title: 'Neighbour Y'),
      ]),
    ]);

    final songs = await aggregator.similarSongs(seed, limit: 10);

    expect(songs.map((song) => song.id), isNot(contains('seed')));
    expect(songs.map((song) => song.id), ['x', 'y']);
  });

  test('one source that cannot answer does not cost the others', () async {
    final aggregator = LibraryAggregator([
      _SimilarSource('dead', const [], failure: Exception('boom')),
      _SimilarSource('a', [_song('x', title: 'Neighbour X')]),
      _SimilarSource('b', [_song('y', title: 'Neighbour Y')]),
    ]);

    final songs = await aggregator.similarSongs(_song('seed'));

    expect(songs.map((song) => song.id), containsAll(['x', 'y']));
  });

  test('every source failing is an error, not an empty answer', () async {
    final aggregator = LibraryAggregator([
      _SimilarSource('a', const [], failure: Exception('boom')),
    ]);

    await expectLater(
      aggregator.similarSongs(_song('seed')),
      throwsA(isA<Exception>()),
    );
  });

  test('a library with no similar source answers nothing, quietly', () async {
    final aggregator = LibraryAggregator([_SimilarSource('a', const [])]);

    // A source that answers nothing is not a failure: the aggregator merges
    // the empty answer the same way it merges a list.
    final songs = await aggregator.similarSongs(_song('seed'));
    expect(songs, isEmpty);
  });
}
