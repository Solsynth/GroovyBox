import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../core/glass.dart';
import '../core/theme.dart';

/// Scroll distance over which a pill header finishes fading its surface in.
///
/// Tied to roughly one header height: by the time the content has meaningfully
/// slid under the bar, the pill is fully surfaced and can carry its controls.
const double kPillFadeDistance = 96.0;

/// Inner height of a pill bar's capsule — the glass box itself, before the
/// status-bar inset and the top gutter are added on top.
const double kPillBarContentHeight = SolSpace.control + SolSpace.md;

/// Side gutter of a pill: the capsule sits [SolSpace.md] in from each edge of
/// its container so the end caps clear it.
const double kPillSideGutter = SolSpace.md;

/// Total height of a pill bar, excluding the status-bar inset.
///
/// A bar reserves `statusTop + kPillAppBarHeight`: the capsule's top margin
/// plus [kPillBarContentHeight]. Anything that has to clear a pill header — a
/// body gap, a scaffold slot, a test assertion — should be computed from this
/// so every pill lands on the same band.
const double kPillAppBarHeight = kPillBarContentHeight + SolSpace.md;

/// Feeds a pill's fade ramp (0..1) from a scroll notification.
///
/// The ramp is read off the scroll offset itself so the surface tracks the
/// drag instead of snapping at the first pixel. [threshold] keeps the pill
/// hidden until the page has scrolled that far, which lets a page open on its
/// artwork before the bar appears. Only the outermost scrollable counts.
///
/// Returns false so the notification keeps bubbling to other listeners.
bool updatePillFade(
  ScrollNotification notification,
  ValueNotifier<double> fade, {
  double threshold = 0,
}) {
  final metrics = notification.metrics;
  if (notification.depth != 0 || metrics.axis != Axis.vertical) return false;
  final ramp = ((metrics.pixels - threshold) / kPillFadeDistance).clamp(
    0.0,
    1.0,
  );
  if (fade.value != ramp) fade.value = ramp;
  return false;
}

/// Evaluates [builder] with the current fade value (1.0 when [fade] is null),
/// passing [child] through untouched so scroll ticks do not rebuild the bar's
/// inner controls.
Widget _buildWithFade({
  required ValueListenable<double>? fade,
  required Widget child,
  required Widget Function(BuildContext context, double t, Widget child)
  builder,
}) {
  if (fade == null) {
    return Builder(builder: (context) => builder(context, 1.0, child));
  }
  return ValueListenableBuilder<double>(
    valueListenable: fade,
    child: child,
    builder: (context, t, builtChild) => builder(context, t, builtChild!),
  );
}

/// Pinned header sliver that keeps a pill in place and fades its surface in
/// with the scroll offset — GroovyBox's port of Solian's `PillSliverAppBar`.
///
/// [fade] is driven by [updatePillFade] from the enclosing scroll view. The
/// sliver's own geometry never changes, and because it is pinned nothing moves
/// the bar either: the feed slides underneath it while only the fill animates.
///
/// [leading] sits inside the capsule at its start — the back affordance on a
/// pushed page, nothing on a tab root. The page's title and trailing actions
/// fill the rest of the capsule's row.
class PillSliverAppBar extends StatelessWidget {
  /// Fade position listenable, 0..1. Null keeps the capsule surfaced: a page
  /// whose content never slides under it has no fade to track, and hiding its
  /// fill would leave bare controls floating on the page.
  final ValueListenable<double>? fade;

  /// Status-bar inset, measured by the caller so the sliver's height matches.
  final double statusTop;

  /// The control at the capsule's leading edge. Null leaves the title to own
  /// the row's start.
  final Widget? leading;

  /// The page title, drawn inside the capsule.
  final String title;

  /// Optional one-line detail under the title; the capsule grows to fit.
  final String? subtitle;

  /// Actions at the capsule's trailing edge.
  final List<Widget> actions;

  const PillSliverAppBar({
    super.key,
    this.fade,
    required this.statusTop,
    this.leading,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      primary: false,
      automaticallyImplyLeading: false,
      toolbarHeight: statusTop + kPillAppBarHeight,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      pinned: true,
      flexibleSpace: _buildWithFade(
        fade: fade,
        child: _PillContent(
          title: title,
          subtitle: subtitle,
          actions: actions,
          leading: leading,
        ),
        builder: (context, t, content) =>
            _PillBarSurface(t: t, statusTop: statusTop, child: content),
      ),
    );
  }
}

/// The capsule's control row: leading, title with an optional one-line
/// subtitle under it, and trailing actions.
class _PillContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  const _PillContent({
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: SolSpace.xs)],
        Expanded(
          child: subtitle == null
              ? Align(alignment: Alignment.centerLeft, child: titleText)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleText,
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
        ...actions,
      ],
    );
  }
}

class _PillBarSurface extends StatelessWidget {
  /// Fade position, 0..1. Drives the glass and shadow together.
  final double t;

  /// Status-bar inset, reserved inside the bar's own box.
  final double statusTop;

  final Widget child;

  const _PillBarSurface({
    required this.t,
    required this.statusTop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kPillSideGutter,
        statusTop + kPillSideGutter,
        kPillSideGutter,
        0,
      ),
      child: PillSurface(
        t: t,
        radius: SolRadius.pillRadius,
        contentPadding: const EdgeInsets.symmetric(horizontal: SolSpace.lg),
        // The capsule is always exactly `kPillBarContentHeight` tall — a
        // control row plus the composer's vertical padding. `PillSurface`
        // sizes the glass to its child, so leaving it to the row would let
        // any child that fills its constraints stretch the pill to whatever
        // height the slot happens to offer. Pinning it keeps every pill the
        // same shape and makes the bar's height the whole truth.
        child: SizedBox(height: kPillBarContentHeight, child: child),
      ),
    );
  }
}

/// A page's header as a pill, for scroll views: measures the status-bar
/// inset itself, so a call site names the page's title and actions and the
/// bar lands on the same band every page uses.
class SliverPillHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// The control at the capsule's leading edge — the back affordance on a
  /// pushed page, nothing on a tab root.
  final Widget? leading;

  /// Fade listenable for pages that open on artwork and reveal the pill as
  /// the content slides under it. Null keeps the capsule surfaced.
  final ValueListenable<double>? fade;

  const SliverPillHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.fade,
  });

  @override
  Widget build(BuildContext context) {
    final statusTop = MediaQuery.paddingOf(context).top;
    return PillSliverAppBar(
      fade: fade,
      statusTop: statusTop,
      leading: leading,
      title: title,
      subtitle: subtitle,
      actions: actions,
    );
  }
}

/// A page's header as a pill, as a plain box — for pages laid out in a
/// [Column] or [ListView] whose content does not scroll under the bar. The
/// capsule is surfaced the whole time: there is nothing sliding beneath it,
/// and hiding its fill would leave bare controls floating on the page.
class PillHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  const PillHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kPillSideGutter,
        kPillSideGutter,
        kPillSideGutter,
        SolSpace.xs,
      ),
      child: PillSurface(
        radius: SolRadius.pillRadius,
        contentPadding: const EdgeInsets.symmetric(horizontal: SolSpace.lg),
        child: SizedBox(
          height: kPillBarContentHeight,
          child: _PillContent(
            title: title,
            subtitle: subtitle,
            actions: actions,
            leading: leading,
          ),
        ),
      ),
    );
  }
}
