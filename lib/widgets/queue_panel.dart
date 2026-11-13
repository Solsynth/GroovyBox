import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
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
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final theme = Theme.of(context);
    // A station plays a run the platform player generates, not the app's
    // queue: listing the queue under it would describe a list that is not
    // playing and cannot be reached.
    final stationRow = playback.queueRow;
    final station = stationRow?.isRadio ?? false;
    final rows = station ? playback.stationTracks : playback.queue;
    final currentRow = station ? playback.stationIndex : playback.currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.sm,
            SolSpace.xs,
            SolSpace.md,
            SolSpace.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'queueTitle'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
                                    )[playback.queueRow!.sourceId]
                                    ?.displayName ??
                                '',
                            playback.queueRow!.title,
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
                queueSummary(rows.length, station ? false : playback.shuffle),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
                  padding: EdgeInsets.zero,
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
                              playback.queue,
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
