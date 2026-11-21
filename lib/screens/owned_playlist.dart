import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:groovy_box/widgets/playlist_picker.dart';
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

  /// Puts every ticked track into another playlist, one write per track for a
  /// cloud target and one transaction for a device one.
  Future<void> _addSelected(List<OwnedPlaylistEntry> list) async {
    final songs = [
      for (final entry in list)
        if (_selection.contains('${entry.entryId}')) entry.song,
    ];
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

  /// Keeps the ticked tracks on this device. The controller reports its own
  /// failures per track, so the bar only says how many landed.
  Future<void> _downloadSelected(List<OwnedPlaylistEntry> list) async {
    final songs = [
      for (final entry in list)
        if (_selection.contains('${entry.entryId}') && !entry.song.isRadio)
          entry.song,
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
    final playlistId = widget.playlistId;
    final playlist = ref.watch(
      ownedPlaylistsProvider.select(
        (state) => state.value?.where((p) => p.id == playlistId).firstOrNull,
      ),
    );
    final entries = ref.watch(ownedPlaylistEntriesProvider(playlistId));
    // The bar floats above the page, so the list reserves its height too:
    // the last row must be able to scroll out from under it.
    final barOffset = solFloatingBarOffset(context);
    final extraBottom = _selection.active
        ? kSelectionBarHeight + SolSpace.md
        : 0.0;
    final list = entries.value ?? const <OwnedPlaylistEntry>[];
    final keys = [for (final e in list) '${e.entryId}'];

    return Scaffold(
      body: SelectionBarOverlay(
        selection: _selection,
        // Above the shell's own floating chrome: the bar belongs to the page,
        // so it stacks rather than taking the dock's place.
        bottom: barOffset,
        bar: SelectionToolbar(
          selection: _selection,
          keys: keys,
          onPlay: () => _playSelected(list),
          onAddToPlaylist: () => _addSelected(list),
          onDownload: () => _downloadSelected(list),
          onRemove: () => _removeSelected(list),
        ),
        child: ContentFrame(
          child: PageScrollView(
            extraBottom: extraBottom,
            slivers: [
              SliverToBoxAdapter(
                child: BackButtonRow(onBack: () => context.router.maybePop()),
              ),
              ...entries.when(
                data: (rows) {
                  if (rows.isEmpty) {
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
                  final trackList = [for (final e in rows) e.song];
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
                        // The hero is about the collection, so it keeps the
                        // collection's actions. What happens to several rows
                        // at once is a different question, answered by the
                        // bar that floats over them.
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
                            localKey: PulsarPlaylistLinks.deviceKey(playlistId),
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
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final entry = rows[index];
                        final song = entry.song;
                        final key = '${entry.entryId}';
                        return SongTrackRow(
                          song: song,
                          subtitle: songRowSubtitle(ref, song),
                          // The row's shape does not change with the mode:
                          // the position keeps its slot and the cover takes
                          // the tick.
                          leading: Text(
                            '${entry.position + 1}',
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
                          artwork: SelectionCover(
                            selection: _selection,
                            rowKey: key,
                            child: LibraryArtwork(
                              sourceId: song.sourceId,
                              artId: song.artId,
                              size: 48,
                              radius: SolRadius.xs,
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
                                .playQueue(
                                  trackList,
                                  startIndex: entry.position,
                                );
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
            ],
          ),
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
