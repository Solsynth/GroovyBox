import 'dart:async';
import 'dart:io';

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
import 'package:window_manager/legacy.dart';

/// Room the macOS window buttons take at the leading edge, plus the gap that
/// keeps the sleeve from sliding under them.
const double _kTrafficLights = 72;

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

/// The pane the window is grown for, if any.
///
/// The pane is a window-level fact, not a widget's: it decides the window's
/// height, and it comes back to the bar when the window hides. The view and
/// [hideMiniPlayer] both read and write this one value.
final miniPlayerPane = ValueNotifier<MiniPane?>(null);

/// Puts the window back to bar size and hides it.
///
/// Shrinking before hiding is what makes reopening instant *and* correct: the
/// engine keeps its last surface size, so a window hidden with the queue open
/// would come back as a queue over a blank bar. The width is remembered, since
/// that one is the user's.
Future<void> hideMiniPlayer() async {
  miniPlayerPane.value = null;
  try {
    final size = await windowManager.getSize();
    await windowManager.setSize(Size(size.width, kMiniPlayerBarHeight));
  } catch (_) {
    // A failed resize costs the next open a moment of the old size.
  }
  await windowManager.hide();
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
  late final _CloseInterceptor _interceptor;

  @override
  void initState() {
    super.initState();
    _interceptor = _CloseInterceptor();
    windowManager.addListener(_interceptor);
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
    windowManager.removeListener(_interceptor);
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

/// Closes by hiding, not destroying: the engine stays alive, so reopening is
/// instant, and `setPreventClose(true)` makes this the only close path.
class _CloseInterceptor with WindowListener {
  bool _closing = false;

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    await hideMiniPlayer();
    _closing = false;
  }
}

/// The pane the window grows for, if any.
enum MiniPane { lyrics, queue }

class MiniPlayerView extends ConsumerStatefulWidget {
  final LibrarySong song;

  const MiniPlayerView({super.key, required this.song});

  @override
  ConsumerState<MiniPlayerView> createState() => _MiniPlayerViewState();
}

class _MiniPlayerViewState extends ConsumerState<MiniPlayerView> {
  /// Grows or shrinks the window to fit the pane that is on show.
  ///
  /// The height is the only thing that changes; the width is the user's.
  Future<void> _fitWindow(MiniPane? pane) async {
    try {
      final size = await windowManager.getSize();
      await windowManager.setSize(
        Size(
          size.width,
          kMiniPlayerBarHeight + (pane == null ? 0 : kMiniPlayerPaneHeight),
        ),
      );
    } catch (_) {
      // A window that refused the resize still shows the right content; it
      // is just too short for it.
    }
  }

  void _pick(MiniPane next) {
    final pane = miniPlayerPane.value == next ? null : next;
    miniPlayerPane.value = pane;
    unawaited(_fitWindow(pane));
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
        // No bar of ours, and little padding: the traffic lights float over
        // the top-left corner, and a frame around a 340px window would eat
        // the transport.
        minimum: const EdgeInsets.all(SolSpace.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Bar(song: shown, pane: pane, onPick: _pick),
            if (pane == null)
              const SizedBox(height: SolSpace.xs)
            else
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
            if (!shown.isRadio) const Scrubber(),
            const Transport(),
          ],
        ),
      ),
    );
  }
}

/// The bar: what is playing, and everything you can do to it from a corner of
/// the screen.
class _Bar extends StatelessWidget {
  final LibrarySong song;
  final MiniPane? pane;
  final ValueChanged<MiniPane> onPick;

  const _Bar({required this.song, required this.pane, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: DragToMoveArea(
        child: Row(
          children: [
            SizedBox(
              width: Platform.isMacOS ? _kTrafficLights : 0,
            ),
            LibraryArtwork(
              sourceId: song.sourceId,
              artId: song.playing.artId,
              size: 40,
              radius: SolRadius.sm,
              pixelSize: 128,
              fallbackIcon: Symbols.music_note_rounded,
            ),
            const SizedBox(width: SolSpace.sm),
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
            _BarButton(
              tooltip: 'playerMiniClose'.tr(),
              icon: Symbols.close_rounded,
              onPressed: () => unawaited(hideMiniPlayer()),
            ),
          ],
        ),
      ),
    );
  }
}

/// One control in the bar's trailing row.
///
/// Smaller than a page's icon button on purpose: three of them plus the sleeve
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
