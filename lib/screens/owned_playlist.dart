import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:groovy_box/widgets/section.dart';
import 'package:groovy_box/widgets/track_selection.dart';
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
///
/// Selection is the batch form of the same job: tick several rows, then play
/// them or take them out in one go. It is a mode rather than a second list,
/// so the rows keep their shape and the hero's action slot says what a tap
/// means right now.
@RoutePage()
class OwnedPlaylistDetailScreen extends ConsumerStatefulWidget {
  final int playlistId;
  final String? playlistName;

  const OwnedPlaylistDetailScreen({
    super.key,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  @override
  ConsumerState<OwnedPlaylistDetailScreen> createState() =>
      _OwnedPlaylistDetailScreenState();
}

class _OwnedPlaylistDetailScreenState
    extends ConsumerState<OwnedPlaylistDetailScreen> {
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

  Future<void> _confirmDelete() async {
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
    await ref.read(ownedPlaylistsProvider.notifier).delete(widget.playlistId);
    if (mounted) context.router.maybePop();
  }

  Future<void> _rename(String current) async {
    final name = await askPlaylistName(
      context,
      title: 'ownedPlaylistRenameTitle'.tr(),
      initial: current,
      confirmLabelKey: 'commonSave',
    );
    if (name == null || name == current) return;
    await ref
        .read(ownedPlaylistsProvider.notifier)
        .rename(widget.playlistId, name);
  }

  /// Plays the ticks in the playlist's own order, whatever order they were
  /// ticked in: a playlist is a sequence, and a batch is a slice of it.
  void _playSelected(List<OwnedPlaylistEntry> list) {
    final songs = [
      for (final entry in list)
        if (_selection.contains('${entry.entryId}')) entry.song,
    ];
    if (songs.isEmpty) return;
    ref.read(playbackProvider.notifier).playQueue(songs);
  }

  /// Removes every ticked entry in one write. Positions are not restored, so
  /// this is the one removal that asks first; a single row still removes with
  /// an undo window instead.
  Future<void> _removeSelected(List<OwnedPlaylistEntry> list) async {
    final ids = [
      for (final entry in list)
        if (_selection.contains('${entry.entryId}')) entry.entryId,
    ];
    if (ids.isEmpty) return;
    final agreed = await confirmBatchRemove(context, count: ids.length);
    if (!agreed || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref
        .read(ownedPlaylistsProvider.notifier)
        .removeSongs(widget.playlistId, ids);
    ref.invalidate(ownedPlaylistEntriesProvider(widget.playlistId));
    _selection.end();
    messenger?.showSnackBar(
      SnackBar(content: Text('playlistSelectionRemoved'.plural(ids.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistId = widget.playlistId;
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BackButtonRow(onBack: () => context.router.maybePop()),
            ),
            ...entries.when(
              data: (list) {
                final trackList = [for (final e in list) e.song];
                if (list.isEmpty) {
                  return [
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Symbols.playlist_play,
                        title: 'ownedPlaylistEmptyTitle'.tr(),
                        message: 'ownedPlaylistEmptyMessage'.tr(),
                      ),
                    ),
                  ];
                }
                final keys = [for (final e in list) '${e.entryId}'];
                return [
                  SliverToBoxAdapter(
                    child: CollectionHero(
                      sourceId: playlist?.artId?.sourceId,
                      artId: playlist?.artId?.artId,
                      fallbackIcon: Symbols.playlist_play,
                      source: playlistSourceName(kLocalSourceId, ref),
                      title:
                          playlist?.name ??
                          widget.playlistName ??
                          'playlistsDetailTitleFallback'.tr(),
                      eyebrow: 'ownedPlaylistKind'.tr(),
                      meta: [
                        if (playlist != null)
                          'ownedPlaylistEdited'.tr(
                            args: [formatRelativeTime(playlist.updatedAt)],
                          ),
                      ].join('  ·  '),
                      actions: _selection.active
                          ? [
                              SelectionActions(
                                selection: _selection,
                                keys: keys,
                                onPlay: () => _playSelected(list),
                                onRemove: () => _removeSelected(list),
                              ),
                            ]
                          : [
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
                              // Editing lives beside the thing it edits, not
                              // in a bar above it: rename, delete and the
                              // cloud push all act on this one playlist.
                              IconButton(
                                tooltip: 'ownedPlaylistRename'.tr(),
                                onPressed: playlist == null
                                    ? null
                                    : () => _rename(playlist.name),
                                icon: const Icon(Symbols.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'commonDelete'.tr(),
                                onPressed: _confirmDelete,
                                icon: const Icon(Symbols.delete_rounded),
                              ),
                              PulsarUploadButton(
                                localKey: PulsarPlaylistLinks.deviceKey(
                                  playlistId,
                                ),
                                suggestedName:
                                    playlist?.name ?? widget.playlistName ?? '',
                                songs: (ref) =>
                                    PulsarUpload.deviceSongs(ref, playlistId),
                              ),
                              SelectionToggleButton(selection: _selection),
                            ],
                    ),
                  ),
                  SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final entry = list[index];
                      final song = entry.song;
                      final key = '${entry.entryId}';
                      return SongTrackRow(
                        song: song,
                        subtitle: songRowSubtitle(ref, song),
                        leading: _selection.active
                            ? SelectionCheckbox(
                                selection: _selection,
                                rowKey: key,
                              )
                            : Text(
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
                        onTap: () {
                          if (_selection.active) {
                            _selection.toggle(key);
                            return;
                          }
                          ref
                              .read(playbackProvider.notifier)
                              .playQueue(trackList, startIndex: entry.position);
                        },
                        onLongPress: _selection.active
                            ? null
                            : () => _removeEntry(entry),
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
                      onPressed: () => ref.invalidate(
                        ownedPlaylistEntriesProvider(playlistId),
                      ),
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

  /// Removes one track, with an undo window rather than a confirm: the
  /// removal is one tap to redo, and a confirm would be asked on every
  /// tidying pass through a playlist.
  Future<void> _removeEntry(OwnedPlaylistEntry entry) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref
        .read(ownedPlaylistsProvider.notifier)
        .removeSong(widget.playlistId, entry.entryId);
    ref.invalidate(ownedPlaylistEntriesProvider(widget.playlistId));
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'ownedPlaylistRemoved'.tr(args: [entry.song.playing.title]),
        ),
        action: SnackBarAction(
          label: 'commonUndo'.tr(),
          onPressed: () async {
            await ref.read(ownedPlaylistsProvider.notifier).add(
              widget.playlistId,
              [entry.song],
            );
            ref.invalidate(ownedPlaylistEntriesProvider(widget.playlistId));
          },
        ),
      ),
    );
  }
}
