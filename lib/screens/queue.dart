import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// The play queue, in the order it will actually play.
///
/// Shuffle reorders this list, so what is shown is what happens: there is no
/// hidden randomisation underneath.
@RoutePage()
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: 'Queue',
            subtitle: playback.queue.isEmpty
                ? 'Nothing queued'
                : '${playback.queue.length} tracks'
                      '${playback.shuffle ? '  ·  shuffled' : ''}',
            actions: [
              IconButton(
                tooltip: 'Shuffle',
                isSelected: playback.shuffle,
                onPressed: () => controller.setShuffle(!playback.shuffle),
                icon: const Icon(Symbols.shuffle_rounded),
              ),
              IconButton(
                tooltip: _repeatLabel(playback.repeatMode),
                isSelected: playback.repeatMode != PlaybackRepeatMode.off,
                onPressed: controller.cycleRepeatMode,
                icon: Icon(
                  playback.repeatMode == PlaybackRepeatMode.single
                      ? Symbols.repeat_one_rounded
                      : Symbols.repeat_rounded,
                ),
              ),
              const SizedBox(width: SolSpace.sm),
            ],
          ),
          if (playback.queue.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Symbols.queue_music,
                title: 'The queue is empty',
                message: 'Play a song or an album and it lands here.',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: playback.queue.length,
                itemBuilder: (context, index) {
                  final song = playback.queue[index];
                  final isCurrent = playback.currentIndex == index;
                  return TrackRow(
                    title: song.title,
                    subtitle: song.subtitle,
                    selected: isCurrent,
                    trailing: formatDuration(song.duration),
                    artwork: ServerArtwork(
                      coverArtId: song.coverArt,
                      size: 44,
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
      ),
    );
  }

  String _repeatLabel(PlaybackRepeatMode mode) => switch (mode) {
    PlaybackRepeatMode.off => 'Repeat off',
    PlaybackRepeatMode.all => 'Repeat queue',
    PlaybackRepeatMode.single => 'Repeat song',
  };
}
