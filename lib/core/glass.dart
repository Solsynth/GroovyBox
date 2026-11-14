import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Whether chrome draws the liquid-glass material or a flat tonal surface.
///
/// Scoped once at the root from the user's setting (`glassEffectsEnabled`).
/// Glass costs a backdrop copy plus a shader pass on every frame a surface is
/// on screen; turning it off keeps every layout identical but paints the same
/// capsules from the theme instead.
///
/// Defaults to `true` when no scope is present, so a surface rendered in
/// isolation still gets the material the app ships with.
class GlassEffects extends InheritedWidget {
  final bool enabled;

  const GlassEffects({super.key, required this.enabled, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassEffects>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(GlassEffects oldWidget) =>
      oldWidget.enabled != enabled;
}

/// Alpha of a floating pill's shadow once it is fully surfaced.
const double _kPillShadowOpacity = 0.12;

/// The painted chrome of a floating pill or rounded surface: GroovyBox's port
/// of Solian's `PillSurface`, so the two apps' floating chrome reads as one
/// system.
///
/// **This is the one glass material in the app.** A capsule, the now-playing
/// dock and every page header paint through it; nothing else builds a
/// `LiquidGlassLayer` of its own.
///
/// Geometry is fixed: the surface keeps the same [margin], [radius] and
/// padding at every scroll offset, so its controls never move under the
/// user's thumb. Only the fill fades with [t] (0..1): invisible at rest,
/// glass (or a tonal Material fill) once the page moves beneath it.
///
/// When [GlassEffects] is on, a [LiquidGlassLayer] samples the page behind
/// the surface and refracts it through a [LiquidRoundedSuperellipse]. When it
/// is off, the same shape is painted as a `colorScheme.surfaceContainer` fill
/// with an elevation shadow — same geometry, same fade, no backdrop sample or
/// shader pass.
///
/// The surface layer is skipped while [t] is 0: there is nothing under the bar
/// yet, and an idle layer would still copy the backdrop.
///
/// The glass samples what is painted *behind* it, so a surface has to sit in a
/// stack over the content it floats above (a `Scaffold` slot with
/// `extendBody`, or a `Stack`). Painting it inside an opaque ancestor hides
/// the effect rather than breaking it.
class PillSurface extends StatelessWidget {
  /// Fade position, 0..1. Drives the surface and shadow together.
  final double t;

  /// Outer margin of the surface, painted against the container it floats in.
  final EdgeInsetsGeometry margin;

  /// Corner radius of the surface. [SolRadius.pillRadius] collapses to a
  /// capsule.
  final BorderRadius radius;

  /// Inset of [child] inside the surface.
  final EdgeInsetsGeometry contentPadding;

  final Widget child;

  const PillSurface({
    super.key,
    this.t = 1.0,
    this.margin = EdgeInsets.zero,
    this.radius = SolRadius.pillRadius,
    this.contentPadding = EdgeInsets.zero,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveT = t.clamp(0.0, 1.0);

    return Container(
      margin: margin,
      // The shadow wraps the Stack so it always paints behind the surface,
      // never over the glass. A plain [DecoratedBox] tracks [t] synchronously
      // without restarting an implicit animation on every scroll frame.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: effectiveT == 0
              ? null
              : [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(
                      alpha: _kPillShadowOpacity * effectiveT,
                    ),
                    blurRadius: 12 * effectiveT,
                    offset: Offset(0, 4 * effectiveT),
                  ),
                ],
        ),
        // `passthrough` so the surface's height comes from its controls: the
        // glass layer is positioned and contributes no size of its own.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (effectiveT > 0)
              Positioned.fill(
                child: GlassEffects.of(context)
                    ? LiquidGlassLayer(
                        // Every floating surface samples the same page plane,
                        // so they share one backdrop capture: two independent
                        // captures in one frame are two full-screen readbacks.
                        useBackdropGroup: true,
                        settings: LiquidGlassSettings.ios27Regular(
                          brightness: theme.brightness,
                        ),
                        // Layer-level appearance: the surface holds a single
                        // shape, and the layer path is the cheaper shader one.
                        defaultAppearance: LiquidGlassAppearance.ios27Regular(
                          brightness: theme.brightness,
                        ).copyWith(visibility: effectiveT),
                        child: LiquidGlass(
                          shape: LiquidRoundedSuperellipse(
                            borderRadius: radius.topLeft.x,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer.withValues(
                            alpha: effectiveT,
                          ),
                          borderRadius: radius,
                        ),
                      ),
              ),
            Padding(
              padding: contentPadding,
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
