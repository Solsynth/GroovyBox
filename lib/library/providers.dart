import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/app.dart';
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
import '../library_sync/queue.dart';
import 'store.dart';
import 'track_identity.dart';

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

/// The shelves the connected libraries curate themselves, in source order.
///
/// Only a source that owns a cloud account has anything here (Apple Music's
/// personal mixes, heavy rotation and station suggestions); a server library
/// contributes nothing, and the page's own shelves carry it.
@Riverpod(keepAlive: true)
class LandingShelves extends AsyncNotifier<List<LandingShelf>> {
  @override
  Future<List<LandingShelf>> build() => _fetch();

  Future<List<LandingShelf>> _fetch() async {
    final sources = [
      for (final source in ref.watch(librarySourcesWithLocalProvider))
        if (source is CuratedSource) source,
    ];
    if (sources.isEmpty) return const [];

    final results = await Future.wait([
      for (final source in sources)
        source.landingShelves().catchError((Object error) {
          debugPrint('[Library] ${source.displayName} shelves: $error');
          return const <LandingShelf>[];
        }),
    ]);
    return [for (final shelves in results) ...shelves];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// What each connected account says about itself, for the landing page's
/// header card. Empty when no source has anything of its own to report.
@Riverpod(keepAlive: true)
class LibraryDigests extends AsyncNotifier<List<LibraryDigest>> {
  @override
  Future<List<LibraryDigest>> build() => _fetch();

  Future<List<LibraryDigest>> _fetch() async {
    final sources = [
      for (final source in ref.watch(librarySourcesWithLocalProvider))
        if (source is CuratedSource) source,
    ];
    if (sources.isEmpty) return const [];

    final digests = await Future.wait([
      for (final source in sources)
        source.digest().catchError((Object error) {
          debugPrint('[Library] ${source.displayName} digest: $error');
          return null;
        }),
    ]);
    return [
      for (final digest in digests)
        if (digest != null && !digest.isEmpty) digest,
    ];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// The stores that can be searched beyond what the account already holds.
@Riverpod(keepAlive: true)
List<ExtendableSource> extendableSources(Ref ref) => [
  for (final source in ref.watch(librarySourcesWithLocalProvider))
    if (source is ExtendableSource) source,
];

/// A store search, fanned out over every library that has a store.
///
/// Empty query = no request: the field is the whole flow, so typing is what
/// asks.
@riverpod
Future<CatalogSearch> catalogSearch(Ref ref, String query) async {
  final term = query.trim();
  if (term.isEmpty) return const CatalogSearch();
  final sources = ref.watch(extendableSourcesProvider);
  if (sources.isEmpty) return const CatalogSearch();

  final results = await Future.wait([
    for (final source in sources)
      source.searchCatalog(term).catchError((Object error) {
        debugPrint('[Library] catalog search on ${source.displayName}: $error');
        return const CatalogSearch();
      }),
  ]);
  var merged = const CatalogSearch();
  for (final result in results) {
    merged = merged.merge(result);
  }
  return merged;
}

/// Adds catalog items to the account that owns the store they came from.
///
/// A write, and the one place the app changes the user's account: it is only
/// ever reached from an explicit action, never from a read or a play.
@Riverpod(keepAlive: true)
class LibraryEditor extends Notifier<void> {
  @override
  void build() {}

  Future<int> add(CatalogKind kind, LibraryRef source, List<String> ids) async {
    final library = ref.read(librarySourceByIdProvider)[source.sourceId];
    if (library is! ExtendableSource) return 0;
    final added = await library.addToLibrary(kind, ids);
    // The read providers would otherwise keep serving the library as it was:
    // what was just added has to appear without a restart.
    ref.invalidate(libraryAggregatorProvider);
    ref.invalidate(recentAlbumsProvider);
    ref.invalidate(landingShelvesProvider);
    return added;
  }
}

/// Every connected library's copy of one song, for the "other versions" sheet.
///
/// Two sources of truth, merged. The catalog knows the copies the app has
/// already seen — instant, offline, and the only way to find a local file. The
/// other libraries are *asked*, because a song this library has but another
/// does not yet show in a browse is exactly the case a lookup is for.
///
/// Auto-disposed: the sheet is opened for one track and closed again.
@riverpod
Future<List<TrackCopy>> songCopies(Ref ref, TrackLookup lookup) async {
  final sources = ref.watch(librarySourceByIdProvider);
  final catalog = ref.watch(libraryCatalogProvider);
  final song = lookup.song;

  final known = catalog == null
      ? const <TrackCopy>[]
      : await catalog.copiesOfSong(
          song,
          connectedSourceIds: sources.keys.toSet(),
        );
  // The track the user is looking at is always one of the answers, even when
  // the catalog has never seen it: it is the copy they currently have.
  final bySource = {
    song.sourceId: TrackCopy(
      sourceId: song.sourceId,
      externalId: song.id,
      song: song,
      playable: sources.containsKey(song.sourceId),
    ),
    for (final copy in known)
      if (copy.playable) copy.sourceId: copy,
  };

  final others = [
    for (final source in sources.values)
      if (source.id != song.sourceId) source,
  ];
  if (others.isEmpty) return bySource.values.toList();

  // Title and artist, not the album: a copy in another library is usually
  // tagged with that library's own album, and an album match would miss it.
  final query = [song.artist, song.title].whereType<String>().join(' ');
  final identity = TrackIdentity.of(song);
  final results = await Future.wait([
    for (final source in others)
      source.search(query, limit: 20).catchError((Object error) {
        debugPrint('[Library] lookup on ${source.displayName}: $error');
        return const <LibrarySong>[];
      }),
  ]);

  for (var index = 0; index < others.length; index++) {
    final source = others[index];
    if (bySource.containsKey(source.id)) continue;
    final match = results[index]
        .where((candidate) => identity.matches(TrackIdentity.of(candidate)))
        .firstOrNull;
    if (match == null) continue;
    bySource[source.id] = TrackCopy(
      sourceId: source.id,
      externalId: match.id,
      song: match,
    );
  }

  // The source the track was opened from comes first; the rest keep the
  // order the user connected them in.
  final ordered = bySource.values.toList()
    ..sort((a, b) {
      if (a.sourceId == song.sourceId) return -1;
      if (b.sourceId == song.sourceId) return 1;
      return 0;
    });
  return ordered;
}

/// Songs of one album, read straight from its own source./// Songs of one album, read straight from its own source.
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
/// Every artist the connected libraries list, merged in source order.
///
/// An artist is a native id plus a name, and ids are only unique within one
/// source — so the artist page is addressed by [LibraryRef], and the same
/// name on two servers stays two rows rather than collapsing into one the
/// way a merged album list would want it to.
@Riverpod(keepAlive: true)
class LibraryArtists extends AsyncNotifier<List<LibraryArtist>> {
  @override
  Future<List<LibraryArtist>> build() => _fetch();

  Future<List<LibraryArtist>> _fetch() async {
    if (ref.watch(librarySourcesWithLocalProvider).isEmpty) return const [];
    return ref.watch(libraryAggregatorProvider).artists();
  }

  Future<void> refresh() async {
    ref.read(sourceFailuresProvider.notifier).clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// The albums one source says an artist recorded.
///
/// Asked of the artist's own library, not fanned out: an artist id is only
/// meaningful there, and another source's answer would describe a different
/// person who happens to share the name.
@riverpod
Future<List<LibraryAlbum>> artistAlbums(Ref ref, LibraryRef artist) async {
  final source = ref.watch(librarySourceByIdProvider)[artist.sourceId];
  if (source == null) return const [];
  return source.artistAlbums(artist.id);
}

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
///
/// Its deletion callbacks queue the matching tombstones for Library Sync, so a
/// forgotten source or a dropped lyric propagates to the other devices.
@Riverpod(keepAlive: true)
LibraryCatalog? libraryCatalog(Ref ref) {
  final database = ref.watch(libraryDatabaseProvider);
  if (database == null) return null;
  final prefs = ref.watch(sharedPreferencesProvider);
  return LibraryCatalog(
    database,
    onLinksForgotten: (sourceId, externalIds) =>
        queueLinkDeletes(prefs, sourceId, externalIds),
  );
}

/// The stored lyrics of each track.
@Riverpod(keepAlive: true)
LyricsStore? lyricsStore(Ref ref) {
  final database = ref.watch(libraryDatabaseProvider);
  if (database == null) return null;
  final prefs = ref.watch(sharedPreferencesProvider);
  return LyricsStore(
    database,
    onDropped: (fingerprints) => queueLyricsDeletes(prefs, fingerprints),
  );
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
    ref.invalidate(songLyricsProvider(song, languageCode: languageCode));
    ref.invalidate(storedLyricsProvider);
  }

  /// Drops the links and downloads of a library that is no longer connected.
  /// The tracks themselves stay: re-adding the same server, or adding another
  /// one with the same songs, adopts them again by fingerprint.
  Future<void> forgetSource(String sourceId) async {
    // forgetSource itself queues the link tombstones; a sync picks them up on
    // the next push.
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

/// The device's record of favourites: read it, and write it.
///
/// No notifier state. The heart's value belongs to the widget that draws it,
/// and a provider whose state is written from `didChangeDependencies` mutates
/// the container while the tree is building — which Riverpod rightly refuses.
/// The database is the record; this class is the one way to reach it.
class Favourites {
  const Favourites(this._ref);

  final Ref _ref;

  /// The device's answer for [song], falling back to the connected source the
  /// first time. Null only when neither has an opinion.
  Future<bool?> read(LibrarySong song) async {
    final catalog = _ref.read(libraryCatalogProvider);
    if (catalog != null) {
      final local = await catalog.favouriteOf(song);
      if (local != null) return local;
    }
    final source = _ref.read(librarySourceByIdProvider)[song.sourceId];
    if (source is RatedSource) {
      try {
        return await source.isFavourite(song);
      } on LibraryException {
        return false;
      }
    }
    return null;
  }

  /// Writes the device's answer, then forwards it to the source.
  ///
  /// The local write is the record; the forward is best effort. [forwardError]
  /// is what the caller shows, and it is null when the source agreed or when
  /// there was no source to ask.
  Future<Object?> set(LibrarySong song, {required bool value}) async {
    await _ref.read(libraryCatalogProvider)?.setFavourite(song, value: value);
    final source = _ref.read(librarySourceByIdProvider)[song.sourceId];
    if (source is! RatedSource || song.isRadio) return null;
    try {
      await source.setFavourite(song, value: value);
      return null;
    } catch (error) {
      // The device keeps the answer; the source simply does not know yet.
      return error;
    }
  }
}

@Riverpod(keepAlive: true)
Favourites favourites(Ref ref) => Favourites(ref);

/// The device's own playlists, and the source's when the account has any.
///
/// Device playlists exist before a library does and survive every server being
/// swapped, so they are the primary list. A source that can edit its own
/// playlists is a second section, not a replacement: adding there writes to
/// that account, which the app does not own.
@Riverpod(keepAlive: true)
class OwnedPlaylists extends AsyncNotifier<List<OwnedPlaylist>> {
  @override
  Future<List<OwnedPlaylist>> build() async {
    final catalog = ref.watch(libraryCatalogProvider);
    if (catalog == null) return const [];
    return catalog.ownedPlaylists();
  }

  /// Creates a playlist and returns it, so a caller can add to it immediately.
  Future<OwnedPlaylist?> create(String name) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return null;
    final playlist = await catalog.createPlaylist(name);
    ref.invalidateSelf();
    return playlist;
  }

  /// Puts [songs] at the end of [playlistId].
  Future<void> add(int playlistId, List<LibrarySong> songs) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return;
    await catalog.addToOwnedPlaylist(playlistId, songs);
    ref.invalidateSelf();
  }

  /// Removes one track from a device-owned playlist.
  Future<void> removeSong(int playlistId, int entryId) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return;
    await catalog.removeFromOwnedPlaylist(playlistId, entryId);
    ref.invalidateSelf();
  }

  /// Renames a device-owned playlist.
  Future<void> rename(int playlistId, String name) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return;
    await catalog.renameOwnedPlaylist(playlistId, name);
    ref.invalidateSelf();
  }

  /// Removes a device-owned playlist.
  Future<void> delete(int playlistId) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return;
    await catalog.deleteOwnedPlaylist(playlistId);
    ref.invalidateSelf();
  }

  /// The songs of one owned playlist, in order.
  Future<List<LibrarySong>> songsOf(int playlistId) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return const [];
    return catalog.ownedPlaylistSongs(playlistId);
  }
}

/// One row of [ownedPlaylistEntries]: the song in order, with the entry id
/// the remove action needs. A plain list of [LibrarySong] would lose that
/// handle, and a remove that guessed by position would delete a different
/// track after any edit shifted the order.
class OwnedPlaylistEntry {
  final int entryId;
  final LibrarySong song;

  /// The row's place in the list, for the track-number column.
  final int position;

  const OwnedPlaylistEntry({
    required this.entryId,
    required this.song,
    required this.position,
  });
}

/// The entries of one owned playlist, in the order the user put them.
@riverpod
Future<List<OwnedPlaylistEntry>> ownedPlaylistEntries(
  Ref ref,
  int playlistId,
) async {
  final catalog = ref.watch(libraryCatalogProvider);
  if (catalog == null) return const [];
  final rows = await catalog.ownedPlaylistEntryRows(playlistId);
  return [
    for (final (index, entry) in rows.indexed)
      OwnedPlaylistEntry(entryId: entry.$1, song: entry.$2, position: index),
  ];
}

/// Where the playing track's words come from, as a translation key resolved
/// by the caller.
///
/// Reads the stored answer directly — no fetch — so a sheet showing it opens
/// instantly and describes only what the track already has. Whether LRCLIB
/// *could* answer is a question for the lyrics pane, which asks on demand.
@riverpod
Future<LyricsOrigin> lyricsOrigin(Ref ref, LibrarySong song) async {
  final catalog = ref.watch(libraryCatalogProvider);
  final store = ref.watch(lyricsStoreProvider);
  if (catalog == null || store == null) return LyricsOrigin.none;
  try {
    final trackId = await catalog.requestTrackId(LyricsRequest.of(song));
    final stored = await store.read(trackId);
    return stored?.origin ?? LyricsOrigin.none;
  } catch (_) {
    return LyricsOrigin.none;
  }
}

/// Whether the device remembers [song] as a favourite.
///
/// A FutureProvider, not a Notifier: the database is the record and writes
/// invalidate this family, so every surface showing the answer rebuilds from
/// the same source of truth instead of each caching its own.
@riverpod
Future<bool> favouriteState(Ref ref, LibrarySong song) async {
  final answer = await ref.watch(favouritesProvider).read(song);
  return answer ?? false;
}
