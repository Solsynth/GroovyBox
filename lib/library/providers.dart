import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../widgets/common.dart';
import 'aggregate.dart';
import 'lrclib.dart';
import 'lyrics.dart';
import 'lyrics_resolver.dart';
import 'lyrics_store.dart';
import 'models.dart';
import 'source.dart';
import 'store.dart';

part 'providers.g.dart';

/// Every connected library, in the order the user added them.
@Riverpod(keepAlive: true)
List<LibrarySource> librarySources(Ref ref) => [
  for (final config in ref.watch(sourceStoreProvider))
    librarySourceFromConfig(config),
];

/// The same sources keyed by id, for resolving a stream or art URL from an
/// item that only carries `sourceId`.
@Riverpod(keepAlive: true)
Map<String, LibrarySource> librarySourceById(Ref ref) => {
  for (final source in ref.watch(librarySourcesProvider)) source.id: source,
};

/// The last failure of each source, so settings can show why it went quiet.
@Riverpod(keepAlive: true)
class SourceFailures extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void report(String sourceId, Object error) {
    state = {...state, sourceId: describeServerError(error)};
  }

  /// Drops one source's entry once it answers again.
  void clearSource(String sourceId) {
    if (!state.containsKey(sourceId)) return;
    state = {
      for (final entry in state.entries)
        if (entry.key != sourceId) entry.key: entry.value,
    };
  }

  void clear() => state = const {};
}

@Riverpod(keepAlive: true)
LibraryAggregator libraryAggregator(Ref ref) => LibraryAggregator(
  ref.watch(librarySourcesProvider),
  onFailure: (sourceId, error) =>
      ref.read(sourceFailuresProvider.notifier).report(sourceId, error),
  // Clearing here, rather than before the fan-out, keeps this out of the
  // window where a provider is still building: riverpod forbids one provider
  // mutating another during `build`.
  onSuccess: (sourceId) =>
      ref.read(sourceFailuresProvider.notifier).clearSource(sourceId),
);

/// Recently added albums, merged across every library.
@Riverpod(keepAlive: true)
class RecentAlbums extends AsyncNotifier<List<LibraryAlbum>> {
  @override
  Future<List<LibraryAlbum>> build() => _fetch();

  Future<List<LibraryAlbum>> _fetch() async {
    if (ref.watch(librarySourcesProvider).isEmpty) return const [];
    return ref.watch(libraryAggregatorProvider).recentlyAdded(limit: 50);
  }

  Future<void> refresh() async {
    ref.read(sourceFailuresProvider.notifier).clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// Songs from a random draw, used as the browse page's instant-play shelf.
@Riverpod(keepAlive: true)
class RandomSongs extends AsyncNotifier<List<LibrarySong>> {
  @override
  Future<List<LibrarySong>> build() => _fetch();

  Future<List<LibrarySong>> _fetch() async {
    if (ref.watch(librarySourcesProvider).isEmpty) return const [];
    return ref.watch(libraryAggregatorProvider).randomSongs(size: 40);
  }

  Future<void> refresh() async {
    ref.read(sourceFailuresProvider.notifier).clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// The user's playlists, merged across every library.
@Riverpod(keepAlive: true)
class Playlists extends AsyncNotifier<List<LibraryPlaylist>> {
  @override
  Future<List<LibraryPlaylist>> build() => _fetch();

  Future<List<LibraryPlaylist>> _fetch() async {
    if (ref.watch(librarySourcesProvider).isEmpty) return const [];
    return ref.watch(libraryAggregatorProvider).playlists();
  }

  Future<void> refresh() async {
    ref.read(sourceFailuresProvider.notifier).clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// Songs of one album, read straight from its own source.
@riverpod
Future<List<LibrarySong>> albumSongs(Ref ref, LibraryRef album) async {
  final source = ref.watch(librarySourceByIdProvider)[album.sourceId];
  if (source == null) return const [];
  return source.albumSongs(album.id);
}

/// Songs of one playlist, read straight from its own source.
@riverpod
Future<List<LibrarySong>> playlistSongs(Ref ref, LibraryRef playlist) async {
  final source = ref.watch(librarySourceByIdProvider)[playlist.sourceId];
  if (source == null) return const [];
  return source.playlistSongs(playlist.id);
}

/// Search results for the browse page's field. Empty query = no request.
@riverpod
Future<List<LibrarySong>> searchSongs(Ref ref, String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  if (ref.watch(librarySourcesProvider).isEmpty) return const [];
  return ref.watch(libraryAggregatorProvider).search(trimmed);
}

/// The lyrics cache, opened in `main` and injected into the container.
///
/// Overriding it keeps the store synchronous to read, and keeps the database
/// out of widget tests, which have no platform channel to open one through. A
/// machine where it could not be opened gets null: playback and lyrics still
/// work, they just ask the network every time.
@Riverpod(keepAlive: true)
LyricsCache? lyricsCache(Ref ref) =>
    throw StateError('lyricsCache must be overridden in main()');

/// The LRCLIB client, shared so its rate-limit state is too.
@Riverpod(keepAlive: true)
Lrclib lrclib(Ref ref) => Lrclib();

/// Resolves lyrics: stored answer first, then the library, then LRCLIB.
@Riverpod(keepAlive: true)
Future<LyricsResolver> lyricsResolver(Ref ref) async => LyricsResolver(
  cache: ref.watch(lyricsCacheProvider),
  lrclib: ref.watch(lrclibProvider),
  // Read, not watch: the resolver is long-lived and must see the library list
  // as it is at the moment of a lookup, including one added mid-session.
  sourceFor: (sourceId) => ref.read(librarySourceByIdProvider)[sourceId],
);

/// Lyrics of one song, from the cache or the network.
///
/// Kept for the session as well as on disk: the pane is rebuilt on every
/// position tick's parent rebuild, and a family entry means it never asks
/// twice for the track it is already showing.
@Riverpod(keepAlive: true)
Future<Lyrics> songLyrics(Ref ref, LyricsRequest song) async {
  final resolver = await ref.watch(lyricsResolverProvider.future);
  return resolver.resolve(song);
}

/// How many songs have a stored lyric, for the settings row.
@Riverpod(keepAlive: true)
Future<int> storedLyrics(Ref ref) async {
  final cache = ref.watch(lyricsCacheProvider);
  return await cache?.count() ?? 0;
}

/// Actions the lyrics UI needs beyond reading: re-ask the network, forget a
/// library's downloads, empty the cache.
@Riverpod(keepAlive: true)
class LyricsMaintenance extends Notifier<void> {
  @override
  void build() {}

  /// Forgets one song and rebuilds its pane, so a wrong or missing lyric is
  /// fetched again instead of served from disk.
  Future<void> refresh(LyricsRequest song) async {
    final resolver = await ref.read(lyricsResolverProvider.future);
    await resolver.forget(song);
    ref.invalidate(songLyricsProvider(song));
    ref.invalidate(storedLyricsProvider);
  }

  /// Drops the downloads of a library that is no longer connected.
  Future<void> forgetSource(String sourceId) async {
    final resolver = await ref.read(lyricsResolverProvider.future);
    await resolver.forgetSource(sourceId);
    ref.invalidate(storedLyricsProvider);
  }

  /// Empties every stored lyric; the next play downloads again.
  Future<void> clear() async {
    final cache = ref.read(lyricsCacheProvider);
    if (cache == null) return;
    await cache.clear();
    ref.invalidate(songLyricsProvider);
    ref.invalidate(storedLyricsProvider);
  }
}
