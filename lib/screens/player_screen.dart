import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/services.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
import 'package:groovy_box/widgets/song_actions.dart';
import 'package:groovy_box/widgets/track_versions.dart';
import 'package:groovy_box/widgets/transport.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:marqueer/marqueer.dart';
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

/// Height the column under the cover takes on a wide window at the default
/// type size: the copy, the scrubber and the transport, plus the gaps
/// between them.
///
/// The wide layout sizes the cover and the words against it, and its controls
/// sit in that column. The compact page measures its own tail instead; this
/// is the wide column's number.
const double _kBodyTail = 300;

/// Narrowest the copy, scrubber and transport column gets before it spills.
///
/// The transport is five icon buttons plus their gaps and does not shrink
/// with the window; a column narrower than this clips the first and last one,
/// so the square above it is what gives way instead.
const double _kControlsMinWidth = 288;

/// Side of the sleeve in the compact page's docked bar.
///
/// Also the cover's landing size: the artwork flies out of the slot and into
/// this box when the words or the queue take the slot, so it is a measurement
/// rather than a preference.
const double _kDockSleeve = 44;

/// Inset of the docked bar's contents inside its capsule.
///
/// The leading edge matches the sleeve's own corner, so the artwork sits
/// square in the capsule's start the way the dock's thumbnail does. Fixed
/// because the cover's flight ends at that sleeve, and its position is
/// arithmetic taken before the bar has been laid out.
const double _kDockPad = SolSpace.md;

/// Gap the docked bar keeps under itself, on top of the page's own margin: a
/// capsule on the page's last pixel reads as the floor rather than as a bar
/// floating above it.
const double _kDockMargin = SolSpace.md;

/// Height the bar's track row takes at the default type size: the sleeve is
/// the tallest thing in it.
const double _kDockRowHeight = 48;

/// Height a slider block takes at the default type size: the slider's tap box
/// and the two clocks under it, plus the type size's own share.
const double _kSeekHeight = 40;

/// Height a transport row takes: the play button's own box, asked of the
/// widget rather than repeated here — a row shorter than the tallest button
/// overflows rather than clipping.
double _transportHeight({bool compact = false}) =>
    Transport.height(compact: compact);

/// Height the compact copy block takes at the default type size: one line of
/// headline and the credit line under it.
///
/// Measured rather than assumed — a headline line, a body line and the gap
/// between them — because the block is what the copy is allowed to take
/// before the artwork above it gives way.
const double _kCopyHeight = 92;

/// The tail under the compact slot, in either arrangement.
///
/// Two tails share the page's floor and swap on the morph: the cover's, which
/// is the copy and the controls laid on the page, and the alternate's, which
/// is one docked capsule. [total] is what each takes, so the slot above them
/// is arithmetic rather than a leftover.
typedef _TailMetrics = ({double seek, double total});

_TailMetrics _coverTail(double textScale) {
  final seek = _kSeekHeight + textScale * 16;
  return (
    seek: seek,
    total:
        textScale * _kCopyHeight +
        SolSpace.sm +
        seek +
        SolSpace.sm +
        _transportHeight(),
  );
}

/// The docked bar's geometry at a given text size, with the cover's landing
/// box inside it.
///
/// Shared by the bar and by the cover's flight, which has to know where the
/// sleeve sits before the bar itself has been laid out: both read the same
/// numbers rather than measuring each other. [total] is the bar's own height
/// — the slot above it is what is left of the page.
typedef _DockMetrics = ({
  double row,
  double seek,
  double total,
  double sleeveTop,
});

_DockMetrics _dockMetrics(double textScale) {
  final row = math.max(_kDockRowHeight, textScale * _kDockRowHeight);
  final seek = _kSeekHeight + textScale * 16;
  return (
    row: row,
    seek: seek,
    // Three rows: the track, the seek bar on its own, then the transport.
    total:
        _kDockPad * 2 +
        row +
        SolSpace.xs +
        seek +
        SolSpace.xs +
        _transportHeight(compact: true) +
        _kDockMargin,
    sleeveTop: _kDockPad + (row - _kDockSleeve) / 2,
  );
}

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
    // last on the track title.
    return Padding(padding: _kPanePadding, child: pane);
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
    final Widget bottom = song.isRadio ? const _LiveBadge() : const Scrubber();
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
            alternateAlive: _view != _PlayerView.cover,
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
                                    : () => TrackVersionsPanel.show(
                                        context,
                                        song,
                                      ),
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
                          top: _kCornerInset,
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

/// Compact: the artwork on top, the copy under it, and the page's corner
/// controls floated at the top edge.
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
        // Two tails share the page's floor: the cover's copy and controls,
        // and the docked capsule the alternates use. Each reserves its own
        // height, so the words get the capsule's room back while the square
        // above them gives way rather than both claiming the same pixels.
        // engine's `scaleFontSize` asserts when the platform's scaling
        // configuration goes stale (a macOS debug failure that has been seen
        // mid-layout), and these constants are plain layout arithmetic —
        // ignore: deprecated_member_use
        final textScale = MediaQuery.textScalerOf(context).textScaleFactor;
        final contentWidth = math.max(
          constraints.maxWidth - SolSpace.xl * 2,
          0.0,
        );
        final available = math.max(
          constraints.maxHeight - _kPageMargin * 2,
          0.0,
        );
        final coverTail = _coverTail(textScale);
        final dock = _dockMetrics(textScale);
        final coverSlot = math.max(available - coverTail.total, 0.0);
        final dockSlot = math.max(available - dock.total, 0.0);
        // As much of the slot as a square can take, capped so a tall window
        // does not turn the sleeve into the page. Measured at the cover end:
        // that is the only state that draws it at this size.
        final coverSize = math.min(
          math.min(coverSlot, contentWidth) * 0.92,
          360.0,
        );
        // The copy, the seek bar and the transport keep the square's width,
        // so the column reads as one object rather than three rows of
        // different lengths.
        final controlsWidth = math.max(
          coverSize,
          math.min(320.0, contentWidth),
        );
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final startRect = Rect.fromLTWH(
          (contentWidth - coverSize) / 2,
          (coverSlot - coverSize) / 2,
          coverSize,
          coverSize,
        );
        // The flight's landing box is the bar's own sleeve, taken from the
        // bar's arithmetic rather than from its laid-out children: the
        // artwork is placed in the stack before the bar has been inflated,
        // so the two cannot read each other.
        final endRect = Rect.fromLTWH(
          isRtl ? contentWidth - _kDockPad - _kDockSleeve : _kDockPad,
          dockSlot + dock.sleeveTop,
          _kDockSleeve,
          _kDockSleeve,
        );
        final coverPixelSize =
            (coverSize * MediaQuery.devicePixelRatioOf(context)).round();
        return AnimatedBuilder(
          animation: morph,
          builder: (context, _) {
            final t = morph.value;
            final slotHeight = lerpDouble(coverSlot, dockSlot, t)!;
            final tailHeight = lerpDouble(coverTail.total, dock.total, t)!;
            final artRect = Rect.lerp(startRect, endRect, t)!;
            final artRadius = lerpDouble(SolRadius.xl, SolRadius.sm, t)!;
            // The copy hands over to the capsule: it fades out as the words
            // take the slot, and the bar settles in behind them. Two ramps
            // rather than one so there is no frame where the page has neither
            // a headline nor a way to seek.
            final copyOut =
                1 - _eased(Curves.easeInCubic, (t / 0.28).clamp(0.0, 1.0));
            final barIn = _eased(
              Curves.easeOutCubic,
              ((t - 0.35) / 0.65).clamp(0.0, 1.0),
            );
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The slot takes what the tail does not: the cover, or
                      // the words and the queue in its place.
                      SizedBox(
                        height: slotHeight,
                        child: _MorphSlot(
                          t: morph,
                          alternate: alternate,
                          leaving: leaving,
                          swap: swap,
                          alternateAlive: alternateAlive,
                        ),
                      ),
                      // One frame holds whichever tail is on show; the two
                      // trade places on the morph. Only the visible one is
                      // mounted, so a page at rest has one seek bar and one
                      // transport, not two of each.
                      SizedBox(
                        height: tailHeight,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              // The cover's tail: the copy and the controls,
                              // laid on the page, anchored to the top so the
                              // headline stays where the artwork left it.
                              if (copyOut > 0)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    ignoring: copyOut < 1,
                                    child: Opacity(
                                      opacity: copyOut,
                                      child: _PageTail(
                                        song: song,
                                        scrubber: scrubber,
                                        width: controlsWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              // Docked, and only while an alternate is up:
                              // the capsule is what buys the words their
                              // height, so the cover keeps the roomier tail.
                              // Anchored to the floor so it rises out of the
                              // page edge as the frame shrinks under it.
                              if (barIn > 0)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    ignoring: barIn < 1,
                                    child: Opacity(
                                      opacity: barIn,
                                      child: _DockBar(
                                        song: song,
                                        scrubber: scrubber,
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
                  // Single persistent artwork widget that flies like a hero
                  // between the slot's center and the bar's sleeve.
                  Positioned.fromRect(
                    rect: artRect,
                    child: _Cover(
                      song: song,
                      size: artRect.width,
                      radius: artRadius,
                      pixelSize: coverPixelSize,
                      shadowOpacity: lerpDouble(0.20, 0.06, t)!,
                      shadowBlur: lerpDouble(40, 6, t)!,
                      shadowOffsetY: lerpDouble(10, 2, t)!,
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

/// The compact cover's tail: the track's copy, the seek bar and the transport,
/// straight on the page's own field.
///
/// This is the arrangement the page opens in, and the one it returns to when
/// the words close: nothing is docked here, so the copy is the page's headline
/// and each control owns its row.
class _PageTail extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;
  final double width;

  const _PageTail({
    required this.song,
    required this.scrubber,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Same arithmetic the flight and the bar use, at the same type size.
    // engine's `scaleFontSize` asserts when the platform's scaling
    // configuration goes stale mid-layout.
    // ignore: deprecated_member_use
    final textScale = MediaQuery.textScalerOf(context).textScaleFactor;
    final tail = _coverTail(textScale);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: textScale * _kCopyHeight,
          child: Center(child: _TrackCopy(song: song, centered: true)),
        ),
        const SizedBox(height: SolSpace.sm),
        // As wide as the artwork, so the column reads as one object: the
        // square the cover paints is the square the controls span.
        Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: tail.seek, child: scrubber),
                const SizedBox(height: SolSpace.sm),
                SizedBox(height: _transportHeight(), child: const Transport()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Alternate pane slot, uncovered as the hero artwork lifts into the bar.
///
/// The alternate exists only while it is wanted or still leaving, and rises
/// into place as the cover flies out of the slot's center down to the bar.
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
              child: Transform.scale(scale: 0.97 + 0.03 * into, child: pane),
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
/// The frame's width, its height and the cover's size are plain measurements
/// of the current arrangement; the containers below animate the change
/// between them. The controls still hand off with the page's morph: they are
/// on the right for the cover and under the artwork for the words, and each
/// copy fades on its own ramp so there is no frame with no transport.
class _WidePlayerBody extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;
  final Widget alternate;
  final Widget? leaving;
  final Animation<double> swap;
  final Animation<double> morph;

  /// Whether the alternate is wanted at all. The frame sizes for the words
  /// when it is and for the cover when it is not, and the containers below
  /// animate the change.
  final bool alternateAlive;

  const _WidePlayerBody({
    required this.song,
    required this.scrubber,
    required this.alternate,
    required this.leaving,
    required this.swap,
    required this.morph,
    required this.alternateAlive,
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
        const Transport(),
      ],
    );

    return AnimatedBuilder(
      animation: morph,
      builder: (context, _) {
        final t = morph.value;
        final screen = MediaQuery.sizeOf(context);

        // The column is exactly one cover wide at both arrangements. Sizing
        // it as a fraction of the frame instead let the scrubber outgrow the
        // square above it, and a progress bar wider than the artwork reads
        // as a separate control rather than as the artwork's own ruler.
        final viewport = math.max(screen.width - SolSpace.xxl * 2, 320.0);
        final width = math.min(alternateAlive ? 1120.0 : 1000.0, viewport);
        final inner = math.max(width - SolSpace.xxxl, 0.0);
        // The window's own margin, and the height the right column's copy
        // and controls need at the reader's type size.
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
            inner * (alternateAlive ? 0.40 : 0.44),
            math.min(screen.height * 0.58, bodyHeight),
          ),
          math.min(_kControlsMinWidth, inner),
        );
        // The controls hand off rather than cross-fade in place: they are on
        // the right for the cover and under the artwork for the words, and
        // the second copy fades in as the first lets go on the morph, so
        // there is no value of t at which the page has no transport at all.
        final rightControls = (1 - t / 0.52).clamp(0.0, 1.0);
        final leftControls = ((t - 0.26) / 0.74).clamp(0.0, 1.0);
        final words = ((t - 0.40) / 0.60).clamp(0.0, 1.0);

        // At the cover end the row is as tall as the artwork (or the controls
        // beside it, because they cannot shrink); under the words it is the
        // pane's height.
        final leftColumnNeeded = coverSize + (SolSpace.lg + controlsHeight);
        final wordsHeight = math.max(
          alternateAlive
              ? (bodyHeight * 0.9).clamp(400.0, 780.0)
              : math.max(coverSize, controlsHeight),
          math.max(controlsHeight, leftColumnNeeded),
        );

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SolSpace.xxl,
              vertical: _kPageMargin,
            ),
            child: AnimatedContainer(
              width: width,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    width: coverSize,
                    height: wordsHeight,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
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
                        AnimatedContainer(
                          width: coverSize,
                          height: coverSize,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
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
                  const SizedBox(width: SolSpace.xxxl),
                  Expanded(
                    child: AnimatedContainer(
                      height: wordsHeight,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
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

/// The compact page's docked bar: the now-playing capsule, with more on it
/// than the shell's dock carries.
///
/// The shell's dock is a strip under every page, so it holds the thumbnail,
/// the track and the transport and nothing else — a seek bar and two clocks
/// there would cost every page its bottom. Here the bar is the player's own
/// floor instead, so it takes the seek bar as well, and the track row keeps a
/// menu for the few things that are about this track rather than about the
/// page.
///
/// [PillSurface] paints it, the same material the dock uses, so a page that is
/// the dock expanded keeps the dock's language at its floor.
///
/// The sleeve carries the same artwork the hero flies: the bar is on screen
/// at both ends of the morph, so it cannot be a hole waiting for the cover to
/// land in it — the player whose cover is up needs its thumbnail at the floor
/// too. The flight ends exactly on the sleeve's box, at the sleeve's radius,
/// so the landing reads as the cover settling rather than as a second copy
/// appearing beside it.
class _DockBar extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;

  const _DockBar({required this.song, required this.scrubber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playing = song.playing;
    // Same arithmetic the cover's flight lands on, at the same type size.
    // engine's `scaleFontSize` asserts when the platform's scaling
    // configuration goes stale mid-layout.
    // ignore: deprecated_member_use
    final textScale = MediaQuery.textScalerOf(context).textScaleFactor;
    final metrics = _dockMetrics(textScale);

    return Padding(
      // Room under the capsule: on the page's last pixel it reads as the
      // floor of the window rather than as a bar floating above it. Part of
      // the bar's own height, so the slot above it is sized for the gap too.
      padding: const EdgeInsets.only(bottom: _kDockMargin),
      child: PillSurface(
        // The page's own surface, not a bar floating over content that
        // scrolls under it: no margin, and the page's field is what it
        // refracts.
        radius: const BorderRadius.all(Radius.circular(SolRadius.sheet)),
        contentPadding: EdgeInsets.fromLTRB(
          _kDockPad,
          _kDockPad,
          SolSpace.md,
          _kDockPad,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: metrics.row,
              child: Row(
                children: [
                  // The hero's landing box: the same art, size and radius the
                  // flight ends on, so the cover settles into it without a jump.
                  LibraryArtwork(
                    sourceId: song.sourceId,
                    artId: song.artId,
                    size: _kDockSleeve,
                    radius: SolRadius.sm,
                  ),
                  const SizedBox(width: SolSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Same marquee as the cover's headline: the bar's
                        // row is narrower than a long title, and a menu
                        // button at its end leaves no room to clamp it.
                        SizedBox(
                          height: theme.textTheme.bodyMedium!.fontSize! * 1.5,
                          child: _MarqueeTitle(
                            title: playing.title,
                            centered: false,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // The credits are links here too, so the bar is not a
                        // read-only copy of the page's own row.
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (playing.artistId != null && !playing.isRadio)
                              _CreditLink(
                                label: playing.artist ?? playing.subtitle,
                                onTap: () => context.router.push(
                                  ArtistDetailRoute(
                                    sourceId: playing.sourceId,
                                    artistId: playing.artistId!,
                                    artistName:
                                        playing.artist ?? playing.subtitle,
                                  ),
                                ),
                              )
                            else
                              _CreditText(
                                label: playing.subtitle,
                                centered: false,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // The track's everything else — favourite, playlist, share,
                  // playback info and other versions. The shell's dock has no
                  // room for a menu; this row is the track's own, so it rides
                  // here instead of beside the corner controls.
                  _TrackMoreMenu(),
                ],
              ),
            ),
            const SizedBox(height: SolSpace.xs),
            // The seek bar takes a row of its own: beside the transport it was
            // squeezed into whatever the buttons left, and a ruler that short
            // cannot be dragged accurately. Its clocks scale with the type
            // size, so the row is a fixed height — the sleeve above must not
            // move while they re-render once a second.
            SizedBox(height: metrics.seek, child: scrubber),
            const SizedBox(height: SolSpace.xs),
            SizedBox(
              height: _transportHeight(compact: true),
              child: const Transport(compact: true),
            ),
          ],
        ),
      ),
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
    // One Hero flight for the route transition: the tag is the track itself,
    // so the same artwork flies from wherever it was showing (the dock's
    // thumbnail) into the page.
    final artwork = Hero(
      tag: 'player-artwork-${song.sourceId}-${song.playing.id}',
      child: LibraryArtwork(
        sourceId: song.sourceId,
        artId: song.artId,
        radius: radius,
        size: size,
        pixelSize: pixelSize,
        fallbackIcon: Symbols.album,
      ),
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
/// which record — with the more button on the trailing edge.
///
/// Set like the back of a sleeve rather than like a card caption: the title
/// carries the weight, and the credits sit on one quiet line under it. The
/// library the track plays from is not drawn here — the question "where is
/// this playing from?" is answered by the playback-info sheet behind the
/// more button, and a cloud mark beside every title cost the title its room
/// for an answer this page never needed to give.
class _TrackCopy extends ConsumerWidget {
  final LibrarySong song;
  final bool centered;

  const _TrackCopy({required this.song, required this.centered});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playing = song.playing;
    // Both credits lead somewhere when the track carries the id: the artist
    // opens their page, the album its own. No id — a radio track, an
    // unmapped server — stays plain text; guessing a page by name would forge
    // one the source never described.
    final artistRef = (playing.artistId == null || playing.isRadio)
        ? null
        : (sourceId: playing.sourceId, id: playing.artistId!);
    final albumRef = playing.albumId == null
        ? null
        : (sourceId: playing.sourceId, id: playing.albumId!);
    final albumCredit = playing.album;

    // The button is the title's suffix, not a corner control: the title line
    // is [mark title ···] as one row, and the credits center under it. The
    // prefix slot cancels the suffix's width, so the title keeps its visual
    // center — and the slot earns its keep as the favourite mark: a filled
    // heart when the device remembers the track, nothing when it does not.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: .center,
          spacing: 4,
          children: [
            const _FavouriteMark(),
            Flexible(
              child: _MarqueeTitle(
                // A station's row carries what it is playing, so the page
                // names the track rather than the station it was started
                // from.
                title: playing.title,
                centered: centered,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
            ),
            // The track's everything-else: favourite, playlist, share,
            // playback info, other versions.
            _TrackMoreMenu(),
          ],
        ),
        const SizedBox(height: 4),
        // The credit line: the artist, then the album, each tappable when the
        // track carries its id. Centered copy centers it; a left-aligned one
        // keeps the line starting at the same edge as the title.
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (artistRef != null)
              _CreditLink(
                label: playing.artist ?? playing.subtitle,
                onTap: () => context.router.push(
                  ArtistDetailRoute(
                    sourceId: artistRef.sourceId,
                    artistId: artistRef.id,
                    artistName: playing.artist ?? playing.subtitle,
                  ),
                ),
              )
            else
              _CreditText(label: playing.subtitle, centered: centered),
            if (albumCredit != null) ...[
              _CreditText(label: '·', centered: centered),
              if (albumRef != null)
                _CreditLink(
                  label: albumCredit,
                  onTap: () => context.router.push(
                    AlbumDetailRoute(
                      sourceId: albumRef.sourceId,
                      albumId: albumRef.id,
                      albumName: albumCredit,
                    ),
                  ),
                )
              else
                _CreditText(label: albumCredit, centered: centered),
            ],
          ],
        ),
      ],
    );
  }
}

/// The track's name, scrolling when it does not fit.
///
/// The headline is the one string on the page that can outgrow its row and
/// cannot be shortened: clamping it to two lines either pushes the controls
/// down or cuts off the name the reader came to see. The marquee runs only
/// when the text is wider than the box it was given, so a short title sits
/// still and centred like ordinary copy.
class _MarqueeTitle extends StatelessWidget {
  final String title;
  final bool centered;
  final TextStyle? style;

  const _MarqueeTitle({
    required this.title,
    required this.centered,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: style,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measured with the style the text actually draws in, so the two
        // cannot disagree about whether the row overflows.
        final painter = TextPainter(
          text: TextSpan(text: title, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final overflows = painter.width > constraints.maxWidth;
        painter.dispose();
        if (!overflows) return Center(child: text);
        return Marqueer(
          // Left to right is the reading direction, and a title that starts
          // off screen is a title nobody reads from the beginning.
          direction: MarqueerDirection.ltr,
          // Slow enough to read: this is the page's headline, not a ticker
          // across the bottom of a broadcast.
          pps: 40,
          // One pass and then rest at the end. A headline that loops forever
          // makes a page at rest look busy.
          infinity: false,
          edgeDuration: const Duration(seconds: 2),
          // A horizontal viewport expands across its own axis, and the row's
          // height is not bounded: the marquee measures the title's line
          // instead of claiming the whole column.
          intrinsicCrossAxisSize: true,
          child: text,
        );
      },
    );
  }
}

/// One quiet credit on the copy's second line.
class _CreditText extends StatelessWidget {
  final String label;
  final bool centered;

  const _CreditText({required this.label, required this.centered});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.xs),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A credit that leads somewhere: the artist's page, or the album's.
///
/// A quiet link: the name keeps the credit line's own colour and only the
/// cursor and the ripple say it is tappable, because on this page nine words
/// out of ten are not links and one that shouts would be noise.
class _CreditLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CreditLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(SolRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SolSpace.xs,
            vertical: 2,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// The more button at the track copy's trailing edge, and its menu.
///
/// A [MenuAnchor] rather than a sheet: the actions are few and read as a
/// continuation of the copy they act on, so the menu opens from the button
/// that named them. The sheet items — playback info, other versions — anchor
/// to the same button, so on iPad they land beside what was tapped rather
/// than at the window edge.
class _TrackMoreMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playbackProvider.select((state) => state.current));
    if (song == null) return const SizedBox.shrink();

    return MenuAnchor(
      builder: (context, controller, child) => IconButton(
        tooltip: 'playerMore'.tr(),
        // Smaller than a toolbar button: it rides beside the title rather
        // than standing in a row of its own, and its tap target keeps the
        // standard 48 box while the glyph and the hover ink stay compact.
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Symbols.more_horiz_rounded),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Symbols.info_rounded),
          onPressed: () => PlaybackInfoSheet.show(context, song),
          child: Text('playerPlaybackInfo'.tr()),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.content_copy_rounded),
          onPressed: song.isRadio
              ? null
              : () => TrackVersionsPanel.show(context, song),
          child: Text('versionsTitle'.tr()),
        ),
        const Divider(height: 1),
        _SongActionsMenuItems(hostContext: context),
      ],
    );
  }
}

/// The track's own writes — favourite, playlist, share — as menu items.
///
/// The same capabilities the action bar drew, asked again here so the menu
/// offers only what the playing source can actually do.
///
/// Watches come through [ref] while the menu is open; the writes go through
/// the host context instead, because the item's own element is deactivated
/// the frame the menu closes and its ref is dead before the handler runs.
class _SongActionsMenuItems extends ConsumerWidget {
  /// The context of the widget hosting the menu — the more button, which
  /// stays mounted across the close — not a menu item's.
  final BuildContext hostContext;

  const _SongActionsMenuItems({required this.hostContext});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playbackProvider.select((state) => state.current));
    if (song == null) return const SizedBox.shrink();
    // The menu item and the prefix heart both read the same provider, so a
    // write through either one turns both surfaces together.
    final favourited = ref.watch(
      favouriteStateProvider(song).select((value) => value.value ?? false),
    );
    final source = ref.watch(
      librarySourceByIdProvider.select((sources) => sources[song.sourceId]),
    );
    final actions = SongActions(
      source is RatedSource ? source : null,
      source is ExtendableSource ? source : null,
      song,
    );
    if (!actions.canFavourite && !actions.canAddToPlaylist) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.canFavourite)
          MenuItemButton(
            leadingIcon: Icon(
              favourited
                  ? Symbols.favorite_rounded
                  : Symbols.favorite_border_rounded,
            ),
            onPressed: () =>
                SongActionsRunner.toggleFavourite(hostContext, actions),
            child: Text(
              favourited ? 'playerFavourited'.tr() : 'playerFavourite'.tr(),
            ),
          ),
        if (actions.canAddToPlaylist)
          MenuItemButton(
            leadingIcon: const Icon(Symbols.playlist_add_rounded),
            onPressed: () =>
                SongActionsRunner.pickPlaylist(hostContext, actions),
            child: Text('playerAddToPlaylist'.tr()),
          ),
        // Always offered, session or not: without an account the runner says
        // so in a snackbar rather than the item vanishing from the menu — a
        // reader looking for Share should find the entry, not guess why the
        // menu is shorter today.
        MenuItemButton(
          leadingIcon: const Icon(Symbols.ios_share_rounded),
          onPressed: () => SongActionsRunner.share(hostContext, song),
          child: Text('playerShare'.tr()),
        ),
      ],
    );
  }
}

/// The prefix slot before the title: a filled heart when the device remembers
/// the track as a favourite, an empty box of the button's size when it does
/// not. The slot's width is fixed either way, so the title between it and the
/// more button keeps its visual center whether or not the heart is lit.
class _FavouriteMark extends ConsumerWidget {
  const _FavouriteMark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playbackProvider.select((state) => state.current));
    final favourited = song == null
        ? false
        : ref.watch(
            favouriteStateProvider(song)
                .select((value) => value.value ?? false),
          );
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 32,
      height: 32,
      child: favourited
          ? Icon(
              Symbols.favorite_rounded,
              size: 20,
              color: colorScheme.error,
              fill: 1,
            )
          : null,
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
