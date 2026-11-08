import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/local/library_database.dart';
import '../widgets/common.dart';
import 'aggregate.dart';
import 'catalog.dart';
import 'local_library.dart';
import 'lrclib.dart';
import 'lyrics.dart';
import 'lyrics_resolver.dart';
import 'lyrics_store.dart';
import 'models.dart';
import 'source.dart';
import 'store.dart';

part 'providers.g.dart';

/// Where imported files live, injected by `main` once the platform has told
/// the app its support directory. Null in tests and on a platform that cannot
/// provide one, which simply means no local library.
@Riverpod(keepAlive: true)
String? localLibraryPath(Ref ref) => null;

/// The library this device owns, or null when it cannot exist (no database,
/// or no storage directory).
@Riverpod(keepAlive: true)
LocalLibrarySource? localLibrary(Ref ref) {
  final database = ref.watch(libraryDatabaseProvider);
  final path = ref.watch(localLibraryPathProvider);
  if (database == null || path == null) return null;
  return LocalLibrarySource(database: database, directory: path);
}

/// Every connected library, in the order the user added them.
///
/// Servers only: [librarySourcesWithLocalProvider] is what reads from when the
/// question is "what music is there".
@Riverpod(keepAlive: true)
List<LibrarySource> librarySources(Ref ref) => [
  for (final config in ref.watch(sourceStoreProvider))
    librarySourceFromConfig(config),
];

/// Everything that can serve music: the local library first, then the servers.
///
/// Local files come first because they are the ones guaranteed to answer; a
/// dead server must not push a device's own music down a merged list.
@Riverpod(keepAlive: true)
List<LibrarySource> librarySourcesWithLocal(Ref ref) => [
  ?ref.watch(localLibraryProvider),
  ...ref.watch(librarySourcesProvider),
];

/// The same sources keyed by id, for resolving a stream or art URL from an
/// item that only carries `sourceId`.
@Riverpod(keepAlive: true)
Map<String, LibrarySource> librarySourceById(Ref ref) => {
  for (final source in ref.watch(librarySourcesWithLocalProvider))
    source.id: source,
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

/// Folds every read into the local library, so songs are adopted as the user
/// browses rather than waiting for a full sync that does not exist yet.
///
/// Adoption is fire-and-forget: a read must never be slower, or fail, because
/// the local database did, and a song that was not adopted is picked up by the
/// next read that mentions it.
@Riverpod(keepAlive: true)
LibraryAggregator libraryAggregator(Ref ref) {
  final catalog = ref.watch(libraryCatalogProvider);
  void adopt(Iterable<LibrarySong> songs) {
    if (catalog == null) return;
    catalog.adoptAll(songs).catchError((Object error) {
      debugPrint('[Library] Could not store songs: $error');
    });
  }

  return LibraryAggregator(
    ref.watch(librarySourcesWithLocalProvider),
    onSongs: adopt,
    onFailure: (sourceId, error) =>
        ref.read(sourceFailuresProvider.notifier).report(sourceId, error),
    // Clearing here, rather than before the fan-out, keeps this out of the
    // window where a provider is still building: riverpod forbids one provider
    // mutating another during `build`.
    onSuccess: (sourceId) =>
        ref.read(sourceFailuresProvider.notifier).clearSource(sourceId),
  );
}

/// Recently added albums, merged across every library.
@Riverpod(keepAlive: true)
class RecentAlbums extends AsyncNotifier<List<LibraryAlbum>> {
  @override
  Future<List<LibraryAlbum>> build() => _fetch();

  Future<List<LibraryAlbum>> _fetch() async {
    if (ref.watch(librarySourcesWithLocalProvider).isEmpty) return const [];
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
    if (ref.watch(librarySourcesWithLocalProvider).isEmpty) return const [];
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
    if (ref.watch(librarySourcesWithLocalProvider).isEmpty) return const [];
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
  if (ref.watch(librarySourcesWithLocalProvider).isEmpty) return const [];
  return ref.watch(libraryAggregatorProvider).search(trimmed);
}

/// The local library, opened in `main` and injected into the container.
///
/// Overriding it keeps the catalog and the lyrics store synchronous to read,
/// and keeps the database out of widget tests, which have no platform channel
/// to open one through. A machine where it could not be opened gets null:
/// playback and lyrics still work, they just ask the network every time and
/// keep no history.
@Riverpod(keepAlive: true)
LibraryDatabase? libraryDatabase(Ref ref) => null;

/// The app's view of the local library.
@Riverpod(keepAlive: true)
LibraryCatalog? libraryCatalog(Ref ref) {
  final database = ref.watch(libraryDatabaseProvider);
  return database == null ? null : LibraryCatalog(database);
}

/// The stored lyrics of each track.
@Riverpod(keepAlive: true)
LyricsStore? lyricsStore(Ref ref) {
  final database = ref.watch(libraryDatabaseProvider);
  return database == null ? null : LyricsStore(database);
}

/// The LRCLIB client, shared so its rate-limit state is too.
@Riverpod(keepAlive: true)
Lrclib lrclib(Ref ref) => Lrclib();

/// Resolves lyrics: stored answer first, then the library, then LRCLIB.
@Riverpod(keepAlive: true)
Future<LyricsResolver> lyricsResolver(Ref ref) async => LyricsResolver(
  catalog: ref.watch(libraryCatalogProvider),
  store: ref.watch(lyricsStoreProvider),
  lrclib: ref.watch(lrclibProvider),
  // Read, not watch: the resolver is long-lived and must see the library list
  // as it is at the moment of a lookup, including one added mid-session.
  sourceFor: (sourceId) => ref.read(librarySourceByIdProvider)[sourceId],
);

/// Lyrics of one song, from the local library or the network.
///
/// Kept for the session as well as on disk: the pane is rebuilt on every
/// position tick's parent rebuild, and a family entry means it never asks
/// twice for the track it is already showing.
/// [languageCode] is the app's current language, so a translation is generated
/// in the language the interface is actually in. A language change gives the
/// family a new argument, which refetches instead of serving the old one.
@Riverpod(keepAlive: true)
Future<Lyrics> songLyrics(
  Ref ref,
  LyricsRequest song, {
  String? languageCode,
}) async {
  final resolver = await ref.watch(lyricsResolverProvider.future);
  return resolver.resolve(song, languageCode: languageCode);
}

/// How many tracks have a stored lyric, for the settings row.
///
/// Auto-disposed rather than kept: a count read when the page opened would be
/// wrong once a track has played, and re-reading is one `COUNT(*)`.
@riverpod
Future<int> storedLyrics(Ref ref) async =>
    await ref.watch(lyricsStoreProvider)?.count() ?? 0;

/// How many songs the local library knows, and how many of them no connected
/// source can play any more, for the settings row.
@riverpod
Future<({int tracks, int orphaned})> libraryStats(Ref ref) async {
  final catalog = ref.watch(libraryCatalogProvider);
  if (catalog == null) return (tracks: 0, orphaned: 0);
  return catalog.libraryCounts();
}

/// What the play history says, for the stats page.
///
/// Auto-disposed and rebuilt on open: the page is a summary of a database that
/// changes as music plays, and re-reading it is a handful of aggregate
/// queries, not a sync.
@riverpod
Future<ListeningStats> listeningStats(Ref ref) async {
  final catalog = ref.watch(libraryCatalogProvider);
  if (catalog == null) return ListeningStats.none;
  return catalog.listeningStats();
}

/// Actions the library UI needs beyond reading: re-ask the network, forget a
/// removed source, empty the stored lyrics.
@Riverpod(keepAlive: true)
class LyricsMaintenance extends Notifier<void> {
  @override
  void build() {}

  /// Forgets one song and rebuilds its pane, so a wrong or missing lyric is
  /// fetched again instead of served from disk.
  ///
  /// [languageCode] must match the one the pane watches with, or the family
  /// entry holding what is on screen is not the one invalidated.
  Future<void> refresh(LyricsRequest song, {String? languageCode}) async {
    final resolver = await ref.read(lyricsResolverProvider.future);
    await resolver.forget(song);
    ref.invalidate(
      songLyricsProvider(song, languageCode: languageCode),
    );
    ref.invalidate(storedLyricsProvider);
  }

  /// Drops the links and downloads of a library that is no longer connected.
  /// The tracks themselves stay: re-adding the same server, or adding another
  /// one with the same songs, adopts them again by fingerprint.
  Future<void> forgetSource(String sourceId) async {
    await ref.read(libraryCatalogProvider)?.forgetSource(sourceId);
    ref.invalidate(storedLyricsProvider);
    ref.invalidate(libraryStatsProvider);
  }

  /// Empties every stored lyric; the next play downloads again.
  Future<void> clear() async {
    final store = ref.read(lyricsStoreProvider);
    if (store == null) return;
    await store.clear();
    ref.invalidate(songLyricsProvider);
    ref.invalidate(storedLyricsProvider);
  }
}
