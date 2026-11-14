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
        );
    ref.invalidateSelf();
  }

  /// Removes one item from a playlist and refreshes.
  Future<void> removeItem(PulsarPlaylist playlist, PlaylistItem item) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    await ref
        .read(pulsarClientProvider)
        .removeTrack(session, playlistId: playlist.id, itemId: item.id);
    ref.invalidateSelf();
  }

  /// Deletes a playlist and refreshes.
  Future<void> delete(PulsarPlaylist playlist) async {
    final session = ref.read(pulsarSessionProvider).value;
    if (session == null) return;
    await ref.read(pulsarClientProvider).deletePlaylist(session, playlist.id);
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

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
@riverpod
Future<List<LibrarySong>> pulsarPlaylistSongs(
  Ref ref,
  PulsarPlaylist playlist,
) async {
  final aggregator = ref.watch(libraryAggregatorProvider);
  final songs = <LibrarySong>[];
  for (final item in playlist.items) {
    final track = item.catalogItem;
    if (track == null) continue;
    final artist = track.subtitle;
    final matches = await aggregator.search(
      [track.title, if (artist != null && artist.isNotEmpty) artist].join(' '),
      limit: 5,
    );
    final best = matches.firstOrNull;
    if (best != null) songs.add(best);
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
    TasteWindow.month => DateTime(now.year, now.month - 1 == 0 ? 12 : now.month - 1, now.day),
  };
  return ref.read(pulsarClientProvider).getStats(session, from: from, to: now);
}
