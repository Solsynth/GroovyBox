import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/solarpass/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_favourite.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:groovy_box/widgets/playlist_picker.dart';
import 'package:groovy_box/widgets/track_selection.dart';
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
///
/// The creator of a Solink playlist is the account that made it: the list
/// endpoint only ever returns the signed-in account's own collections, so the
/// hero names that account rather than the first track's artist.
@RoutePage()
class PulsarPlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String? playlistName;

  const PulsarPlaylistDetailScreen({
    super.key,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  @override
  ConsumerState<PulsarPlaylistDetailScreen> createState() =>
      _PulsarPlaylistDetailScreenState();
}

class _PulsarPlaylistDetailScreenState
    extends ConsumerState<PulsarPlaylistDetailScreen> {
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

  Future<void> _rename(String current) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = await askPlaylistName(
      context,
      title: 'ownedPlaylistRenameTitle'.tr(),
      initial: current,
      confirmLabelKey: 'commonSave',
    );
    if (name == null || name == current) return;
    try {
      await ref
          .read(pulsarPlaylistsProvider.notifier)
          .rename(widget.playlistId, name);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }

  Future<void> _confirmDelete() async {
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
        ?.where((p) => p.id == widget.playlistId)
        .firstOrNull;
    if (playlist == null) return;
    try {
      await ref.read(pulsarPlaylistsProvider.notifier).delete(playlist);
      if (mounted) context.router.maybePop();
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
    PulsarPlaylist playlist,
    PlaylistItem item,
    LibrarySong song,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(pulsarPlaylistsProvider.notifier)
          .removeItem(playlist, item);
      ref.invalidate(pulsarPlaylistDetailProvider(widget.playlistId));
      messenger?.showSnackBar(
        SnackBar(
          content: Text('ownedPlaylistRemoved'.tr(args: [song.playing.title])),
          action: SnackBarAction(
            label: 'commonUndo'.tr(),
            onPressed: () async {
              await ref
                  .read(pulsarPlaylistsProvider.notifier)
                  .addSong(playlist, song);
              ref.invalidate(pulsarPlaylistDetailProvider(widget.playlistId));
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

  /// Removes every ticked item in one pass. The server has no batch delete,
  /// so this is several requests; a failure is reported and the page is
  /// re-read either way, because what remains is the truth.
  Future<void> _removeSelected(
    PulsarPlaylist playlist,
    List<PlaylistItem> items,
  ) async {
    if (items.isEmpty) return;
    final agreed = await confirmBatchRemove(context, count: items.length);
    if (!agreed || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(pulsarPlaylistsProvider.notifier)
          .removeItems(playlist, items);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('playlistSelectionRemoved'.plural(items.length)),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    } finally {
      ref.invalidate(pulsarPlaylistDetailProvider(widget.playlistId));
      _selection.end();
    }
  }

  /// The ticked rows' playable copies, in playlist order.
  List<LibrarySong> _selectedSongs(
    List<(PlaylistItem, LibrarySong?)> pairs,
  ) => [
    for (final (item, song) in pairs)
      if (_selection.contains(item.id)) ?song,
  ];

  /// Puts the ticked tracks into another playlist. Rows the libraries cannot
  /// name carry no song, so they are not offered: there is nothing to write.
  Future<void> _addSelected(
    List<(PlaylistItem, LibrarySong?)> pairs,
  ) async {
    final songs = _selectedSongs(pairs);
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

  /// Keeps the ticked tracks on this device.
  Future<void> _downloadSelected(
    List<(PlaylistItem, LibrarySong?)> pairs,
  ) async {
    final songs = [
      for (final song in _selectedSongs(pairs))
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
    final detail = ref.watch(pulsarPlaylistDetailProvider(widget.playlistId));
    // The bar floats above the page, so the list reserves its height too:
    // the last row must be able to scroll out from under it.
    final barOffset = solFloatingBarOffset(context);
    final extraBottom = _selection.active
        ? kSelectionBarHeight + SolSpace.md
        : 0.0;
    final creator = ref.watch(solarpassAccountProvider).value?.displayName;

    // The bar floats outside the scroll view, so it reads the same resolved
    // list the rows do. Both are derived from the same two providers; a null
    // playlist or an unresolved list simply means nothing is tickable yet.
    final playlist = detail.value;
    final resolved = playlist == null
        ? null
        : ref.watch(pulsarPlaylistSongsProvider(playlist)).value;
    // The resolver is index-aligned with the items, so a track the libraries
    // cannot name keeps its row instead of shifting the ones after it.
    final pairs = playlist == null || resolved == null
        ? const <(PlaylistItem, LibrarySong?)>[]
        : [
            for (var i = 0; i < playlist.items.length; i++)
              (playlist.items[i], resolved[i]),
          ];

    return Scaffold(
      body: SelectionBarOverlay(
        selection: _selection,
        bottom: barOffset,
        bar: SelectionToolbar(
          selection: _selection,
          keys: [for (final (item, _) in pairs) item.id],
          onPlay: () => ref
              .read(playbackProvider.notifier)
              .playQueue(_selectedSongs(pairs)),
          onAddToPlaylist: () => _addSelected(pairs),
          onDownload: () => _downloadSelected(pairs),
          onRemove: () => switch (playlist) {
            final playlist? => _removeSelected(playlist, [
              for (final (item, _) in pairs)
                if (_selection.contains(item.id)) item,
            ]),
            null => null,
          },
        ),
        child: ContentFrame(
          child: PageScrollView(
            extraBottom: extraBottom,
            slivers: [
              SliverToBoxAdapter(
                child: BackButtonRow(onBack: () => context.router.maybePop()),
              ),
              ...detail.when(
                data: (playlist) {
                  final list = ref.watch(pulsarPlaylistSongsProvider(playlist));
                  return list.when(
                    data: (list) {
                      if (playlist.items.isEmpty) {
                        return [
                          SliverToBoxAdapter(
                            child: EmptyState(
                              icon: Symbols.cloud_rounded,
                              title: 'pulsarPlaylistEmptyTitle'.tr(),
                              message: 'pulsarPlaylistEmptyMessage'.tr(),
                            ),
                          ),
                        ];
                      }
                      final rows = [
                        for (var i = 0; i < playlist.items.length; i++)
                          (playlist.items[i], list[i]),
                      ];
                      final playable = [for (final (_, song) in rows) ?song];
                      // The collection's own cover, or its first named track's
                      // when the cloud record has none: a playlist filled by
                      // uploading tracks never had an artwork_url of its own.
                      final cover =
                          playlist.artworkUrl ??
                          rows
                              .map((pair) => pair.$1.catalogItem?.artworkUrl)
                              .whereType<String>()
                              .where((url) => url.isNotEmpty)
                              .firstOrNull;
                      return [
                        SliverToBoxAdapter(
                          child: CollectionHero(
                            artworkUrl: cover,
                            source: 'settingsSectionSolarNetwork'.tr(),
                            title: playlist.name.isEmpty
                                ? 'pulsarPlaylistKind'.tr()
                                : playlist.name,
                            eyebrow: 'pulsarPlaylistKind'.tr(),
                            meta: [
                              if (creator != null && creator.isNotEmpty)
                                creator,
                              if (playlist.description != null &&
                                  playlist.description!.isNotEmpty)
                                playlist.description!,
                              'playlistsTrackCount'.plural(
                                playlist.items.length,
                              ),
                            ].join('  ·  '),
                            fallbackIcon: Symbols.cloud_rounded,
                            // The hero keeps the collection's own actions; a
                            // batch belongs to the bar over the rows.
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
                              IconButton(
                                tooltip: 'ownedPlaylistRename'.tr(),
                                onPressed: () => _rename(playlist.name),
                                icon: const Icon(Symbols.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'commonDelete'.tr(),
                                onPressed: _confirmDelete,
                                icon: const Icon(Symbols.delete_rounded),
                              ),
                              SelectionToggleButton(selection: _selection),
                              // A Solink playlist is a favourite in its own
                              // right: its source is [kSolinkSourceId], since
                              // no library behind it can be asked.
                              CollectionFavouriteButton(
                                favourite: solinkPlaylistFavourite(
                                  playlist,
                                  cover: cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final (item, song) = rows[index];
                            final track = item.catalogItem;
                            void onTap() {
                              if (_selection.active) {
                                _selection.toggle(item.id);
                                return;
                              }
                              if (song == null) return;
                              ref
                                  .read(playbackProvider.notifier)
                                  .playQueue(
                                    playable,
                                    startIndex: playable.indexOf(song),
                                  );
                            }

                            final artwork = SelectionCover(
                              selection: _selection,
                              rowKey: item.id,
                              child: LibraryArtwork(
                                sourceId: song?.sourceId,
                                artId: song?.artId,
                                size: 48,
                                radius: SolRadius.xs,
                                fallbackIcon: Symbols.cloud_rounded,
                              ),
                            );
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
                                artwork: artwork,
                                subtitle: 'pulsarPlaylistUnmatched'.tr(),
                                trailing: track?.durationSeconds == null
                                    ? null
                                    : formatDuration(
                                        Duration(
                                          seconds: track!.durationSeconds!,
                                        ),
                                      ),
                                onTap: onTap,
                              );
                            }
                            return SongTrackRow(
                              song: song,
                              subtitle: songRowSubtitle(ref, song),
                              trailing: formatDuration(song.duration),
                              artwork: artwork,
                              onTap: onTap,
                              onLongPress: _selection.active
                                  ? null
                                  : () => _removeItem(playlist, item, song),
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
                              pulsarPlaylistDetailProvider(widget.playlistId),
                            ),
                            child: Text('commonTryAgain'.tr()),
                          ),
                        ),
                      ),
                    ],
                  );
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
                          pulsarPlaylistDetailProvider(widget.playlistId),
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
}
