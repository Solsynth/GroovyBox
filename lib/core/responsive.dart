import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Width at which the shell swaps the bottom bar for a navigation rail.
///
/// Same threshold as Solian so both apps break at the same window sizes.
const double kWideScreenWidth = 768.0;

/// Width of the floating navigation capsule on wide layouts.
///
/// Content has to clear it: the capsule overlaps the page so the glass has
/// something to refract, which means the gutter on wide windows is never
/// narrower than the capsule plus its margins.
const double kWideRailWidth = 88.0;

/// Widest a single content column gets on a large window.
///
/// Beyond this the extra pixels become gutter instead of stretching rows and
/// covers until they stop reading as a list.
const double kContentMaxWidth = 1120.0;

/// Widest a text-heavy column gets (detail headers, the player's copy).
const double kReadingMaxWidth = 720.0;

bool isWideScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width > kWideScreenWidth;
}

/// Horizontal gutter that centers a column of at most [maxWidth] on wide
/// windows and falls back to the page gutter on narrow ones.
///
/// Every page uses this instead of a fixed `SolSpace.xxl` inset, so a
/// maximized window keeps its content in one column rather than smearing rows
/// across the whole screen.
double solContentGutter(
  BuildContext context, {
  double maxWidth = kContentMaxWidth,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = width >= 600 ? SolSpace.pageWide : SolSpace.page;
  if (width <= maxWidth) return gutter;
  return math.max(gutter, (width - maxWidth) / 2);
}

/// Symmetric page padding for a centered content column.
EdgeInsets solContentPadding(
  BuildContext context, {
  double maxWidth = kContentMaxWidth,
  double top = 0,
  double bottom = 0,
}) {
  final gutter = solContentGutter(context, maxWidth: maxWidth);
  return EdgeInsets.fromLTRB(gutter, top, gutter, bottom);
}

/// Raw bottom-chrome geometry, for the shell that draws the chrome.
///
/// [dockVisible] adds the now-playing capsule's height; the compact layout
/// also stacks the tab capsule under it, while the wide layout keeps
/// navigation in the rail. Pages never call this: they read the shell's
/// answer through [solBottomChromeInset] and [solFloatingBarOffset].
({double inset, double barOffset}) solChromeGeometry(
  BuildContext context, {
  required bool dockVisible,
}) {
  final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
  final dock = dockVisible ? kNowPlayingDockHeight + SolSpace.sm : 0.0;
  final nav = isWideScreen(context) ? 0.0 : kBottomNavHeight + SolSpace.md;
  return (
    inset: dock + nav + SolSpace.xl + safeBottom,
    barOffset: dock + nav + SolSpace.sm + safeBottom,
  );
}

/// Bottom clearance a page needs to keep its last row tappable under the
/// shell's floating chrome.
///
/// The chrome floats *over* the page (so the glass has something to refract),
/// so each page reserves the space at the end of its scroll. The shell
/// publishes the measurement through [SolChromeInset] once, so a page cannot
/// forget the dock, the tab capsule or the home indicator — every page reads
/// the same number, and pages pushed above the shell (the player) are
/// unaffected.
///
/// Outside the shell — a page pumped on its own — nothing floats over it, so
/// only the device's own inset and the page's bottom runway are reserved.
double solBottomChromeInset(BuildContext context) {
  final published = SolChromeInset.maybeOf(context);
  if (published != null) return published.inset;
  return MediaQuery.viewPaddingOf(context).bottom + SolSpace.xl;
}

/// Height of the floating now-playing capsule's content box.
const double kNowPlayingDockHeight = 56.0;

/// Height of the floating tab capsule's content box.
const double kBottomNavHeight = 56.0;

/// Gutter between the floating chrome and the window edges.
const double kChromeGutter = SolSpace.md;

/// Where one of the page's own floating bars sits, measured from the page's
/// bottom edge: above the now-playing capsule when it is up, and above the
/// tab capsule on the compact layout. A page that adds a bar of its own
/// stacks it here rather than at a guessed offset, so it never covers the
/// chrome the shell already floats.
double solFloatingBarOffset(BuildContext context) {
  final published = SolChromeInset.maybeOf(context);
  if (published != null) return published.barOffset;
  return MediaQuery.viewPaddingOf(context).bottom + SolSpace.sm;
}

/// The shell's bottom chrome, published to every page under it.
///
/// Two measurements, both from the shell so they cannot drift apart:
/// [inset] is the clearance a page's scroll content reserves at its end, and
/// [barOffset] is where a page's own floating bar sits above the chrome.
class SolChromeInset extends InheritedWidget {
  /// Space the last scrolling row keeps clear of the floating chrome.
  final double inset;

  /// Distance from the page's bottom edge to a page-level floating bar.
  final double barOffset;

  const SolChromeInset({
    super.key,
    required this.inset,
    required this.barOffset,
    required super.child,
  });

  static SolChromeInset? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SolChromeInset>();

  @override
  bool updateShouldNotify(SolChromeInset oldWidget) =>
      inset != oldWidget.inset || barOffset != oldWidget.barOffset;
}
