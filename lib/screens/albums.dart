import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
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
                            list.fold(
                              Duration.zero,
                              (sum, s) => sum + s.duration,
                            ),
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
                            final first = list.first;
                            return CollectionHero(
                              sourceId: first.sourceId,
                              artId: first.artId,
                              eyebrow: 'albumsEyebrow'.tr(),
                              meta: [
                                first.artist ?? 'commonUnknownArtist'.tr(),
                                if (first.year != null) '${first.year}',
                                if (first.albumArtist != null &&
                                    first.albumArtist != first.artist)
                                  first.albumArtist!,
                              ].join('  ·  '),
                              actions: [
                                FilledButton.icon(
                                  onPressed: () => ref
                                      .read(playbackProvider.notifier)
                                      .playQueue(list),
                                  icon: const Icon(
                                    Symbols.play_arrow_rounded,
                                    size: 20,
                                  ),
                                  label: Text('albumsPlayAlbum'.tr()),
                                ),
                                IconButton.filledTonal(
                                  tooltip: 'libraryShuffle'.tr(),
                                  onPressed: () {
                                    final notifier = ref.read(
                                      playbackProvider.notifier,
                                    );
                                    notifier.playQueue(list);
                                    notifier.setShuffle(true);
                                  },
                                  icon: const Icon(Symbols.shuffle_rounded),
                                ),
                              ],
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            subtitle: song.artist ?? 'commonUnknownArtist'.tr(),
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
