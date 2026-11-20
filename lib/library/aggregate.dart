import 'package:flutter/foundation.dart';

import 'models.dart';
import 'source.dart';
import 'track_identity.dart';

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

  /// Called with the songs of a read that describes what the library *holds*,
  /// so the local library learns a track the first time the user sees it.
  ///
  /// Never called for [search] or [randomSongs]: those answer with things the
  /// account does not own — a NetEase search is the whole cloud catalogue, and
  /// its "random" feed is a recommendation list — and adopting them fills the
  /// local library with tracks the user never added, which then turn up in the
  /// device's own random draw and in its "on this device" count.
  final void Function(Iterable<LibrarySong> songs)? onSongs;

  /// Called once per source that answered with an error, after the merge.
  final void Function(String sourceId, Object error)? onFailure;

  /// Called once per source that answered cleanly, so a failure reported by an
  /// earlier fan-out does not outlive the problem.
  final void Function(String sourceId)? onSuccess;

  Future<List<T>> _fanOut<T>(
    Future<List<T>> Function(LibrarySource source) task, {
    bool adopt = false,
    List<LibrarySource>? overrides,
  }) async {
    final targets = overrides ?? sources;
    if (targets.isEmpty) return const [];

    final results = await Future.wait<Object?>([
      for (final source in targets)
        task(source)
            .then<Object?>((items) => items, onError: (Object error) => error),
    ], eagerError: false);

    final merged = <T>[];
    final failures = <(String, Object)>[];
    for (var index = 0; index < targets.length; index++) {
      final result = results[index];
      if (result is List<T>) {
        // Sources keep their own ordering; concatenation is in source order
        // because not every backend exposes a comparable timestamp.
        merged.addAll(result);
        if (adopt) {
          if (result case final List<LibrarySong> songs) onSongs?.call(songs);
        }
      } else if (result != null) {
        failures.add((targets[index].id, result));
      }
    }

    if (failures.length == targets.length) throw failures.first.$2;
    final failedIds = {for (final (sourceId, _) in failures) sourceId};
    for (final source in targets) {
      if (!failedIds.contains(source.id)) onSuccess?.call(source.id);
    }
    for (final (sourceId, error) in failures) {
      onFailure?.call(sourceId, error);
    }
    return merged;
  }

  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) =>
      _fanOut((source) => source.recentlyAdded(limit: limit), adopt: true);

  Future<List<LibraryAlbum>> albums({int limit = 60, int offset = 0}) =>
      _fanOut((source) => source.albums(limit: limit, offset: offset));

  Future<List<LibrarySong>> albumSongs(String albumId) =>
      _fanOut((source) => source.albumSongs(albumId), adopt: true);

  Future<List<LibraryArtist>> artists() =>
      _fanOut((source) => source.artists());

  Future<List<LibraryAlbum>> artistAlbums(String artistId) =>
      _fanOut((source) => source.artistAlbums(artistId));

  Future<List<LibraryPlaylist>> playlists() =>
      _fanOut((source) => source.playlists());

  Future<List<LibrarySong>> playlistSongs(String playlistId) =>
      _fanOut((source) => source.playlistSongs(playlistId), adopt: true);

  /// Everything the libraries **hold** that matches [query].
  ///
  /// The question a page's "in your library" section asks, and the reason
  /// [LibrarySource.search] is defined as the holdings set: a cloud account's
  /// own search endpoint answers its whole service, which would put tracks
  /// the user never added under a heading promising the opposite.
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    final songs = await _fanOut((source) => source.search(query, limit: limit));
    return _deduplicateSongs(songs);
  }

  /// The artists and albums the libraries **hold** that match [query].
  ///
  /// Same holdings rule as [search], asked about the two groups a track list
  /// cannot answer. Merged in source order and deduped by name where a server
  /// lists the same act twice under one id each.
  Future<LibraryGroups> searchGroups(String query, {int limit = 20}) async {
    // A source that cannot answer is a source with nothing to say here: the
    // group search is additive, and one server mid-restart must not cost the
    // page its albums.
    final groups = await Future.wait([
      for (final source in sources)
        source.searchGroups(query, limit: limit).catchError((Object error) {
          debugPrint('[Library] groups on ${source.id}: $error');
          return const LibraryGroups();
        }),
    ]);
    final seenArtists = <String>{};
    final seenAlbums = <String>{};
    final artists = <LibraryArtist>[];
    final albums = <LibraryAlbum>[];
    for (final group in groups) {
      for (final artist in group.artists) {
        if (seenArtists.add(artist.name.trim().toLowerCase())) {
          artists.add(artist);
        }
      }
      for (final album in group.albums) {
        final key =
            '${album.name.trim().toLowerCase()}\u0000'
            '${(album.artist ?? '').trim().toLowerCase()}';
        if (seenAlbums.add(key)) albums.add(album);
      }
    }
    return LibraryGroups(artists: artists, albums: albums);
  }

  /// The same question asked of everything each library can *reach*.
  ///
  /// Used where the point is finding this exact recording somewhere playable
  /// — playback's cross-library fallback, a cloud playlist naming a track —
  /// rather than listing what the account owns. A source with no wider reach
  /// than its own holdings answers with them: for a server, the two sets are
  /// the same thing.
  Future<List<LibrarySong>> searchCatalogue(
    String query, {
    int limit = 40,
  }) async {
    final songs = await _fanOut(
      (source) => source is CatalogueSource
          ? source.searchCatalogue(query, limit: limit)
          : source.search(query, limit: limit),
    );
    return _deduplicateSongs(songs);
  }

  Future<List<LibrarySong>> randomSongs({int size = 40}) async {
    final songs = await _fanOut((source) => source.randomSongs(size: size));
    return _deduplicateSongs(songs);
  }

  /// Tracks that flow from [seed], asked of every library that knows how.
  ///
  /// The seed is addressed first to the library that served it: a provider's
  /// neighbours are its own catalogue's, and a second server's answer would
  /// describe a recording it may not even hold. Libraries that cannot answer
  /// this question contribute nothing, and one server being down must not
  /// cost the others' answers, so failures are swallowed exactly as the other
  /// additive reads swallow them.
  Future<List<LibrarySong>> similarSongs(
    LibrarySong seed, {
    int limit = 30,
  }) async {
    final knowers = [
      for (final source in sources)
        if (source is SimilarSource) source,
    ];
    if (knowers.isEmpty) return const [];

    // The seed's own library leads the fan-out; its answer is weighted first
    // by arriving first, because `_fanOut` keeps source order.
    final ordered = [
      for (final source in knowers)
        if (source.id == seed.sourceId) source,
      for (final source in knowers)
        if (source.id != seed.sourceId) source,
    ];

    final songs = await _fanOut(
      (source) => (source as SimilarSource).similarSongs(seed, limit: limit),
      overrides: ordered,
    );
    final key = trackBaseFingerprint(title: seed.title, artist: seed.artist);
    return [
      for (final song in _deduplicateSongs(songs))
        if (trackBaseFingerprint(title: song.title, artist: song.artist) != key)
          song,
    ];
  }

  List<LibrarySong> _deduplicateSongs(List<LibrarySong> songs) {
    final seen = <String>{};
    final result = <LibrarySong>[];
    for (final song in songs) {
      final key = song.mbid ?? TrackIdentity.of(song).fingerprint;
      if (seen.add(key)) {
        result.add(song);
      }
    }
    return result;
  }
}
