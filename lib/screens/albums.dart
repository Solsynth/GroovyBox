import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Shared album cover card, used by the library grid.
///
/// The cover lifts on hover instead of drawing a border: on a grid of
/// artwork, a hairline around every tile is noise, and motion is the cheapest
/// way to say "this is a target".
class AlbumCard extends StatefulWidget {
  final LibraryAlbum album;
  final VoidCallback onTap;

  const AlbumCard({super.key, required this.album, required this.onTap});

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: SolRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(SolSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedScale(
                    scale: _hovered ? 1.02 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SolRadius.md),
                        boxShadow: _hovered
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: LibraryArtwork(
                        sourceId: widget.album.sourceId,
                        artId: widget.album.artId,
                        radius: SolRadius.md,
                        fallbackIcon: Symbols.album,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SolSpace.sm),
              Text(
                widget.album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.album.artist ?? 'commonUnknownArtist'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One album's track list, with a play-all header.
///
/// On a wide window the cover and the actions sit side by side above the
/// tracks instead of stacking in the middle of the page.
@RoutePage()
class AlbumDetailScreen extends ConsumerWidget {
  /// Which library the album belongs to; albums are only unique per source.
  final String sourceId;
  final String albumId;
  final String? albumName;

  const AlbumDetailScreen({
    super.key,
    @PathParam('sourceId') required this.sourceId,
    @PathParam('albumId') required this.albumId,
    this.albumName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(
      albumSongsProvider((sourceId: sourceId, id: albumId)),
    );
    // One boolean, not the transport: a position tick must not rebuild an
    // album of twelve rows. Each row decides its own selection.
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
              title: albumName ?? 'albumsDetailTitleFallback'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
              subtitle: songs.maybeWhen(
                data: (list) => list.isEmpty
                    ? null
                    : 'albumsTrackCount'.plural(
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
            ),
            Expanded(
              child: songs.when(
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Symbols.album,
                        title: 'albumsDetailEmptyTitle'.tr(),
                        message: 'albumsDetailEmptyMessage'.tr(),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: list.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _AlbumHero(
                              songs: list,
                              onPlay: () => ref
                                  .read(playbackProvider.notifier)
                                  .playQueue(list),
                            );
                          }

                          final song = list[index - 1];
                          return SongTrackRow(
                            song: song,
                            // An album is a sequence: the number is the
                            // position in the record, which the title does
                            // not carry. The cover would be the same square
                            // twelve times, so the number takes its place.
                            leading: Text(
                              '${song.track ?? index}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            subtitle:
                                song.artist ?? 'commonUnknownArtist'.tr(),
                            trailing: formatDuration(song.duration),
                            onTap: () => ref
                                .read(playbackProvider.notifier)
                                .playQueue(list, startIndex: index - 1),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  icon: Symbols.error_rounded,
                  title: 'albumsDetailLoadError'.tr(),
                  message: describeServerError(error),
                  iconColor: Theme.of(context).colorScheme.error,
                  action: FilledButton(
                    onPressed: () => ref.invalidate(
                      albumSongsProvider((sourceId: sourceId, id: albumId)),
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

/// Cover, title block and play action at the top of an album.
class _AlbumHero extends StatelessWidget {
  final List<LibrarySong> songs;
  final VoidCallback onPlay;

  const _AlbumHero({required this.songs, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final first = songs.first;
    final wide = isWideScreen(context);
    final coverSize = wide ? 168.0 : 132.0;

    // The page header already names the record and counts its tracks: the
    // hero would only repeat it in smaller type. It carries what the header
    // does not — who made it, when, and the way in.
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          first.artist ?? 'commonUnknownArtist'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SolSpace.xxs),
        Text(
          [
            if (first.year != null) '${first.year}',
            if (first.genre != null) first.genre!,
            if (first.albumArtist != null &&
                first.albumArtist != first.artist)
              first.albumArtist!,
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SolSpace.md),
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Symbols.play_arrow_rounded),
          label: Text('albumsPlayAlbum'.tr()),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.sm,
        SolSpace.xxl,
        SolSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SolRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: LibraryArtwork(
              sourceId: first.sourceId,
              artId: first.artId,
              size: coverSize,
              radius: SolRadius.lg,
              fallbackIcon: Symbols.album,
            ),
          ),
          const SizedBox(width: SolSpace.lg),
          Expanded(child: details),
        ],
      ),
    );
  }
}
