import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
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
              title: 'playlistsTitle'.tr(),
              subtitle: playlists.maybeWhen(
                data: (list) => list.isEmpty
                    ? 'playlistsEmptyHeader'.tr()
                    : 'playlistsCount'.plural(list.length),
                orElse: () => null,
              ),
              actions: [
                IconButton(
                  tooltip: 'commonRefresh'.tr(),
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
                    ? EmptyState(
                        icon: Symbols.playlist_play,
                        title: 'playlistsEmptyTitle'.tr(),
                        message: 'playlistsEmptyMessage'.tr(),
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
                                'playlistsTrackCount'.plural(
                                  playlist.songCount!,
                                ),
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
                  title: 'playlistsLoadError'.tr(),
                  message: describeServerError(error),
                  iconColor: Theme.of(context).colorScheme.error,
                  action: FilledButton(
                    onPressed: () =>
                        ref.read(playlistsProvider.notifier).refresh(),
                    child: Text('commonTryAgain'.tr()),
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
    // One boolean, not the transport: rows decide their own selection.
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
              title: playlistName ?? 'playlistsDetailTitleFallback'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
              subtitle: songs.maybeWhen(
                data: (list) => list.isEmpty
                    ? 'playlistsDetailEmptyHeader'.tr()
                    : 'playlistsDetailTrackCount'.plural(
                        list.length,
                        args: [
                          '${list.length}',
                          formatDuration(
                            list.fold(Duration.zero, (sum, s) => sum + s.duration),
                          ),
                        ],
                      ),
                orElse: () => null,
              ),
              actions: [
                if (songs.hasValue && songs.value!.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(songs.value!),
                    icon: const Icon(Symbols.play_arrow_rounded, size: 20),
                    label: Text('commonPlay'.tr()),
                  ),
                const SizedBox(width: SolSpace.sm),
              ],
            ),
            Expanded(
              child: songs.when(
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Symbols.playlist_play,
                        title: 'playlistsDetailEmptyTitle'.tr(),
                        message: 'playlistsDetailEmptyMessage'.tr(),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final song = list[index];
                          return SongTrackRow(
                            song: song,
                            subtitle: songRowSubtitle(ref, song),
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
                  title: 'playlistsDetailLoadError'.tr(),
                  message: describeServerError(error),
                  iconColor: Theme.of(context).colorScheme.error,
                  action: FilledButton(
                    onPressed: () => ref.invalidate(
                      playlistSongsProvider((
                        sourceId: sourceId,
                        id: playlistId,
                      )),
                    ),
                    child: Text('commonTryAgain'.tr()),
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
