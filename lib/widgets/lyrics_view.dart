import 'dart:async';
import 'dart:math' as math;

import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Timed lyrics, drawn the way Apple Music draws them.
///
/// One scrolling column, left aligned, with the line being sung in full tone
/// and weight and everything else dimmed to a trace. The column follows the
/// transport and keeps the current line around the upper third of the box, so
/// the eye never hunts; the upcoming line enters from below.
///
/// The list is a `ListView` with per-line keys rather than a fixed item extent:
/// lyric lines wrap to two or three rows on a narrow pane, and scrolling to a
/// guessed offset lands between lines. `ensureVisible` on the line's own
/// context is what keeps a karaoke scroll honest.
///
/// The widget owns no state about the song. Give it lyrics and a position; tap
/// is offered only when [onSeek] is set.
class LyricsView extends StatefulWidget {
  final Lyrics lyrics;
  final Duration position;
  final ValueChanged<Duration>? onSeek;

  /// Inset inside the scrolling plane.
  final EdgeInsets padding;

  /// Whether to fade the column's edges into the surface behind it.
  final bool fade;

  const LyricsView({
    super.key,
    required this.lyrics,
    required this.position,
    this.onSeek,
    this.padding = const EdgeInsets.symmetric(horizontal: SolSpace.xl),
    this.fade = true,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _controller = ScrollController();
  final _keys = <int, GlobalKey>{};

  /// The line the scroll is parked on. Kept separately from the position so a
  /// rebuild caused by any other pixel change does not re-run the animation.
  int _shownLine = -2;

  /// Set while the user is dragging the column. The transport keeps playing,
  /// but it must not yank the text out from under a finger that is reading
  /// ahead; follow resumes a few seconds after the gesture ends.
  bool _userScrolling = false;
  Timer? _resumeTimer;

  int get _index => widget.lyrics.synced
      ? lyricIndexAt(widget.lyrics.lines, widget.position)
      : -1;

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _shownLine = -2;
      _keys.clear();
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _follow(int index) {
    if (index < 0 || index == _shownLine) return;
    _shownLine = index;
    // After the frame in which the line is laid out: its context does not
    // exist yet during this build, and scrolling during layout is refused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _keys[index]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.36,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    final current = _index;
    if (lyrics.synced && !_userScrolling) _follow(current);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Enough air above and below that the first and last line can both sit
        // where the middle ones do. Unsynced text does not need the runway: it
        // only scrolls by hand, and empty space at the top is just empty.
        final margin = lyrics.synced ? constraints.maxHeight * 0.34 : 0.0;
        final column = SingleChildScrollView(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          padding: widget.padding.copyWith(
            top: math.max(widget.padding.top, margin),
            bottom: math.max(widget.padding.bottom, margin),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < lyrics.lines.length; index++)
                _LyricLine(
                  key: _keys.putIfAbsent(index, GlobalKey.new),
                  line: lyrics.lines[index],
                  current: lyrics.synced && index == current,
                  onTap: widget.onSeek == null
                      ? null
                      : () => widget.onSeek!(
                          lyrics.synced
                              ? lyrics.lines[index].at
                              : Duration.zero,
                        ),
                ),
            ],
          ),
        );

        // The scrollbar is a response to a gesture, not furniture: it fades in
        // while the column is being dragged and is gone otherwise. The platform
        // scrollbar is switched off underneath so the column never shows two.
        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: RawScrollbar(
              controller: _controller,
              thumbVisibility: false,
              thickness: 3,
              radius: const Radius.circular(SolRadius.pill),
              fadeDuration: const Duration(milliseconds: 400),
              child: widget.fade ? _faded(column) : column,
            ),
          ),
        );
      },
    );
  }

  /// Suspends auto-follow while a drag is in flight, then hands control back
  /// to the transport once the user has stopped looking around.
  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userScrolling = true;
    } else if (notification is ScrollEndNotification) {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        // Re-arm the follow: the next build parks the current line again.
        setState(() {
          _userScrolling = false;
          _shownLine = -2;
        });
      });
    }
    return false;
  }

  Widget _faded(Widget child) => ShaderMask(
    // Fades the column into the panel instead of cutting it off with a hard
    // edge; a scrolled list that ends flush reads as broken.
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black,
        Colors.black,
        Colors.transparent,
      ],
      stops: [0, 0.12, 0.88, 1],
    ).createShader(rect),
    blendMode: BlendMode.dstIn,
    child: child,
  );
}

/// One line of the column.
///
/// Colour and weight carry the state, not a box or a highlight behind the
/// text. A romanization and a translation hang below the words they annotate,
/// smaller and quieter, the way Apple Music shows a translated lyric.
class _LyricLine extends StatelessWidget {
  final LyricLine line;
  final bool current;
  final VoidCallback? onTap;

  const _LyricLine({
    super.key,
    required this.line,
    required this.current,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Blank lines are stanza breaks: they need the height, not a widget.
    if (line.text.trim().isEmpty) return const SizedBox(height: SolSpace.lg);

    final tone = current
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.34);

    final words = theme.textTheme.titleLarge?.copyWith(
      fontSize: 22,
      height: 1.28,
      fontWeight: current ? FontWeight.w800 : FontWeight.w700,
      letterSpacing: 0.1,
      color: tone,
    );
    final reading = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13.5,
      height: 1.35,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: colorScheme.onSurface.withValues(alpha: current ? 0.62 : 0.24),
    );
    final translation = theme.textTheme.bodySmall?.copyWith(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface.withValues(alpha: current ? 0.72 : 0.26),
    );

    return Semantics(
      selected: current,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SolRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SolSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                style: words!,
                child: Text(line.text),
              ),
              if (line.pronunciation != null) ...[
                const SizedBox(height: SolSpace.xxs),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  style: reading!,
                  child: Text(line.pronunciation!),
                ),
              ],
              if (line.translation != null) ...[
                const SizedBox(height: SolSpace.xxs),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  style: translation!,
                  child: Text(line.translation!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The lyrics of the song the transport is on, with the live line countdown
/// and the requests already answered.
///
/// Reading the transport here rather than taking a position argument keeps the
/// rebuild scoped to the pane: the dock's own row does not repaint because a
/// lyric line changed.
class SongLyricsPane extends ConsumerWidget {
  /// Height the pane fills, or null to take the space its parent gives it.
  /// The dock sizes the sheet itself; the player page gives it the column.
  final double? height;
  final EdgeInsets padding;

  /// Whether to fade the column's edges. The dock's sheet floats over glass
  /// and wants the fade; the player page's column ends in the page's own
  /// inset, where a fade would erase the last line for no reason.
  final bool fade;

  const SongLyricsPane({
    super.key,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: SolSpace.xl),
    this.fade = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playbackProvider.select((state) => state.current));
    final position = ref.watch(
      playbackProvider.select((state) => state.position),
    );
    final theme = Theme.of(context);

    Widget status(
      IconData? icon,
      String title, {
      String? detail,
      bool retry = false,
    }) {
      return SizedBox(
        height: height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SolSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == null)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    icon,
                    size: 26,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.65,
                    ),
                  ),
                const SizedBox(height: SolSpace.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: SolSpace.xxs),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
                if (retry) ...[
                  const SizedBox(height: SolSpace.md),
                  TextButton.icon(
                    onPressed: () => ref
                        .read(lyricsMaintenanceProvider.notifier)
                        .refresh(LyricsRequest.of(song!)),
                    icon: const Icon(Symbols.refresh_rounded, size: 18),
                    label: const Text('Ask again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (song == null) {
      return status(Symbols.lyrics_rounded, 'Nothing is playing');
    }

    final lyrics = ref.watch(songLyricsProvider(LyricsRequest.of(song)));
    final controller = ref.read(playbackProvider.notifier);

    return lyrics.when(
      skipLoadingOnRefresh: true,
      loading: () => status(null, 'Loading lyrics'),
      error: (_, _) => status(
        Symbols.cloud_off_rounded,
        'Lyrics unavailable',
        detail: 'Neither the library nor LRCLIB answered.',
        retry: true,
      ),
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return status(
            Symbols.lyrics_rounded,
            'No lyrics for this track',
            detail: 'Neither the library nor LRCLIB has words for it.',
            retry: true,
          );
        }
        return SizedBox(
          height: height,
          child: LyricsView(
            lyrics: lyrics,
            position: position,
            padding: padding,
            fade: fade,
            onSeek: lyrics.synced ? controller.seek : null,
          ),
        );
      },
    );
  }
}
