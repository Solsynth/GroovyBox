import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/app.dart';
import '../data/local/library_database.dart';
import '../widgets/common.dart';
import 'aggregate.dart';
import 'catalog.dart';
import 'http_cache.dart';
import 'local_library.dart';
import 'lookup.dart';
import 'lrclib.dart';
import 'lyrics.dart';
import 'lyrics_query.dart';
import 'lyrics_resolver.dart';
import 'lyrics_store.dart';
import 'models.dart';
import 'netease_adapter.dart';
import 'smart_shuffle.dart';
import 'source.dart';
import 'plugins/plugin_host.dart';
import 'plugins/plugin_schema.dart';
import '../library_sync/queue.dart';
import 'store.dart';
import 'track_identity.dart';

import 'lyrics_enricher.dart';
import 'lyrics_translator.dart';

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
@Riverpod(keepAlive: true)
List<LibrarySource> librarySources(Ref ref) {
  final cache = ref.watch(responseCacheProvider);
  return [
    for (final config in ref.watch(sourceStoreProvider))
      librarySourceFromConfig(config, cache: cache),
  ];
}

/// Providers contributed by installed plugins, empty when none is installed.
///
/// Reads the process-wide host and rebuilds when it changes, so installing a
/// plugin mid-session updates the setup picker and the settings card without a
/// restart. Nothing else in the library chain changes: a plugin source is an
/// ordinary stored config, resolved by `librarySourceFromConfig`.
@Riverpod(keepAlive: true)
List<PluginProvider> pluginProviders(Ref ref) {
  final host = PluginHost.instance;
  if (host == null) return const [];
  void listener() => ref.invalidateSelf();
  ref.onDispose(() => host.removeListener(listener));
  host.addListener(listener);
  return host.providers;
}

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

/// The device's copy of every library's answers: what makes a screen show
/// what it last showed when the network is gone.
///
/// Built from the database, which every source already shares, so no second
/// storage decision had to be made for it. Null without a database, exactly
/// like [libraryCatalogProvider]: the app then reads from the network only.
@Riverpod(keepAlive: true)
ResponseCache? responseCache(Ref ref) {
  final database = ref.watch(libraryDatabaseProvider);
  if (database == null) return null;
  final cache = ResponseCache(
    database,
    // A disk-served answer is visible where a failure already shows: the
    // settings row names the library, so "offline" never looks like "the
    // server changed".
    onServedStale: (scopeId) => ref
        .read(sourceFailuresProvider.notifier)
        .report(scopeId, offlineCachedFailure),
  );
  // The plugin host makes its own requests, so it is handed the cache here
  // rather than through an adapter: its scope is per provider, not per
  // config, and the host outlives every source object.
  PluginHost.instance?.cache = cache;
  return cache;
}

/// How many answers are cached and how many bytes they take, for Settings.
@riverpod
Future<({int count, int bytes})> responseCacheTotals(Ref ref) async {
  final cache = ref.watch(responseCacheProvider);
  if (cache == null) return (count: 0, bytes: 0);
  return cache.totals();
}

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

/// What each connected account says about itself, for the row that manages
/// that connection. Empty when no source has anything of its own to report.
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
    // what was just added has to appear without a restart. The search
    // families are in the list because a held track is what the Library tab
    // answers with and what the Explore tab filters out — the two must not
    // disagree about the row that was just added.
    ref
      ..invalidate(libraryAggregatorProvider)
      ..invalidate(recentAlbumsProvider)
      ..invalidate(landingShelvesProvider)
      ..invalidate(playlistsProvider)
      ..invalidate(searchSongsProvider)
      ..invalidate(catalogSearchProvider);
    return added;
  }
}

/// Every connected library's copy of one song, for the "other versions" sheet.
///
/// The lookup itself is [findCopies]: playback asks the same question when a
/// provider only sells a trial excerpt, so the two answers can never disagree
/// about which libraries hold the track.
///
/// Auto-disposed: the sheet is opened for one track and closed again.
@riverpod
Future<List<TrackCopy>> songCopies(Ref ref, TrackLookup lookup) => findCopies(
  lookup.song,
  sources: ref.watch(librarySourceByIdProvider),
  catalog: ref.watch(libraryCatalogProvider),
);

/// Songs of one album, read straight from its own source./// Songs of one album, read straight from its own source.
@riverpod
Future<List<LibrarySong>> albumSongs(Ref ref, LibraryRef album) async {
  final source = ref.watch(librarySourceByIdProvider)[album.sourceId];
  if (source == null) return const [];
  return source.albumSongs(album.id);
}

/// One album as its own source describes it, independent of its tracks.
///
/// A store album the account never added answers with no tracklist but is
/// still a record with a name, a year and a cover — which is what the album
/// page's hero needs to draw when the library has nothing to list. Null when
/// the source is gone or does not know the id; the page then falls back to
/// what its route carried.
@riverpod
Future<LibraryAlbum?> albumInfo(Ref ref, LibraryRef album) async {
  final source = ref.watch(librarySourceByIdProvider)[album.sourceId];
  if (source == null) return null;
  try {
    return await source.album(album.id);
  } catch (error) {
    // A store album the account never added, a bridge that answers 301, a
    // server that does not know the id: every one of those is "no record",
    // not a reason to fail the page that already knows the name.
    debugPrint('[Library] album ${album.id} on ${album.sourceId}: $error');
    return null;
  }
}

/// The tracks of one album, from wherever they can be played.
///
/// A cloud account is the case this exists for: Apple Music and NetEase hand
/// a page an album id their own endpoints refuse to turn into tracks — a
/// store album the account never added, a bridge that answers 301 — so the
/// album page would open empty beside a title it already knows. The album is
/// not empty; this device simply cannot ask for it there.
///
/// The fallback is the other connected libraries, found by the record's own
/// title and artist and kept only when the album title matches: a different
/// record with a similar name is not this album. Each row keeps its own
/// source, so a copy found on the server plays from the server.
///
/// [AlbumTracksTarget.title] is the name the route carried, used when the
/// album's own source cannot describe it either.
typedef AlbumTracksTarget = ({LibraryRef album, String? title});

@riverpod
Future<List<LibrarySong>> albumTracks(Ref ref, AlbumTracksTarget target) async {
  final album = target.album;
  final own = await ref.watch(albumSongsProvider(album).future);
  if (own.isNotEmpty) return own;
  final info = await ref.watch(albumInfoProvider(album).future);
  final name = (info?.name ?? target.title)?.trim();
  if (name == null || name.isEmpty) return const [];
  final title = name.toLowerCase();
  final artist = info?.artist?.trim().toLowerCase();
  // The wide question: the copy may live in a store the account never added,
  // and a server's holdings are its catalogue anyway.
  final found = await ref
      .watch(libraryAggregatorProvider)
      .searchCatalogue([info?.artist, name].whereType<String>().join(' '));
  return [
    for (final song in found)
      if (song.sourceId != album.sourceId &&
          (song.album ?? '').trim().toLowerCase() == title &&
          (artist == null ||
              (song.albumArtist ?? song.artist ?? '').trim().toLowerCase() ==
                  artist))
        song,
  ];
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

/// A record the fleet names, as this device could actually open it.
///
/// The artist page's discography is the fleet's: a record the connected
/// libraries do not list is a row with no id to open, which is why those
/// tiles were inert. This is the other half of that answer — the same record
/// found where it *can* be played.
///
/// Two questions, cheapest first. The connected libraries are asked for the
/// record by title and credit and kept only where the title matches; a store
/// is asked only when none of them has it, and its row counts only when the
/// store can also list the tracks ([LibrarySource.albumSongs]) — a result a
/// page cannot open is the same dead end the tile already was.
///
/// Null is the honest answer for a record nobody here has, and the tile stays
/// inert rather than opening an empty page.
typedef DiscoveredAlbumTarget = ({String title, String? artist});

@riverpod
Future<LibraryAlbum?> discoveredAlbum(
  Ref ref,
  DiscoveredAlbumTarget target,
) async {
  final title = trackTitleKey(target.title);
  if (title.isEmpty) return null;
  final artist = target.artist?.trim();
  final sources = ref.watch(librarySourceByIdProvider);

  bool matches(LibraryAlbum album) {
    if (trackTitleKey(album.name) != title) return false;
    if (artist == null || artist.isEmpty) return true;
    // The credit is compared the way the catalog compares two libraries'
    // spellings of it, so an ampersand or a missing "The" does not hide the
    // record.
    final wanted = trackArtistWords(artist);
    final theirs = trackArtistWords(album.artist);
    return wanted.isEmpty ||
        theirs.isEmpty ||
        wanted.intersection(theirs).isNotEmpty;
  }

  // What this device can already play: instant, offline, and answered by a
  // server's holdings as much as by a store's trial copy.
  final query = [target.artist, target.title].whereType<String>().join(' ');
  final held = await ref
      .watch(libraryAggregatorProvider)
      .searchCatalogue(query);
  for (final song in held) {
    final id = song.albumId;
    final album = song.album;
    if (id == null || album == null) continue;
    final candidate = LibraryAlbum(
      sourceId: song.sourceId,
      id: id,
      name: album,
      artist: song.albumArtist ?? song.artist,
      artId: song.artId,
      duration: Duration.zero,
      year: song.year,
    );
    if (sources.containsKey(song.sourceId) && matches(candidate)) {
      return candidate;
    }
  }

  // A server cannot answer what the holdings search just missed — its
  // catalogue is its holdings — so only a store is asked, and only for a
  // record the store can also turn into tracks: a page that opens on "empty"
  // is the dead end this lookup exists to avoid.
  for (final source in sources.values) {
    if (source is! ExtendableSource) continue;
    try {
      final found = await source.searchCatalog(query);
      for (final album in found.albums.where(matches)) {
        final tracks = await source.albumSongs(album.id);
        if (tracks.isNotEmpty) return album;
      }
    } catch (error) {
      // One store refusing is not the record's absence: the next one, or the
      // tile staying inert, is still an answer.
      debugPrint('[Library] store lookup of "${target.title}": $error');
    }
  }
  return null;
}

@riverpod
Future<List<LibrarySong>> searchSongs(Ref ref, String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  if (ref.watch(librarySourcesWithLocalProvider).isEmpty) return const [];
  return ref.watch(libraryAggregatorProvider).search(trimmed);
}

/// The artists and albums the libraries hold that match [query].
///
/// The search page's other two sections: one search field answers three
/// kinds, and only the songs were ever asked for. Kept as its own provider so
/// a page section can fold without costing the songs their answer, and so the
/// two requests can land in either order.
///
/// Additive by design: a library that cannot enumerate its artists (a plugin
/// without the capability, a server mid-restart) answers here with nothing
/// rather than failing the page. The songs still carry the failure, and the
/// search field still answered the question the reader asked.
@riverpod
Future<LibraryGroups> searchGroups(Ref ref, String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const LibraryGroups();
  if (ref.watch(librarySourcesWithLocalProvider).isEmpty) {
    return const LibraryGroups();
  }
  try {
    return await ref.watch(libraryAggregatorProvider).searchGroups(trimmed);
  } catch (error) {
    debugPrint('[Library] group search for "$trimmed": $error');
    return const LibraryGroups();
  }
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

/// Every service that can find a song's words by title and artist, in the
/// order they are asked.
///
/// LRCLIB first: it is vetted, keyed by recording, and needs no account. A
/// signed-in NetEase account follows, because its catalogue is far larger than
/// that account's own library — this is what gives a local file or a Subsonic
/// track words when only NetEase knows them. Adding a service here is what
/// puts it in the chain; the resolver never names one.
@Riverpod(keepAlive: true)
List<LyricsQuerySource> lyricsQuerySources(Ref ref) => [
  ref.watch(lrclibProvider),
  for (final source in ref.watch(librarySourcesProvider))
    if (source is NeteaseSource && source.canQueryLyrics) source,
];

/// Resolves lyrics: stored answer first, then the library, then the query
/// sources.
@Riverpod(keepAlive: true)
Future<LyricsResolver> lyricsResolver(Ref ref) async => LyricsResolver(
  catalog: ref.watch(libraryCatalogProvider),
  store: ref.watch(lyricsStoreProvider),
  // Called per lookup, so a service connected mid-session joins the chain
  // without the long-lived resolver being rebuilt.
  queries: () => ref.read(lyricsQuerySourcesProvider),
  // Read per lookup, not watched: picking a model, or signing in, changes
  // which engine the next translation uses without rebuilding the resolver.
  enricherFor: () async => LyricsEnricher(
    translator: await ref.read(personaLyricsTranslatorProvider.future),
  ),
  // Read, not watch: the resolver is long-lived and must see the library list
  // as it is at the moment of a lookup, including one added mid-session.
  sourceFor: (sourceId) => ref.read(librarySourceByIdProvider)[sourceId],
);

/// The words of one song, and their readings: from the local library or the
/// network, never waiting for a translation.
///
/// Kept for the session as well as on disk: the pane is rebuilt on every
/// position tick's parent rebuild, and a family entry means it never asks
/// twice for the track it is already showing.
@Riverpod(keepAlive: true)
Future<Lyrics> songLyrics(Ref ref, LyricsRequest song) async {
  final resolver = await ref.watch(lyricsResolverProvider.future);
  return resolver.resolve(song);
}

/// The translation layer for [songLyrics]'s words, in the app's language.
///
/// Auto-disposed: the pane watching it is the only thing that wants it, and a
/// finished translation is already in the stored row, so the next read is a
/// cache hit rather than a second request. Kept out of [songLyrics] on purpose
/// — a model completing a page of lyrics takes seconds, and the words must not
/// wait behind that.
///
/// [languageCode] is the app's current language: a language change gives the
/// family a new argument, which translates again instead of serving the old
/// language.
@riverpod
Future<Lyrics> songLyricsTranslation(
  Ref ref,
  LyricsRequest song, {
  String? languageCode,
}) async {
  final words = await ref.watch(songLyricsProvider(song).future);
  if (words.isEmpty) return words;
  final resolver = await ref.watch(lyricsResolverProvider.future);
  return resolver.translate(song, words, languageCode: languageCode);
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

/// Which recording a row is, across two libraries' copies: the fingerprint's
/// artist-and-title half, which ignores length so a slightly different timing
/// still meets the other copy of the same recording.
String _shuffleKey(LibrarySong song) =>
    trackBaseFingerprint(title: song.title, artist: song.artist);

/// What the smart shuffle draws from: every playable track the device knows,
/// its hearts and its play history, plus the account's own recommendations.
///
/// Kept alive because it is a whole-library read and a queue is planned from
/// it: rebuilding it on every press would make the second press as slow as
/// the first.
@Riverpod(keepAlive: true)
class ShuffleSeeds extends AsyncNotifier<List<ShuffleSeed>> {
  /// How far back a play counts as recent, so a mix rotates instead of
  /// replaying the queue the listener just heard.
  static const recentWindow = Duration(days: 2);

  @override
  Future<List<ShuffleSeed>> build() => _fetch();

  Future<List<ShuffleSeed>> _fetch() async {
    final database = ref.watch(libraryDatabaseProvider);
    if (database == null) return const [];
    final rows = await database.shuffleCandidates();
    final cutoff = DateTime.now().subtract(recentWindow);
    final recent = [
      for (final row in rows)
        if (row.lastPlayed != null && row.lastPlayed!.isAfter(cutoff))
          _shuffleKey(row.song),
    ];

    // The account's own shelves are recommendations, not holdings: they enter
    // the mix weighted like a heart's lesser cousin, without being adopted
    // into the local library (a station is not a track the user owns).
    final curated = ref.watch(landingShelvesProvider).value ?? const [];
    final recommended = [
      for (final shelf in curated)
        for (final song in shelf.songs) song,
    ];

    return [
      for (final row in rows)
        ShuffleSeed(
          song: row.song,
          favourite: row.favourite,
          plays: row.plays,
          recentlyPlayed: recent.contains(_shuffleKey(row.song)),
        ),
      for (final song in recommended)
        ShuffleSeed(song: song, recommended: true),
    ];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// The mix the smart shuffle currently plans, shared by its page and the
/// dashboard shelf: one plan means the shelf and the page always show the same
/// queue, and "shuffle again" on either moves both.
///
/// Kept alive so a trip to the page and back does not redraw the mix under a
/// card the user was about to press; [shuffle] is the one way to redraw it.
@Riverpod(keepAlive: true)
class ShufflePlan extends AsyncNotifier<SmartShuffle> {
  /// The seed the current plan was drawn with. A new press is a new seed, so
  /// the same library is walked from another place instead of repeating.
  int _seed = 0;

  @override
  Future<SmartShuffle> build() async {
    final seeds = await ref.watch(shuffleSeedsProvider.future);
    return planSmartShuffle(seeds, seed: _seed);
  }

  /// Draws a new mix from the same seeds.
  ///
  /// Written straight into the state rather than invalidating: the seeds are
  /// already in hand, and a spinner between two presses of the same button is
  /// noise. A failed read lands in the error state the page and the shelf both
  /// draw, so the press is never silently lost.
  Future<void> shuffle() async {
    state = await AsyncValue.guard(() async {
      final seeds = await ref.read(shuffleSeedsProvider.future);
      return planSmartShuffle(seeds, seed: ++_seed);
    });
  }
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
  /// Both halves of the pane go: the words and the translation are separate
  /// families, and leaving the second one up would show the old track's
  /// translation over the new words.
  Future<void> refresh(LyricsRequest song, {String? languageCode}) async {
    final resolver = await ref.read(lyricsResolverProvider.future);
    await resolver.forget(song);
    ref.invalidate(songLyricsProvider(song));
    ref.invalidate(songLyricsTranslationProvider(song, languageCode: languageCode));
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
  /// The local write is the record; the forward is best effort. The returned
  /// value is what the caller shows, and it is null when the source agreed or
  /// when there was no source to ask. The fleet copy is pushed by the caller,
  /// the layer that is allowed to know about Pulsar.
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

/// Albums and playlists this device remembers liking.
///
/// The same shape as [Favourites] and for the same reason: the database is
/// the record, the widget asks a provider, and the fleet copy is forwarded by
/// the caller that is allowed to know about Pulsar.
@Riverpod(keepAlive: true)
CollectionFavourites collectionFavourites(Ref ref) =>
    CollectionFavourites(ref);

class CollectionFavourites {
  const CollectionFavourites(this._ref);

  final Ref _ref;

  /// Writes the device's answer. Nothing is forwarded here: an album's own
  /// service has no album rating the app writes, and the account's copy is
  /// the other half, pushed by the surface that tapped the heart.
  Future<void> set(CollectionFavourite favourite, {required bool value}) async {
    await _ref
        .read(libraryCatalogProvider)
        ?.setCollectionFavourite(favourite, value: value);
  }
}

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

  /// Removes several tracks from a device-owned playlist in one write.
  Future<void> removeSongs(int playlistId, Iterable<int> entryIds) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return;
    await catalog.removeFromOwnedPlaylistBatch(playlistId, entryIds);
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
