import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
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
import 'package:groovy_box/widgets/transport.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

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
    with SingleTickerProviderStateMixin {
  /// The slot's current shape. Apple Music's player keeps the alternatives
  /// behind controls in the corner, because they compete for the cover's
  /// column rather than stacking above it.
  _PlayerView _view = _PlayerView.cover;

  /// The alternate the slot last showed. The slot keeps it mounted while the
  /// cover comes back, so closing fades the panel out instead of deleting it
  /// on the frame the button was tapped.
  _PlayerView _pane = _PlayerView.cover;

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
    curve: Curves.easeInOutCubic,
    reverseCurve: Curves.easeInOutCubic,
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
    // The page is what has the keys when it opens, not whichever control the
    // route happened to hand focus to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shortcutFocus.requestFocus();
    });
  }

  void _onMorphStatus(AnimationStatus status) {
    if (status.isDismissed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _volumeSaveTimer?.cancel();
    _shortcutFocus.dispose();
    _morph.removeStatusListener(_onMorphStatus);
    _morph.dispose();
    super.dispose();
  }

  /// Swaps the slot's alternate. Asking for the one already open closes it,
  /// so each corner button toggles itself and picking the other one hands the
  /// slot over rather than opening both.
  void _showView(_PlayerView view) {
    final next = _view == view ? _PlayerView.cover : view;
    setState(() {
      _view = next;
      if (next != _PlayerView.cover) _pane = next;
    });
    if (next == _PlayerView.cover) {
      _morph.reverse();
    } else {
      _morph.forward();
    }
  }

  void _nudgeVolume(double volume, double delta) {
    final next = (volume + delta).clamp(0.0, 100.0);
    ref.read(playbackProvider.notifier).setVolume(next);
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) saveVolume(ref, next);
    });
  }

  void _seekBy(Duration position, Duration by, Duration duration) {
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
  KeyEventResult _onTransportKey(
    KeyEvent event,
    PlaybackState playback,
    Duration duration,
  ) {
    if (!_shortcutFocus.hasPrimaryFocus) return KeyEventResult.ignored;
    // Repeats are wanted for seeking and volume — those are the keys people
    // hold down — and not for the toggles, which would otherwise flap.
    final repeat = event is KeyRepeatEvent;
    if (event is! KeyDownEvent && !repeat) return KeyEventResult.ignored;

    final controller = ref.read(playbackProvider.notifier);
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        if (!repeat) controller.togglePlayPause();
      case LogicalKeyboardKey.arrowLeft:
        if (shift) {
          if (!repeat) controller.previous();
        } else {
          _seekBy(playback.position, const Duration(seconds: -5), duration);
        }
      case LogicalKeyboardKey.arrowRight:
        if (shift) {
          if (!repeat) controller.next();
        } else {
          _seekBy(playback.position, const Duration(seconds: 5), duration);
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
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final song = playback.current;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
    final wide = isWideScreen(context);

    final scrubber = _Scrubber(
      positionMs: positionMs,
      maxMs: maxMs,
      position: playback.position,
      duration: duration,
      onSeek: (value) => controller.seek(Duration(milliseconds: value.round())),
    );

    final transport = _Transport(playback: playback, controller: controller);
    // Built once per page build, not per animation frame: whichever pane is
    // on show keeps its scroll position while the morph runs.
    final alternate = switch (_pane) {
      _PlayerView.queue => const QueuePanel(),
      _ => const SongLyricsPane(
        padding: EdgeInsets.symmetric(horizontal: SolSpace.xs),
        fade: false,
      ),
    };
    final body = wide
        ? _WidePlayerBody(
            song: song,
            scrubber: scrubber,
            transport: transport,
            alternate: alternate,
            morph: _morphT,
          )
        : _CompactPlayerBody(
            song: song,
            scrubber: scrubber,
            transport: transport,
            alternate: alternate,
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
                  onKeyEvent: (_, event) =>
                      _onTransportKey(event, playback, duration),
                  // The body owns the whole page: the close and view
                  // controls float over it rather than sitting in a bar above
                  // it, so the artwork is not charged a row it does not need
                  // and the player reads as one full-bleed surface.
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(child: body),
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => context.router.maybePop(),
                          icon: const Icon(Symbols.keyboard_arrow_down_rounded),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _view == _PlayerView.queue
                                  ? 'Hide queue'
                                  : 'Show queue',
                              isSelected: _view == _PlayerView.queue,
                              onPressed: () => _showView(_PlayerView.queue),
                              icon: const Icon(Symbols.queue_music_rounded),
                            ),
                            IconButton(
                              tooltip: _view == _PlayerView.lyrics
                                  ? 'Hide lyrics'
                                  : 'Show lyrics',
                              isSelected: _view == _PlayerView.lyrics,
                              onPressed: () => _showView(_PlayerView.lyrics),
                              icon: const Icon(Symbols.lyrics_rounded),
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
  final Widget transport;
  final Widget alternate;
  final bool alternateAlive;
  final Animation<double> morph;

  const _CompactPlayerBody({
    required this.song,
    required this.scrubber,
    required this.transport,
    required this.alternate,
    required this.alternateAlive,
    required this.morph,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sized from the window, not from the column left over: the copy,
        // scrubber and transport below have fixed heights, and letting the
        // art claim half the screen is what pushed the transport onto the
        // bottom edge. The second clamp keeps those controls their room on a
        // window short enough for both to compete.
        final coverSize = math.min(
          (constraints.maxHeight * 0.44).clamp(160.0, 360.0),
          math.max(constraints.maxHeight - 250, 120.0),
        );
        // The transport is five buttons wide and does not shrink; where the
        // window is too small for both, the art gives way so the controls
        // keep the width they need instead of spilling out of the column.
        final controlsWidth = math.max(
          coverSize,
          math.min(320.0, constraints.maxWidth),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xl,
            0,
            SolSpace.xl,
            // Clear of the phone's own bottom inset, which [SafeArea] has
            // already applied, and of the window edge: the transport is the
            // last thing on the page, and a button on the glass edge reads as
            // clipped rather than placed.
            SolSpace.xxl,
          ),
          child: Column(
            children: [
              Expanded(
                // The alternate takes the cover's place rather than stacking
                // above the controls: two scrolling bodies in one column
                // leaves neither enough room to read.
                child: _MorphSlot(
                  t: morph,
                  cover: Center(
                    child: _Cover(song: song, size: coverSize),
                  ),
                  alternate: () => alternate,
                  alternateAlive: alternateAlive,
                ),
              ),
              _TrackCopy(song: song, centered: true),
              const SizedBox(height: SolSpace.lg),
              // As wide as the artwork, so the column reads as one object:
              // the square the cover paints is the square the controls span.
              Center(
                child: SizedBox(
                  width: controlsWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [scrubber, transport],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cover and alternate as one slot, morphed rather than swapped.
///
/// The cover sits on top and lifts away while the alternate rises from behind
/// it, so the two never dissolve into each other. The cover stays mounted at
/// both ends — it is the expensive subtree, and rebuilding it on every toggle
/// would blink the artwork — while the alternate exists only while it is
/// wanted or still leaving.
class _MorphSlot extends StatelessWidget {
  final Animation<double> t;
  final Widget cover;
  final Widget Function() alternate;

  /// Whether the alternate is wanted at all. Kept separate from [t] because
  /// the controller reaches 0 one frame before the pane can be dropped.
  final bool alternateAlive;

  const _MorphSlot({
    required this.t,
    required this.cover,
    required this.alternate,
    required this.alternateAlive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        // Staggered, with the cover on top: the alternate rises from behind
        // the artwork and is only uncovered as it lifts away, so no frame
        // shows lettering bleeding through a half-transparent cover. Both
        // subtrees stay mounted at every value — unmounting one would drop its
        // decoded image and its scroll position.
        final out =
            1 - Curves.easeInCubic.transform((v / 0.58).clamp(0.0, 1.0));
        final into = Curves.easeOutCubic.transform(
          ((v - 0.34) / 0.66).clamp(0.0, 1.0),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            // The alternate sits *under* the artwork, so during the morph it
            // is uncovered rather than painted over it. Both subtrees stay
            // mounted at every value, including the ends: unmounting one would
            // drop its decoded image and its scroll position, and the next
            // toggle would re-enter from a blank tile.
            if (alternateAlive || into > 0)
              IgnorePointer(
                ignoring: into < 1,
                child: Opacity(
                  opacity: into,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - into)),
                    child: Transform.scale(
                      scale: 0.97 + 0.03 * into,
                      child: alternate(),
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              ignoring: out < 1,
              child: Opacity(
                opacity: out,
                child: Transform.scale(
                  scale: 1 - 0.05 * (1 - out),
                  child: Transform.translate(
                    offset: Offset(0, -28 * (1 - out)),
                    child: cover,
                  ),
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
  final Widget transport;
  final Widget alternate;
  final Animation<double> morph;

  const _WidePlayerBody({
    required this.song,
    required this.scrubber,
    required this.transport,
    required this.alternate,
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
        const SizedBox(height: SolSpace.lg),
        scrubber,
        const SizedBox(height: SolSpace.sm),
        transport,
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
        // Under half the column, and never taller than the window can show:
        // the cover is a companion to the controls, not the page itself.
        final coverSize = math.min(
          inner * lerpDouble(0.44, 0.40, t)!,
          screen.height * 0.58,
        );
        // The pane grows with the morph instead of starting at the words'
        // full height: at the cover end it is exactly the cover's square, so
        // the row is as tall as the artwork and the column stays centred.
        final wordsHeight = lerpDouble(
          coverSize,
          (screen.height * 0.76).clamp(520.0, 780.0),
          t,
        )!;

        // The controls hand off rather than cross-fade in place: they are on
        // the right for the cover and under the artwork for the words, and the
        // second copy unfolds from beneath the cover as the first lets go. The
        // two ranges overlap, so there is no value of t at which the page has
        // no transport at all.
        final rightControls = (1 - t / 0.52).clamp(0.0, 1.0);
        final leftControls = ((t - 0.26) / 0.74).clamp(0.0, 1.0);
        final words = ((t - 0.40) / 0.60).clamp(0.0, 1.0);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SolSpace.xxl),
            child: SizedBox(
              width: width,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: coverSize,
                    child: Column(
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
                            child: AspectRatio(aspectRatio: 1, child: cover),
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
                                  child: alternate,
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

class _Cover extends StatelessWidget {
  final LibrarySong song;
  final double? size;

  const _Cover({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final artwork = LibraryArtwork(
      sourceId: song.sourceId,
      artId: song.artId,
      radius: SolRadius.xl,
      size: size,
      fallbackIcon: Symbols.album,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SolRadius.xl),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.20),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: size == null
          ? SizedBox.expand(child: artwork)
          : SizedBox.square(dimension: size, child: artwork),
    );
  }
}

class _TrackCopy extends StatelessWidget {
  final LibrarySong song;
  final bool centered;

  const _TrackCopy({required this.song, required this.centered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
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
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Scrubber extends StatelessWidget {
  final double positionMs;
  final double maxMs;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _Scrubber({
    required this.positionMs,
    required this.maxMs,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: positionMs,
          max: maxMs <= 0 ? 1 : maxMs,
          onChanged: maxMs <= 0 ? null : onSeek,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(position), style: labelStyle),
              Text(formatDuration(duration), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  final PlaybackState playback;
  final Playback controller;

  const _Transport({required this.playback, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Shuffle',
          isSelected: playback.shuffle,
          onPressed: () => controller.setShuffle(!playback.shuffle),
          icon: const Icon(Symbols.shuffle_rounded),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton(
          tooltip: 'Previous',
          onPressed: controller.previous,
          iconSize: 32,
          icon: const Icon(Symbols.skip_previous_rounded),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton.filled(
          tooltip: playback.playing ? 'Pause' : 'Play',
          onPressed: controller.togglePlayPause,
          iconSize: 36,
          padding: const EdgeInsets.all(SolSpace.lg),
          icon: PlayPauseIcon(playing: playback.playing, size: 36),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton(
          tooltip: 'Next',
          onPressed: playback.hasNext ? controller.next : null,
          iconSize: 32,
          icon: const Icon(Symbols.skip_next_rounded),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton(
          tooltip: playback.repeatMode == PlaybackRepeatMode.single
              ? 'Repeat song'
              : 'Repeat',
          isSelected: playback.repeatMode != PlaybackRepeatMode.off,
          onPressed: controller.cycleRepeatMode,
          icon: Icon(
            playback.repeatMode == PlaybackRepeatMode.single
                ? Symbols.repeat_one_rounded
                : Symbols.repeat_rounded,
          ),
        ),
      ],
    );
  }
}
