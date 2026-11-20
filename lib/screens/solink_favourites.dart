import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/solarpass/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_picker.dart';
import 'package:groovy_box/widgets/track_selection.dart';
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
class SolinkFavouritesScreen extends ConsumerStatefulWidget {
  const SolinkFavouritesScreen({super.key});

  @override
  ConsumerState<SolinkFavouritesScreen> createState() =>
      _SolinkFavouritesScreenState();
}

class _SolinkFavouritesScreenState
    extends ConsumerState<SolinkFavouritesScreen> {
  final _selection = TrackSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _selection
      ..removeListener(_onSelectionChanged)
      ..dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  /// The ticked rows' playable copies, in the account's order.
  List<LibrarySong> _selectedSongs(
    List<PlaylistItem> list,
    List<LibrarySong?> resolved,
  ) => [
    for (var i = 0; i < list.length; i++)
      if (list[i].catalogId case final id?
          when _selection.contains(id))
        if (i < resolved.length) ?resolved[i],
  ];

  /// Puts the ticked recordings into another playlist. Only the ones this
  /// device can name are offered: a row without a copy has nothing to write.
  Future<void> _addSelected(
    List<PlaylistItem> list,
    List<LibrarySong?> resolved,
  ) async {
    final songs = _selectedSongs(list, resolved);
    if (songs.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result = await addTracksToPlaylist(context, songs: songs);
      if (result == null) return;
      _selection.end();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'playlistSelectionAdded'.plural(
              result.added,
              args: [result.name],
            ),
          ),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }

  /// Keeps the ticked recordings on this device.
  Future<void> _downloadSelected(
    List<PlaylistItem> list,
    List<LibrarySong?> resolved,
  ) async {
    final songs = [
      for (final song in _selectedSongs(list, resolved))
        if (!song.isRadio) song,
    ];
    if (songs.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final added = await ref
        .read(downloadsControllerProvider.notifier)
        .downloadAll(songs);
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? 'downloadsNothingNew'.tr()
              : 'downloadsAdded'.plural(added),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(pulsarFavouritesProvider);
    final songs = ref.watch(solarFavouriteSongsProvider);
    // The bar floats above the page, so the list reserves its height too:
    // the last row must be able to scroll out from under it.
    final barOffset = solFloatingBarOffset(context);
    final extraBottom = _selection.active
        ? kSelectionBarHeight + SolSpace.md
        : 0.0;
    final creator = ref.watch(solarpassAccountProvider).value?.displayName;

    // Index-aligned with the account's order: a null is a track no connected
    // library holds, and dropping it would shift every row after it onto the
    // wrong recording. The bar reads the same pairing the rows do.
    final list = favourites.value ?? const <PlaylistItem>[];
    final resolved = songs.value ?? const <LibrarySong?>[];
    // The catalog id is the row's identity here: it is what a removal names,
    // and it exists whether or not this device holds a copy of the recording.
    final keys = [
      for (final item in list)
        if (item.catalogId != null) item.catalogId!,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SelectionBarOverlay(
        selection: _selection,
        bottom: barOffset,
        bar: SelectionToolbar(
          selection: _selection,
          keys: keys,
          onPlay: () => ref
              .read(playbackProvider.notifier)
              .playQueue(_selectedSongs(list, resolved)),
          onAddToPlaylist: () => _addSelected(list, resolved),
          onDownload: () => _downloadSelected(list, resolved),
          onRemove: () => _removeSelected(list),
        ),
        child: ContentFrame(
          child: PageScrollView(
            extraBottom: extraBottom,
            slivers: [
              SliverToBoxAdapter(
                child: BackButtonRow(onBack: () => context.router.maybePop()),
              ),
              ...favourites.when(
                data: (rows) {
                  if (rows.isEmpty) {
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
                  final playable = [for (final song in resolved) ?song];
                  final cover = rows
                      .map((item) => item.catalogItem?.artworkUrl)
                      .whereType<String>()
                      .where((url) => url.isNotEmpty)
                      .firstOrNull;
                  return [
                    SliverToBoxAdapter(
                      child: CollectionHero(
                        artworkUrl: cover,
                        source: 'settingsSectionSolarNetwork'.tr(),
                        title: 'libraryCloudFavourites'.tr(),
                        eyebrow: 'settingsSectionSolarNetwork'.tr(),
                        meta: [
                          if (creator != null && creator.isNotEmpty) creator,
                          'playlistsTrackCount'.plural(rows.length),
                        ].join('  ·  '),
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
                          SelectionToggleButton(selection: _selection),
                        ],
                      ),
                    ),
                    SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        final track = item.catalogItem;
                        final catalogId = item.catalogId;
                        if (track == null || catalogId == null) {
                          return const SizedBox.shrink();
                        }
                        final song = index < resolved.length
                            ? resolved[index]
                            : null;
                        void onTap() {
                          if (_selection.active) {
                            _selection.toggle(catalogId);
                            return;
                          }
                          if (song == null || playable.isEmpty) return;
                          ref
                              .read(playbackProvider.notifier)
                              .playQueue(
                                playable,
                                startIndex: playable.indexOf(song),
                              );
                        }

                        return _CloudFavouriteRow(
                          track: track,
                          song: song,
                          onPlay: onTap,
                          artwork: SelectionCover(
                            selection: _selection,
                            rowKey: catalogId,
                            child: _CloudFavouriteCover(
                              track: track,
                              song: song,
                            ),
                          ),
                          onLongPress: _selection.active
                              ? null
                              : () => _remove(catalogId, track, song),
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
                        onPressed: () => ref.invalidate(pulsarFavouritesProvider),
                        child: Text('commonTryAgain'.tr()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Takes several recordings out of the account's favourites in one pass,
  /// and the device's own hearts with them: the next sync pushes every local
  /// heart the account is missing, so leaving them would put them all back.
  Future<void> _removeSelected(List<PlaylistItem> list) async {
    final picked = [
      for (final item in list)
        if (item.catalogId case final id? when _selection.contains(id)) item,
    ];
    if (picked.isEmpty) return;
    final agreed = await confirmBatchRemove(context, count: picked.length);
    if (!agreed || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final songs = ref.read(solarFavouriteSongsProvider).value;
    try {
      for (final item in picked) {
        final catalogId = item.catalogId!;
        await ref.read(pulsarFavouritesProvider.notifier).clear(catalogId);
        final index = list.indexOf(item);
        final song = songs != null && index < songs.length
            ? songs[index]
            : null;
        if (song != null) {
          await ref.read(favouritesProvider).set(song, value: false);
          ref.invalidate(favouriteStateProvider(song));
        }
      }
      // The account's key set is what the hearts read, so one removal turns
      // every surface that asked.
      ref.invalidate(solarFavouriteKeysProvider);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('playlistSelectionRemoved'.plural(picked.length)),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    } finally {
      _selection.end();
    }
  }

  Future<void> _remove(
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

/// The cover of one favourite: the device's own art when it holds a copy,
/// the account's `artwork_url` otherwise, and the heart when neither exists.
class _CloudFavouriteCover extends StatelessWidget {
  final CatalogItem track;
  final LibrarySong? song;

  const _CloudFavouriteCover({required this.track, required this.song});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final local = song;
    final art = track.artworkUrl;
    if (local != null) {
      return LibraryArtwork(
        sourceId: local.sourceId,
        artId: local.artId,
        size: 48,
        radius: SolRadius.xs,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(SolRadius.xs),
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
    );
  }
}

/// One row of the account's favourites: the track, playable when this device
/// holds it, and the heart that takes it back out of the account.
///
/// A favourite no library holds has no song to draw a row from, so it keeps
/// its own two-line layout. It is written at the same metrics as [TrackRow]
/// so the list does not change rhythm at the one row the device cannot play.
class _CloudFavouriteRow extends ConsumerWidget {
  final CatalogItem track;
  final LibrarySong? song;
  final Widget artwork;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;

  const _CloudFavouriteRow({
    required this.track,
    required this.song,
    required this.artwork,
    required this.onPlay,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = song;
    if (local != null) {
      return SongTrackRow(
        song: local,
        subtitle: songRowSubtitle(ref, local),
        trailing: local.duration == Duration.zero
            ? null
            : formatDuration(local.duration),
        artwork: artwork,
        onTap: onPlay,
        onLongPress: onLongPress,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPlay,
          onLongPress: onLongPress,
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
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
