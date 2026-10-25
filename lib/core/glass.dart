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

/// Alpha of a floating surface's shadow.
const double _kGlassShadowOpacity = 0.16;

/// Floating chrome: a capsule or squircle painted as iOS 27 regular glass when
/// [GlassEffects] is on, and as a flat tonal fill with a hairline when it is
/// off or the platform cannot run the shader.
///
/// Geometry is identical in both branches — same margin, radius and padding —
/// so toggling the material never moves a control. Only the paint changes.
///
/// **This is for chrome that floats over content**, never for cards: the
/// navigation capsules, the now-playing dock and the rail. Anything in the
/// scrolling plane is an `IslandCard`, which is tonal and opaque so text stays
/// legible and long lists stay cheap; the player page paints no card at all,
/// because its blurred field already is the surface.
///
/// The glass samples the page painted *behind* it, so the surface has to sit
/// in a stack over the content it floats above (a `Scaffold` slot with
/// `extendBody`, or a `Stack`). Painting it inside an opaque ancestor hides
/// the effect rather than breaking it.
class GlassSurface extends StatelessWidget {
  final Widget child;

  /// Corner radius in logical pixels. [SolRadius.pill] collapses to a capsule.
  final double cornerRadius;

  final EdgeInsets margin;
  final EdgeInsets padding;

  /// Material tint. Its alpha controls how strongly it mixes with the
  /// backdrop; leave null for the neutral material.
  final Color? tint;

  /// Whether to draw the exterior shadow. Off for surfaces flush with a page.
  final bool shadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.cornerRadius = SolRadius.card,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(cornerRadius);
    final shadows = shadow
        ? [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: _kGlassShadowOpacity),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];
    // Transparent Material so ripples and tooltips paint *above* the glass
    // instead of on the scaffold surface underneath it.
    final content = Material(
      type: MaterialType.transparency,
      child: Padding(padding: padding, child: child),
    );

    if (!GlassEffects.of(context)) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
          borderRadius: radius,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: shadows,
        ),
        child: content,
      );
    }

    return Container(
      margin: margin,
      child: LiquidGlassLayer(
        // Every floating capsule samples the same page plane, so they share
        // one backdrop capture: two independent captures in one frame are two
        // full-screen readbacks.
        useBackdropGroup: true,
        settings: LiquidGlassSettings.ios27Regular(
          brightness: theme.brightness,
        ),
        defaultAppearance: LiquidGlassAppearance.ios27Regular(
          brightness: theme.brightness,
          tint: tint ?? const Color(0x00007AFF),
        ),
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: cornerRadius),
          shadows: shadows,
          child: content,
        ),
      ),
    );
  }
}
