import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Full-window player: large cover, scrubber, transport and volume.
///
/// This is the only place seeking happens; the dock shows position but leaves
/// dragging to a control with room for it.
@RoutePage()
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final song = playback.current;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (song == null) {
      return Scaffold(
        body: Center(
          child: TextButton.icon(
            onPressed: () => context.router.maybePop(),
            icon: const Icon(Symbols.arrow_back_rounded),
            label: const Text('Nothing is playing'),
          ),
        ),
      );
    }

    final duration = playback.duration == Duration.zero
        ? song.duration
        : playback.duration;
    final maxMs = duration.inMilliseconds.toDouble();
    final positionMs = playback.position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The cover, blown up and blurred, gives the page a colour field
          // without introducing a gradient of our own.
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Opacity(
                  opacity: 0.35,
                  child: LibraryArtwork(
                    sourceId: song.sourceId,
                    artId: song.artId,
                    radius: 0,
                    fallbackIcon: Symbols.music_note_rounded,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => context.router.maybePop(),
                      icon: const Icon(Symbols.keyboard_arrow_down_rounded),
                    ),
                    const Spacer(),
                    Text(
                      'Now playing',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SolSpace.huge,
                        vertical: SolSpace.lg,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      SolRadius.xl,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.shadow.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 40,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: LibraryArtwork(
                                    sourceId: song.sourceId,
                                    artId: song.artId,
                                    radius: SolRadius.xl,
                                    size: 420,
                                    fallbackIcon: Symbols.album,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: SolSpace.xxl),
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.album == null
                                  ? song.subtitle
                                  : '${song.subtitle}  ·  ${song.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: SolSpace.lg),
                            Slider(
                              value: positionMs,
                              max: maxMs <= 0 ? 1 : maxMs,
                              onChanged: maxMs <= 0
                                  ? null
                                  : (value) => controller.seek(
                                      Duration(milliseconds: value.round()),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SolSpace.sm,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatDuration(playback.position),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  Text(
                                    formatDuration(duration),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: SolSpace.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Shuffle',
                                  isSelected: playback.shuffle,
                                  onPressed: () => controller.setShuffle(
                                    !playback.shuffle,
                                  ),
                                  icon: const Icon(Symbols.shuffle_rounded),
                                ),
                                const SizedBox(width: SolSpace.sm),
                                IconButton(
                                  tooltip: 'Previous',
                                  onPressed: controller.previous,
                                  iconSize: 34,
                                  icon: const Icon(
                                    Symbols.skip_previous_rounded,
                                  ),
                                ),
                                const SizedBox(width: SolSpace.sm),
                                IconButton.filled(
                                  tooltip: playback.playing ? 'Pause' : 'Play',
                                  onPressed: controller.togglePlayPause,
                                  iconSize: 38,
                                  padding: const EdgeInsets.all(SolSpace.lg),
                                  icon: Icon(
                                    playback.playing
                                        ? Symbols.pause_rounded
                                        : Symbols.play_arrow_rounded,
                                  ),
                                ),
                                const SizedBox(width: SolSpace.sm),
                                IconButton(
                                  tooltip: 'Next',
                                  onPressed: playback.hasNext
                                      ? controller.next
                                      : null,
                                  iconSize: 34,
                                  icon: const Icon(Symbols.skip_next_rounded),
                                ),
                                const SizedBox(width: SolSpace.sm),
                                IconButton(
                                  tooltip: playback.repeatMode ==
                                          PlaybackRepeatMode.single
                                      ? 'Repeat song'
                                      : 'Repeat',
                                  isSelected: playback.repeatMode !=
                                      PlaybackRepeatMode.off,
                                  onPressed: controller.cycleRepeatMode,
                                  icon: Icon(
                                    playback.repeatMode ==
                                            PlaybackRepeatMode.single
                                        ? Symbols.repeat_one_rounded
                                        : Symbols.repeat_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: SolSpace.md),
                            _VolumeControl(
                              volume: playback.volume,
                              onChanged: controller.setVolume,
                              onSaved: (value) => saveVolume(ref, value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Volume row. Writes through to prefs when the drag ends, not on every tick.
class _VolumeControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onSaved;

  const _VolumeControl({
    required this.volume,
    required this.onChanged,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          volume <= 0 ? Symbols.volume_off_rounded : Symbols.volume_up_rounded,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: Slider(
            value: volume.clamp(0, 100),
            max: 100,
            onChanged: onChanged,
            onChangeEnd: onSaved,
          ),
        ),
      ],
    );
  }
}
