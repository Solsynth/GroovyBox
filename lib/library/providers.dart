import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../widgets/common.dart';
import 'aggregate.dart';
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
