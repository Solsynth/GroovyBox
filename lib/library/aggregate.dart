import 'models.dart';
import 'source.dart';

/// Fans a read out over every connected library and merges the results.
///
/// One dead server must never blank the whole app: a failing source is
/// reported through [onFailure] and simply contributes nothing, as long as at
/// least one other source answered.
class LibraryAggregator {
  LibraryAggregator(
    this.sources, {
    this.onSongs,
    this.onFailure,
    this.onSuccess,
  });

  final List<LibrarySource> sources;

  /// Called with the songs of every successful read, including a single
  /// album's or playlist's, so the local library learns a track the first time
  /// the user sees it instead of at some later sync.
  final void Function(Iterable<LibrarySong> songs)? onSongs;

  /// Called once per source that answered with an error, after the merge.
  final void Function(String sourceId, Object error)? onFailure;

  /// Called once per source that answered cleanly, so a failure reported by an
  /// earlier fan-out does not outlive the problem.
  final void Function(String sourceId)? onSuccess;

  Future<List<T>> _fanOut<T>(
    Future<List<T>> Function(LibrarySource source) task,
  ) async {
    if (sources.isEmpty) return const [];

    final results = await Future.wait<Object?>([
      for (final source in sources)
        task(
          source,
        ).then<Object?>((items) => items, onError: (Object error) => error),
    ], eagerError: false);

    final merged = <T>[];
    final failures = <(String, Object)>[];
    for (var index = 0; index < sources.length; index++) {
      final result = results[index];
      if (result is List<T>) {
        // Sources keep their own ordering; concatenation is in source order
        // because not every backend exposes a comparable timestamp.
        merged.addAll(result);
        if (result case final List<LibrarySong> songs) onSongs?.call(songs);
      } else if (result != null) {
        failures.add((sources[index].id, result));
      }
    }

    if (failures.length == sources.length) throw failures.first.$2;
    final failedIds = {for (final (sourceId, _) in failures) sourceId};
    for (final source in sources) {
      if (!failedIds.contains(source.id)) onSuccess?.call(source.id);
    }
    for (final (sourceId, error) in failures) {
      onFailure?.call(sourceId, error);
    }
    return merged;
  }

  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) =>
      _fanOut((source) => source.recentlyAdded(limit: limit));

  Future<List<LibraryAlbum>> albums({int limit = 60, int offset = 0}) =>
      _fanOut((source) => source.albums(limit: limit, offset: offset));

  Future<List<LibrarySong>> albumSongs(String albumId) =>
      _fanOut((source) => source.albumSongs(albumId));

  Future<List<LibraryArtist>> artists() =>
      _fanOut((source) => source.artists());

  Future<List<LibraryAlbum>> artistAlbums(String artistId) =>
      _fanOut((source) => source.artistAlbums(artistId));

  Future<List<LibraryPlaylist>> playlists() =>
      _fanOut((source) => source.playlists());

  Future<List<LibrarySong>> playlistSongs(String playlistId) =>
      _fanOut((source) => source.playlistSongs(playlistId));

  Future<List<LibrarySong>> search(String query, {int limit = 40}) =>
      _fanOut((source) => source.search(query, limit: limit));

  Future<List<LibrarySong>> randomSongs({int size = 40}) =>
      _fanOut((source) => source.randomSongs(size: size));
}
