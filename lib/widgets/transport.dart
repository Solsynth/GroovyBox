import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The play/pause glyph, white and filled, cross-faded rather than swapped.
///
/// Both players — the dock's capsule and the full page — show this one widget,
/// so the two never disagree about which symbol or which size belongs on the
/// transport. The outgoing symbol scales down into the button while the
/// incoming one rises out of it, on the same duration, so a toggle reads as
/// one press rather than two icons trading places.
class PlayPauseIcon extends StatelessWidget {
  final bool playing;
  final double size;

  const PlayPauseIcon({super.key, required this.playing, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: playing
          ? Icon(
              Symbols.pause_rounded,
              key: const ValueKey('pause'),
              color: Colors.white,
              fill: 1,
              size: size,
            )
          : Icon(
              Symbols.play_arrow_rounded,
              key: const ValueKey('play'),
              color: Colors.white,
              fill: 1,
              size: size,
            ),
    );
  }
}

/// The seek bar and its two clocks.
///
/// Watches the transport itself: position arrives once a second, and only
/// this row has anything to say about it.
///
/// Dragging is previewed here and committed once: the thumb follows the
/// finger, the left clock names the point being scrubbed to, and the
/// transport is asked to seek only when the drag ends. Seeking on every pixel
/// would issue a stream request per frame and leave the label chasing the
/// player.
class Scrubber extends ConsumerStatefulWidget {
  const Scrubber({super.key});

  @override
  ConsumerState<Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends ConsumerState<Scrubber> {
  /// Where the finger is, in milliseconds. Null when not dragging.
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(
      playbackProvider.select(
        (state) => (state.position, state.duration, state.current?.duration),
      ),
    );
    final (position, reported, songLength) = playback;
    final duration = reported == Duration.zero
        ? songLength ?? Duration.zero
        : reported;
    final maxMs = duration.inMilliseconds.toDouble();
    final liveMs = position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // While dragging, the clocks describe the scrub rather than the player:
    // the left one is where the release will land.
    final shownMs = _drag ?? liveMs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
          ),
          child: Slider(
            value: shownMs,
            max: maxMs <= 0 ? 1 : maxMs,
            onChanged: maxMs <= 0
                ? null
                : (value) => setState(() => _drag = value),
            onChangeEnd: (value) {
              setState(() => _drag = null);
              ref
                  .read(playbackProvider.notifier)
                  .seek(Duration(milliseconds: value.round()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(Duration(milliseconds: shownMs.round())),
                style: labelStyle,
              ),
              Text(formatDuration(duration), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// Previous, play/pause, next.
///
/// Shuffle and repeat live in the queue pane's header, where they belong to
/// the list they shape; this row is the only place the page still draws the
/// playback's own moment.
///
/// [compact] is the docked bar's row: the capsule already carries the track
/// and the seek bar, so the transport's buttons shrink to keep its height
/// from eating the words above it.
///
/// Watches only what the buttons draw, so a position tick does not repaint
/// three buttons and their ink.
class Transport extends ConsumerWidget {
  final bool compact;

  const Transport({super.key, this.compact = false});

  /// The play button's box: its icon plus the padding around it. Callers size
  /// their row from it, so the two cannot disagree about how tall the row is.
  static double height({bool compact = false}) =>
      (compact ? 24.0 : 36.0) + (compact ? 10.0 : SolSpace.lg) * 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The button is enabled whenever pressing it would move: the next row,
    // the top of the queue under repeat-all, or a fresh draw of tracks when
    // the library is allowed to keep going. A disabled Next said the queue
    // was over while the transport was about to play on anyway.
    final infinite = ref.watch(infinitePlaybackEnabledProvider);
    final state = ref.watch(
      playbackProvider.select(
        (state) => (
          playing: state.playing,
          advances: canAdvance(state, infinite: infinite),
        ),
      ),
    );
    final controller = ref.read(playbackProvider.notifier);
    final playSize = compact ? 24.0 : 36.0;
    final skipSize = compact ? 22.0 : 32.0;
    final gap = compact ? SolSpace.sm : SolSpace.md;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'playerPrevious'.tr(),
          onPressed: controller.previous,
          visualDensity: compact ? VisualDensity.compact : null,
          iconSize: skipSize,
          icon: const Icon(Symbols.skip_previous_rounded),
        ),
        SizedBox(width: gap),
        IconButton.filled(
          tooltip: state.playing ? 'playerPause'.tr() : 'playerPlay'.tr(),
          onPressed: controller.togglePlayPause,
          visualDensity: compact ? VisualDensity.compact : null,
          iconSize: playSize,
          padding: EdgeInsets.all(compact ? 10 : SolSpace.lg),
          icon: PlayPauseIcon(playing: state.playing, size: playSize),
        ),
        SizedBox(width: gap),
        IconButton(
          tooltip: 'playerNext'.tr(),
          onPressed: state.advances ? controller.next : null,
          visualDensity: compact ? VisualDensity.compact : null,
          iconSize: skipSize,
          icon: const Icon(Symbols.skip_next_rounded),
        ),
      ],
    );
  }
}
