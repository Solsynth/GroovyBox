/// Riverpod wiring for Pulsar.
library;

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../solarpass/models.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../library/models.dart';
import '../library/providers.dart';
import '../solarpass/providers.dart';
import 'client.dart';
import 'favourites.dart';
import 'links.dart';
import 'models.dart';

part 'providers.g.dart';

/// The HTTP client, pointed at the one server setting Solarpass already owns.
@Riverpod(keepAlive: true)
PulsarClient pulsarClient(Ref ref) {
  final config = ref.watch(solarpassConfigProvider);
  return PulsarClient(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    ),
    baseUrl: config.serverUrl,
  );
}

/// The signed-in session or null, unwrapped once for every Pulsar call.
///
/// Watches the session's state, not its notifier: the notifier's own `build`
/// is a future, so a first read of it is `AsyncLoading` and [validSession]
/// answers null from that. Watched that way the answer was captured once by
/// this `keepAlive` provider and stayed "signed out" for the rest of the
/// process — including right after a successful login — which is why a
/// logged-in user was still told to log in.
@Riverpod(keepAlive: true)
Future<OAuthSession?> pulsarSession(Ref ref) async {
  final session = await ref.watch(solarpassSessionProvider.future);
  if (session == null || !session.needsRefresh) return session;
  // Expiring: the notifier trades the refresh token for a new access token
  // and saves it, which rebuilds this provider with the fresh session.
  return ref.read(solarpassSessionProvider.notifier).validSession();
}

/// The account's playlists, as Pulsar holds them. Empty without a session:
/// a signed-out window has no cloud playlists and that is not an error.
@Riverpod(keepAlive: true)
class PulsarPlaylists extends AsyncNotifier<List<PulsarPlaylist>> {
  @override
  Future<List<PulsarPlaylist>> build() async {
    final session = ref.watch(pulsarSessionProvider).value;
    if (session == null) return const [];
    return ref.watch(pulsarClientProvider).listPlaylists(session);
  }

  /// Creates a playlist and refreshes the list, so the caller can navigate
  /// to what came back.
  Future<PulsarPlaylist?> create(String name) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return null;
    final playlist = await ref
        .read(pulsarClientProvider)
        .createPlaylist(session, name: name);
    ref.invalidateSelf();
    return playlist;
  }

  /// Uploads a whole playlist into Pulsar and returns it. The tracks are
  /// written in order, then the same list is pushed as the collection's
  /// contents, so one call is enough for a first upload.
  Future<PulsarPlaylist?> upload(
    String name,
    List<LibrarySong> songs, {
    String? description,
    bool isPublic = true,
  }) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return null;
    final created = await ref
        .read(pulsarClientProvider)
        .createPlaylist(
          session,
          name: name,
          description: description,
          isPublic: isPublic,
        );
    await replace(created, songs);
    return created;
  }

  /// Makes [playlist] hold exactly [songs], in order. This is the re-sync:
  /// run it again after the source playlist changes and Pulsar follows.
  Future<void> replace(PulsarPlaylist playlist, List<LibrarySong> songs) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    final sources = ref.read(librarySourceByIdProvider);
    await ref
        .read(pulsarClientProvider)
        .replacePlaylistTracks(
          session,
          playlistId: playlist.id,
          tracks: [
            for (final song in songs)
              PulsarTrackPayload(
                title: song.title,
                artist: song.artist,
                album: song.album,
                artworkUrl: sources[song.sourceId]
                    ?.artworkUri(song.artId)
                    ?.toString(),
                durationSeconds: song.duration.inSeconds,
                providerKey: pulsarTrackKey(song),
              ),
          ],
        );
    ref.invalidateSelf();
    ref.invalidate(pulsarPlaylistDetailProvider(playlist.id));
  }

  /// Renames a playlist and refreshes, so every list shows the new name.
  Future<void> rename(String id, String name) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    await ref
        .read(pulsarClientProvider)
        .renamePlaylist(session, id, name: name);
    ref.invalidateSelf();
    ref.invalidate(pulsarPlaylistDetailProvider(id));
  }

  /// Adds [song] to a playlist and refreshes, so counts stay true.
  Future<void> addSong(PulsarPlaylist playlist, LibrarySong song) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    final sources = ref.read(librarySourceByIdProvider);
    final artUri = sources[song.sourceId]?.artworkUri(song.artId);
    await ref
        .read(pulsarClientProvider)
        .addTrack(
          session,
          playlistId: playlist.id,
          title: song.title,
          artist: song.artist,
          artworkUrl: artUri?.toString(),
          durationSeconds: song.duration.inSeconds,
          trackKey: pulsarTrackKey(song),
        );
    ref.invalidateSelf();
    // The detail page holds this playlist's items; a list refresh alone
    // would leave it showing the set it was built from.
    ref.invalidate(pulsarPlaylistDetailProvider(playlist.id));
  }

  /// Removes one item from a playlist and refreshes.
  Future<void> removeItem(PulsarPlaylist playlist, PlaylistItem item) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    await ref
        .read(pulsarClientProvider)
        .removeTrack(session, playlistId: playlist.id, itemId: item.id);
    ref.invalidateSelf();
    ref.invalidate(pulsarPlaylistDetailProvider(playlist.id));
  }

  /// Removes several items in one pass and refreshes once. Each removal is
  /// its own request — the server has no batch delete — so a failure part way
  /// through still leaves everything before it gone and the page honest about
  /// what remains.
  Future<void> removeItems(
    PulsarPlaylist playlist,
    Iterable<PlaylistItem> items,
  ) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    final client = ref.read(pulsarClientProvider);
    for (final item in items) {
      await client.removeTrack(
        session,
        playlistId: playlist.id,
        itemId: item.id,
      );
    }
    ref.invalidateSelf();
    ref.invalidate(pulsarPlaylistDetailProvider(playlist.id));
  }

  /// Deletes a playlist and refreshes. Any local playlist that was syncing
  /// into it loses its link: the next push must not target a dead id.
  Future<void> delete(PulsarPlaylist playlist) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    await ref.read(pulsarClientProvider).deletePlaylist(session, playlist.id);
    await ref.read(pulsarPlaylistLinksProvider).clearForCloud(playlist.id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = ref.read(pulsarSessionProvider).value;
      if (session == null) return const <PulsarPlaylist>[];
      return ref.read(pulsarClientProvider).listPlaylists(session);
    });
  }
}

/// One cloud playlist as the detail page reads it: the collection itself
/// with its items preloaded, from the one endpoint that returns both.
@riverpod
Future<PulsarPlaylist> pulsarPlaylistDetail(Ref ref, String playlistId) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) {
    throw PulsarException(
      statusCode: 0,
      code: 'NO_SESSION',
      message: 'Sign in to read cloud playlists.',
    );
  }
  return ref.watch(pulsarClientProvider).getPlaylist(session, playlistId);
}

/// One cover URL per cloud playlist, for lists that draw the item.
///
/// A collection record carries `artwork_url` only when someone set it, and a
/// playlist made by uploading tracks never did: the list response is a bare
/// array with no items, so the row had nothing to draw and every Solar
/// playlist read as a grey cloud. The cover a playlist actually shows is its
/// first track's artwork, which only the detail read knows — so the ones
/// missing a cover ask for it once, and a failure costs a cover, never the
/// list.
@Riverpod(keepAlive: true)
Future<Map<String, String>> pulsarPlaylistCovers(Ref ref) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) return const {};
  final playlists = await ref.watch(pulsarPlaylistsProvider.future);
  final client = ref.read(pulsarClientProvider);

  final covers = <String, String>{};
  final missing = <PulsarPlaylist>[];
  for (final playlist in playlists) {
    final art = playlist.artworkUrl;
    if (art != null && art.isNotEmpty) {
      covers[playlist.id] = art;
    } else {
      missing.add(playlist);
    }
  }
  if (missing.isEmpty) return covers;

  // A handful of playlists, one request each, in parallel: the page can draw
  // every row the moment this answers, and a row without a cover falls back
  // to its own monogram.
  final details = await Future.wait([
    for (final playlist in missing)
      client
          .getPlaylist(session, playlist.id)
          .then<CatalogItem?>((detail) => detail.items.firstOrNull?.catalogItem)
          .catchError((Object _) => null),
  ]);
  for (var i = 0; i < missing.length; i++) {
    final artwork = details[i]?.artworkUrl;
    if (artwork != null && artwork.isNotEmpty) covers[missing[i].id] = artwork;
  }
  return covers;
}

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.
@riverpod
Future<List<LibrarySong?>> pulsarPlaylistSongs(
  Ref ref,
  PulsarPlaylist playlist,
) async {
  final aggregator = ref.watch(libraryAggregatorProvider);
  final songs = <LibrarySong?>[];
  for (final item in playlist.items) {
    final track = item.catalogItem;
    if (track == null) {
      songs.add(null);
      continue;
    }
    final artist = track.subtitle;
    final matches = await aggregator.search(
      [track.title, if (artist != null && artist.isNotEmpty) artist].join(' '),
      limit: 5,
    );
    songs.add(matches.firstOrNull);
  }
  return songs;
}

/// What the account's friends are listening to. Empty without a session.
@Riverpod(keepAlive: true)
class FriendListeningFeed extends AsyncNotifier<List<FriendListening>> {
  @override
  Future<List<FriendListening>> build() async {
    final session = ref.watch(pulsarSessionProvider).value;
    if (session == null) return const [];
    final friends = await ref
        .watch(pulsarClientProvider)
        .friendsListening(session);
    // A friend with no live activity is noise on the shelf; only the ones
    // actually playing something are worth a row.
    return [
      for (final friend in friends)
        if (friend.nowPlaying != null) friend,
    ];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = ref.read(pulsarSessionProvider).value;
      if (session == null) return const <FriendListening>[];
      final friends = await ref
          .read(pulsarClientProvider)
          .friendsListening(session);
      return [
        for (final friend in friends)
          if (friend.nowPlaying != null) friend,
      ];
    });
  }
}

/// How far back the taste summary reaches.
enum TasteWindow { all, year, month }

/// The account's taste, aggregated by Pulsar over every scrobble the fleet
/// has. Empty-without-session is silence, not an error: the profile page
/// still shows the local listening story when the account is signed out.
@riverpod
Future<PulsarMediaStats?> pulsarTaste(Ref ref, TasteWindow window) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) return null;
  final now = DateTime.now().toUtc();
  final from = switch (window) {
    TasteWindow.all => null,
    TasteWindow.year => DateTime(now.year - 1, now.month, now.day),
    TasteWindow.month => DateTime(
      now.year,
      now.month - 1 == 0 ? 12 : now.month - 1,
      now.day,
    ),
  };
  return ref.read(pulsarClientProvider).getStats(session, from: from, to: now);
}

/// The account's favourites, as Pulsar holds them: the same heart the device
/// keeps, in the fleet where a second device can read it.
@Riverpod(keepAlive: true)
class PulsarFavourites extends AsyncNotifier<List<PlaylistItem>> {
  @override
  Future<List<PlaylistItem>> build() async {
    final session = ref.watch(pulsarSessionProvider).value;
    if (session == null) return const [];
    return ref.watch(pulsarClientProvider).favourites(session);
  }

  /// Pushes one decision to the account. Best effort by design: the device's
  /// database is the record, and a fleet that is down must not undo a tap.
  Future<void> set(LibrarySong song, {required bool value}) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    final sources = ref.read(librarySourceByIdProvider);
    final client = ref.read(pulsarClientProvider);
    if (value) {
      await client.addFavourite(
        session,
        PulsarTrackPayload(
          title: song.title,
          artist: song.artist,
          album: song.album,
          artworkUrl: sources[song.sourceId]?.artworkUri(song.artId)?.toString(),
          durationSeconds: song.duration.inSeconds,
          providerKey: pulsarTrackKey(song),
        ),
      );
    } else {
      // Removing needs the catalog id the server assigned, which only the
      // favourites list carries; a track never pushed has nothing to remove.
      final match = state.value?.where((item) {
        final key = item.catalogItem?.providerKey;
        return key != null && key == pulsarTrackKey(song);
      }).firstOrNull;
      final catalogId = match?.catalogId;
      if (catalogId == null) return;
      await client.removeFavourite(session, catalogId);
    }
    ref.invalidateSelf();
  }

  /// Takes one recording back out of the fleet's favourites, by the catalog
  /// id the server assigned it.
  Future<void> clear(String catalogId) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    await ref.read(pulsarClientProvider).removeFavourite(session, catalogId);
    ref.invalidateSelf();
  }

  /// Re-reads the account's list.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = ref.read(pulsarSessionProvider).value;
      if (session == null) return const <PlaylistItem>[];
      return ref.read(pulsarClientProvider).favourites(session);
    });
  }
}

/// The account's favourite recordings, as the source-scoped keys every Solar
/// write spells a track with. One key set is what the heart reads, so the
/// question costs no request per redraw.
@Riverpod(keepAlive: true)
Future<Set<String>> solarFavouriteKeys(Ref ref) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) return const {};
  final favourites = await ref.watch(pulsarFavouritesProvider.future);
  return {
    for (final item in favourites) ?item.catalogItem?.providerKey,
  };
}

/// Whether the account holds [song] as a favourite.
///
/// Solar Network is the record when this device is signed in: a heart set on
/// any device, or imported from another provider, is the answer every surface
/// draws. Signed out there is no account to ask, so the device's own record
/// answers instead of the heart going blank.
@riverpod
Future<bool> solarFavouriteState(Ref ref, LibrarySong song) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) {
    return await ref.watch(favouriteStateProvider(song).future);
  }
  final keys = await ref.watch(solarFavouriteKeysProvider.future);
  return keys.contains(pulsarTrackKey(song));
}

/// The account's favourites, resolved to the copies this device can play.
///
/// Index-aligned with [pulsarFavouritesProvider]: null where no connected
/// library holds the recording. Dropping the entry instead would shift every
/// row after it onto the wrong track, and the account's order is the truth.
@riverpod
Future<List<LibrarySong?>> solarFavouriteSongs(Ref ref) async {
  final items = await ref.watch(pulsarFavouritesProvider.future);
  final resolver = ref.watch(solarFavouriteResolverProvider);
  final connected = ref.watch(librarySourceByIdProvider).keys.toSet();
  var searches = 0;
  final songs = <LibrarySong?>[];
  for (final item in items) {
    final track = item.catalogItem;
    if (track == null) {
      songs.add(null);
      continue;
    }
    final search = searches < solarFavouriteSearchBudget;
    final song = await resolver.resolve(track, search: search);
    if (song == null) {
      if (search) searches++;
      songs.add(null);
      continue;
    }
    if (!connected.contains(song.sourceId)) searches++;
    songs.add(song);
  }
  return songs;
}


/// What the fleet knows about one artist, as the artist page draws it.
///
/// Matched by name, in the artist's own domain (`music`): Pulsar's creators
/// are per-domain, and the fleet has no id the device's libraries share. A
/// miss is silence, not an error — the page is built from the device's own
/// libraries first, and the fleet section only ever adds.
class PulsarArtistMetadata {
  const PulsarArtistMetadata({
    required this.creator,
    required this.roles,
    required this.catalog,
  });

  final PulsarCreator creator;

  /// Every role the catalog credits this creator with, alphabetical and
  /// deduped across items.
  final List<String> roles;

  /// The fleet's catalog items credited to them, newest first as the server
  /// returns them.
  final List<CatalogItem> catalog;
}

/// The fleet's view of [name]. Null when signed out, when nothing matches,
/// or when the fleet is unreachable — each a reason the section stays quiet,
/// never a failure of the page.
@riverpod
Future<PulsarArtistMetadata?> pulsarArtistMetadata(Ref ref, String name) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null || name.trim().isEmpty) return null;
  final client = ref.watch(pulsarClientProvider);

  final creators = await client.creators(
    query: name,
    domain: 'music',
    session: session,
  );
  // The list is alphabetical; an exact, case-insensitive name match is the
  // one this page means — a prefix hit for a different artist is not.
  final creator = creators
      .where((candidate) => candidate.name.toLowerCase() == name.toLowerCase())
      .firstOrNull;
  if (creator == null) return null;

  final catalog = await client.creatorCatalog(
    creator.id,
    domain: 'music',
    session: session,
  );
  final roles = {
    for (final item in catalog)
      for (final credit in item.creators)
        if (credit.name.toLowerCase() == creator.name.toLowerCase() &&
            credit.role.isNotEmpty)
          credit.role,
  }.toList()..sort();

  return PulsarArtistMetadata(
    creator: creator,
    roles: roles,
    catalog: catalog,
  );
}
