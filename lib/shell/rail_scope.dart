import 'package:material_ui/material_ui.dart';

/// Shell-level handle for the wide layout's navigation rail.
///
/// Ported from Solian's `NavigationRailScope`: on the wide layout the rail is
/// the only navigation surface, so a page's menu button expands it over every
/// destination instead of opening a drawer. The shell owns the flag; this
/// scope is how a page header reaches it.
class RailScope extends InheritedWidget {
  /// Whether this layout presents a rail at all (wide windows only).
  final bool available;

  /// Whether the rail is expanded, showing labels for every destination.
  final bool expanded;

  final VoidCallback toggle;

  const RailScope({
    super.key,
    required this.available,
    required this.expanded,
    required this.toggle,
    required super.child,
  });

  static RailScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RailScope>();

  @override
  bool updateShouldNotify(RailScope oldWidget) =>
      available != oldWidget.available || expanded != oldWidget.expanded;
}
