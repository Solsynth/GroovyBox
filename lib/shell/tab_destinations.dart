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

/// Every root tab, in route order. Mirrors the child order in `AppRouter`.
///
/// There is no Queue tab: the queue is a pane of the player and a sheet in the
/// now-playing dock, so a third place to see the same list only made the
/// transport's own controls compete with a page. Stats took the slot, because
/// a play history with nowhere to read it is a database nobody sees.
List<TabDestination> get allTabDestinations => const [
  TabDestination(
    id: 'browse',
    routeIndex: 0,
    labelKey: 'tabBrowse',
    icon: Symbols.explore,
    selectedIcon: Symbols.explore_rounded,
  ),
  TabDestination(
    id: 'albums',
    routeIndex: 1,
    labelKey: 'tabAlbums',
    icon: Symbols.album,
    selectedIcon: Symbols.album_rounded,
  ),
  TabDestination(
    id: 'playlists',
    routeIndex: 2,
    labelKey: 'tabPlaylists',
    icon: Symbols.playlist_play,
    selectedIcon: Symbols.playlist_play_rounded,
  ),
  TabDestination(
    id: 'stats',
    routeIndex: 3,
    labelKey: 'tabStats',
    icon: Symbols.query_stats,
    selectedIcon: Symbols.query_stats_rounded,
  ),
];

/// The compact bottom bar carries every root tab. Settings lives behind the
/// header's overflow there instead of taking a slot.
const kBottomBarIds = ['browse', 'albums', 'playlists', 'stats'];

/// Settings is a pushed route, not a tab, so it is not part of
/// [allTabDestinations]. Both shells still need one button for it, and they
/// must not disagree about its label or icon — hence one constant
/// destination. `routeIndex` is -1 on purpose: nothing may select it through
/// the tabs router.
const kSettingsLabelKey = 'tabSettings';
const kSettingsIcon = Symbols.settings;

const kSettingsDestination = TabDestination(
  id: 'settings',
  routeIndex: -1,
  labelKey: kSettingsLabelKey,
  icon: kSettingsIcon,
  selectedIcon: kSettingsIcon,
);

List<TabDestination> get bottomBarDestinations => allTabDestinations
    .where((destination) => kBottomBarIds.contains(destination.id))
    .toList();
