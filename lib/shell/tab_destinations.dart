import 'package:easy_localization/easy_localization.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One root destination in the shell: rail, bottom bar, or drawer.
class TabDestination {
  final String id;

  /// Position in `AutoTabsRouter.routes`.
  final int routeIndex;

  /// Translation key for the tab's name. Resolved with `.tr()` where the
  /// label is drawn: these destinations are `const`, so they cannot translate
  /// at definition time, and the key keeps one label in one place.
  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;

  const TabDestination({
    required this.id,
    required this.routeIndex,
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
  });

  String get label => labelKey.tr();

  Widget iconFor(bool selected) => Icon(selected ? selectedIcon : icon);
}

/// There is no Queue tab: the queue is a pane of the player and a sheet in the
/// now-playing dock, so a third place to see the same list only made the
/// transport's own controls compete with a page. Settings is the fifth tab:
/// sources and preferences are a destination, not a page hidden behind a gear.
List<TabDestination> get allTabDestinations => const [
  TabDestination(
    id: 'explore',
    routeIndex: 0,
    labelKey: 'tabExplore',
    icon: Symbols.explore,
    selectedIcon: Symbols.explore_rounded,
  ),
  TabDestination(
    id: 'search',
    routeIndex: 1,
    labelKey: 'tabSearch',
    icon: Symbols.search,
    selectedIcon: Symbols.search_rounded,
  ),
  TabDestination(
    id: 'library',
    routeIndex: 2,
    labelKey: 'tabAlbums',
    icon: Symbols.library_music,
    selectedIcon: Symbols.library_music_rounded,
  ),
  TabDestination(
    id: 'profile',
    routeIndex: 3,
    labelKey: 'tabProfile',
    icon: Symbols.account_circle,
    selectedIcon: Symbols.account_circle_rounded,
  ),
  TabDestination(
    id: 'settings',
    routeIndex: 4,
    labelKey: 'tabSettings',
    icon: Symbols.settings,
    selectedIcon: Symbols.settings_rounded,
  ),
];

/// The compact bottom bar carries every root tab, settings included.
List<TabDestination> get bottomBarDestinations => allTabDestinations;
