import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The account's favourites, as Solink holds them, as a playlist page.
///
/// Solink is the record: this is the list every device writes to and every
/// import lands in, so it is a collection like any other — it has a cover, a
/// count and a play button, and it opens into its tracks. Embedding the tracks
/// on the library page made one list render differently from every other list
/// there and cost the library a scroll of rows it could not fold.
///
/// A recording this device can play is matched to its own copy and played from
/// there; one it cannot play yet stays visible, because its presence is what
/// the next import or library connection fills in.
@RoutePage()
class SolinkFavouritesScreen extends ConsumerWidget {
  const SolinkFavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(pulsarFavouritesProvider);
    final songs = ref.watch(solarFavouriteSongsProvider);
    // One boolean, not the transport: rows decide their own selection.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BackButtonRow(onBack: () => context.router.maybePop()),
            ),
            ...favourites.when(
              data: (list) {
                if (list.isEmpty) {
                  return [
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Symbols.favorite_rounded,
                        title: 'libraryCloudFavouritesEmptyTitle'.tr(),
                        message: 'libraryCloudFavouritesEmptyMessage'.tr(),
                      ),
                    ),
                  ];
                }
                // Index-aligned with the account's order: a null is a track
                // no connected library holds, and dropping it would shift
                // every row after it onto the wrong recording.
                final resolved = songs.value ?? const <LibrarySong?>[];
                final playable = [for (final song in resolved) ?song];
                final cover = list
                    .map((item) => item.catalogItem?.artworkUrl)
                    .whereType<String>()
                    .where((url) => url.isNotEmpty)
                    .firstOrNull;
                return [
                  SliverToBoxAdapter(
                    child: CollectionHero(
                      artworkUrl: cover,
                      eyebrow: 'libraryCloudFavourites'.tr(),
                      meta: 'playlistsTrackCount'.plural(list.length),
                      fallbackIcon: Symbols.favorite_rounded,
                      actions: [
                        FilledButton.icon(
                          onPressed: playable.isEmpty
                              ? null
                              : () => ref
                                    .read(playbackProvider.notifier)
                                    .playQueue(playable),
                          icon: const Icon(
                            Symbols.play_arrow_rounded,
                            size: 20,
                          ),
                          label: Text('commonPlay'.tr()),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'libraryShuffle'.tr(),
                          onPressed: playable.isEmpty
                              ? null
                              : () {
                                  final notifier = ref.read(
                                    playbackProvider.notifier,
                                  );
                                  notifier.playQueue(playable);
                                  notifier.setShuffle(true);
                                },
                          icon: const Icon(Symbols.shuffle_rounded),
                        ),
                      ],
                    ),
                  ),
                  SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final track = item.catalogItem;
                      final catalogId = item.catalogId;
                      if (track == null || catalogId == null) {
                        return const SizedBox.shrink();
                      }
                      final song = index < resolved.length
                          ? resolved[index]
                          : null;
                      return _CloudFavouriteRow(
                        track: track,
                        song: song,
                        onPlay: song == null || playable.isEmpty
                            ? null
                            : () => ref
                                  .read(playbackProvider.notifier)
                                  .playQueue(
                                    playable,
                                    startIndex: playable.indexOf(song),
                                  ),
                        onRemove: () =>
                            _remove(context, ref, catalogId, track, song),
                      );
                    },
                  ),
                ];
              },
              loading: () => const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(SolSpace.huge),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (error, _) => [
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Symbols.error_rounded,
                    title: 'playlistsDetailLoadError'.tr(),
                    message: describeServerError(error),
                    iconColor: Theme.of(context).colorScheme.error,
                    action: FilledButton(
                      onPressed: () =>
                          ref.invalidate(pulsarFavouritesProvider),
                      child: Text('commonTryAgain'.tr()),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String catalogId,
    CatalogItem track,
    LibrarySong? song,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(pulsarFavouritesProvider.notifier).clear(catalogId);
      // The device's own heart goes with it: the sync pushes every local heart
      // the account is missing, so leaving it behind would put this one back
      // on the next run.
      if (song != null) {
        await ref.read(favouritesProvider).set(song, value: false);
        ref.invalidate(favouriteStateProvider(song));
      }
      // The account's key set is what the hearts read, so one removal turns
      // every surface that asked.
      ref.invalidate(solarFavouriteKeysProvider);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('libraryCloudFavouriteRemoved'.tr(args: [track.title])),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }
}

/// One row of the account's favourites: the track, playable when this device
/// holds it, and the heart that takes it back out of the account.
class _CloudFavouriteRow extends ConsumerWidget {
  final CatalogItem track;
  final LibrarySong? song;
  final VoidCallback? onPlay;
  final VoidCallback onRemove;

  const _CloudFavouriteRow({
    required this.track,
    required this.song,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = song;
    if (local != null) {
      return SongTrackRow(
        song: local,
        subtitle: songRowSubtitle(ref, local),
        trailing: local.duration == Duration.zero
            ? null
            : formatDuration(local.duration),
        artwork: LibraryArtwork(
          sourceId: local.sourceId,
          artId: local.artId,
          size: 48,
          radius: SolRadius.xs,
        ),
        onTap: onPlay,
        onLongPress: onRemove,
      );
    }
    final art = track.artworkUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(SolRadius.md),
            child: SizedBox.square(
              dimension: 48,
              child: art == null || art.isEmpty
                  ? ColoredBox(
                      color: scheme.surfaceContainerHigh,
                      child: Icon(
                        Symbols.favorite_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Image.network(
                      art,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: Icon(
                          Symbols.favorite_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: SolSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  track.subtitle ?? 'pulsarPlaylistUnmatched'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'libraryCloudFavouriteRemove'.tr(),
            icon: const Icon(Symbols.favorite_rounded),
            color: scheme.error,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
