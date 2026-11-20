import 'dart:async';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/desktop/mini_player/mini_actions.dart';
import 'package:groovy_box/desktop/mini_player/mini_playback.dart';
import 'package:groovy_box/desktop/mini_player/mini_track_menu.dart';
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
                    // The pane runs all the way down: the footer floats over
                    // it and slides away, so the rows behind it are still a
                    // full pane's worth of content rather than a column with
                    // a reserved strip cut off the bottom.
                    Expanded(
                      child: switch (pane) {
                        // The bottom inset clears the whole floating band,
                        // scrim included: a row that stops at the controls but
                        // runs under the fade still ends in the gradient.
                        MiniPane.lyrics => const SongLyricsPane(
                          padding: EdgeInsets.fromLTRB(
                            SolSpace.xl,
                            0,
                            SolSpace.xl,
                            kMiniPlayerFooterHeight +
                                kMiniPlayerFooterFadeHeight,
                          ),
                          fade: true,
                        ),
                        MiniPane.queue => const QueuePanel(
                          bottomInset:
                              kMiniPlayerFooterHeight +
                              kMiniPlayerFooterFadeHeight,
                        ),
                      },
                    )
                  else
                    // The bar shape lays the footer inline: it is the whole
                    // lower half of that window, not an overlay.
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A station has no length to scrub: its rows report
                        // track changes, not a clock.
                        if (!shown.isRadio) const _Scrubber(),
                        const _TransportRow(),
                      ],
                    ),
                ],
              ),
              // A pane's footer is an overlay: it fades and slides away when
              // idle instead of holding a strip of the pane's height.
              //
              // Over a pane it needs a scrim: lyrics and queue rows run under
              // it, and transparent buttons over live text are unreadable
              // whichever way the two overlap. The scrim is a gradient — clear
              // at the top, surface at the controls — so the pane's content
              // fades out beneath it instead of meeting a hard edge.
              if (pane != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    offset: _controlsVisible ? Offset.zero : const Offset(0, 1),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _controlsVisible ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: _FooterScrim(
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
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The gradient behind a pane's floating footer.
///
/// Clear where the pane's rows still read, opaque [ColorScheme.surface] under
/// the scrubber and the transport, so the controls sit on a surface that
/// changes with the theme while the content above runs out through the fade
/// instead of being clipped at the controls' edge.
class _FooterScrim extends StatelessWidget {
  final Widget child;

  const _FooterScrim({required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    // A fixed strip, not a fraction of the footer: the fade has to end exactly
    // where the controls begin, whatever the footer's height is (a station
    // drops the scrubber), so every control sits on solid surface and only the
    // pane's last words run out through a gradient instead of a seam.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: kMiniPlayerFooterFadeHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [surface.withValues(alpha: 0), surface],
              ),
            ),
          ),
        ),
        ColoredBox(color: surface, child: child),
      ],
    );
  }
}

/// The blurred cover that carries the whole window's colour, over the window's
/// own gradient.
///
/// Blurred past recognition like the main player page's backdrop, so detail
/// would be decoded and thrown away — a thumbnail is enough. The gradient
/// underneath is what the window shows when there is no cover at all, and over
/// a cover it keeps the top and the bottom from reading as one flat tint; the
/// scrim on top keeps text legible whatever the art's brightness.
class _ArtworkField extends ConsumerWidget {
  final LibrarySong song;
  final bool paneOpen;

  const _ArtworkField({required this.song, required this.paneOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // The window's base is a vertical gradient whether or not there is a
    // cover: with no art, a flat surface read as a dead panel, and the very
    // scrim that makes a blurry cover quiet also hid it. The gradient is drawn
    // first, so the cover tints it rather than replacing it.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surfaceContainerHigh,
            scheme.surface,
            scheme.surfaceContainerLowest,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
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
          // The scrim: without it, a bright cover washes the labels out. It
          // fades in from nothing at the top rather than sitting at a flat
          // tint, so the top half keeps the cover's colour and the controls
          // below land on the surface.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface.withValues(alpha: 0),
                    scheme.surface.withValues(alpha: 0.45),
                    scheme.surface.withValues(alpha: 0.8),
                  ],
                  stops: const [0, 0.5, 1],
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
    final art = compact ? 36.0 : 56.0;

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

    // The window is named explicitly: inside a secondary engine `getCurrent`
    // answers the *main* window, so a drag or a double-click from here would
    // otherwise act on the app's window instead of this one.
    return DragToMoveArea(
      window: miniPlayerWindow(),
      child: SizedBox(height: compact ? 56 : 64, child: body),
    );
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

/// Previous, play, next, flanked by the favourite and the track menu.
///
/// Own row instead of the shared [Transport]: the shared one sits on plain
/// surfaces with filled accents; here every button but play is a ghost over
/// the artwork, the way Apple Music's overlay reads.
///
/// The flanks are the track's own actions, not the queue's. Shuffle and
/// repeat describe the list, and they live on the queue pane's header where
/// the list is; here the two things a mini player can still do about the track
/// itself — remember it, and put it somewhere — are one tap away.
class _TransportRow extends ConsumerWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(playbackProvider.notifier);
    final song = ref.watch(playbackProvider.select((state) => state.current));
    final playing = ref.watch(
      playbackProvider.select((state) => state.playing),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.lg,
        0,
        SolSpace.lg,
        SolSpace.sm,
      ),
      child: Row(
        children: [
          // The flanks are the track's own actions. A station is a standing
          // request rather than a track, so neither one is offered there and
          // the slot keeps its width to stay centred either way.
          if (song == null || song.isRadio)
            const SizedBox(width: _kFlankWidth)
          else
            _FavouriteButton(song: song),
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
          // The flanks are the track's own actions. Shuffle and repeat are
          // statements about the queue, and they live on the queue pane's
          // header; what a mini player can say about the track itself is
          // here. A station is a standing request rather than a track, so
          // neither control is offered and the slot keeps its width.
          const Spacer(),
          if (song == null || song.isRadio)
            const SizedBox(width: _kFlankWidth)
          else
            MiniTrackMenuButton(song: song),
        ],
      ),
    );
  }
}

/// The width of a transport flank: one icon button at its compact size.
///
/// A station draws neither the heart nor the menu, and the empty slot keeps
/// this width so the three transport buttons stay where they were.
const double _kFlankWidth = 40;

/// The heart, lit from the host's record and written through the link.
///
/// No local flag: the host answers, and its write is the same one the player
/// page's bar performs. The two surfaces never disagree, because neither one
/// keeps its own copy.
class _FavouriteButton extends ConsumerWidget {
  final LibrarySong song;

  const _FavouriteButton({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final track = TrackLookup(song);
    // A host that has not answered yet reads as "not a favourite": the
    // placeholder is the honest value while there is nothing to say.
    final favourited = ref.watch(miniFavouriteProvider(track)).value ?? false;
    return IconButton(
      tooltip: favourited ? 'playerFavourited'.tr() : 'playerFavourite'.tr(),
      isSelected: favourited,
      onPressed: () => _toggle(context, ref, song),
      color: theme.colorScheme.onSurfaceVariant,
      iconSize: 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(
        width: _kFlankWidth,
        height: _kFlankWidth,
      ),
      icon: Icon(
        favourited ? Symbols.favorite_rounded : Symbols.favorite_border_rounded,
        fill: favourited ? 1 : null,
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    LibrarySong song,
  ) async {
    final answer = await ref.read(miniActionsProvider).toggleFavourite(song);
    // The host's providers moved under it; asking again is what redraws this
    // heart — and the player page's — with the value now on record.
    ref.invalidate(miniFavouriteProvider(TrackLookup(song)));
    if (answer == null || !context.mounted) return;
    final error = answer.error;
    if (error != null) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(error)));
    }
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
