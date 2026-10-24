import 'package:auto_route/auto_route.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/shell/dock_morph.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The persistent transport strip under every tab.
///
/// It floats over the page as a glass capsule rather than occupying a band, so
/// the content keeps scrolling underneath and the glass has something to
/// refract.
///
/// The whole capsule is one target. It is the collapsed player, so tapping
/// anywhere that is not a control grows it into the full player page
/// ([DockMorphOrigin]) instead of pushing a page over it. The transport buttons
/// and the wide layout's scrubber win their own gestures, so playing and
/// seeking still work without leaving the page.
class NowPlayingDock extends ConsumerStatefulWidget {
  const NowPlayingDock({super.key});

  @override
  ConsumerState<NowPlayingDock> createState() => _NowPlayingDockState();
}

class _NowPlayingDockState extends ConsumerState<NowPlayingDock> {
  /// The capsule's own box, measured at tap time so the player can start the
  /// morph from exactly where the capsule was.
  final _capsuleKey = GlobalKey();

  void _openPlayer() {
    final box = _capsuleKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      DockMorphOrigin.rect = box.localToGlobal(Offset.zero) & box.size;
    }
    context.router.push(const PlayerRoute());
  }

  @override
  Widget build(BuildContext context) {
    // The dock is the one widget that *should* repaint every tick, so it
    // watches the whole transport. Nothing above it does.
    final playback = ref.watch(playbackProvider);
    final song = playback.current;
    if (song == null) return const SizedBox.shrink();

    final controller = ref.read(playbackProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wide = isWideScreen(context);
    final duration = playback.duration == Duration.zero
        ? song.duration
        : playback.duration;
    final maxMs = duration.inMilliseconds.toDouble();
    final positionMs = playback.position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kChromeGutter),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openPlayer,
          child: GlassSurface(
            key: _capsuleKey,
            cornerRadius: SolRadius.pill,
            padding: const EdgeInsets.fromLTRB(
              SolSpace.sm,
              SolSpace.sm,
              SolSpace.md,
              SolSpace.sm,
            ),
            child: SizedBox(
              height: kNowPlayingDockHeight,
              child: Row(
                children: [
                  LibraryArtwork(
                    sourceId: song.sourceId,
                    artId: song.artId,
                    size: 44,
                    radius: SolRadius.pill,
                  ),
                  const SizedBox(width: SolSpace.md),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 220 : 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          wide
                              ? song.subtitle
                              : '${formatDuration(playback.position)} / '
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
                  if (wide) ...[
                    const SizedBox(width: SolSpace.md),
                    Text(
                      formatDuration(playback.position),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: positionMs,
                        max: maxMs <= 0 ? 1 : maxMs,
                        onChanged: maxMs <= 0
                            ? null
                            : (value) => controller.seek(
                                Duration(milliseconds: value.round()),
                              ),
                      ),
                    ),
                    Text(
                      formatDuration(duration),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: SolSpace.sm),
                  ] else
                    const Spacer(),
                  // The controls own their taps, including a disabled button
                  // (a disabled control is still a control, not a way into the
                  // player). Without this, a disabled Next would fall through
                  // to the capsule's morph.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Previous',
                          visualDensity: VisualDensity.compact,
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
                          visualDensity: VisualDensity.compact,
                          onPressed: playback.hasNext ? controller.next : null,
                          icon: const Icon(Symbols.skip_next_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
