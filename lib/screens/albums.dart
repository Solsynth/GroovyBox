import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/router.gr.dart';
import '../core/server_data.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../server/models.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// Every album on the server, newest first, as a grid of covers.
///
/// The server's own `getAlbumList2` sort is used rather than a client-side
/// sort: paged lists must agree with the server about order or pages drift.
@RoutePage()
class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(recentAlbumsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: 'Albums',
            subtitle: albums.maybeWhen(
              data: (list) =>
                  '${list.length} ${list.length == 1 ? 'album' : 'albums'}',
              orElse: () => null,
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.read(recentAlbumsProvider.notifier).refresh(),
                icon: const Icon(Symbols.refresh_rounded),
              ),
              const SizedBox(width: SolSpace.sm),
            ],
          ),
          Expanded(
            child: albums.when(
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Symbols.album,
                      title: 'No albums yet',
                      message:
                          'Anything with an album tag on your server shows up here.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        SolSpace.xl,
                        0,
                        SolSpace.xl,
                        96,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: SolSpace.md,
                            crossAxisSpacing: SolSpace.md,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final album = list[index];
                        return AlbumCard(
                          album: album,
                          // Tapping the cover opens the album and starts it:
                          // one tap from the grid to music is the point of a
                          // player, and the detail page is one push away for
                          // anyone who wants to pick a track.
                          onTap: () => context.router.push(
                            AlbumDetailRoute(
                              albumId: album.id,
                              albumName: album.name,
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Symbols.error_rounded,
                title: 'Could not load albums',
                message: describeServerError(error),
                iconColor: Theme.of(context).colorScheme.error,
                action: FilledButton(
                  onPressed: () =>
                      ref.read(recentAlbumsProvider.notifier).refresh(),
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

/// Shared album cover card, used by the grid and the browse shelves.
class AlbumCard extends StatelessWidget {
  final SubsonicAlbum album;
  final VoidCallback onTap;

  const AlbumCard({super.key, required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: SolRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.all(SolSpace.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: ServerArtwork(
                  coverArtId: album.coverArt,
                  radius: SolRadius.md,
                  fallbackIcon: Symbols.album,
                ),
              ),
            ),
            const SizedBox(height: SolSpace.sm),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              album.artist ?? 'Unknown artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One album's track list, with a play-all header.
@RoutePage()
class AlbumDetailScreen extends ConsumerWidget {
  final String albumId;
  final String? albumName;

  const AlbumDetailScreen({
    super.key,
    @PathParam('albumId') required this.albumId,
    this.albumName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(albumSongsProvider(albumId));
    final playback = ref.watch(playbackProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: albumName ?? 'Album',
            subtitle: songs.maybeWhen(
              data: (list) => list.isEmpty
                  ? null
                  : '${list.length} tracks  ·  '
                        '${formatDuration(
                          list.fold(Duration.zero, (sum, s) => sum + s.duration),
                        )}',
              orElse: () => null,
            ),
            actions: [
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
                      icon: Symbols.album,
                      title: 'This album is empty',
                      message: 'The server returned no tracks for it.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SolSpace.xxl,
                              SolSpace.sm,
                              SolSpace.xxl,
                              SolSpace.md,
                            ),
                            child: Row(
                              children: [
                                ServerArtwork(
                                  coverArtId: list.first.coverArt,
                                  size: 132,
                                  radius: SolRadius.lg,
                                  fallbackIcon: Symbols.album,
                                ),
                                const SizedBox(width: SolSpace.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () => ref
                                            .read(playbackProvider.notifier)
                                            .playQueue(list),
                                        icon: const Icon(
                                          Symbols.play_arrow_rounded,
                                        ),
                                        label: const Text('Play'),
                                      ),
                                      const SizedBox(height: SolSpace.sm),
                                      Text(
                                        '${list.first.artist ?? 'Unknown artist'}'
                                        '${list.first.year == null ? '' : '  ·  ${list.first.year}'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final song = list[index - 1];
                        return TrackRow(
                          title: song.title,
                          subtitle: song.artist ?? 'Unknown artist',
                          selected: playback.current?.id == song.id,
                          trailing: formatDuration(song.duration),
                          artwork: ServerArtwork(
                            coverArtId: song.coverArt,
                            size: 44,
                            radius: SolRadius.xs,
                          ),
                          onTap: () => ref
                              .read(playbackProvider.notifier)
                              .playQueue(list, startIndex: index - 1),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Symbols.error_rounded,
                title: 'Could not load this album',
                message: describeServerError(error),
                iconColor: Theme.of(context).colorScheme.error,
                action: FilledButton(
                  onPressed: () => ref.invalidate(albumSongsProvider(albumId)),
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
