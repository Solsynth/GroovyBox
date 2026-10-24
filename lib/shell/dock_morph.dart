import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Shared state for the dock's container transform.
///
/// The now-playing capsule *is* the collapsed player, so opening the player is
/// a morph: the capsule grows into the page instead of a new page sliding over
/// it. The dock records where it was when tapped; the route's transition
/// animates the player's own box from that rect to the full window.
///
/// The origin is read once, when the route is first built, so a rotated window
/// or a scroll during the push cannot drag the animation around.
class DockMorphOrigin {
  /// The capsule's rect in global coordinates, captured at tap time.
  static Rect? rect;

  /// Radius the capsule had when it was tapped.
  static double radius = SolRadius.pill;

  /// Clears the capture after the transition has finished, so the next push
  /// starts from wherever that tap happened rather than a stale rect.
  static void clear() => rect = null;
}

/// The container transform used by the player route.
///
/// [animation] runs 0 → 1 on push and 1 → 0 on pop. The page is clipped to a
/// rect that interpolates between the dock capsule and the full window, with
/// the corner radius easing from the capsule's pill to square.
///
/// The growing box paints the theme surface behind the page. Without it the
/// page's own translucent layers let the *previous* page through, which reads
/// as a ghost of Browse inside the expanding capsule rather than as one object
/// changing shape.
Widget dockMorphTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final origin = DockMorphOrigin.rect;
  final size = MediaQuery.sizeOf(context);
  final screen = Offset.zero & size;
  final from = origin ?? screen;

  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return AnimatedBuilder(
    animation: curved,
    builder: (context, _) {
      final rect = Rect.lerp(from, screen, curved.value)!;
      final radius = lerpDouble(
        DockMorphOrigin.radius,
        0,
        Curves.easeOutCubic.transform(curved.value),
      )!;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}
