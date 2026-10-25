import 'package:auto_route/auto_route.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/shell/dock_morph.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/queue_sheet.dart';
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
///
/// The lyrics button lifts the capsule into a lyric sheet: the transport row
/// stays put and the timed lines rise above it, following the song the way the
/// player page's lyrics do. It is a second tap to go back, not a route, so a
/// glance at the next line never costs the page underneath.
///
/// The queue button does the same for what is coming up: the sheet lists the
/// queue and a row seeks to it, all without leaving the page. Only one of the
/// two sheets is open at a time — they occupy the same space above the
/// transport, and stacking them would push the tab capsule off a short window.
class NowPlayingDock extends ConsumerStatefulWidget {
  const NowPlayingDock({super.key});

  @override
  ConsumerState<NowPlayingDock> createState() => _NowPlayingDockState();
}

class _NowPlayingDockState extends ConsumerState<NowPlayingDock> {
  /// The capsule's own box, measured at tap time so the player can start the
  /// morph from exactly where the capsule was.
  final _capsuleKey = GlobalKey();

  /// Which sheet, if any, is lifted above the transport row. One at a time:
  /// both take the same space, and two of them would push the tab capsule off
  /// the bottom of a short window.
  _DockSheet _openSheet = _DockSheet.none;

  bool get _lyricsOpen => _openSheet == _DockSheet.lyrics;
  bool get _queueOpen => _openSheet == _DockSheet.queue;

  void _toggleSheet(_DockSheet sheet) {
    setState(() => _openSheet = _openSheet == sheet ? _DockSheet.none : sheet);
  }

  /// Height the lyric sheet asks for, capped to a share of the window so the
  /// transport row and the tab capsule still fit on a short phone.
  double _sheetHeight({required bool wide}) {
    final preferred = wide ? 300.0 : 220.0;
    return preferred.clamp(0.0, MediaQuery.sizeOf(context).height * 0.34);
  }

  /// The queue needs more room than the words: it is a list, and three rows
  /// are the fewest that show a song, the one playing, and what follows.
  double _queueSheetHeight({required bool wide}) {
    final preferred = wide ? 380.0 : 280.0;
    return preferred.clamp(0.0, MediaQuery.sizeOf(context).height * 0.46);
  }

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
          child: AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: GlassSurface(
              key: _capsuleKey,
              // A capsule when collapsed; a card once a sheet gives it
              // height, where a pill's ends would eat the first and last row.
              cornerRadius: _openSheet == _DockSheet.none
                  ? SolRadius.pill
                  : SolRadius.xxl,
              // Leading inset matches the artwork's own corner, so the cover
              // sits square in the capsule's left end. A sheet keeps the same
              // padding: its own list has the inner inset instead, and
              // changing this box is what the morph would read as movement.
              padding: const EdgeInsets.fromLTRB(
                SolSpace.sm,
                SolSpace.sm,
                SolSpace.md,
                SolSpace.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Each sheet owns its taps: a lyric line seeks, a queue row
                  // plays, and a tap on the space beside them must not morph
                  // the dock.
                  if (_lyricsOpen) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: SongLyricsPane(
                        height: _sheetHeight(wide: wide),
                        padding: const EdgeInsets.symmetric(
                          horizontal: SolSpace.md,
                        ),
                      ),
                    ),
                    // No rule between the words and the transport: tone and
                    // space separate groups everywhere else in the app.
                    const SizedBox(height: SolSpace.md),
                  ] else if (_queueOpen) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: SizedBox(
                        height: _queueSheetHeight(wide: wide),
                        child: const QueueSheet(),
                      ),
                    ),
                    const SizedBox(height: SolSpace.xs),
                  ],
                  SizedBox(
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
                        Expanded(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: wide ? 260 : double.infinity,
                            ),
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
                                  switch (_openSheet) {
                                    _DockSheet.lyrics => 'Lyrics',
                                    _DockSheet.queue =>
                                      '${playback.queue.length} tracks'
                                          '${playback.shuffle ? '  ·  shuffled' : ''}',
                                    _DockSheet.none => wide
                                        ? song.subtitle
                                        : '${formatDuration(playback.position)}'
                                              ' / ${formatDuration(duration)}',
                                  },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
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
                        ],
                        // The controls own their taps, including a disabled
                        // button (a disabled control is still a control, not a
                        // way into the player). Without this, a disabled Next
                        // would fall through to the capsule's morph.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: _queueOpen ? 'Hide queue' : 'Show queue',
                                visualDensity: VisualDensity.compact,
                                isSelected: _queueOpen,
                                onPressed: () => _toggleSheet(_DockSheet.queue),
                                icon: const Icon(Symbols.queue_music_rounded),
                              ),
                              IconButton(
                                tooltip: _lyricsOpen
                                    ? 'Hide lyrics'
                                    : 'Show lyrics',
                                visualDensity: VisualDensity.compact,
                                isSelected: _lyricsOpen,
                                onPressed: () => _toggleSheet(_DockSheet.lyrics),
                                icon: const Icon(Symbols.lyrics_rounded),
                              ),
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
                                onPressed: playback.hasNext
                                    ? controller.next
                                    : null,
                                icon: const Icon(Symbols.skip_next_rounded),
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
          ),
        ),
      ),
    );
  }
}

/// Which sheet the dock is lifted into, if any.
enum _DockSheet { none, lyrics, queue }
