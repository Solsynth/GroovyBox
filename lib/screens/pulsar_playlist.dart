import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/pill_app_bar.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One cloud playlist's tracks, with a play-all button.
///
/// The playlist lives on Pulsar; the tracks it names are matched against the
/// connected library sources, so what plays is the user's own copy of the
/// recording. A track no source holds is skipped rather than shown as a
/// blank: a playlist is not a graveyard, here either.
///
/// The page reads the detail endpoint, not the list: the list never preloads
/// items, so a page built from it showed every cloud playlist as empty.
/// Editing is here because this is the only surface that knows the item ids
/// a removal needs — adding happens where tracks are, through the player's
/// add-to-playlist action.
@RoutePage()
class PulsarPlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;
  final String? playlistName;

  const PulsarPlaylistDetailScreen({
    super.key,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = await askPlaylistName(
      context,
      title: 'ownedPlaylistRenameTitle'.tr(),
      initial: current,
      confirmLabelKey: 'commonSave',
    );
    if (name == null || name == current) return;
    try {
      await ref.read(pulsarPlaylistsProvider.notifier).rename(playlistId, name);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('pulsarPlaylistDeleteTitle'.tr()),
        content: Text('pulsarPlaylistDeleteMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('commonCancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('commonDelete'.tr()),
          ),
        ],
      ),
    );
    if (agreed != true) return;
    final playlist = ref
        .read(pulsarPlaylistsProvider)
        .value
        ?.where((p) => p.id == playlistId)
        .firstOrNull;
    if (playlist == null) return;
    try {
      await ref.read(pulsarPlaylistsProvider.notifier).delete(playlist);
      if (context.mounted) context.router.maybePop();
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }

  /// Removes one track, with an undo window rather than a confirm: the
  /// removal is one tap to redo, and a confirm would be asked on every
  /// tidying pass through a playlist.
  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    PulsarPlaylist playlist,
    PlaylistItem item,
    LibrarySong song,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(pulsarPlaylistsProvider.notifier)
          .removeItem(playlist, item);
      ref.invalidate(pulsarPlaylistDetailProvider(playlistId));
      messenger?.showSnackBar(
        SnackBar(
          content: Text('ownedPlaylistRemoved'.tr(args: [song.playing.title])),
          action: SnackBarAction(
            label: 'commonUndo'.tr(),
            onPressed: () async {
              await ref
                  .read(pulsarPlaylistsProvider.notifier)
                  .addSong(playlist, song);
              ref.invalidate(pulsarPlaylistDetailProvider(playlistId));
            },
          ),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(pulsarPlaylistDetailProvider(playlistId));
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
            PillHeader(
              title:
                  detail.value?.name ??
                  playlistName ??
                  'playlistsDetailTitleFallback'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
              subtitle: detail.maybeWhen(
                data: (playlist) => playlist.items.isEmpty
                    ? 'pulsarPlaylistEmptyHeader'.tr()
                    : null,
                orElse: () => null,
              ),
              actions: [
                IconButton(
                  tooltip: 'ownedPlaylistRename'.tr(),
                  icon: const Icon(Symbols.edit_rounded),
                  onPressed: detail.value == null
                      ? null
                      : () => _rename(context, ref, detail.value!.name),
                ),
                IconButton(
                  tooltip: 'commonDelete'.tr(),
                  icon: const Icon(Symbols.delete_rounded),
                  onPressed: () => _confirmDelete(context, ref),
                ),
                const SizedBox(width: SolSpace.sm),
              ],
            ),
            Expanded(
              child: detail.when(
                data: (playlist) => ref
                    .watch(pulsarPlaylistSongsProvider(playlist))
                    .when(
                      data: (list) {
                        if (playlist.items.isEmpty) {
                          return EmptyState(
                            icon: Symbols.cloud_rounded,
                            title: 'pulsarPlaylistEmptyTitle'.tr(),
                            message: 'pulsarPlaylistEmptyMessage'.tr(),
                          );
                        }
                        // The resolver is index-aligned with the items, so
                        // a track the libraries cannot name keeps its row
                        // instead of shifting the ones after it.
                        final pairs = [
                          for (var i = 0; i < playlist.items.length; i++)
                            (playlist.items[i], list[i]),
                        ];
                        final playable = [for (final (_, song) in pairs) ?song];
                        return ListView.builder(
                          padding: EdgeInsets.only(bottom: bottomInset),
                          itemCount: pairs.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return CollectionHero(
                                artId: null,
                                eyebrow: 'pulsarPlaylistKind'.tr(),
                                meta: [
                                  if (playlist.description != null &&
                                      playlist.description!.isNotEmpty)
                                    playlist.description!,
                                  'playlistsTrackCount'.plural(
                                    playlist.items.length,
                                  ),
                                ].join('  ·  '),
                                fallbackIcon: Symbols.cloud_rounded,
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
                              );
                            }
                            final (item, song) = pairs[index - 1];
                            final track = item.catalogItem;
                            if (song == null || track == null) {
                              return SongTrackRow(
                                song: LibrarySong(
                                  sourceId: '',
                                  id: item.id,
                                  title: track?.title ?? '',
                                  artist: track?.subtitle,
                                  duration: Duration(
                                    seconds: track?.durationSeconds ?? 0,
                                  ),
                                ),
                                subtitle: 'pulsarPlaylistUnmatched'.tr(),
                                trailing: track?.durationSeconds == null
                                    ? null
                                    : formatDuration(
                                        Duration(
                                          seconds: track!.durationSeconds!,
                                        ),
                                      ),
                              );
                            }
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
                                  .playQueue(
                                    playable,
                                    startIndex: playable.indexOf(song),
                                  ),
                              onLongPress: () => _removeItem(
                                context,
                                ref,
                                playlist,
                                item,
                                song,
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => EmptyState(
                        icon: Symbols.error_rounded,
                        title: 'playlistsDetailLoadError'.tr(),
                        message: describeServerError(error),
                        iconColor: Theme.of(context).colorScheme.error,
                        action: FilledButton(
                          onPressed: () => ref.invalidate(
                            pulsarPlaylistDetailProvider(playlistId),
                          ),
                          child: Text('commonTryAgain'.tr()),
                        ),
                      ),
                    ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  icon: Symbols.error_rounded,
                  title: 'playlistsDetailLoadError'.tr(),
                  message: describeServerError(error),
                  iconColor: Theme.of(context).colorScheme.error,
                  action: FilledButton(
                    onPressed: () => ref.invalidate(
                      pulsarPlaylistDetailProvider(playlistId),
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
