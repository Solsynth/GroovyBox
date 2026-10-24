import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/router.gr.dart';
import '../core/server_data.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// The user's server-side playlists.
///
/// Playlists are the server's, not the app's: creating and editing them stays
/// in Navidrome/Jellyfin's own UI so there is exactly one owner of that state.
@RoutePage()
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: 'Playlists',
            subtitle: playlists.maybeWhen(
              data: (list) => list.isEmpty
                  ? 'No playlists on this server'
                  : '${list.length} ${list.length == 1 ? 'playlist' : 'playlists'}',
              orElse: () => null,
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.read(playlistsProvider.notifier).refresh(),
                icon: const Icon(Symbols.refresh_rounded),
              ),
              const SizedBox(width: SolSpace.sm),
            ],
          ),
          Expanded(
            child: playlists.when(
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Symbols.playlist_play,
                      title: 'No playlists yet',
                      message:
                          'Playlists you make in Navidrome or Jellyfin appear '
                          'here automatically.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final playlist = list[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: SolSpace.xxl,
                            vertical: SolSpace.xxs,
                          ),
                          leading: ServerArtwork(
                            coverArtId: playlist.coverArt,
                            size: 52,
                            radius: SolRadius.sm,
                            fallbackIcon: Symbols.playlist_play,
                          ),
                          title: Text(playlist.name),
                          subtitle: Text(
                            [
                              if (playlist.songCount != null)
                                '${playlist.songCount} tracks',
                              formatDuration(playlist.duration),
                              if (playlist.owner != null) playlist.owner!,
                            ].join('  ·  '),
                          ),
                          trailing: const Icon(Symbols.chevron_right_rounded),
                          onTap: () => context.router.push(
                            PlaylistDetailRoute(
                              playlistId: playlist.id,
                              playlistName: playlist.name,
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Symbols.error_rounded,
                title: 'Could not load playlists',
                message: describeServerError(error),
                iconColor: Theme.of(context).colorScheme.error,
                action: FilledButton(
                  onPressed: () => ref.read(playlistsProvider.notifier).refresh(),
                  child: const Text('Try again'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One playlist's tracks, with a play-all button.
@RoutePage()
class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;
  final String? playlistName;

  const PlaylistDetailScreen({
    super.key,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(playlistSongsProvider(playlistId));
    final playback = ref.watch(playbackProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: playlistName ?? 'Playlist',
            subtitle: songs.maybeWhen(
              data: (list) => list.isEmpty
                  ? 'Empty playlist'
                  : '${list.length} tracks  ·  '
                        '${formatDuration(
                          list.fold(Duration.zero, (sum, s) => sum + s.duration),
                        )}',
              orElse: () => null,
            ),
            actions: [
              if (songs.hasValue && songs.value!.isNotEmpty)
                IconButton(
                  tooltip: 'Play all',
                  onPressed: () => ref
                      .read(playbackProvider.notifier)
                      .playQueue(songs.value!),
                  icon: const Icon(Symbols.play_circle_rounded),
                ),
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.router.maybePop(),
                icon: const Icon(Symbols.arrow_back_rounded),
              ),
              const SizedBox(width: SolSpace.sm),
            ],
          ),
          Expanded(
            child: songs.when(
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Symbols.playlist_play,
                      title: 'This playlist is empty',
                      message: 'Add tracks from your server, then refresh.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final song = list[index];
                        return TrackRow(
                          title: song.title,
                          subtitle: song.subtitle,
                          selected: playback.current?.id == song.id,
                          trailing: formatDuration(song.duration),
                          artwork: ServerArtwork(
                            coverArtId: song.coverArt,
                            size: 44,
                            radius: SolRadius.xs,
                          ),
                          onTap: () => ref
                              .read(playbackProvider.notifier)
                              .playQueue(list, startIndex: index),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Symbols.error_rounded,
                title: 'Could not load this playlist',
                message: describeServerError(error),
                iconColor: Theme.of(context).colorScheme.error,
                action: FilledButton(
                  onPressed: () =>
                      ref.invalidate(playlistSongsProvider(playlistId)),
                  child: const Text('Try again'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
