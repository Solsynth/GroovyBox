import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/desktop/mini_player/mini_playback.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
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
  final window = WindowManager.instance.getCurrent();
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
    ..maximumSize = const Size(
      kMiniPlayerMaxWidth,
      kMiniPlayerMaxHeight,
    ).toNative();
}

/// The window's single screen: a bar of transport, with the queue or the
/// lyrics growing it in place.
///
/// The bar is deliberately not the player page at small scale — the full page
/// already exists one shortcut away. What is left is the sleeve, the title and
/// the transport: the three things a floating window is for.
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
    // The mini window keeps a real title bar, so its close button is the
    // window's own. Closing hides rather than destroys: the engine stays
    // alive and reopening is instant.
    final window = WindowManager.instance.getCurrent();
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
      WindowManager.instance.getCurrent()?.removeListener(listenerId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(playbackProvider.select((state) => state.current));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: song == null
          ? Center(
              child: Text(
                'playerNothingPlaying'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
  /// Grows or shrinks the window to fit the pane that is on show.
  ///
  /// Only the height changes, and only to the shape's opening height: a user
  /// who dragged the window taller keeps their height when a pane opens — the
  /// pane takes the room that is already there — and only a window too short
  /// for the pane is grown.
  void _fitWindow(MiniPane? pane) {
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    _applyBounds(window, expanded: pane != null);

    final target =
        kMiniPlayerBarHeight + (pane == null ? 0 : kMiniPlayerPaneHeight);
    final height = pane == null ? target : math.max(window.size.height, target);
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
  }

  @override
  Widget build(BuildContext context) {
    // The live track, not the one this widget was built with: the mirror
    // state changes underneath the window, and the whole view follows it.
    final song = ref.watch(playbackProvider.select((state) => state.current));
    final shown = song ?? widget.song;

    return ValueListenableBuilder<MiniPane?>(
      valueListenable: miniPlayerPane,
      builder: (context, pane, _) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          SolSpace.sm,
          SolSpace.sm,
          SolSpace.sm,
          SolSpace.sm,
        ),
        child: Column(
          children: [
            if (pane == null)
              // The bar is the only content, so it takes whatever height the
              // window has and the artwork grows into it.
              Expanded(
                child: _Bar(
                  song: shown,
                  pane: pane,
                  onPick: _pick,
                  expanded: true,
                ),
              )
            else ...[
              _Bar(song: shown, pane: pane, onPick: _pick, expanded: false),
              Expanded(
                child: switch (pane) {
                  MiniPane.lyrics => SongLyricsPane(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.sm,
                    ),
                    fade: true,
                  ),
                  MiniPane.queue => const QueuePanel(),
                },
              ),
            ],
            if (!shown.isRadio) const Scrubber(),
            const Transport(),
          ],
        ),
      ),
    );
  }
}

/// The bar: what is playing, and the two views that grow the window.
///
/// With no pane open the bar is the whole window and its artwork takes the
/// room: drag the window taller and the sleeve becomes a cover. With a pane
/// open the bar collapses to a header stripe so the pane gets the height.
class _Bar extends StatelessWidget {
  final LibrarySong song;
  final MiniPane? pane;
  final ValueChanged<MiniPane> onPick;

  /// Whether the bar fills the window's height instead of sitting as a stripe
  /// above a pane.
  final bool expanded;

  const _Bar({
    required this.song,
    required this.pane,
    required this.onPick,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = DragToMoveArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The sleeve grows with the window, between the size a stripe needs
          // and a size that still leaves the title room beside it.
          final art = expanded
              ? math.min(
                  math.min(constraints.maxWidth * 0.45, 220.0),
                  math.max(constraints.maxHeight - SolSpace.sm, 24.0),
                )
              : 36.0;

          return Row(
            children: [
              LibraryArtwork(
                sourceId: song.sourceId,
                artId: song.playing.artId,
                size: art,
                radius: art >= 64 ? SolRadius.md : SolRadius.sm,
                pixelSize: art >= 64 ? 512 : 128,
                fallbackIcon: Symbols.music_note_rounded,
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.playing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
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
              const SizedBox(width: SolSpace.xs),
            ],
          );
        },
      ),
    );

    if (expanded) return content;

    return SizedBox(height: 44, child: content);
  }
}

/// One control in the bar's trailing row.
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
