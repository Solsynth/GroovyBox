import 'dart:async';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/desktop/mini_player/mini_playback.dart';
import 'package:groovy_box/desktop/mini_player/window.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/shell/window_frame.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/transport.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

/// The mini player window's root: a plain [MaterialApp] with the same theme
/// and locale wiring as [GroovyBoxApp], minus the router — the guest engine
/// has exactly one screen and no routes to draw.
class MiniPlayerApp extends ConsumerWidget {
  const MiniPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'GroovyBox Mini',
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      supportedLocales: kSupportedLocales,
      locale: context.locale,
      localizationsDelegates: [
        ...context.localizationDelegates,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: const MiniPlayerHome(),
    );
  }
}

/// The pane the window grows for, if any.
enum MiniPane { lyrics, queue }

/// The pane the window is grown for, or null for the bar alone.
///
/// A window-level fact, not a widget's: it decides the window's height and its
/// resize limits, and it comes back to the bar when the window hides. The view
/// and [hideMiniPlayer] both read and write this one value.
final miniPlayerPane = ValueNotifier<MiniPane?>(null);

/// Puts the window back to bar size and hides it.
///
/// Shrinking before hiding is what makes reopening instant *and* correct: the
/// engine keeps its last surface size, so a window hidden with the queue open
/// would come back as a queue over a blank bar.
Future<void> hideMiniPlayer() async {
  miniPlayerPane.value = null;
  final window = miniPlayerWindow();
  if (window == null) return;
  _applyBounds(window, expanded: false);
  window.setSize(
    Size(window.size.width, kMiniPlayerBarHeight).toNative(),
    false,
  );
  window.hide();
}

/// Applies the resize limits for the current shape.
///
/// Both shapes can be dragged taller than their opening height — a user who
/// wants more artwork, or more of the queue, gets it. Only the floor differs:
/// an open pane needs room to be a pane.
void _applyBounds(Window window, {required bool expanded}) {
  window
    ..minimumSize = Size(
      kMiniPlayerMinWidth,
      expanded
          ? kMiniPlayerBarHeight + kMiniPlayerPaneMinHeight
          : kMiniPlayerBarHeight,
    ).toNative()
    // The bar is a fixed height: with no pane there is nothing a taller
    // window would show, so the drag cannot make one. Panes get the range.
    ..maximumSize = Size(
      kMiniPlayerMaxWidth,
      expanded ? kMiniPlayerMaxHeight : kMiniPlayerBarHeight,
    ).toNative();
}

/// The window's single screen: Apple Music's mini player — the artwork fills
/// the window, the track info, scrubber and transport float over it.
///
/// With a pane open the artwork shrinks to a small sleeve in the header and
/// the pane takes the rest, still over the blurred art field.
class MiniPlayerHome extends ConsumerStatefulWidget {
  const MiniPlayerHome({super.key});

  @override
  ConsumerState<MiniPlayerHome> createState() => _MiniPlayerHomeState();
}

class _MiniPlayerHomeState extends ConsumerState<MiniPlayerHome> {
  ListenerId? _closeListener;

  @override
  void initState() {
    super.initState();
    // The window's controls close it. Closing hides rather than destroys:
    // the engine stays alive and reopening is instant.
    final window = miniPlayerWindow();
    if (window != null) {
      _closeListener = window.addListener((event) async {
        if (event is WindowCloseRequestedEvent) {
          event.request.cancel();
          await hideMiniPlayer();
        }
      });
    }
    // The mirror subscribes to the host here rather than in `main()`: the
    // notifier only exists once the container does, and this is the earliest
    // point the window is about to draw anyway.
    final controller = ref.read(playbackProvider.notifier);
    if (controller is MiniPlayback) {
      controller.attach(ref.read(miniPlayerLinkProvider));
    }
  }

  @override
  void dispose() {
    final listenerId = _closeListener;
    if (listenerId != null) {
      miniPlayerWindow()?.removeListener(listenerId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(playbackProvider.select((state) => state.current));

    final window = miniPlayerWindow();
    return DesktopWindowFrame(
      isDesktopPlatform: true,
      // This engine's own window, not the app's: `getCurrent` answers the
      // main window from inside a secondary engine.
      window: window,
      // The artwork runs behind the drag band and the traffic lights; the
      // band stays a hit area, and the content starts below it.
      overlayTitleBar: true,
      // Closing hides this window, keeping the engine alive: the event
      // listener in `initState` cancels the real close, so this button is
      // the same path.
      onClose: () => unawaited(hideMiniPlayer()),
      child: song == null
          ? Center(
              child: Text(
                'playerNothingPlaying'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : MiniPlayerView(song: song),
    );
  }
}

class MiniPlayerView extends ConsumerStatefulWidget {
  final LibrarySong song;

  const MiniPlayerView({super.key, required this.song});

  @override
  ConsumerState<MiniPlayerView> createState() => _MiniPlayerViewState();
}

class _MiniPlayerViewState extends ConsumerState<MiniPlayerView> {
  /// Whether the footer controls are showing.
  ///
  /// With a pane open the footer floats over the lyrics or the queue, so it
  /// gets out of the way: it appears on hover or on a transport key, and
  /// fades back out once the pointer has been still for a moment. The bar
  /// shape always shows it — there is nothing else in that window.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  void _revealControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted || miniPlayerPane.value == null) return;
      setState(() => _controlsVisible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  /// Resizes the window for the shape that is about to be shown.
  ///
  /// A height the user dragged to is theirs and survives a pane opening or
  /// closing; only a window that is too short for what it must now show is
  /// grown, and only a bar taller than the bar ceiling is pulled back to it.
  void _fitWindow(MiniPane? pane) {
    final window = miniPlayerWindow();
    if (window == null) return;
    _applyBounds(window, expanded: pane != null);

    final floor = pane == null
        ? kMiniPlayerBarHeight
        : kMiniPlayerBarHeight + kMiniPlayerPaneMinHeight;
    final ceiling = pane == null ? kMiniPlayerBarHeight : kMiniPlayerMaxHeight;
    final height = window.size.height.clamp(floor, ceiling).toDouble();
    if (height == window.size.height && pane != null) return;
    window.setSize(
      Size(window.size.width, height).toNative(),
      // Animated on macOS; other platforms apply it at once.
      true,
    );
  }

  void _pick(MiniPane next) {
    final pane = miniPlayerPane.value == next ? null : next;
    miniPlayerPane.value = pane;
    _fitWindow(pane);
    if (pane == null) {
      // Back to the bar: the footer is the only content and stays put.
      _hideTimer?.cancel();
      _hideTimer = null;
      if (!_controlsVisible) setState(() => _controlsVisible = true);
      return;
    }
    // A pane opens with its controls showing, then they get out of the way.
    _revealControls();
  }

  @override
  Widget build(BuildContext context) {
    // The live track, not the one this widget was built with: the mirror
    // state changes underneath the window, and the whole view follows it.
    final song = ref.watch(playbackProvider.select((state) => state.current));
    final shown = song ?? widget.song;

    return ValueListenableBuilder<MiniPane?>(
      valueListenable: miniPlayerPane,
      builder: (context, pane, _) {
        // A window that opens with its pane already showing has never been
        // hovered, so nothing has armed the hide timer: arm it here.
        if (pane != null && _hideTimer == null && _controlsVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && miniPlayerPane.value != null) _revealControls();
          });
        }
        return MouseRegion(
          // Any pointer movement over the window brings the footer back; a
          // pane is the only surface that hides it.
          onHover: pane != null ? (_) => _revealControls() : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The cover fills the window and everything floats over it, the
              // way Apple Music's mini player does. A pane opens over the same
              // field, blurred harder so the pane's text still reads.
              _ArtworkField(song: shown, paneOpen: pane != null),
              // Header, pane, footer. The pane takes the space that is left
              // instead of being positioned over the furniture below it — a
              // positioned pane drew its first lyric line behind the scrubber.
              Column(
                children: [
                  // The frame's title band is an overlay, so the artwork can
                  // run behind the traffic lights while the header still
                  // starts below them.
                  const SizedBox(height: DesktopWindowFrame.titleBarHeight),
                  _Header(
                    song: shown,
                    pane: pane,
                    onPick: _pick,
                    compact: pane != null,
                  ),
                  if (pane != null)
                    Expanded(
                      child: switch (pane) {
                        MiniPane.lyrics => const SongLyricsPane(
                          padding: EdgeInsets.symmetric(
                            horizontal: SolSpace.xl,
                          ),
                          fade: true,
                        ),
                        MiniPane.queue => const QueuePanel(),
                      },
                    ),
                  // No Spacer: the bar is exactly the height its stack is,
                  // and a bar-shaped window that is taller than the stack
                  // would have nothing to put in the difference.
                  if (pane == null) const SizedBox(height: SolSpace.md),
                  // A pane's footer floats over its content, so it slides
                  // away when idle; the bar shape keeps it in place.
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    offset: pane != null && !_controlsVisible
                        ? const Offset(0, 1)
                        : Offset.zero,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: pane != null && !_controlsVisible ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: pane != null && !_controlsVisible,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!shown.isRadio) const _Scrubber(),
                            const _TransportRow(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The blurred cover that carries the whole window's colour.
///
/// Blurred past recognition like the main player page's backdrop, so detail
/// would be decoded and thrown away — a thumbnail is enough. Over it a scrim
/// keeps text legible no matter how bright the art is.
class _ArtworkField extends ConsumerWidget {
  final LibrarySong song;
  final bool paneOpen;

  const _ArtworkField({required this.song, required this.paneOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surface;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: paneOpen ? 90 : 60,
                  sigmaY: paneOpen ? 90 : 60,
                ),
                child: Opacity(
                  opacity: paneOpen ? 0.55 : 0.7,
                  child: LibraryArtwork(
                    sourceId: song.sourceId,
                    artId: song.playing.artId,
                    radius: 0,
                    pixelSize: 256,
                    fallbackIcon: Symbols.music_note_rounded,
                  ),
                ),
              ),
            ),
          ),
          // The scrim: without it, a bright cover washes the labels out.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [surface.withValues(alpha: 0.15), surface.withValues(alpha: 0.55)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The window's top strip: artwork and track title, plus the two pane toggles.
///
/// Drag anywhere that is not a button — it is the only chrome the frameless
/// surface has that is not a control. When a pane is open it shrinks to a
/// small sleeve so the pane gets the height.
class _Header extends StatelessWidget {
  final LibrarySong song;
  final MiniPane? pane;
  final ValueChanged<MiniPane> onPick;
  final bool compact;

  const _Header({
    required this.song,
    required this.pane,
    required this.onPick,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = compact ? 36.0 : 64.0;

    Widget body = Row(
      children: [
        LibraryArtwork(
          sourceId: song.sourceId,
          artId: song.playing.artId,
          size: art,
          radius: SolRadius.sm,
          pixelSize: 128,
          fallbackIcon: Symbols.music_note_rounded,
        ),
        SizedBox(width: compact ? SolSpace.sm : SolSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                song.playing.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                song.playing.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _BarButton(
          tooltip: pane == MiniPane.queue
              ? 'playerQueueHide'.tr()
              : 'playerQueueShow'.tr(),
          selected: pane == MiniPane.queue,
          icon: Symbols.queue_music_rounded,
          onPressed: () => onPick(MiniPane.queue),
        ),
        _BarButton(
          tooltip: pane == MiniPane.lyrics
              ? 'playerLyricsHide'.tr()
              : 'playerLyricsShow'.tr(),
          selected: pane == MiniPane.lyrics,
          icon: Symbols.lyrics_rounded,
          onPressed: () => onPick(MiniPane.lyrics),
        ),
      ],
    );

    // Both shapes keep the same side margin; the compact stripe used to go
    // full-bleed and read as a different control set than the bar's.
    body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.lg),
      child: body,
    );

    return DragToMoveArea(child: SizedBox(height: 72, child: body));
  }
}

/// A light scrubber over the artwork: hairline track, small thumb.
class _Scrubber extends ConsumerWidget {
  const _Scrubber();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(
      playbackProvider.select(
        (state) => (state.position, state.duration, state.current?.duration),
      ),
    );
    final (position, reported, songLength) = state;
    final duration = reported == Duration.zero
        ? songLength ?? Duration.zero
        : reported;
    final maxMs = duration.inMilliseconds.toDouble();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
            ),
            child: Slider(
              value: position.inMilliseconds
                  .clamp(0, maxMs <= 0 ? 1 : maxMs)
                  .toDouble(),
              max: maxMs <= 0 ? 1 : maxMs,
              onChanged: maxMs <= 0
                  ? null
                  : (value) => ref
                        .read(playbackProvider.notifier)
                        .seek(Duration(milliseconds: value.round())),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(position), style: labelStyle),
              Text(formatDuration(duration), style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }
}

/// Previous, play, next, flanked by the two mode toggles.
///
/// Own row instead of the shared [Transport]: the shared one sits on plain
/// surfaces with filled accents; here every button but play is a ghost over
/// the artwork, the way Apple Music's overlay reads.
class _TransportRow extends ConsumerWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(playbackProvider.notifier);
    final state = ref.watch(
      playbackProvider.select(
        (state) => (state.playing, state.shuffle, state.repeatMode),
      ),
    );
    final (playing, shuffle, repeat) = state;
    final ghostColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.lg,
        0,
        SolSpace.lg,
        SolSpace.md,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'playerShuffle'.tr(),
            isSelected: shuffle,
            onPressed: () => controller.setShuffle(!shuffle),
            color: ghostColor,
            iconSize: 20,
            icon: const Icon(Symbols.shuffle_rounded),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'playerPrevious'.tr(),
            onPressed: controller.previous,
            color: theme.colorScheme.onSurface,
            iconSize: 28,
            icon: const Icon(Symbols.skip_previous_rounded),
          ),
          const Spacer(),
          IconButton.filled(
            tooltip: playing ? 'playerPause'.tr() : 'playerPlay'.tr(),
            onPressed: controller.togglePlayPause,
            iconSize: 26,
            padding: const EdgeInsets.all(10),
            icon: PlayPauseIcon(playing: playing, size: 26),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'playerNext'.tr(),
            onPressed: controller.next,
            color: theme.colorScheme.onSurface,
            iconSize: 28,
            icon: const Icon(Symbols.skip_next_rounded),
          ),
          const Spacer(),
          IconButton(
            tooltip: repeat == PlaybackRepeatMode.single
                ? 'playerRepeatSong'.tr()
                : 'playerRepeat'.tr(),
            isSelected: repeat != PlaybackRepeatMode.off,
            onPressed: controller.cycleRepeatMode,
            color: ghostColor,
            iconSize: 20,
            icon: const Icon(Symbols.repeat_rounded),
          ),
        ],
      ),
    );
  }
}

/// One control in the header's trailing row.
///
/// Smaller than a page's icon button on purpose: two of them plus the sleeve
/// and the title have to fit 340 pixels, and a 48px tap box each would leave
/// the title nothing.
class _BarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _BarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      iconSize: 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      icon: Icon(icon),
    );
  }
}
