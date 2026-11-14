import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../shell/tab_destinations.dart';

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
