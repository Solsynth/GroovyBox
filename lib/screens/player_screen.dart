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
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Full-window player: large cover, scrubber, transport and volume.
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
/// Lyrics are not a second page: they are the same page in another shape. One
/// controller drives the change, and every box that differs between the two
/// arrangements — the slot's height, the frame's width, the cover's size, the
/// side the controls hang from — is interpolated from it, so there is no frame
/// where the player is neither one layout nor the other.
@RoutePage()
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  /// Whether the page shows lyrics instead of the cover. Apple Music's player
  /// keeps both behind one control in the corner, because the cover and the
  /// words compete for the same column.
  bool _showLyrics = false;

  /// Drives the morph between the two arrangements: 0 is the cover, 1 is the
  /// lyrics. It runs in both directions, so closing the words is the opening
  /// played backwards rather than a second, different animation.
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

  void _toggleLyrics() {
    setState(() => _showLyrics = !_showLyrics);
    if (_showLyrics) {
      _morph.forward();
    } else {
      _morph.reverse();
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

  /// Escape backs out one layer at a time: the words first, the page second.
  /// Leaving the player from under an open lyric pane would take the pane with
  /// it, and closing the pane is what the same key means everywhere else.
  void _backOut() {
    if (_showLyrics) {
      _toggleLyrics();
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
  /// A focused control keeps its own keys: Space activates the button the user
  /// tabbed to and the volume slider takes the arrows, which is what a
  /// keyboard user expects from each. These apply to the page's own focus,
  /// which is where the page starts and where a click on empty space returns.
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
        if (!repeat) _toggleLyrics();
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

    final volume = _VolumeControl(
      volume: playback.volume,
      onChanged: controller.setVolume,
      onSaved: (value) => saveVolume(ref, value),
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
            // The empty field around the content is a way back to the page's
            // own keys: after tabbing onto a control, Space and the arrows
            // belong to that control, and a tap on the backdrop hands them
            // back instead of leaving the user to tab around in a circle.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _shortcutFocus.requestFocus,
                // The cover, blown up and blurred, gives the page a colour
                // field without introducing a gradient of our own.
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
            SafeArea(
              child: Focus(
                focusNode: _shortcutFocus,
                autofocus: true,
                includeSemantics: false,
                onKeyEvent: (_, event) =>
                    _onTransportKey(event, playback, duration),
                child: Column(
                  children: [
                    _PlayerHeader(
                      onClose: () => context.router.maybePop(),
                      showingLyrics: _showLyrics,
                      onToggleLyrics: _toggleLyrics,
                    ),
                    Expanded(
                      child: wide
                          ? _WidePlayerBody(
                              song: song,
                              scrubber: scrubber,
                              transport: transport,
                              volume: volume,
                              morph: _morphT,
                            )
                          : _CompactPlayerBody(
                              song: song,
                              scrubber: scrubber,
                              transport: transport,
                              volume: volume,
                              showLyrics: _showLyrics,
                              morph: _morphT,
                            ),
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

/// The player's own bar: close on the left, the lyrics toggle on the right.
///
/// No title between them — the track's copy is the page's headline, and a
/// "Now playing" label above it only said what the artwork and the scrubber
/// already say.
class _PlayerHeader extends StatelessWidget {
  final VoidCallback onClose;
  final bool showingLyrics;
  final VoidCallback onToggleLyrics;

  const _PlayerHeader({
    required this.onClose,
    required this.showingLyrics,
    required this.onToggleLyrics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Symbols.keyboard_arrow_down_rounded),
          ),
          const Spacer(),
          IconButton(
            tooltip: showingLyrics ? 'Hide lyrics' : 'Show lyrics',
            isSelected: showingLyrics,
            onPressed: onToggleLyrics,
            icon: const Icon(Symbols.lyrics_rounded),
          ),
        ],
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
/// The cover and the words are one slot rather than two layouts, so the lyrics
/// button morphs that slot instead of swapping its child.
class _CompactPlayerBody extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;
  final Widget transport;
  final Widget volume;
  final bool showLyrics;
  final Animation<double> morph;

  const _CompactPlayerBody({
    required this.song,
    required this.scrubber,
    required this.transport,
    required this.volume,
    required this.showLyrics,
    required this.morph,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = (constraints.maxHeight * 0.54).clamp(200.0, 460.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xl,
            0,
            SolSpace.xl,
            SolSpace.lg,
          ),
          child: Column(
            children: [
              Expanded(
                // Lyrics take the cover's place rather than stacking above the
                // controls: two scrolling bodies in one column leaves neither
                // enough room to read a verse.
                child: _MorphSlot(
                  t: morph,
                  cover: Center(child: _Cover(song: song, size: coverSize)),
                  // Built only once the words are on their way in or still
                  // fading out, so the cover state costs no lyric request.
                  lyrics: () => const SongLyricsPane(
                    padding: EdgeInsets.symmetric(horizontal: SolSpace.xs),
                    fade: false,
                  ),
                  lyricsAlive: showLyrics,
                ),
              ),
              _TrackCopy(song: song, centered: true),
              const SizedBox(height: SolSpace.lg),
              // Exactly the artwork's width, so the column reads as one
              // object: the square the cover paints is the square the
              // controls span. Both clamp to the same padded width on a
              // narrow window, so they stay matched at every size.
              Center(
                child: SizedBox(
                  width: coverSize,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      scrubber,
                      transport,
                      const SizedBox(height: SolSpace.xs),
                      volume,
                    ],
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

/// Cover and lyrics as one slot, morphed rather than swapped.
///
/// The cover sits on top and lifts away while the words rise from behind it,
/// so the two never dissolve into each other. The cover stays mounted at both
/// ends — it is the expensive subtree, and rebuilding it on every toggle would
/// blink the artwork — while the words exist only while they are wanted or
/// still leaving.
class _MorphSlot extends StatelessWidget {
  final Animation<double> t;
  final Widget cover;
  final Widget Function() lyrics;

  /// Whether the words are wanted at all. Kept separate from [t] because the
  /// controller reaches 0 one frame before the pane can be dropped.
  final bool lyricsAlive;

  const _MorphSlot({
    required this.t,
    required this.cover,
    required this.lyrics,
    required this.lyricsAlive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        // Staggered, with the cover on top: the words rise from behind the
        // artwork and are only uncovered as it lifts away, so no frame shows
        // lettering bleeding through a half-transparent cover. Both subtrees
        // stay mounted at every value — unmounting one would drop its decoded
        // image and its scroll position.
        final out = 1 - Curves.easeInCubic.transform((v / 0.58).clamp(0.0, 1.0));
        final into = Curves.easeOutCubic.transform(
          ((v - 0.34) / 0.66).clamp(0.0, 1.0),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            // Words sit *under* the artwork, so during the morph they are
            // uncovered rather than painted over it. Both subtrees stay
            // mounted at every value, including the ends: unmounting one would
            // drop its decoded image and its scroll position, and the next
            // toggle would re-enter from a blank tile.
            if (lyricsAlive || into > 0)
              IgnorePointer(
                ignoring: into < 1,
                child: Opacity(
                  opacity: into,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - into)),
                    child: Transform.scale(
                      scale: 0.97 + 0.03 * into,
                      child: lyrics(),
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
  final Widget volume;
  final Animation<double> morph;

  const _WidePlayerBody({
    required this.song,
    required this.scrubber,
    required this.transport,
    required this.volume,
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
    // words it sits in the cover's own column, so the scrubber and the volume
    // row span the same width as the art rather than a width of their own.
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
        const SizedBox(height: SolSpace.lg),
        volume,
      ],
    );
    const lyrics = SongLyricsPane(
      padding: EdgeInsets.symmetric(horizontal: SolSpace.sm),
      fade: false,
    );

    return AnimatedBuilder(
      animation: morph,
      builder: (context, _) {
        final t = morph.value;
        final screen = MediaQuery.sizeOf(context);

        // Both ends of every measurement, so no frame has to choose between
        // them: the cover end is a square that sizes itself from its column,
        // the lyrics end is a frame that fits the viewport.
        final viewport = math.max(screen.width - SolSpace.xxl * 2, 320.0);
        final width = math.min(lerpDouble(1000, 1120, t)!, viewport);
        final inner = math.max(width - SolSpace.xxxl, 0.0);
        final squareEnd = inner * 0.5;
        final lyricsHeight = (screen.height * 0.76).clamp(520.0, 780.0);
        final height = lerpDouble(squareEnd, lyricsHeight, t)!;
        final leftWidth = inner * lerpDouble(0.5, 0.45, t)!;

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
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (rightControls > 0)
                          IgnorePointer(
                            ignoring: rightControls < 1,
                            child: Opacity(
                              opacity: rightControls,
                              child: Center(child: controls),
                            ),
                          ),
                        if (words > 0)
                          IgnorePointer(
                            ignoring: words < 1,
                            child: Opacity(
                              opacity: words,
                              child: Transform.translate(
                                offset: Offset(28 * (1 - words), 0),
                                child: lyrics,
                              ),
                            ),
                          ),
                      ],
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
          icon: Icon(
            playback.playing
                ? Symbols.pause_rounded
                : Symbols.play_arrow_rounded,
          ),
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