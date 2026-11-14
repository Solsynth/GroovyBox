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
@Riverpod(keepAlive: true)
Future<OAuthSession?> pulsarSession(Ref ref) async {
  final session = await ref
      .watch(solarpassSessionProvider.notifier)
      .validSession();
  return session;
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

/// Whether Pulsar knows [song] as one of the account's favourites.
@riverpod
Future<bool> pulsarFavouriteState(Ref ref, LibrarySong song) async {
  final session = ref.watch(pulsarSessionProvider).value;
  if (session == null) return false;
  final favourites = await ref.watch(pulsarFavouritesProvider.future);
  final key = pulsarTrackKey(song);
  return favourites.any((item) => item.catalogItem?.providerKey == key);
}

