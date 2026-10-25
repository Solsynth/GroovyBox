import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../shell/tab_destinations.dart';

/// Opens [route] on the active tab's own stack.
///
/// Pages inside a tab resolve `context.router` to that tab's stack, so they do
/// not need this. The shell does: its rail and bottom bar sit above the tabs,
/// where `context.router` is the *root* stack, and pushing there would cover
/// the shell — and the now-playing capsule floating in it.
Future<T?> pushInActiveTab<T extends Object?>(
  BuildContext context,
  PageRouteInfo route,
) {
  final tabs = context.tabsRouter;
  final stack = tabs.stackRouterOfIndex(tabs.activeIndex);
  // A tab that has not been built yet has no nested router to push onto; the
  // scoped router then resolves the route wherever it can, as it always did.
  return (stack ?? context.router).push<T>(route);
}

/// Switches to the tab with [id] (see [allTabDestinations]).
///
/// A tab's landing page is not reachable as a push: it belongs to *another*
/// tab's collection, so no router in the current hierarchy matches it. Sending
/// the user to a tab means selecting it, the same way the rail and the bottom
/// bar do.
void activateTab(BuildContext context, String id) {
  final index = allTabDestinations.indexWhere(
    (destination) => destination.id == id,
  );
  if (index >= 0) context.tabsRouter.setActiveIndex(index);
}
