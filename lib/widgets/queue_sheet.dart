import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The queue, as a sheet inside the now-playing capsule.
///
/// The dock's queue button opens this instead of navigating to the Queue tab:
/// a glance at what is next should not cost the page underneath, and the
/// transport stays visible below it while it is open. The full Queue tab still
/// exists for the repeat and shuffle controls that need room.
///
/// It paints no surface of its own — the capsule around it already is one, and
/// a second glass panel inside it would sample an already-sampled backdrop.
///
/// It fills the height the dock gives it. A list that measured itself would
/// make the capsule's `AnimatedSize` chase its own output, so the header is
/// fixed and the rows take the rest.
class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final theme = Theme.of(context);

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
                child: Text(
                  'Queue',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                playback.shuffle
                    ? '${playback.queue.length} tracks  ·  shuffled'
                    : '${playback.queue.length} tracks',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: playback.queue.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Symbols.queue_music,
                  title: 'Nothing queued',
                  message: 'Play a song or an album and it lands here.',
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: playback.queue.length,
                  itemBuilder: (context, index) {
                    final song = playback.queue[index];
                    return TrackRow(
                      title: song.title,
                      subtitle: songRowSubtitle(ref, song),
                      selected: playback.currentIndex == index,
                      trailing: formatDuration(song.duration),
                      artwork: LibraryArtwork(
                        sourceId: song.sourceId,
                        artId: song.artId,
                        size: 40,
                        radius: SolRadius.xs,
                      ),
                      onTap: () => controller.playQueue(
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
