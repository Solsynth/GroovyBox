import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:material_ui/material_ui.dart';

/// Per-line horizontal feathered karaoke sweep across multi-line wrapped text.
///
/// Inactive lines render as plain static [Text] to avoid `saveLayer` overhead.
/// Active lines paint the unsung base text and then mask a bright sung layer
/// line-by-line via [TextPainter.computeLineMetrics] and [BlendMode.dstIn], so
/// wrapped lines sweep left-to-right at uniform reading speed with zero layout
/// changes.
class KaraokeSweepText extends StatelessWidget {
  const KaraokeSweepText({
    super.key,
    required this.text,
    required this.style,
    required this.isActive,
    required this.progress,
    this.unsungAlpha = 0.34,
    this.sungAlpha = 0.96,
    this.featherWidth = 24.0,
  });

  final String text;
  final TextStyle style;
  final bool isActive;
  final double progress;
  final double unsungAlpha;
  final double sungAlpha;
  final double featherWidth;

  @override
  Widget build(BuildContext context) {
    final baseColor = style.color ?? Theme.of(context).colorScheme.onSurface;
    // Inactive lines render as plain static Text (no saveLayer overhead).
    if (!isActive) {
      return Text(
        text,
        style: style.copyWith(color: baseColor.withValues(alpha: unsungAlpha)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _KaraokeLinePainter(
            text: text,
            style: style,
            progress: progress.clamp(0.0, 1.0),
            maxWidth: constraints.maxWidth,
            unsungColor: baseColor.withValues(alpha: unsungAlpha),
            sungColor: baseColor.withValues(alpha: sungAlpha),
            featherWidth: featherWidth,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          ),
          // Invisible layout/semantics twin: guarantees identical sizing to
          // inactive Text, preserves screen-reader semantics, and skips all
          // painting in RenderOpacity (alpha == 0).
          child: Visibility.maintain(
            visible: false,
            child: Text(text, style: style),
          ),
        );
      },
    );
  }
}

class _KaraokeLinePainter extends CustomPainter {
  _KaraokeLinePainter({
    required this.text,
    required this.style,
    required this.progress,
    required this.maxWidth,
    required this.unsungColor,
    required this.sungColor,
    required this.featherWidth,
    required this.textDirection,
    required this.textScaler,
  });

  final String text;
  final TextStyle style;
  final double progress;
  final double maxWidth;
  final Color unsungColor;
  final Color sungColor;
  final double featherWidth;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) {
      final sungPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(color: sungColor),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      sungPainter.paint(canvas, Offset.zero);
      return;
    }

    // 1. Paint base (unsung) text.
    final basePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: unsungColor),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    basePainter.paint(canvas, Offset.zero);

    if (progress <= 0.0) return;

    // 2. Measure exact visual line widths so wrapped lines sweep at uniform
    //    reading speed.
    final lines = basePainter.computeLineMetrics();
    final totalTextWidth = lines.fold<double>(0.0, (sum, l) => sum + l.width);
    if (totalTextWidth <= 0) return;

    // 3. Paint bright (sung) text into an isolated layer, then mask
    //    line-by-line with BlendMode.dstIn.
    final sungPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: sungColor),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);

    canvas.saveLayer(Offset.zero & size, Paint());
    sungPainter.paint(canvas, Offset.zero);

    var accumulatedWidth = 0.0;
    final targetSungWidth = totalTextWidth * progress;

    for (final line in lines) {
      final lineTop = (line.baseline - line.ascent).clamp(0.0, size.height);
      final lineBottom = (line.baseline + line.descent).clamp(0.0, size.height);
      final lineRect = Rect.fromLTRB(0, lineTop, size.width, lineBottom);

      final lineWidth = line.width;
      if (lineWidth <= 0) continue;

      final lineSungPx = (targetSungWidth - accumulatedWidth).clamp(
        0.0,
        lineWidth,
      );
      accumulatedWidth += lineWidth;
      final lineProgress = lineSungPx / lineWidth;

      if (lineProgress >= 1.0) {
        continue;
      }
      if (lineProgress <= 0.0) {
        canvas.drawRect(lineRect, Paint()..blendMode = BlendMode.clear);
        continue;
      }

      // Sweep a feathered edge across this wrapped line so 0.0 is completely
      // dim and 1.0 is completely bright without leaking onto subsequent lines.
      final sweepStart =
          line.left - featherWidth + lineProgress * (lineWidth + featherWidth);
      final sweepEnd = sweepStart + featherWidth;

      final maskPaint = Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(sweepStart, 0),
          Offset(sweepEnd, 0),
          const [Colors.white, Color(0x00FFFFFF)],
        );

      canvas.drawRect(lineRect, maskPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KaraokeLinePainter old) =>
      old.progress != progress ||
      old.text != text ||
      old.style != style ||
      old.maxWidth != maxWidth ||
      old.unsungColor != unsungColor ||
      old.sungColor != sungColor ||
      old.featherWidth != featherWidth ||
      old.textDirection != textDirection ||
      old.textScaler != textScaler;
}

/// The live position feed an active row reads its own progress from.
///
/// Carries the timeline item rather than a `progressAt` tear-off so it
/// compares by identity: the item instances are stable for as long as the
/// timeline is, and a row that re-attached on every frame would add and remove
/// a listener 120 times a second.
typedef LyricTick = ({
  ValueListenable<Duration> listenable,
  LyricTimelineItem item,
});

/// Rebuilds a small leaf — the karaoke text, or the three dots — on every
/// position tick, and nowhere else.
///
/// Deliberately *below* the row's activation tween. Putting the listener above
/// it, as a [ValueListenableBuilder] around the whole row, made the active row
/// a different element from the inactive one: every tween inside it was
/// recreated, started at its end value, and the line snapped to full size
/// instead of growing into it.
///
/// Keeps its last progress after the tick is withdrawn, so a row that is
/// leaving keeps the fill it had while it fades rather than blanking first.
class _TickProgress extends StatefulWidget {
  const _TickProgress({
    this.tick,
    required this.fallback,
    required this.builder,
  });

  /// The live feed, set only while this row is the active one.
  final LyricTick? tick;

  /// Value used until the row has ever been active. The rows below the active
  /// one are all at zero progress, so this is almost always zero.
  final double fallback;

  final Widget Function(double progress) builder;

  @override
  State<_TickProgress> createState() => _TickProgressState();
}

class _TickProgressState extends State<_TickProgress> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _progress = widget.fallback.clamp(0.0, 1.0);
    _listen();
  }

  @override
  void didUpdateWidget(covariant _TickProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tick != widget.tick) {
      oldWidget.tick?.listenable.removeListener(_onTick);
      _listen();
    }
  }

  @override
  void dispose() {
    widget.tick?.listenable.removeListener(_onTick);
    super.dispose();
  }

  void _listen() {
    final tick = widget.tick;
    if (tick == null) return;
    _progress = tick.item.progressAt(tick.listenable.value);
    tick.listenable.addListener(_onTick);
  }

  void _onTick() {
    final tick = widget.tick;
    if (tick == null) return;
    final next = tick.item.progressAt(tick.listenable.value);
    if (next != _progress) setState(() => _progress = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_progress);
}

/// Apple Music-style collapsible three-dot interlude indicator.
///
/// Expands when the break starts and collapses to zero height when vocals
/// resume, through [Align.heightFactor], so [AnchoredLyricList] absorbs the
/// vertical change instead of the column jumping a whole row.
///
/// [tick] is what keeps that hand-off animated: the same element is built
/// whether this row is the active one or not, so the tween below runs to its
/// new end value instead of being recreated already there. It also keeps the
/// last fill while the dots fade, so they leave at the progress they reached
/// rather than blanking first.
class InterludeDotsItem extends StatelessWidget {
  const InterludeDotsItem({
    super.key,
    required this.isActive,
    this.progress = 0.0,
    this.tick,
    this.onTap,
    this.dotColor,
  });

  final bool isActive;

  /// Static progress, used until [tick] has ever been attached.
  final double progress;

  /// The live position feed, set only while this is the active row.
  final LyricTick? tick;
  final VoidCallback? onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final color = dotColor ?? Theme.of(context).colorScheme.onSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isActive ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      builder: (context, visibility, _) {
        if (visibility <= 0.001 && !isActive) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              heightFactor: visibility,
              child: Opacity(
                opacity: visibility,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: _TickProgress(
                    tick: tick,
                    fallback: progress,
                    builder: (progress) {
                      final clamped = progress.clamp(0.0, 1.0);
                      // Quick anticipation swell in the final 8% before
                      // vocals enter.
                      final anticipation = clamped > 0.92
                          ? 1.0 +
                                0.16 *
                                    math.sin(
                                      ((clamped - 0.92) / 0.08) * math.pi,
                                    )
                          : 1.0;
                      return Transform.scale(
                        alignment: Alignment.centerLeft,
                        scale:
                            ui.lerpDouble(0.85, 1.0, visibility)! *
                            anticipation,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            // Each dot fills sequentially across its 1/3 slice.
                            final sliceStart = index / 3.0;
                            final dotFill = ((clamped - sliceStart) * 3.0)
                                .clamp(0.0, 1.0);

                            // Ambient breathing + sequential activation pop.
                            final ambient =
                                0.05 *
                                math.sin(
                                  (clamped * math.pi * 6) - (index * 0.9),
                                );
                            final pop = 0.14 * math.sin(dotFill * math.pi);
                            final scale =
                                (0.88 + 0.12 * dotFill + pop + ambient).clamp(
                                  0.75,
                                  1.25,
                                );

                            final alpha = ui.lerpDouble(0.24, 0.88, dotFill)!;

                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < 2 ? 10.0 : 0.0,
                              ),
                              child: Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: alpha),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Zero-reflow lyric block.
///
/// Always renders its main lyric, pronunciation and translation at their full
/// active `fontSize` and `fontWeight` so `RenderParagraph` never recalculates
/// line breaks. Inactive lines scale visually via [Transform.scale] while
/// [Align.heightFactor] smoothly reclaims vertical space without reflow.
class LyricLineItem extends StatelessWidget {
  const LyricLineItem({
    super.key,
    required this.line,
    required this.isActive,
    this.progress = 0.0,
    this.tick,
    this.synced = true,
    this.showPronunciation = true,
    this.showTranslation = true,
    this.onTap,
    this.inactiveScale = 0.82,
    this.mainFontSize = 28.0,
  });

  final LyricLine line;
  final bool isActive;

  /// Static fill of the sung layer, used until [tick] has ever been attached.
  final double progress;

  /// The live position feed, set only while this is the active row.
  ///
  /// Read by the sung layer alone, below this row's activation tween: the row
  /// has to be the same element while it grows into the active state, or the
  /// tween is recreated at its end value and the line snaps.
  final LyricTick? tick;
  final bool synced;
  final bool showPronunciation;
  final bool showTranslation;
  final VoidCallback? onTap;
  final double inactiveScale;
  final double mainFontSize;

  @override
  Widget build(BuildContext context) {
    // Blank lines in unsynced lyrics are stanza breaks.
    if (line.text.trim().isEmpty) return const SizedBox(height: SolSpace.lg);

    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurface;
    final cleanText = line.text.trim().toLowerCase();
    final hasPronunciation =
        showPronunciation &&
        line.pronunciation != null &&
        line.pronunciation!.trim().isNotEmpty &&
        line.pronunciation!.trim().toLowerCase() != cleanText;
    final hasTranslation =
        showTranslation &&
        line.translation != null &&
        line.translation!.trim().isNotEmpty &&
        line.translation!.trim().toLowerCase() != cleanText &&
        line.translation!.trim().toLowerCase() !=
            line.pronunciation?.trim().toLowerCase();

    final baseMainStyle = (theme.textTheme.titleLarge ?? const TextStyle())
        .copyWith(
          fontSize: mainFontSize,
          fontWeight: FontWeight.w800,
          height: 1.22,
          letterSpacing: -0.2,
          color: baseColor,
        );
    final basePronunciationStyle =
        (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
          fontSize: 15.0,
          fontWeight: FontWeight.w600,
          height: 1.32,
          letterSpacing: 0.2,
          color: baseColor,
        );
    final baseTranslationStyle =
        (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
          fontSize: 16.0,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: baseColor,
        );

    if (!synced) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              line.text,
              style: baseMainStyle.copyWith(
                fontSize: mainFontSize * 0.86,
                color: baseColor.withValues(alpha: 0.88),
              ),
            ),
            if (hasPronunciation) ...[
              const SizedBox(height: 6),
              Text(
                line.pronunciation!,
                style: basePronunciationStyle.copyWith(
                  color: baseColor.withValues(alpha: 0.64),
                ),
              ),
            ],
            if (hasTranslation) ...[
              const SizedBox(height: 3),
              Text(
                line.translation!,
                style: baseTranslationStyle.copyWith(
                  color: baseColor.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Semantics(
      selected: isActive,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isActive ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            final scale = ui.lerpDouble(inactiveScale, 1.0, t)!;
            final inactiveAlpha = ui.lerpDouble(0.32, 0.92, t)!;
            final subAlpha = ui.lerpDouble(0.26, 0.72, t)!;
            final transAlpha = ui.lerpDouble(0.28, 0.82, t)!;

            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: ui.lerpDouble(8.0, 14.0, t)!,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: scale,
                child: Transform.scale(
                  alignment: Alignment.centerLeft,
                  scale: scale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TickProgress(
                        tick: tick,
                        fallback: progress,
                        builder: (progress) => KaraokeSweepText(
                          text: line.text,
                          style: baseMainStyle,
                          isActive: isActive,
                          progress: progress,
                          unsungAlpha: isActive ? 0.34 : inactiveAlpha,
                          sungAlpha: 0.96,
                        ),
                      ),
                      if (hasPronunciation) ...[
                        const SizedBox(height: 6),
                        Text(
                          line.pronunciation!,
                          style: basePronunciationStyle.copyWith(
                            color: baseColor.withValues(alpha: subAlpha),
                          ),
                        ),
                      ],
                      if (hasTranslation) ...[
                        const SizedBox(height: 3),
                        Text(
                          line.translation!,
                          style: baseTranslationStyle.copyWith(
                            color: baseColor.withValues(alpha: transAlpha),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bounce-free scrolling lyric column anchored via a Ticker-driven critically
/// damped exponential damper (`lambda = 12.0`).
///
/// Measures the active item's live [RenderBox.localToGlobal] offset inside a
/// [SingleChildScrollView] + [Column] on every frame, absorbing real-time
/// height changes from shrinking lines or collapsing interludes above it with
/// zero overshoot.
class AnchoredLyricList extends StatefulWidget {
  const AnchoredLyricList({
    super.key,
    required this.items,
    required this.synced,
    required this.activeIndex,
    required this.positionListenable,
    this.onSelectItem,
    this.padding = const EdgeInsets.symmetric(horizontal: SolSpace.xl),
    this.fade = true,
    this.showPronunciation = true,
    this.showTranslation = true,
  });

  final List<LyricTimelineItem> items;
  final bool synced;
  final int activeIndex;
  final ValueListenable<Duration> positionListenable;
  final ValueChanged<int>? onSelectItem;
  final EdgeInsets padding;
  final bool fade;
  final bool showPronunciation;
  final bool showTranslation;

  @override
  State<AnchoredLyricList> createState() => _AnchoredLyricListState();
}

class _AnchoredLyricListState extends State<AnchoredLyricList>
    with SingleTickerProviderStateMixin {
  static const double _kDamperLambda = 12.0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  late List<GlobalKey> _itemKeys;
  late final Ticker _ticker;

  Duration? _lastTick;
  Duration _settleNotBefore = Duration.zero;
  double _anchorTopOffset = 96.0;
  bool _userDragging = false;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    _ticker = createTicker(_onTick);
    if (widget.synced && widget.activeIndex >= 0) {
      _resumeTicker(holdForTransition: false);
    }
  }

  @override
  void didUpdateWidget(covariant AnchoredLyricList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items) ||
        oldWidget.items.length != widget.items.length) {
      _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
      _userDragging = false;
      _resumeTimer?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (widget.synced && widget.activeIndex >= 0) {
        _resumeTicker(holdForTransition: false);
      } else {
        _ticker.stop();
      }
      return;
    }

    if (oldWidget.activeIndex != widget.activeIndex) {
      if (widget.synced && widget.activeIndex >= 0 && !_userDragging) {
        _resumeTicker(holdForTransition: true);
      } else if (!widget.synced || widget.activeIndex < 0) {
        _ticker.stop();
      }
    }
  }

  void _resumeTicker({required bool holdForTransition}) {
    final hold = holdForTransition
        ? const Duration(milliseconds: 360)
        : Duration.zero;
    if (_ticker.isActive) {
      if (_lastTick != null && hold > Duration.zero) {
        _settleNotBefore = _lastTick! + hold;
      }
      return;
    }
    _lastTick = null;
    _settleNotBefore = hold;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_userDragging ||
        !widget.synced ||
        widget.activeIndex < 0 ||
        widget.activeIndex >= _itemKeys.length) {
      _ticker.stop();
      return;
    }

    if (!_scrollController.hasClients) {
      _lastTick = elapsed;
      return;
    }

    final dt = _lastTick == null
        ? 1 / 60
        : (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        _itemKeys[widget.activeIndex].currentContext?.findRenderObject()
            as RenderBox?;

    if (viewportBox == null ||
        !viewportBox.attached ||
        targetBox == null ||
        !targetBox.attached) {
      return;
    }

    final currentDy = targetBox
        .localToGlobal(Offset.zero, ancestor: viewportBox)
        .dy;

    final error = currentDy - _anchorTopOffset;
    final position = _scrollController.position;
    final desiredOffset = (position.pixels + error).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    final remainingDelta = desiredOffset - position.pixels;

    if (remainingDelta.abs() < 0.25) {
      if (remainingDelta != 0) {
        _scrollController.jumpTo(desiredOffset);
      }
      // Keep tracking while neighbouring lines finish their 320ms heightFactor
      // transition so we absorb every pixel of collapse without drift.
      if (elapsed >= _settleNotBefore || position.maxScrollExtent <= 0) {
        _ticker.stop();
      }
      return;
    }

    // Critically damped exponential decay (lambda = 12.0 -> ~300ms settle,
    // zero overshoot).
    final factor = 1.0 - math.exp(-_kDamperLambda * dt.clamp(0.0, 0.05));
    _scrollController.jumpTo(position.pixels + remainingDelta * factor);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!widget.synced) return false;
    if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        _userDragging = true;
        _resumeTimer?.cancel();
        _ticker.stop();
      }
    } else if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userDragging = true;
      _resumeTimer?.cancel();
      _ticker.stop();
    } else if (notification is ScrollEndNotification && _userDragging) {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _userDragging = false;
        if (widget.activeIndex >= 0) {
          _resumeTicker(holdForTransition: false);
        }
      });
    }
    return false;
  }

  void _handleTap(int index) {
    final onSelect = widget.onSelectItem;
    if (onSelect == null) return;
    _resumeTimer?.cancel();
    _userDragging = false;
    onSelect(index);
    if (widget.synced) {
      _resumeTicker(holdForTransition: true);
    }
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildItem(
    int index,
    LyricTimelineItem item, {
    required bool isActive,
    required double mainFontSize,
  }) {
    // One shape for the active and the inactive row. The active one used to be
    // wrapped in a ValueListenableBuilder, which made it a different element
    // from the row that was already mounted: every tween inside it was built
    // fresh at its end value, so a line popped to full size on the frame the
    // vocals arrived and an interlude vanished instead of collapsing. The
    // live feed is handed down to the leaf that draws the fill instead, and
    // the row itself is the same widget at both states.
    final LyricTick? tick = isActive && widget.synced
        ? (listenable: widget.positionListenable, item: item)
        : null;
    final key = _itemKeys[index];
    final VoidCallback? onTap = widget.onSelectItem == null
        ? null
        : () => _handleTap(index);

    return switch (item) {
      LyricLineEntry(:final line) => LyricLineItem(
        key: key,
        line: line,
        isActive: isActive,
        tick: tick,
        synced: widget.synced,
        showPronunciation: widget.showPronunciation,
        showTranslation: widget.showTranslation,
        mainFontSize: mainFontSize,
        onTap: onTap,
      ),
      LyricInterludeEntry() => InterludeDotsItem(
        key: key,
        isActive: isActive,
        tick: tick,
        onTap: onTap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchorTop = widget.synced
            ? (constraints.maxHeight * 0.28).clamp(48.0, 140.0)
            : 0.0;
        _anchorTopOffset = anchorTop;

        final bottomRunway = widget.synced
            ? math.max(widget.padding.bottom, constraints.maxHeight * 0.65)
            : widget.padding.bottom;
        final mainFontSize = constraints.maxWidth < 340 ? 24.0 : 28.0;

        final scrollView = SingleChildScrollView(
          key: _viewportKey,
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            widget.padding.left,
            math.max(widget.padding.top, anchorTop),
            widget.padding.right,
            bottomRunway,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                _buildItem(
                  i,
                  widget.items[i],
                  isActive: widget.synced && i == widget.activeIndex,
                  mainFontSize: mainFontSize,
                ),
            ],
          ),
        );

        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: widget.fade ? _faded(scrollView) : scrollView,
          ),
        );
      },
    );
  }

  Widget _faded(Widget child) => ShaderMask(
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

/// Timed lyrics, drawn the way Apple Music draws them.
///
/// Accepts either a high-frequency [positionListenable] (preferred, so 60/120Hz
/// audio ticks only repaint the single active item) or a static [position]
/// value.
class LyricsView extends StatefulWidget {
  final Lyrics lyrics;
  final Duration position;
  final ValueListenable<Duration>? positionListenable;
  final Duration? trackDuration;
  final ValueChanged<Duration>? onSeek;

  /// Inset inside the scrolling plane.
  final EdgeInsets padding;

  /// Whether to fade the column's edges into the surface behind it.
  final bool fade;

  /// Whether to show pronunciation (Romaji/Pinyin/Hangul) layers.
  final bool showPronunciation;

  /// Whether to show translation layers.
  final bool showTranslation;

  const LyricsView({
    super.key,
    required this.lyrics,
    this.position = Duration.zero,
    this.positionListenable,
    this.trackDuration,
    this.onSeek,
    this.padding = const EdgeInsets.symmetric(horizontal: SolSpace.xl),
    this.fade = true,
    this.showPronunciation = true,
    this.showTranslation = true,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  ValueNotifier<Duration>? _ownedPosition;
  late List<LyricTimelineItem> _timeline;
  int _activeIndex = -1;

  ValueListenable<Duration> get _effectivePosition =>
      widget.positionListenable ?? _ownedPosition!;

  @override
  void initState() {
    super.initState();
    if (widget.positionListenable == null) {
      _ownedPosition = ValueNotifier<Duration>(widget.position);
    }
    _timeline = buildLyricTimeline(
      widget.lyrics,
      trackDuration: widget.trackDuration,
    );
    _activeIndex = _computeActiveIndex(_effectivePosition.value);
    _effectivePosition.addListener(_onPositionChanged);
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.positionListenable != widget.positionListenable) {
      final oldListenable = oldWidget.positionListenable ?? _ownedPosition;
      oldListenable?.removeListener(_onPositionChanged);

      if (widget.positionListenable == null) {
        _ownedPosition ??= ValueNotifier<Duration>(widget.position);
        _ownedPosition!.value = widget.position;
      } else {
        _ownedPosition?.dispose();
        _ownedPosition = null;
      }
      _effectivePosition.addListener(_onPositionChanged);
    } else if (widget.positionListenable == null &&
        oldWidget.position != widget.position) {
      _ownedPosition!.value = widget.position;
    }

    if (oldWidget.lyrics != widget.lyrics ||
        oldWidget.trackDuration != widget.trackDuration) {
      _timeline = buildLyricTimeline(
        widget.lyrics,
        trackDuration: widget.trackDuration,
      );
      _activeIndex = _computeActiveIndex(_effectivePosition.value);
    }
  }

  int _computeActiveIndex(Duration position) =>
      widget.lyrics.synced ? timelineIndexAt(_timeline, position) : -1;

  void _onPositionChanged() {
    final next = _computeActiveIndex(_effectivePosition.value);
    if (next != _activeIndex && mounted) {
      setState(() => _activeIndex = next);
    }
  }

  @override
  void dispose() {
    _effectivePosition.removeListener(_onPositionChanged);
    _ownedPosition?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnchoredLyricList(
      items: _timeline,
      synced: widget.lyrics.synced,
      activeIndex: _activeIndex,
      positionListenable: _effectivePosition,
      padding: widget.padding,
      fade: widget.fade,
      showPronunciation: widget.showPronunciation,
      showTranslation: widget.showTranslation,
      onSelectItem: widget.onSeek == null
          ? null
          : (index) {
              if (index < 0 || index >= _timeline.length) return;
              widget.onSeek!(
                widget.lyrics.synced
                    ? _timeline[index].startTime
                    : Duration.zero,
              );
            },
    );
  }
}
