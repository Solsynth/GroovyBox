import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics_store.dart' show LyricsOrigin;
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
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
            ],
          ),
        ),
        // The fade lives on the list, not the whole pane: the header's own
        // words — the title, the summary, the toggles — are never on their way
        // out, so masking them would dim them for no reason. A row cut off at
        // the slot's edge still reads as "more".
        Expanded(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0, 0.06, 0.94, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
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
                        // A station's row is rewritten with what it is
                        // playing, so the queue says what is on the air, not
                        // the name of the station it started from.
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
                        // Inside a station, a row is reached by skipping to
                        // it; the run is the platform player's to advance.
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
class PlaybackInfoSheet extends ConsumerWidget {
  final LibrarySong song;

  const PlaybackInfoSheet({super.key, required this.song});

  /// Opens the sheet anchored to [anchor], when one is known.
  ///
  /// The rect is the iPad popover's origin; elsewhere the sheet is modal.
  static Future<void> show(BuildContext context, LibrarySong song) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => PlaybackInfoSheet(song: song),
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
    // Where the words come from, asked of the stored answer rather than by
    // fetching: the sheet describes what the track has, it does not go get
    // anything. An unstored track reads as having no lyrics yet — which is
    // the same thing the lyrics pane would go check on demand.
    final lyricsOrigin = ref.watch(lyricsOriginProvider(song)).value;
    final lyricsOriginLabel = switch (lyricsOrigin) {
      LyricsOrigin.library => 'lyricsOriginLibrary'.tr(),
      LyricsOrigin.file => 'lyricsOriginFile'.tr(),
      LyricsOrigin.lrclib => 'lyricsOriginLrclib'.tr(),
      LyricsOrigin.manual => 'lyricsOriginManual'.tr(),
      _ => 'lyricsOriginNone'.tr(),
    };
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
      // Lyrics as metadata, not text: where the words come from, or that
      // there are none. The words themselves are the lyrics pane's job; this
      // sheet only describes the track.
      (
        Symbols.lyrics_rounded,
        'playbackInfoLyrics'.tr(),
        lyricsOriginLabel,
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
          ],
        ),
      ),
    );
  }
}

