import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/router.gr.dart';
import '../core/theme.dart';
import '../player/player.dart';
import 'artwork.dart';
import 'format.dart';

/// The persistent transport strip under every tab.
///
/// It is the only way into the player page while browsing, so it has to show
/// the current song, the scrub position, and the three transport controls
/// without any of them being hidden behind a menu. Tapping the song area opens
/// the full player.
class NowPlayingDock extends ConsumerWidget {
  const NowPlayingDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final song = playback.current;
    if (song == null) return const SizedBox.shrink();

    final controller = ref.read(playbackProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = playback.duration == Duration.zero
        ? song.duration
        : playback.duration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (playback.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

    return Material(
      color: colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A 2px bar doubles as the position affordance: dragging a slider
            // in this compact strip would fight its height, so the dock shows
            // where you are and the player page owns seeking.
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            InkWell(
              onTap: () => context.router.push(const PlayerRoute()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SolSpace.md,
                  SolSpace.sm,
                  SolSpace.md,
                  SolSpace.sm,
                ),
                child: Row(
                  children: [
                    ServerArtwork(
                      coverArtId: song.coverArt,
                      size: 40,
                      radius: SolRadius.sm,
                    ),
                    const SizedBox(width: SolSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${song.subtitle}  ·  '
                            '${formatDuration(playback.position)} / '
                            '${formatDuration(duration)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: controller.previous,
                      icon: const Icon(Symbols.skip_previous_rounded),
                    ),
                    IconButton.filled(
                      tooltip: playback.playing ? 'Pause' : 'Play',
                      onPressed: controller.togglePlayPause,
                      icon: Icon(
                        playback.playing
                            ? Symbols.pause_rounded
                            : Symbols.play_arrow_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: playback.hasNext ? controller.next : null,
                      icon: const Icon(Symbols.skip_next_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
