import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/pill_app_bar.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:groovy_box/pulsar/links.dart';
import 'package:groovy_box/widgets/pulsar_upload.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One playlist this device owns, as a page.
///
/// A device playlist is the one thing in the collection the app can actually
/// edit — a server's playlist is a view of someone else's database — so this
/// page is where editing lives: remove a track, rename, delete the whole
/// thing. Adding tracks happens where tracks are, through the player's
/// add-to-playlist action.
@RoutePage()
class OwnedPlaylistDetailScreen extends ConsumerWidget {
  final int playlistId;
  final String? playlistName;

  const OwnedPlaylistDetailScreen({
    super.key,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ownedPlaylistDeleteTitle'.tr()),
        content: Text('ownedPlaylistDeleteMessage'.tr()),
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
    await ref.read(ownedPlaylistsProvider.notifier).delete(playlistId);
    if (context.mounted) context.router.maybePop();
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final name = await askPlaylistName(
      context,
      title: 'ownedPlaylistRenameTitle'.tr(),
      initial: current,
      confirmLabelKey: 'commonSave',
    );
    if (name == null || name == current) return;
    await ref.read(ownedPlaylistsProvider.notifier).rename(playlistId, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(
      ownedPlaylistsProvider.select(
        (state) => state.value?.where((p) => p.id == playlistId).firstOrNull,
      ),
    );
    final entries = ref.watch(ownedPlaylistEntriesProvider(playlistId));
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
                  playlist?.name ??
                  playlistName ??
                  'playlistsDetailTitleFallback'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),

              actions: [
                PulsarUploadButton(
                  localKey: PulsarPlaylistLinks.deviceKey(playlistId),
                  suggestedName: playlist?.name ?? playlistName ?? '',
                  songs: (ref) => PulsarUpload.deviceSongs(ref, playlistId),
                ),
                IconButton(
                  tooltip: 'ownedPlaylistRename'.tr(),
                  icon: const Icon(Symbols.edit_rounded),
                  onPressed: playlist == null
                      ? null
                      : () => _rename(context, ref, playlist.name),
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
              child: entries.when(
                data: (list) {
                  final trackList = [for (final e in list) e.song];
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Symbols.playlist_play,
                      title: 'ownedPlaylistEmptyTitle'.tr(),
                      message: 'ownedPlaylistEmptyMessage'.tr(),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    itemCount: list.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return CollectionHero(
                          fallbackIcon: Symbols.playlist_play,
                          eyebrow: 'ownedPlaylistKind'.tr(),
                          meta: [
                            playlist?.name ?? playlistName ?? '',
                            if (playlist != null)
                              'ownedPlaylistEdited'.tr(
                                args: [formatRelativeTime(playlist.updatedAt)],
                              ),
                          ].join('  ·  '),
                          actions: [
                            FilledButton.icon(
                              onPressed: () => ref
                                  .read(playbackProvider.notifier)
                                  .playQueue(trackList),
                              icon: const Icon(
                                Symbols.play_arrow_rounded,
                                size: 20,
                              ),
                              label: Text('commonPlay'.tr()),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'libraryShuffle'.tr(),
                              onPressed: () {
                                final notifier = ref.read(
                                  playbackProvider.notifier,
                                );
                                notifier.playQueue(trackList);
                                notifier.setShuffle(true);
                              },
                              icon: const Icon(Symbols.shuffle_rounded),
                            ),
                          ],
                        );
                      }
                      final entry = list[index - 1];
                      final song = entry.song;
                      return SongTrackRow(
                        song: song,
                        subtitle: songRowSubtitle(ref, song),
                        leading: Text(
                          '${entry.position + 1}',
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
                        trailing: formatDuration(song.duration),
                        onTap: () => ref
                            .read(playbackProvider.notifier)
                            .playQueue(trackList, startIndex: entry.position),
                        onLongPress: () => _removeEntry(context, ref, entry),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  icon: Symbols.error_rounded,
                  title: 'playlistsDetailLoadError'.tr(),
                  message: describeServerError(error),
                  iconColor: Theme.of(context).colorScheme.error,
                  action: FilledButton(
                    onPressed: () => ref.invalidate(
                      ownedPlaylistEntriesProvider(playlistId),
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

  /// Removes one track, with an undo window rather than a confirm: the
  /// removal is one tap to redo, and a confirm would be asked on every
  /// tidying pass through a playlist.
  Future<void> _removeEntry(
    BuildContext context,
    WidgetRef ref,
    OwnedPlaylistEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref
        .read(ownedPlaylistsProvider.notifier)
        .removeSong(playlistId, entry.entryId);
    ref.invalidate(ownedPlaylistEntriesProvider(playlistId));
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'ownedPlaylistRemoved'.tr(args: [entry.song.playing.title]),
        ),
        action: SnackBarAction(
          label: 'commonUndo'.tr(),
          onPressed: () async {
            await ref.read(ownedPlaylistsProvider.notifier).add(playlistId, [
              entry.song,
            ]);
            ref.invalidate(ownedPlaylistEntriesProvider(playlistId));
          },
        ),
      ),
    );
  }
}
