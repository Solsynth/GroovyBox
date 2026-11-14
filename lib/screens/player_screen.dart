import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/services.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
import 'package:groovy_box/widgets/song_actions.dart';
import 'package:groovy_box/widgets/track_versions.dart';
import 'package:groovy_box/widgets/transport.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Room the page keeps at the top and bottom of the window.
///
/// Both arrangements are one full-bleed surface, so without it the cover sits
/// on the window edge and the transport on the glass edge; the corner
/// controls also need somewhere to sit that is not on top of the artwork.
/// Wider than the [SolSpace.xl] side gutters on purpose: the page is read
/// top-to-bottom, so the breathing room belongs above and below.
const double _kPageMargin = SolSpace.xxxl;

/// Clearance between the floating corner controls and the window edges.
///
/// They are not in a bar: they sit on the page's field above the artwork. On
/// the glass edge they read as cropped, so they keep their own inset — smaller
/// than [_kPageMargin] because a button already carries its own tap padding.
const double _kCornerInset = SolSpace.lg;

/// Height the column under the slot takes at the default type size: the
/// library eyebrow, the copy, the action bar, the scrubber and the transport,
/// plus the gaps between them.
///
/// Measured rather than assumed from [SolSpace], because the transport is a
/// row of icon buttons, the action bar is two more, and the copy is three
/// lines of text; the compact body subtracts it (scaled by the reader's text
/// size) from the window to size the slot, so the tail and the slot cannot
/// both claim the same pixels.
///
/// The wide layout uses the same number: the column beside the cover holds
/// exactly the same things, in the same order.
const double _kBodyTail = 300;

/// Narrowest the copy, scrubber and transport column gets before it spills.
///
/// The transport is five icon buttons plus their gaps and does not shrink
/// with the window; a column narrower than this clips the first and last one,
/// so the square above it is what gives way instead.
const double _kControlsMinWidth = 288;

/// Height the compact copy block takes at the default type size: the eyebrow,
/// two lines of title and the credit line, plus the gap under it.
const double _kTrackCopyHeight = 92;

/// Side of the sleeve thumbnail in the compact header above the words and
/// the queue.
const double _kHeaderHeight = 56;

/// Vertical room the compact pane's header claims above the slot: the header
/// itself, plus the gap between it and the pane. The page's top margin already
/// clears the artwork's top, so the header needs no extra runway above it.
const double _kPaneHeaderBand = _kHeaderHeight + SolSpace.md;

/// [Curve.transform] solves its cubic numerically and stops at a tolerance, so
/// `Curves.easeOutCubic.transform(1)` is 0.9999997 rather than 1. Any code
/// that compares progress against 1 to decide whether a subtree is
/// interactive (`IgnorePointer(ignoring: value < 1)`) would then leave the
/// pane permanently untappable once the animation settled. Answering the ends
/// directly is the only place this can be fixed once: every ramp downstream
/// divides or offsets the value, and each of those would have to repeat it.
class _EndExact extends Curve {
  final Curve curve;

  const _EndExact(this.curve);

  @override
  double transformInternal(double t) =>
      t <= 0 ? 0 : (t >= 1 ? 1 : curve.transform(t));
}

/// Eases [t], landing on exactly 0 and exactly 1 at the ends.
///
/// For the ramps that carve a sub-range out of an already-curved value.
///
/// Tolerant at the ends because the ramp arithmetic is not exact: at `v = 1`,
/// `((1 - 0.34) / 0.66)` is 0.9999999999999999, not 1. A strict comparison
/// there is the same bug as the curve's own, one multiplication further on.
double _eased(Curve curve, double t) {
  if (t >= 1 - 1e-9) return 1;
  if (t <= 1e-9) return 0;
  return curve.transform(t);
}

/// Room the lyrics and queue keep inside the slot.
///
/// The slot is the cover's footprint, and the cover is an object sitting in
/// space; a pane that filled it edge to edge would put its first line on the
/// track title. Horizontal is wider than vertical because lines of text need
/// the break at the ends.
const EdgeInsets _kPanePadding = EdgeInsets.fromLTRB(
  SolSpace.sm,
  SolSpace.sm,
  SolSpace.sm,
  SolSpace.sm,
);

/// Full-window player: large cover, scrubber and transport.
///
/// The window's volume lives in Settings, not here: it is set once and rarely
/// touched, and the column under the cover belongs to the track.
///
/// This is the only place seeking happens from the page stack; the dock shows
/// position but leaves dragging to a control with room for it.
///
/// The page is built around a color field taken from the cover, and nothing is
/// laid over that field: the cover, the copy and the controls sit directly on
/// it, so the artwork stays the page rather than the wallpaper behind a panel.
/// On a wide window the cover and the controls sit side by side instead of
/// stacking in a narrow column.
///
/// Lyrics and the queue are not second pages: they are the same page in
/// another shape. One controller drives the change, and every box that differs
/// between the arrangements — the slot's height, the frame's width, the cover's
/// size, the side the controls hang from — is interpolated from it, so there is
/// no frame where the player is neither one layout nor the other.
///
/// The cover, the words and the queue compete for the same column, so the two
/// alternates sit behind one pair of corner controls and only one can be open.
@RoutePage()
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

/// What the page's slot shows instead of the cover.
enum _PlayerView { cover, lyrics, queue }

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {
  /// The slot's current shape. Apple Music's player keeps the alternatives
  /// behind controls in the corner, because they compete for the cover's
  /// column rather than stacking above it.
  _PlayerView _view = _PlayerView.cover;

  /// The alternate the slot last showed. The slot keeps it mounted while the
  /// cover comes back, so closing fades the panel out instead of deleting it
  /// on the frame the button was tapped.
  _PlayerView _pane = _PlayerView.cover;

  /// Whether the hand-off in [swap] is running backwards, which means the
  /// pane it was leaving is the one that ends up in the slot.
  bool _swapUndoing = false;

  /// The alternate the slot is handing over to [_pane], while it leaves.
  ///
  /// Only set while one pane replaces the other: picking the queue with the
  /// words open is not a close and a reopen, so [_morph] is already at its far
  /// end and cannot animate it. This is that second move, on its own clock.
  _PlayerView? _swapFrom;

  /// Drives the morph between the arrangements: 0 is the cover, 1 is whichever
  /// alternate is asked for. It runs in both directions, so closing the words
  /// is the opening played backwards rather than a second, different
  /// animation.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  late final Animation<double> _morphT = CurvedAnimation(
    parent: _morph,
    curve: const _EndExact(Curves.easeInOutCubic),
    reverseCurve: const _EndExact(Curves.easeInOutCubic),
  );

  /// One alternate giving the slot to the other. Shorter than [_morph]
  /// because it moves far less: the slot keeps its size, only its contents
  /// change.
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  late final Animation<double> _swapT = CurvedAnimation(
    parent: _swap,
    curve: const _EndExact(Curves.easeInOutCubic),
    reverseCurve: const _EndExact(Curves.easeInOutCubic),
  );

  /// The page's own focus: the transport keys belong to it while nothing
  /// inside the page has been tabbed to, and it is the primary focus on
  /// arrival so the keys work the moment the page opens.
  final _shortcutFocus = FocusNode(debugLabel: 'player-shortcuts');

  /// Writes the volume once the last key repeat has passed rather than on
  /// every step: a held arrow key changes the transport dozens of times, and
  /// each change would otherwise be its own prefs write.
  Timer? _volumeSaveTimer;

  @override
  void initState() {
    super.initState();
    // The lyrics pane is only built while the morph is off its cover end, so
    // the last frame has to rebuild once the controller settles back at 0.
    _morph.addStatusListener(_onMorphStatus);
    _swap.addStatusListener(_onSwapStatus);
    // The page is what has the keys when it opens, not whichever control the
    // route happened to hand focus to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shortcutFocus.requestFocus();
    });
  }

  void _onMorphStatus(AnimationStatus status) {
    if (status.isDismissed && mounted) setState(() {});
  }

  void _onSwapStatus(AnimationStatus status) {
    if (_swapFrom == null || !mounted) return;
    if (status == AnimationStatus.completed) {
      // Reached the far end: the arriving pane is the slot's pane and the one
      // that left can be dropped.
      setState(() => _swapFrom = null);
    } else if (status == AnimationStatus.dismissed && _swapUndoing) {
      // Ran back to zero because the hand-off was undone, so the pane being
      // dropped is the one that had arrived and the slot belongs to the pane
      // that never finished leaving. A dismissed status also arrives when the
      // clock is rewound to start a fresh hand-off; [_swapUndoing] tells the
      // two apart.
      setState(() {
        _pane = _swapFrom!;
        _swapFrom = null;
        _swapUndoing = false;
      });
    }
  }

  @override
  void dispose() {
    _volumeSaveTimer?.cancel();
    _shortcutFocus.dispose();
    _morph.removeStatusListener(_onMorphStatus);
    _morph.dispose();
    _swap.removeStatusListener(_onSwapStatus);
    _swap.dispose();
    super.dispose();
  }

  /// Swaps the slot's alternate. Asking for the one already open closes it,
  /// so each corner button toggles itself and picking the other one hands the
  /// slot over rather than opening both.
  void _showView(_PlayerView view) {
    final next = _view == view ? _PlayerView.cover : view;
    if (next == _view) return;
    final wasAlternate = _view != _PlayerView.cover;
    // Asking again for the pane that is still on its way out is not a new
    // hand-off: it is this one undone. The slot's fields stay as they are and
    // the clock runs backwards, so that pane returns from where it stands
    // instead of blinking to the far end and sliding a second time.
    final back = wasAlternate && _swap.isAnimating && _swapFrom == next;
    setState(() {
      if (back) {
        // Nothing to change in the slot: [_swapFrom] is the pane being asked
        // back and [_pane] is the one it took the slot from. Running the clock
        // down returns both.
        _swapUndoing = true;
      } else if (next == _PlayerView.cover) {
        // Closing: the pane on show is the one that leaves, so nothing is
        // handing over to anything.
        _swapFrom = null;
        _swapUndoing = false;
      } else if (!wasAlternate) {
        // Opening from the cover: the morph carries the pane in, so there is
        // nothing to hand over from.
        _swapFrom = null;
        _swapUndoing = false;
        _pane = next;
      } else {
        // Queue and words share the slot, so this is not a close and a reopen:
        // the slot keeps its size and one pane gives way to the other.
        _swapFrom = _pane;
        _swapUndoing = false;
        _pane = next;
      }
      _view = next;
    });
    if (next == _PlayerView.cover) {
      _swap.stop();
      _morph.reverse();
    } else if (_swapFrom == null) {
      _morph.forward();
    } else if (back) {
      _swap.reverse();
    } else if (!_swap.isAnimating) {
      _swap.forward(from: 0);
    }
  }

  /// The slot's alternate, by name. One builder for both the pane on show and
  /// the one leaving, so a hand-off never changes how a panel is built.
  Widget _paneWidget(_PlayerView view) {
    final pane = switch (view) {
      _PlayerView.queue => const QueuePanel(),
      _ => const SongLyricsPane(
        padding: EdgeInsets.symmetric(horizontal: SolSpace.xs),
        // Fading the column's edges: with the scrollbar gone, a line cut off
        // at the slot's edge reads as broken rather than as more to come.
        fade: true,
      ),
    };
    // Inset inside the slot, not just inside the pane: the words and the queue
    // take the cover's footprint, and the cover is an object with air around
    // it. Flush, the first lyric line sat under the corner controls and the
    // last on the track title, and the queue's hover tone ran to the edge.
    //
    // The queue gets the same edge fade as the words, so the two panes read
    // as one material: a row cut off at the slot's edge means "more", in both.
    return Padding(
      padding: _kPanePadding,
      child: view == _PlayerView.queue
          ? ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, 0.08, 0.92, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: pane,
            )
          : pane,
    );
  }

  void _nudgeVolume(double volume, double delta) {
    final next = (volume + delta).clamp(0.0, 100.0);
    ref.read(playbackProvider.notifier).setVolume(next);
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) saveVolume(ref, next);
    });
  }

  /// Seeks by [by], kept inside the track by the transport's own length.
  ///
  /// Read here rather than taken as an argument: this runs on a key press,
  /// and the page no longer rebuilds on every position tick just to hand it
  /// a fresher duration.
  void _seekBy(Duration position, Duration by) {
    final playback = ref.read(playbackProvider);
    final duration = playback.duration == Duration.zero
        ? playback.current?.duration ?? Duration.zero
        : playback.duration;
    final target = position + by;
    ref
        .read(playbackProvider.notifier)
        .seek(
          target < Duration.zero
              ? Duration.zero
              : (target > duration ? duration : target),
        );
  }

  /// Escape backs out one layer at a time: the open alternate first, the page
  /// second. Leaving the player from under a panel would take the panel with
  /// it, and closing it is what the same key means everywhere else.
  void _backOut() {
    if (_view != _PlayerView.cover) {
      _showView(_view);
    } else {
      context.router.maybePop();
    }
  }

  /// Escape, from anywhere on the page.
  ///
  /// Sits on a node that cannot take focus, so it never competes with a
  /// control: it only sees the key after the focused widget has declined it,
  /// and no widget in the app binds Escape for itself.
  KeyEventResult _onEscape(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _backOut();
    return KeyEventResult.handled;
  }

  /// Transport keys, while the page itself is what has the focus.
  ///
  /// A focused control keeps its own keys: Space activates the button the
  /// user tabbed to, which is what a keyboard user expects. These apply to
  /// the page's own focus, which is where the page starts and where a click
  /// on empty space returns. The arrows still set the volume even though the
  /// slider moved to Settings.
  ///
  /// Reads the transport at key time rather than taking it as an argument:
  /// the page watches only the song, so a position tick does not rebuild the
  /// whole window just to hand this handler a fresher number.
  KeyEventResult _onTransportKey(KeyEvent event) {
    if (!_shortcutFocus.hasPrimaryFocus) return KeyEventResult.ignored;
    // Repeats are wanted for seeking and volume — those are the keys people
    // hold down — and not for the toggles, which would otherwise flap.
    final repeat = event is KeyRepeatEvent;
    if (event is! KeyDownEvent && !repeat) return KeyEventResult.ignored;

    final playback = ref.read(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        if (!repeat) controller.togglePlayPause();
      case LogicalKeyboardKey.arrowLeft:
        if (shift) {
          if (!repeat) controller.previous();
        } else {
          _seekBy(playback.position, const Duration(seconds: -5));
        }
      case LogicalKeyboardKey.arrowRight:
        if (shift) {
          if (!repeat) controller.next();
        } else {
          _seekBy(playback.position, const Duration(seconds: 5));
        }
      case LogicalKeyboardKey.arrowUp:
        _nudgeVolume(playback.volume, 5);
      case LogicalKeyboardKey.arrowDown:
        _nudgeVolume(playback.volume, -5);
      case LogicalKeyboardKey.keyL:
        if (!repeat) _showView(_PlayerView.lyrics);
      case LogicalKeyboardKey.keyQ:
        if (!repeat) _showView(_PlayerView.queue);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // The song, not the transport: a position tick arrives once a second and
    // the cover, the panes and the corner controls have nothing to say about
    // it. The scrubber and the transport watch the state themselves, so a
    // tick repaints two small rows instead of the whole window.
    final song = ref.watch(playbackProvider.select((state) => state.current));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: TextButton.icon(
            onPressed: () => context.router.maybePop(),
            icon: const Icon(Symbols.arrow_back_rounded),
            label: Text('playerNothingPlaying'.tr()),
          ),
        ),
      );
    }

    // A station has no length and no end, so a scrubber over it would be a
    // control with nothing to move.
    final Widget bottom = song.isRadio
        ? const _LiveBadge()
        : const _Scrubber();
    // Built once per page build, not per animation frame: whichever pane is
    // on show keeps its scroll position while the morph runs.
    final alternate = _paneWidget(_pane);
    // The pane it is replacing, while that fade is still running. Built from
    // the same builder so the hand-off is between identical subtrees, and
    // only while it is needed, so a closed player holds one panel not two.
    final leaving = _swapFrom == null ? null : _paneWidget(_swapFrom!);
    final body = isWideScreen(context)
        ? _WidePlayerBody(
            song: song,
            scrubber: bottom,
            alternate: alternate,
            leaving: leaving,
            swap: _swapT,
            morph: _morphT,
          )
        : _CompactPlayerBody(
            song: song,
            scrubber: bottom,
            alternate: alternate,
            leaving: leaving,
            swap: _swapT,
            alternateAlive: _view != _PlayerView.cover,
            morph: _morphT,
          );

    return Focus(
      // Cannot take focus itself, so it only ever sees the keys a control has
      // already declined; Escape is the one the page owns outright.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onEscape(event),
      child: Scaffold(
        // Opaque: this page owns the whole window, and the page it grew out of
        // must not show through the artwork blur.
        backgroundColor: colorScheme.surface,
        body: Stack(
          children: [
            // The blurred cover gives the page a colour field without
            // introducing a gradient of our own. It is not the tap target:
            // the surface above it is, so content that covers the field still
            // hands the keys back.
            Positioned.fill(
              child: RepaintBoundary(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Opacity(
                      opacity: 0.4,
                      child: LibraryArtwork(
                        sourceId: song.sourceId,
                        artId: song.artId,
                        radius: 0,
                        // Blurred past recognition: detail here would be
                        // decoded and thrown away, so ask for a thumbnail,
                        // not the cover.
                        pixelSize: 256,
                        fallbackIcon: Symbols.music_note_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // A scrim so text and glass always have something even behind a
            // bright cover; without it the blurred art washes the labels out.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.surface.withValues(alpha: 0.55),
                        colorScheme.surface.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The whole surface is the way back to the page's own keys: after
            // tabbing onto a control, Space and the arrows belong to that
            // control, and a tap anywhere that is not one hands them back
            // instead of leaving the user to tab around in a circle. It wraps
            // the content rather than sitting under it, so the artwork and the
            // lyrics are covered by it too; a control still wins the tap
            // because it is the deeper target.
            SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _shortcutFocus.requestFocus,
                child: Focus(
                  focusNode: _shortcutFocus,
                  autofocus: true,
                  includeSemantics: false,
                  onKeyEvent: (_, event) => _onTransportKey(event),
                  // The body owns the whole page: the close and view
                  // controls float over it rather than sitting in a bar above
                  // it, so the artwork is not charged a row it does not need
                  // and the player reads as one full-bleed surface.
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(child: body),
                      // Floated off the edges rather than flush with them: the
                      // page is full-bleed, so a control on the glass edge
                      // reads as cropped instead of placed.
                      if (isWideScreen(context)) ...[
                        Positioned(
                          top: _kCornerInset,
                          left: _kCornerInset,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'playerClose'.tr(),
                                onPressed: () => context.router.maybePop(),
                                icon: const Icon(
                                  Symbols.keyboard_arrow_down_rounded,
                                ),
                              ),
                              // About this track rather than about the page,
                              // so it sits with the way out. A station has no
                              // other versions: its run is generated.
                              IconButton(
                                tooltip: 'versionsTitle'.tr(),
                                onPressed: song.isRadio
                                    ? null
                                    : () =>
                                          TrackVersionsPanel.show(context, song),
                                icon: const Icon(Symbols.content_copy_rounded),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: _kCornerInset,
                          right: _kCornerInset,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: _view == _PlayerView.queue
                                    ? 'playerQueueHide'.tr()
                                    : 'playerQueueShow'.tr(),
                                isSelected: _view == _PlayerView.queue,
                                onPressed: () => _showView(_PlayerView.queue),
                                icon: const Icon(Symbols.queue_music_rounded),
                              ),
                              IconButton(
                                tooltip: _view == _PlayerView.lyrics
                                    ? 'playerLyricsHide'.tr()
                                    : 'playerLyricsShow'.tr(),
                                isSelected: _view == _PlayerView.lyrics,
                                onPressed: () => _showView(_PlayerView.lyrics),
                                icon: const Icon(Symbols.lyrics_rounded),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Positioned(
                          left: SolSpace.xl,
                          right: SolSpace.xl,
                          bottom: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'playerClose'.tr(),
                                    onPressed: () => context.router.maybePop(),
                                    icon: const Icon(
                                      Symbols.keyboard_arrow_down_rounded,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'versionsTitle'.tr(),
                                    onPressed: song.isRadio
                                        ? null
                                        : () => TrackVersionsPanel.show(
                                            context,
                                            song,
                                          ),
                                    icon: const Icon(
                                      Symbols.content_copy_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: _view == _PlayerView.queue
                                        ? 'playerQueueHide'.tr()
                                        : 'playerQueueShow'.tr(),
                                    isSelected: _view == _PlayerView.queue,
                                    onPressed: () =>
                                        _showView(_PlayerView.queue),
                                    icon: const Icon(
                                      Symbols.queue_music_rounded,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _view == _PlayerView.lyrics
                                        ? 'playerLyricsHide'.tr()
                                        : 'playerLyricsShow'.tr(),
                                    isSelected: _view == _PlayerView.lyrics,
                                    onPressed: () =>
                                        _showView(_PlayerView.lyrics),
                                    icon: const Icon(Symbols.lyrics_rounded),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact: cover, copy, and the controls pinned to the bottom of the page.
///
/// Nothing here is a card. The page's own field — the blown-up cover under a
/// scrim — is the surface, so the controls sit straight on it; a tonal panel
/// on top of that only reads as a second background.
///
/// The cover and one alternate are one slot rather than two layouts, so the
/// corner controls morph that slot instead of swapping its child.
class _CompactPlayerBody extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;
  final Widget alternate;
  final Widget? leaving;
  final Animation<double> swap;
  final bool alternateAlive;
  final Animation<double> morph;

  const _CompactPlayerBody({
    required this.song,
    required this.scrubber,
    required this.alternate,
    required this.leaving,
    required this.swap,
    required this.alternateAlive,
    required this.morph,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The copy, scrubber and transport are fixed content: they cannot
        // give way, so the slot is sized from what is left over instead of
        // the tail competing with the artwork for the column. The reserve is
        // taken at the current type size, so a large one makes the tail
        // taller rather than letting it run past the window edge. Under the
        // words and the queue the centered copy and the action bar ride the
        // morph into the header row above the pane, so the column never
        // jumps between the two arrangements.
        // `textScaleFactor` directly rather than `textScaler.scale`: the
        // engine's `scaleFontSize` asserts when the platform's scaling
        // configuration goes stale (a macOS debug failure that has been seen
        // mid-layout), and these constants are plain layout arithmetic —
        // the linear factor is what they wanted all along.
        // ignore: deprecated_member_use
        final textScale = MediaQuery.textScalerOf(context).textScaleFactor;
        final available = math.max(
          constraints.maxHeight - _kPageMargin * 2,
          0.0,
        );
        // The slot keeps enough room for the words and the queue even on a
        // window too short for both ends of it; the page scrolls below rather
        // than squeezing the alternate into a stripe.
        final reserve0 = textScale * _kBodyTail;
        final slotHeight0 = math.max(available - reserve0, textScale * 180.0);
        // Sized from the window, not from the column left over: letting the
        // art claim half the screen is what pushed the transport onto the
        // bottom edge. The second clamp keeps the square inside its slot.
        final coverSize = math.min(
          (available * 0.44).clamp(160.0, 360.0),
          math.max(slotHeight0, 120.0),
        );
        // The transport is five buttons wide and does not shrink; where the
        // window is too small for both, the art gives way so the controls
        // keep the width they need instead of spilling out of the column.
        final contentWidth = math.max(
          constraints.maxWidth - SolSpace.xl * 2,
          0.0,
        );
        final controlsWidth = math.max(
          coverSize,
          math.min(320.0, contentWidth),
        );
        final headerBand0 = math.max(textScale * _kTrackCopyHeight, 0.0);
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final startRect = Rect.fromLTWH(
          (contentWidth - coverSize) / 2,
          headerBand0 + (slotHeight0 - coverSize) / 2,
          coverSize,
          coverSize,
        );
        final endRect = Rect.fromLTWH(
          isRtl ? contentWidth - _kHeaderHeight : 0.0,
          _kPaneHeaderBand - _kHeaderHeight,
          _kHeaderHeight,
          _kHeaderHeight,
        );
        final coverPixelSize =
            (coverSize * MediaQuery.devicePixelRatioOf(context)).round();
        return AnimatedBuilder(
          animation: morph,
          builder: (context, _) {
            // One t drives every branch of the hand-over: the cover flies
            // like a hero from the slot's center into the compact header, the
            // copy folds out, and the header's title and actions settle beside
            // the landed sleeve.
            final t = morph.value;
            final reserve =
                reserve0 +
                textScale * t * (_kPaneHeaderBand - _kTrackCopyHeight);
            final slotHeight = math.max(available - reserve, textScale * 180.0);
            final headerBandHeight = math.max(
              lerpDouble(headerBand0, _kPaneHeaderBand, t)!,
              0.0,
            );
            final artRect = Rect.lerp(startRect, endRect, t)!;
            final artRadius = lerpDouble(SolRadius.xl, SolRadius.md, t)!;
            // The header is interactive only once it has arrived; mid-flight
            // taps would hit moving controls.
            final headerIn = _eased(
              Curves.easeOutCubic,
              ((t - 0.35) / 0.65).clamp(0.0, 1.0),
            );
            final copyOut =
                1 - _eased(Curves.easeInCubic, (t / 0.32).clamp(0.0, 1.0));
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: SolSpace.xl,
                // Clear of the phone's own bottom inset, which [SafeArea] has
                // already applied, and of the window edge: the transport is
                // the last thing on the page, and a button on the glass edge
                // reads as clipped rather than placed. The same room at the
                // top keeps the cover off the window edge.
                vertical: _kPageMargin,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      // The pane's header rises into the copy's old band: same
                      // slot, same curve, so the two read as one element
                      // trading shapes rather than two rows trading places.
                      SizedBox(
                        height: headerBandHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // The full copy — eyebrow, big title, credits —
                            // centered, on its way out.
                            IgnorePointer(
                              ignoring: copyOut < 1,
                              child: Opacity(
                                opacity: copyOut,
                                child: Transform.translate(
                                  offset: Offset(0, -16 * (1 - copyOut)),
                                  child: OverflowBox(
                                    minHeight: textScale * _kTrackCopyHeight,
                                    maxHeight: textScale * _kTrackCopyHeight,
                                    child: _TrackCopy(
                                      song: song,
                                      centered: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // The compact header — sleeve placeholder, one-line
                            // title, the actions — left aligned, settling in
                            // beside the hero artwork as it lands.
                            IgnorePointer(
                              ignoring: headerIn < 1,
                              child: Opacity(
                                opacity: headerIn,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - headerIn)),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: _CompactHeader(song: song),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: slotHeight,
                        // The alternate takes the cover's place rather than
                        // stacking above the controls: two scrolling bodies in
                        // one column leaves neither enough room to read.
                        child: _MorphSlot(
                          t: morph,
                          alternate: alternate,
                          leaving: leaving,
                          swap: swap,
                          alternateAlive: alternateAlive,
                        ),
                      ),
                      const SizedBox(height: SolSpace.sm),
                      // As wide as the artwork, so the column reads as one
                      // object: the square the cover paints is the square the
                      // controls span. The action bar has already travelled up
                      // into the header row by the time the words arrive.
                      Center(
                        child: SizedBox(
                          width: controlsWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              scrubber,
                              const _Transport(),
                              if (copyOut > 0)
                                Opacity(
                                  opacity: copyOut,
                                  child: SongActionBar(song: song),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Single persistent artwork widget that flies like a hero
                  // between the centered slot and the compact header's sleeve.
                  Positioned.fromRect(
                    rect: artRect,
                    child: _Cover(
                      song: song,
                      size: artRect.width,
                      radius: artRadius,
                      pixelSize: coverPixelSize,
                      shadowOpacity: lerpDouble(0.20, 0.06, t)!,
                      shadowBlur: lerpDouble(40, 10, t)!,
                      shadowOffsetY: lerpDouble(10, 3, t)!,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Alternate pane slot, uncovered as the hero artwork lifts into the header.
///
/// The alternate exists only while it is wanted or still leaving, and rises
/// into place as the cover flies out of the slot's center.
class _MorphSlot extends StatelessWidget {
  final Animation<double> t;
  final Widget alternate;

  /// The pane [alternate] is replacing, while that hand-off runs. Null at
  /// every other moment, so the slot never holds two panels it is not
  /// cross-fading between.
  final Widget? leaving;

  /// 0 while [leaving] still fills the slot, 1 once [alternate] does.
  final Animation<double> swap;

  /// Whether the alternate is wanted at all. Kept separate from [t] because
  /// the controller reaches 0 one frame before the pane can be dropped.
  final bool alternateAlive;

  const _MorphSlot({
    required this.t,
    required this.alternate,
    required this.leaving,
    required this.swap,
    required this.alternateAlive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        // End-exact: the value that decides whether the pane is interactive is
        // exactly 1, and the curve's own numeric solve never quite reaches it.
        final into = _eased(
          Curves.easeOutCubic,
          ((v - 0.28) / 0.72).clamp(0.0, 1.0),
        );
        if (!alternateAlive && into <= 0) {
          return const SizedBox.shrink();
        }
        // The pane, cross-faded with the one it is replacing when the slot is
        // handing over between the queue and the words. Aligned to the same
        // bottom edge so a panel entering from below does not jump the row.
        final pane = leaving == null
            ? alternate
            : _PaneSwap(swap: swap, leaving: leaving!, child: alternate);
        return IgnorePointer(
          ignoring: into < 1,
          child: Opacity(
            opacity: into,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - into)),
              child: Transform.scale(
                scale: 0.97 + 0.03 * into,
                child: pane,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One alternate giving the slot to the other.
///
/// The queue and the words are the same page in different shapes, so moving
/// between them is not a close and a reopen: the slot keeps its size and only
/// its contents change. They slide past each other rather than dissolving in
/// place — the leaving pane drops away while the arriving one rises into the
/// space — because a cross-fade of two panels with different text would read
/// for a moment as one garbled panel.
class _PaneSwap extends StatelessWidget {
  final Animation<double> swap;
  final Widget leaving;
  final Widget child;

  const _PaneSwap({
    required this.swap,
    required this.leaving,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: swap,
      builder: (context, _) {
        final v = swap.value;
        // End-exact, like the slot's: whether the arriving pane is tappable
        // is decided by comparing this against 1.
        final out = _eased(Curves.easeInCubic, v);
        final into = _eased(Curves.easeOutCubic, v);
        return Stack(
          fit: StackFit.expand,
          children: [
            // The pane on its way out stays under the incoming one, so the
            // arrival is never seen through a half-faded predecessor.
            IgnorePointer(
              child: Opacity(
                opacity: 1 - out,
                child: Transform.translate(
                  offset: Offset(0, -20 * out),
                  child: leaving,
                ),
              ),
            ),
            IgnorePointer(
              // Only the pane that stays is tappable, and only once it is
              // fully in place: a half-slid list would scroll under a finger
              // that did not mean to touch it.
              ignoring: into < 1,
              child: Opacity(
                opacity: into,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - into)),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Wide: cover on the left, everything you can do to the track on the right.
///
/// No panel groups the pair: the page's blurred field already reads as one
/// object, and a card over it would only add a tonal rectangle on top of the
/// artwork it is meant to show.
///
/// The two arrangements are one shape with two ends. The frame's width, its
/// height, the split between the columns and the cover's side all come from
/// [morph], and the controls travel from the right column to under the cover
/// as it moves, so nothing is laid out twice at a moment in time.
class _WidePlayerBody extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;
  final Widget alternate;
  final Widget? leaving;
  final Animation<double> swap;
  final Animation<double> morph;

  const _WidePlayerBody({
    required this.song,
    required this.scrubber,
    required this.alternate,
    required this.leaving,
    required this.swap,
    required this.morph,
  });
  @override
  Widget build(BuildContext context) {
    // Built once per page build, not per animation frame: the animated
    // wrappers change every tick, these subtrees do not, so they can be reused
    // by identity and skipped by the element tree.
    final cover = _Cover(song: song, size: null);
    // One column shape, reused at both ends of the morph so the handoff is
    // between identical blocks. Its width always follows the artwork: at the
    // cover end the right column is exactly the cover's width, and under the
    // words it sits in the cover's own column, so the scrubber spans the
    // same width as the art rather than a width of its own.
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Centered in both layouts: the column is the cover's width, so a
        // left-aligned title sat under the artwork's left edge and read as a
        // caption for it rather than as the page's headline.
        _TrackCopy(song: song, centered: true),
        const SizedBox(height: SolSpace.sm),
        scrubber,
        const SizedBox(height: SolSpace.sm),
        const _Transport(),
        // Under the transport, where the other controls for the same track
        // are: the heart and the playlist button act on what is playing. The
        // row may render nothing at all (a station, or a source that cannot
        // act), so it is never given a minimum height of its own.
        SongActionBar(song: song),
      ],
    );

    return AnimatedBuilder(
      animation: morph,
      builder: (context, _) {
        final t = morph.value;
        final screen = MediaQuery.sizeOf(context);

        // Both ends of every measurement, so no frame has to choose between
        // them: the cover end is a square that sizes itself from its column,
        // the alternate end is a pane that fits the viewport.
        //
        // The column is exactly one cover wide at both ends. Sizing it as a
        // fraction of the frame instead let the scrubber outgrow the square
        // above it once the frame grew for the words, and a progress bar
        // wider than the artwork reads as a separate control rather than as
        // the artwork's own ruler.
        final viewport = math.max(screen.width - SolSpace.xxl * 2, 320.0);
        final width = math.min(lerpDouble(1000, 1120, t)!, viewport);
        final inner = math.max(width - SolSpace.xxxl, 0.0);
        // The window's own margin, and the height the right column's copy
        // and controls need at the reader's type size. The cover end used to
        // size the row to the square alone, so on a short window the column
        // beside it was taller than the square and spilled out of the row.
        // Same linear factor as the compact body: the engine's
        // `scaleFontSize` asserts when the platform's configuration goes
        // stale mid-layout.
        // ignore: deprecated_member_use
        final textScale = MediaQuery.textScalerOf(context).textScaleFactor;
        final bodyHeight = math.max(screen.height - _kPageMargin * 2, 240.0);
        final controlsHeight = textScale * _kBodyTail;
        // Under half the column, and never taller than the window can show:
        // the cover is a companion to the controls, not the page itself. The
        // floor is the controls' own width, because the column beside the
        // square is exactly the square's width and a shorter square would
        // clip the transport's outer buttons.
        final coverSize = math.max(
          math.min(
            inner * lerpDouble(0.44, 0.40, t)!,
            math.min(screen.height * 0.58, bodyHeight),
          ),
          math.min(_kControlsMinWidth, inner),
        );
        // The controls hand off rather than cross-fade in place: they are on
        // the right for the cover and under the artwork for the words, and the
        // second copy unfolds from beneath the cover as the first lets go. The
        // two ranges overlap, so there is no value of t at which the page has
        // no transport at all.
        final rightControls = (1 - t / 0.52).clamp(0.0, 1.0);
        final leftControls = ((t - 0.26) / 0.74).clamp(0.0, 1.0);
        final words = ((t - 0.40) / 0.60).clamp(0.0, 1.0);

        // The pane grows with the morph instead of starting at the words'
        // full height: at the cover end it is the cover's square, so the row
        // is as tall as the artwork and the column stays centred — unless the
        // square is shorter than the controls beside it, and then the row is
        // theirs instead, because they cannot shrink.
        final leftColumnNeeded =
            coverSize + (SolSpace.lg + controlsHeight) * leftControls;
        final wordsHeight = math.max(
          lerpDouble(
            math.max(coverSize, controlsHeight),
            (bodyHeight * 0.9).clamp(400.0, 780.0),
            t,
          )!,
          math.max(controlsHeight, leftColumnNeeded),
        );

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SolSpace.xxl,
              vertical: _kPageMargin,
            ),
            child: SizedBox(
              width: width,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: coverSize,
                    child: SizedBox(
                      height: wordsHeight,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // The square is the measurement, not a leftover: its
                            // side is exactly the column's width, so the scrubber
                            // under it can never be wider than the art it rules.
                            // Sizing it from the row height instead left a gap
                            // whenever the words made the row taller than the
                            // square.
                            SizedBox.square(
                              dimension: coverSize,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: cover,
                                ),
                              ),
                            ),
                            if (leftControls > 0)
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: leftControls,
                                  child: Opacity(
                                    opacity: leftControls,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: SolSpace.lg,
                                      ),
                                      child: controls,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SolSpace.xxxl),
                  Expanded(
                    child: SizedBox(
                      height: wordsHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (rightControls > 0)
                            IgnorePointer(
                              ignoring: rightControls < 1,
                              child: Opacity(
                                opacity: rightControls,
                                child: Center(
                                  // The same width as the art at the cover
                                  // end, where the right pane is already
                                  // exactly one cover wide.
                                  child: SizedBox(
                                    width: coverSize,
                                    child: controls,
                                  ),
                                ),
                              ),
                            ),
                          if (words > 0)
                            IgnorePointer(
                              ignoring: words < 1,
                              child: Opacity(
                                opacity: words,
                                child: Transform.translate(
                                  offset: Offset(28 * (1 - words), 0),
                                  child: leaving == null
                                      ? alternate
                                      : _PaneSwap(
                                          swap: swap,
                                          leaving: leaving!,
                                          child: alternate,
                                        ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The track's identity, as the compact pane's header: a small sleeve, the
/// title and the artist on one line under it, left aligned.
///
/// When the words or the queue take the cover's column, the copy under the
/// slot collapses — the pane is the page's body, and a headline repeated
/// under it is noise. What the reader still needs is *what* is playing, and
/// Apple Music answers that with a small artwork beside the title above the
/// words, not with a second full-size block below.
class _CompactHeader extends StatelessWidget {
  final LibrarySong song;

  const _CompactHeader({required this.song});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playing = song.playing;

    return Row(
      children: [
        // Reserves the sleeve's footprint for the hero artwork flying up from
        // the slot.
        const SizedBox.square(dimension: _kHeaderHeight),
        const SizedBox(width: SolSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playing.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              // The same credit line the full copy draws, so the header
              // reads as the track's own row rather than a menu caption.
              Text(
                playing.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // The track's own writes — heart and playlist — ride the header's
        // trailing edge, where a media row keeps its actions: the transport
        // stays the row that plays, and the pane keeps its column clear.
        SongActionBar(song: song),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final LibrarySong song;
  final double? size;
  final double radius;
  final int? pixelSize;
  final double shadowOpacity;
  final double shadowBlur;
  final double shadowOffsetY;

  const _Cover({
    required this.song,
    required this.size,
    this.radius = SolRadius.xl,
    this.pixelSize,
    this.shadowOpacity = 0.20,
    this.shadowBlur = 40,
    this.shadowOffsetY = 10,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final artwork = LibraryArtwork(
      sourceId: song.sourceId,
      artId: song.artId,
      radius: radius,
      size: size,
      pixelSize: pixelSize,
      fallbackIcon: Symbols.album,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffsetY),
          ),
        ],
      ),
      child: size == null
          ? SizedBox.expand(child: artwork)
          : SizedBox.square(dimension: size, child: artwork),
    );
  }
}

/// The sleeve credits under the artwork: what is playing, by whom, from
/// which record.
///
/// Set like the back of a sleeve rather than like a card caption: the title
/// carries the weight, and the credits sit on one quiet line under it. The
/// library the track plays from is not drawn here — the question "where is
/// this playing from?" is answered by the playback-info sheet behind the
/// queue header's more menu, and a cloud mark beside every title cost the
/// title its room for an answer this page never needed to give.
class _TrackCopy extends ConsumerWidget {
  final LibrarySong song;
  final bool centered;

  const _TrackCopy({required this.song, required this.centered});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playing = song.playing;
    final credits = [
      playing.subtitle,
      if (playing.album != null) playing.album!,
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          // A station's row carries what it is playing, so the page names the
          // track rather than the station it was started from.
          playing.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          credits,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Stands where the scrubber would be for a station: there is no position to
/// drag, only the fact that the run has no end.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Symbols.podcasts_rounded,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: SolSpace.sm),
        Text(
          'playerRadio'.tr(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
      ],
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
class _Scrubber extends ConsumerStatefulWidget {
  const _Scrubber();

  @override
  ConsumerState<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends ConsumerState<_Scrubber> {
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
/// Watches only what the buttons draw, so a position tick does not repaint
/// three buttons and their ink.
class _Transport extends ConsumerWidget {
  const _Transport();

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'playerPrevious'.tr(),
          onPressed: controller.previous,
          iconSize: 32,
          icon: const Icon(Symbols.skip_previous_rounded),
        ),
        const SizedBox(width: SolSpace.md),
        IconButton.filled(
          tooltip: state.playing ? 'playerPause'.tr() : 'playerPlay'.tr(),
          onPressed: controller.togglePlayPause,
          iconSize: 36,
          padding: const EdgeInsets.all(SolSpace.lg),
          icon: PlayPauseIcon(playing: state.playing, size: 36),
        ),
        const SizedBox(width: SolSpace.md),
        IconButton(
          tooltip: 'playerNext'.tr(),
          onPressed: state.advances ? controller.next : null,
          iconSize: 32,
          icon: const Icon(Symbols.skip_next_rounded),
        ),
      ],
    );
  }
}
