import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../server/models.dart';
import 'app.dart';

part 'server_data.g.dart';

/// Recently added albums, refreshed on demand and after a pull-to-refresh.
@Riverpod(keepAlive: true)
class RecentAlbums extends AsyncNotifier<List<SubsonicAlbum>> {
  @override
  Future<List<SubsonicAlbum>> build() => _fetch();

  Future<List<SubsonicAlbum>> _fetch() async {
    final client = ref.watch(subsonicClientProvider);
    if (client == null) return const [];
    return client.getAlbums(type: 'newest', size: 50);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// Songs from a random draw, used as the browse page's instant-play shelf.
@Riverpod(keepAlive: true)
class RandomSongs extends AsyncNotifier<List<SubsonicSong>> {
  @override
  Future<List<SubsonicSong>> build() => _fetch();

  Future<List<SubsonicSong>> _fetch() async {
    final client = ref.watch(subsonicClientProvider);
    if (client == null) return const [];
    return client.getRandomSongs(size: 40);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await _fetch());
  }
}

/// Songs of one album, cached per album id.
@riverpod
Future<List<SubsonicSong>> albumSongs(Ref ref, String albumId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return const [];
  return client.getAlbumSongs(albumId);
}

/// The user's playlists.
@Riverpod(keepAlive: true)
class Playlists extends AsyncNotifier<List<SubsonicPlaylist>> {
  @override
  Future<List<SubsonicPlaylist>> build() => _fetch();

  Future<List<SubsonicPlaylist>> _fetch() async {
    final client = ref.watch(subsonicClientProvider);
    if (client == null) return const [];
    return client.getPlaylists();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await _fetch());
  }
}

/// Songs of one playlist, cached per playlist id.
@riverpod
Future<List<SubsonicSong>> playlistSongs(Ref ref, String playlistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return const [];
  return client.getPlaylistSongs(playlistId);
}

/// Search results for the browse page's field. Empty query = no request.
@riverpod
Future<List<SubsonicSong>> searchSongs(Ref ref, String query) async {
  if (query.trim().isEmpty) return const [];
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return const [];
  return client.search(query.trim());
}
