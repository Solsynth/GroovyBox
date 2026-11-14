import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/song_actions.dart';
import 'package:groovy_box/widgets/track_versions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The queue, as a panel: a sheet in the now-playing capsule, a page-wide
/// list in the player.
///
/// The dock's queue button opens this instead of navigating anywhere: a
/// glance at what is next should not cost the page underneath, and the
/// transport stays visible below it while it is open. Shuffle and repeat live
/// on the player page's transport, which is the only place the whole queue is
/// a page of its own.
///
/// It paints no surface of its own — the capsule around it already is one, and
/// a second glass panel inside it would sample an already-sampled backdrop.
///
/// It fills the height the dock gives it. A list that measured itself would
/// make the capsule's `AnimatedSize` chase its own output, so the header is
/// fixed and the rows take the rest.
class QueuePanel extends ConsumerWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only what the list draws: a position tick must not re-sort or repaint
    // the queue once a second while a song plays.
    final state = ref.watch(
      playbackProvider.select(
        (state) => (
          queue: state.queue,
          stationTracks: state.stationTracks,
          currentIndex: state.currentIndex,
          stationIndex: state.stationIndex,
          shuffle: state.shuffle,
          repeatMode: state.repeatMode,
          queueRow: state.queueRow,
        ),
      ),
    );
    final controller = ref.read(playbackProvider.notifier);
    final theme = Theme.of(context);
    // A station plays a run the platform player generates, not the app's
    // queue: listing the queue under it would describe a list that is not
    // playing and cannot be reached.
    final stationRow = state.queueRow;
    final station = stationRow?.isRadio ?? false;
    final rows = station ? state.stationTracks : state.queue;
    final currentRow = station ? state.stationIndex : state.currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.sm,
            SolSpace.xs,
            SolSpace.sm,
            SolSpace.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'queueTitle'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // What this list *is*: a station's generated run is not
                    // the app's queue, and saying so is the only thing that
                    // explains why its rows cannot be tapped.
                    if (station)
                      Text(
                        'queueRadioFrom'.tr(
                          args: [
                            ref
                                    .watch(
                                      librarySourceByIdProvider,
                                    )[stationRow!.sourceId]
                                    ?.displayName ??
                                '',
                            stationRow.title,
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                queueSummary(rows.length, station ? false : state.shuffle),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Shuffle and repeat live here rather than on the transport:
              // they are statements about this list, and the header is the
              // list's own row. Off in the transport they were reachable only
              // from the player page, while this pane opens from the dock too.
              if (!station) ...[
                IconButton(
                  tooltip: 'playerShuffle'.tr(),
                  isSelected: state.shuffle,
                  onPressed: () =>
                      controller.setShuffle(!state.shuffle),
                  icon: const Icon(Symbols.shuffle_rounded),
                ),
                IconButton(
                  tooltip: state.repeatMode == PlaybackRepeatMode.single
                      ? 'playerRepeatSong'.tr()
                      : 'playerRepeat'.tr(),
                  isSelected: state.repeatMode != PlaybackRepeatMode.off,
                  onPressed: controller.cycleRepeatMode,
                  icon: Icon(
                    state.repeatMode == PlaybackRepeatMode.single
                        ? Symbols.repeat_one_rounded
                        : Symbols.repeat_rounded,
                  ),
                ),
              ],
              const _QueueHeaderMenu(),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  compact: true,
                  icon: Symbols.queue_music,
                  title: 'queueEmptyTitle'.tr(),
                  message: 'queueEmptyMessage'.tr(),
                )
              : ListView.builder(
                  // Room under the last row, so a short pane does not end
                  // with a row flush against its bottom edge.
                  padding: const EdgeInsets.only(bottom: SolSpace.sm),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final song = rows[index];
                    return TrackRow(
                      // A station's row is rewritten with what it is playing,
                      // so the queue says what is on the air, not the name of
                      // the station it started from.
                      title: song.playing.title,
                      subtitle: songRowSubtitle(ref, song.playing),
                      selected: currentRow == index,
                      trailing: formatDuration(song.duration),
                      artwork: LibraryArtwork(
                        sourceId: song.sourceId,
                        artId: song.playing.artId,
                        size: 40,
                        radius: SolRadius.xs,
                      ),
                      // Inside a station, a row is reached by skipping to it;
                      // the run is the platform player's to advance.
                      onTap: station
                          ? null
                          : () => controller.playQueue(
                              state.queue,
                              startIndex: index,
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// The more menu at the queue header's trailing edge.
///
/// A [MenuAnchor] rather than a sheet: the actions are few and read as a
/// continuation of the header's own controls, so the menu opens from the
/// button that named them. The sheet items — playback info, other versions —
/// anchor to the same button, so on iPad they land beside what was tapped
/// rather than at the window edge.
class _QueueHeaderMenu extends ConsumerWidget {
  const _QueueHeaderMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(
      playbackProvider.select((state) => state.current),
    );
    if (song == null) return const SizedBox.shrink();

    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        tooltip: 'playerMore'.tr(),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Symbols.more_horiz_rounded),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Symbols.info_rounded),
          onPressed: () => _PlaybackInfoSheet.show(context, song),
          child: Text('playerPlaybackInfo'.tr()),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.content_copy_rounded),
          onPressed: song.isRadio
              ? null
              : () => TrackVersionsPanel.show(context, song),
          child: Text('versionsTitle'.tr()),
        ),
        const Divider(height: 1),
        const _SongActionsMenuItems(),
      ],
    );
  }
}

/// The track's own writes — favourite, playlist, share — as menu items.
///
/// The same capabilities the player page's action bar draws, asked again here
/// so the menu offers only what the playing source can actually do.
class _SongActionsMenuItems extends ConsumerWidget {
  const _SongActionsMenuItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(
      playbackProvider.select((state) => state.current),
    );
    if (song == null) return const SizedBox.shrink();
    final source = ref.watch(
      librarySourceByIdProvider.select(
        (sources) => sources[song.sourceId],
      ),
    );
    final actions = SongActions(
      source is RatedSource ? source : null,
      source is ExtendableSource ? source : null,
      song,
    );
    if (!actions.canFavourite &&
        !actions.canAddToPlaylist &&
        !ref.watch(pulsarSessionProvider.select((s) => s.value != null))) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.canFavourite)
          MenuItemButton(
            leadingIcon: const Icon(Symbols.favorite_border_rounded),
            child: Text('playerFavourite'.tr()),
            onPressed: () => SongActionsRunner.toggleFavourite(context, ref, actions),
          ),
        if (actions.canAddToPlaylist)
          MenuItemButton(
            leadingIcon: const Icon(Symbols.playlist_add_rounded),
            child: Text('playerAddToPlaylist'.tr()),
            onPressed: () => SongActionsRunner.pickPlaylist(context, ref, actions),
          ),
        if (ref.watch(pulsarSessionProvider.select((s) => s.value != null)))
          MenuItemButton(
            leadingIcon: const Icon(Symbols.ios_share_rounded),
            child: Text('playerShare'.tr()),
            onPressed: () => SongActionsRunner.share(context, ref, song),
          ),
      ],
    );
  }
}

/// What "Playback info" says, as a sheet: the track's metadata and, when the
/// source can name it, the library it plays from.
///
/// The player page dropped the library eyebrow from its copy — the track is
/// the headline, and the library is not — but the question "where is this
/// playing from?" still deserves one answer somewhere. This sheet is it, and
/// lyrics ride along because they are the other thing a track owns that the
/// full-width copy has no room for.
class _PlaybackInfoSheet extends ConsumerWidget {
  final LibrarySong song;

  const _PlaybackInfoSheet({required this.song});

  /// Opens the sheet anchored to [anchor], when one is known.
  ///
  /// The rect is the iPad popover's origin; elsewhere the sheet is modal.
  static Future<void> show(BuildContext context, LibrarySong song) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => _PlaybackInfoSheet(song: song),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playing = song.playing;
    final source = ref.watch(
      librarySourceByIdProvider.select(
        (sources) => sources[song.sourceId],
      ),
    );

    final rows = <(IconData, String, String)>[
      (
        Symbols.music_note_rounded,
        'playbackInfoTitle'.tr(),
        playing.title,
      ),
      (
        Symbols.person_rounded,
        'playbackInfoArtist'.tr(),
        playing.subtitle,
      ),
      if (playing.album != null)
        (
          Symbols.album_rounded,
          'playbackInfoAlbum'.tr(),
          playing.album!,
        ),
      if (source != null)
        (
          source.kind.mark ?? Symbols.cloud_rounded,
          'playbackInfoSource'.tr(),
          source.identityLabel,
        ),
      (
        Symbols.schedule_rounded,
        'playbackInfoDuration'.tr(),
        formatDuration(song.duration),
      ),
      if (playing.year != null)
        (
          Symbols.calendar_month_rounded,
          'playbackInfoYear'.tr(),
          '${playing.year}',
        ),
      if (playing.genre != null)
        (
          Symbols.category_rounded,
          'playbackInfoGenre'.tr(),
          playing.genre!,
        ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SolSpace.xl,
          SolSpace.sm,
          SolSpace.xl,
          SolSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'playerPlaybackInfo'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SolSpace.md),
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: SolSpace.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        icon,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: SolSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _PlaybackInfoLyrics(song: song),
          ],
        ),
      ),
    );
  }
}

/// The lyrics block at the foot of the playback-info sheet.
///
/// The words, plain: no position line to follow, because a sheet is read at
/// leisure rather than sung along with. Loading and missing states are one
/// quiet line each, so a track without words ends the sheet cleanly.
class _PlaybackInfoLyrics extends ConsumerWidget {
  final LibrarySong song;

  const _PlaybackInfoLyrics({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lyrics = ref.watch(
      songLyricsProvider(
        LyricsRequest.of(song),
        languageCode: Localizations.localeOf(context).languageCode,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: SolSpace.sm),
          child: Row(
            children: [
              Icon(
                Symbols.lyrics_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: SolSpace.md),
              Text(
                'lyricsTitle'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SolSpace.xs),
        lyrics.when(
          skipLoadingOnRefresh: false,
          loading: () => Padding(
            padding: const EdgeInsets.only(left: SolSpace.xl),
            child: Text(
              'lyricsLoading'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(left: SolSpace.xl),
            child: Text(
              'lyricsUnavailable'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          data: (lyrics) => lyrics.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(left: SolSpace.xl),
                  child: Text(
                    'lyricsEmpty'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(left: SolSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in lyrics.lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
