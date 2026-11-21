/// Riverpod wiring for Pulsar.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../solarpass/models.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../library/aggregate.dart';
import '../library/catalog.dart';
import '../library/models.dart';
import '../library/providers.dart';
import '../library/snapshot_cache.dart';
import '../solarpass/providers.dart';
import 'client.dart';
import 'favourites.dart';
import 'links.dart';
import 'metadata.dart';
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
  OAuthSession? _session;

  @override
  Future<List<PulsarPlaylist>> build() {
    _session = ref.watch(pulsarSessionProvider).value;
    // A signed-out window has no cloud playlists; that is an answer, not a
    // reason to read a stored one from a previous session.
    if (_session == null) return Future.value(const []);
    return snapshotThenRefresh(
      ref,
      key: SnapshotKeys.cloudPlaylists,
      fetch: () => ref.read(pulsarClientProvider).listPlaylists(_session!),
      parse: PulsarPlaylist.fromJson,
      encode: (playlist) => playlist.toJson(),
      publish: (value) => state = value,
    );
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
class PulsarPlaylistDetail extends _$PulsarPlaylistDetail {
  OAuthSession? _session;

  @override
  Future<PulsarPlaylist> build(String playlistId) {
    _session = ref.watch(pulsarSessionProvider).value;
    final session = _session;
    if (session == null) {
      throw PulsarException(
        statusCode: 0,
        code: 'NO_SESSION',
        message: 'Sign in to read cloud playlists.',
      );
    }
    // The list-shaped helper, wrapped around the one playlist it holds: the
    // detail page is a cold-start page (a dashboard pin, a share link) and its
    // stored copy is the difference between a page and a spinner.
    return snapshotThenRefresh<PulsarPlaylist>(
      ref,
      key: SnapshotKeys.cloudPlaylistDetail(playlistId),
      fetch: () async => [
        await ref
            .read(pulsarClientProvider)
            .getPlaylist(_session!, playlistId),
      ],
      parse: PulsarPlaylist.fromJson,
      encode: (playlist) => playlist.toJson(),
      publish: (value) => state = AsyncData(value.value!.first),
    ).then((playlists) => playlists.first);
  }
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
class PulsarPlaylistSongs extends _$PulsarPlaylistSongs {
  LibraryAggregator? _aggregator;

  @override
  Future<List<LibrarySong?>> build(PulsarPlaylist playlist) async {
    _aggregator = ref.watch(libraryAggregatorProvider);
    final cache = ref.watch(snapshotCacheProvider);
    final key = SnapshotKeys.cloudPlaylistSongs(playlist.id);
    final cached = ref.isFirstBuild && cache != null
        ? await cache.restore(key, _parseRows)
        : null;
    if (cached == null) {
      final fresh = await _resolve(playlist);
      await _remember(cache, key, fresh);
      return fresh;
    }
    unawaited(() async {
      if (!ref.mounted) return;
      try {
        final fresh = await _resolve(playlist);
        if (!ref.mounted) return;
        state = AsyncData(fresh);
        await _remember(cache, key, fresh);
      } catch (error) {
        debugPrint('[Pulsar] Background resolve of $key: $error');
      }
    }());
    return cached;
  }

  /// The rows as JSON. A null entry is a hook the list must keep: every row
  /// after it would otherwise shift onto another track.
  static List<LibrarySong?> _parseRows(Object? json) => [
    for (final entry in (json as List?) ?? const [])
      if (entry is Map)
        LibrarySong.fromJson(Map<String, dynamic>.from(entry))
      else
        null,
  ];

  static Future<void> _remember(
    SnapshotCache? cache,
    String key,
    List<LibrarySong?> rows,
  ) async {
    if (cache == null) return;
    await cache.store(key, rows, (raw) => [
      for (final row in raw! as List<LibrarySong?>) row?.toJson(),
    ]);
  }

  Future<List<LibrarySong?>> _resolve(PulsarPlaylist playlist) async {
    final aggregator = _aggregator!;
    final songs = <LibrarySong?>[];
    for (final item in playlist.items) {
      final track = item.catalogItem;
      if (track == null) {
        songs.add(null);
        continue;
      }
      final artist = track.subtitle;
      // A cloud playlist names tracks by catalogue id, so the row is resolved
      // through the wide search: a track the account never added is still the
      // right answer if it is the one the playlist means.
      final matches = await aggregator.searchCatalogue(
        [track.title, if (artist != null && artist.isNotEmpty) artist].join(' '),
        limit: 5,
      );
      songs.add(matches.firstOrNull);
    }
    return songs;
  }
}

/// What the account's friends are listening to. Empty without a session.
@Riverpod(keepAlive: true)
class FriendListeningFeed extends AsyncNotifier<List<FriendListening>> {
  OAuthSession? _session;

  @override
  Future<List<FriendListening>> build() {
    _session = ref.watch(pulsarSessionProvider).value;
    if (_session == null) return Future.value(const []);
    return snapshotThenRefresh(
      ref,
      key: SnapshotKeys.friendListening,
      fetch: _fetch,
      parse: FriendListening.fromJson,
      encode: (friend) => friend.toJson(),
      publish: (value) => state = value,
    );
  }

  /// The rows worth drawing: a friend with no live activity is noise on the
  /// shelf. [FriendListening.nowPlaying] judges liveness, so a stored row that
  /// has since expired is dropped here rather than shown as "listening".
  Future<List<FriendListening>> _fetch() async {
    final session = _session;
    if (session == null) return const [];
    final friends = await ref
        .read(pulsarClientProvider)
        .friendsListening(session);
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

/// Where [window] starts, relative to [now].
///
/// Month and year are calendar shifts, not day counts: the 31st of March is
/// "a month ago" on the 30th of April even though that day does not exist in
/// the target month, so the day is clamped to the month's last. Building the
/// date arithmetically instead rolls March 31 → May 1 and the window quietly
/// stops covering a month.
DateTime? tasteWindowStart(TasteWindow window, DateTime now) =>
    switch (window) {
      TasteWindow.all => null,
      TasteWindow.year => _monthsBefore(now, 12),
      TasteWindow.month => _monthsBefore(now, 1),
    };

DateTime _monthsBefore(DateTime now, int months) {
  final total = now.year * 12 + (now.month - 1) - months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, now.day > lastDay ? lastDay : now.day);
}

/// The account's taste, aggregated by Pulsar over every scrobble the fleet
/// has. Empty-without-session is silence, not an error: the profile page
/// still shows the local listening story when the account is signed out.
@riverpod
Future<PulsarMediaStats?> pulsarTaste(Ref ref, TasteWindow window) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) return null;
  final now = DateTime.now().toUtc();
  return ref
      .read(pulsarClientProvider)
      .getStats(session, from: tasteWindowStart(window, now), to: now);
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
      final catalogId = catalogIdForKey(pulsarTrackKey(song));
      if (catalogId == null) return;
      await client.removeFavourite(session, catalogId);
    }
    ref.invalidateSelf();
  }

  /// Pushes one album or playlist heart to the account.
  ///
  /// The entry's own library key is the provider key, so a second device
  /// reads the same album back and resolves it against its own copy of that
  /// library. A Solink playlist has no library behind it, which is why its
  /// key names [kSolinkSourceId] and its own id.
  Future<void> setCollection(
    CollectionFavourite favourite, {
    required bool value,
  }) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    final client = ref.read(pulsarClientProvider);
    final key = pulsarCollectionKey(favourite);
    if (value) {
      await client.addFavourite(
        session,
        PulsarTrackPayload(
          title: favourite.name,
          artist: favourite.subtitle,
          artworkUrl:
              favourite.artworkUrl ??
              ref
                  .read(librarySourceByIdProvider)[favourite.sourceId]
                  ?.artworkUri(favourite.artId)
                  ?.toString(),
          providerKey: key,
          kind: favourite.kind,
        ),
      );
    } else {
      final catalogId = catalogIdForKey(key);
      if (catalogId == null) return;
      await client.removeFavourite(session, catalogId);
    }
    ref.invalidateSelf();
  }

  /// The catalog id the account assigned the entry spelled [providerKey].
  String? catalogIdForKey(String providerKey) => state.value
      ?.where((item) => item.catalogItem?.providerKey == providerKey)
      .firstOrNull
      ?.catalogId;

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
    // An album or a playlist is not a recording: there is nothing to resolve,
    // and asking for one as a track would put an unrelated song on its row.
    // The null keeps the list index-aligned with the account's order.
    if (track == null || item.kind.isCollection) {
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

/// The account's favourite albums and playlists, newest decision first.
///
/// The same list [pulsarFavouritesProvider] holds, narrowed to the entries
/// whose kind is a collection: one read is the truth for every heart in the
/// app, and which of them a page shows is a filter, not a second request.
@Riverpod(keepAlive: true)
Future<List<CollectionFavourite>> solarCollectionFavourites(Ref ref) async {
  final items = await ref.watch(pulsarFavouritesProvider.future);
  return [
    for (final item in items)
      if (item.kind.isCollection)
        if (item.catalogItem case final track?)
          if (parsePulsarCollectionKey(track.providerKey) case final key?)
            CollectionFavourite(
              kind: key.kind,
              sourceId: key.sourceId,
              id: key.id,
              name: track.title,
              subtitle: track.subtitle,
              artworkUrl: track.artworkUrl,
              decidedAt: DateTime.now(),
            ),
  ];
}

/// Whether this album or playlist is a favourite.
///
/// The account is the record when signed in, exactly as it is for a track: a
/// heart set on another device is what every surface draws. Signed out the
/// device's own row answers, so the heart still works with no account.
@riverpod
Future<bool> collectionFavouriteState(
  Ref ref,
  CollectionFavouriteKey key,
) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) {
    return await ref.watch(deviceCollectionFavouriteStateProvider(key).future);
  }
  final favourites = await ref.watch(solarCollectionFavouritesProvider.future);
  return favourites.any(
    (favourite) =>
        favourite.kind == key.kind &&
        favourite.sourceId == key.sourceId &&
        favourite.id == key.id,
  );
}

/// The device's own heart for one album or playlist.
@riverpod
Future<bool> deviceCollectionFavouriteState(
  Ref ref,
  CollectionFavouriteKey key,
) async =>
    await ref.watch(libraryCatalogProvider)?.collectionFavouriteOf(key) ??
    false;


/// What the fleet knows about one artist, as the artist page draws it.
///
/// Matched by name, in the artist's own domain (`music`): Pulsar's creators
/// are per-domain, and the fleet has no id the device's libraries share. A
/// miss is silence, not an error — the page is built from the device's own
/// libraries first, and the fleet section only ever adds.
class PulsarArtistMetadata {
  const PulsarArtistMetadata({required this.creator, required this.catalog});

  final PulsarCreator creator;

  /// Every catalog item the fleet credits to them, newest first as the server
  /// returns them. Mixed by design: the fleet's own resolved entities sit in
  /// the same list as the tracks devices pushed, and the reader picks.
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

  return PulsarArtistMetadata(creator: creator, catalog: catalog);
}

/// The fleet's record for one artist, as the artist page reads it.
///
/// Signed out is not a failure: the endpoint is public, and the section
/// simply shows what the request answered. Any failure — the fleet being
/// down, a name MusicBrainz does not know — answers null so the page keeps
/// the device's own libraries and never turns into an error screen.
@riverpod
Future<PulsarEntityMetadata?> pulsarArtistProfile(
  Ref ref,
  String name, {
  String? language,
}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  final client = ref.watch(pulsarClientProvider);
  try {
    return await client.artistMetadata(
      trimmed,
      language: language,
      session: ref.read(pulsarSessionProvider).value,
    );
  } on PulsarException {
    return null;
  }
}

/// The fleet's record for one album, asked by title and artist — the pair
/// every connected library spells.
@riverpod
Future<PulsarEntityMetadata?> pulsarAlbumProfile(
  Ref ref, {
  required String title,
  String? artist,
  String? language,
}) async {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return null;
  final client = ref.watch(pulsarClientProvider);
  try {
    return await client.albumMetadata(
      title: trimmed,
      artist: artist,
      language: language,
      session: ref.read(pulsarSessionProvider).value,
    );
  } on PulsarException {
    return null;
  }
}
