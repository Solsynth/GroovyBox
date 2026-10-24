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

/// Bottom clearance a scrolling page needs to keep its last row tappable
/// under the floating chrome.
///
/// The chrome floats *over* the page (so the glass has something to refract),
/// which means the page has to reserve the space itself. [dockVisible] adds
/// the now-playing capsule's height; the compact layout also stacks the tab
/// capsule under it, while the wide layout keeps navigation in the rail.
double solBottomChromeInset(BuildContext context, {required bool dockVisible}) {
  final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
  final dock = dockVisible ? kNowPlayingDockHeight + SolSpace.sm : 0.0;
  final nav = isWideScreen(context) ? 0.0 : kBottomNavHeight + SolSpace.md;
  return dock + nav + SolSpace.xl + safeBottom;
}

/// Height of the floating now-playing capsule's content box.
const double kNowPlayingDockHeight = 64.0;

/// Height of the floating tab capsule's content box.
const double kBottomNavHeight = 56.0;

/// Gutter between the floating chrome and the window edges.
const double kChromeGutter = SolSpace.md;
