import 'package:auto_route/auto_route.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The user's server-side playlists, merged across every library.
///
/// Playlists are the server's, not the app's: creating and editing them stays
/// in Navidrome/Jellyfin's own UI so there is exactly one owner of that state.
@RoutePage()
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    // Select the identity, not the state: watching the whole transport would
    // rebuild this page on every position tick, once a second.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: Column(
          children: [
            PageHeader(
              showRailToggle: true,
              title: 'Playlists',
              subtitle: playlists.maybeWhen(
                data: (list) => list.isEmpty
                    ? 'No playlists in your libraries'
                    : '${list.length} ${list.length == 1 ? 'playlist' : 'playlists'}',
                orElse: () => null,
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.read(playlistsProvider.notifier).refresh(),
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
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final playlist = list[index];
                          return _PlaylistRow(
                            artwork: LibraryArtwork(
                              sourceId: playlist.sourceId,
                              artId: playlist.artId,
                              size: 52,
                              radius: SolRadius.md,
                              fallbackIcon: Symbols.playlist_play,
                            ),
                            title: playlist.name,
                            subtitle: [
                              if (playlist.songCount != null)
                                '${playlist.songCount} tracks',
                              formatDuration(playlist.duration),
                              if (playlist.owner != null) playlist.owner!,
                            ].join('  ·  '),
                            onTap: () => context.router.push(
                              PlaylistDetailRoute(
                                sourceId: playlist.sourceId,
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
                    onPressed: () =>
                        ref.read(playlistsProvider.notifier).refresh(),
                    child: const Text('Try again'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A playlist row: cover, name, counts and a chevron. Same rounded hover
/// language as [TrackRow], so lists read as one family without dividers.
class _PlaylistRow extends StatelessWidget {
  final Widget artwork;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlaylistRow({
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SolRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SolSpace.md,
            vertical: SolSpace.sm,
          ),
          child: Row(
            children: [
              artwork,
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One playlist's tracks, with a play-all button.
@RoutePage()
class PlaylistDetailScreen extends ConsumerWidget {
  /// Which library the playlist belongs to.
  final String sourceId;
  final String playlistId;
  final String? playlistName;

  const PlaylistDetailScreen({
    super.key,
    @PathParam('sourceId') required this.sourceId,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(
      playlistSongsProvider((sourceId: sourceId, id: playlistId)),
    );
    final playback = ref.watch(playbackProvider);
    final hasSong = playback.current != null;
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: Column(
          children: [
            PageHeader(
              title: playlistName ?? 'Playlist',
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
              subtitle: songs.maybeWhen(
                data: (list) => list.isEmpty
                    ? 'Empty playlist'
                    : '${list.length} tracks  ·  '
                          '${formatDuration(list.fold(Duration.zero, (sum, s) => sum + s.duration))}',
                orElse: () => null,
              ),
              actions: [
                if (songs.hasValue && songs.value!.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(songs.value!),
                    icon: const Icon(Symbols.play_arrow_rounded, size: 20),
                    label: const Text('Play'),
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
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final song = list[index];
                          return TrackRow(
                            title: song.title,
                            subtitle: songRowSubtitle(ref, song),
                            selected: playback.isCurrentSong(song),
                            trailing: formatDuration(song.duration),
                            artwork: LibraryArtwork(
                              sourceId: song.sourceId,
                              artId: song.artId,
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
                    onPressed: () => ref.invalidate(
                      playlistSongsProvider((
                        sourceId: sourceId,
                        id: playlistId,
                      )),
                    ),
                    child: const Text('Try again'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
