import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One root destination in the shell: rail, bottom bar, or drawer.
class TabDestination {
  final String id;

  /// Position in `AutoTabsRouter.routes`.
  final int routeIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const TabDestination({
    required this.id,
    required this.routeIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  Widget iconFor(bool selected) => Icon(selected ? selectedIcon : icon);
}

/// Every root tab, in route order. Mirrors the child order in `AppRouter`.
List<TabDestination> get allTabDestinations => const [
  TabDestination(
    id: 'browse',
    routeIndex: 0,
    label: 'Browse',
    icon: Symbols.explore,
    selectedIcon: Symbols.explore_rounded,
  ),
  TabDestination(
    id: 'albums',
    routeIndex: 1,
    label: 'Albums',
    icon: Symbols.album,
    selectedIcon: Symbols.album_rounded,
  ),
  TabDestination(
    id: 'playlists',
    routeIndex: 2,
    label: 'Playlists',
    icon: Symbols.playlist_play,
    selectedIcon: Symbols.playlist_play_rounded,
  ),
  TabDestination(
    id: 'queue',
    routeIndex: 3,
    label: 'Queue',
    icon: Symbols.queue_music,
    selectedIcon: Symbols.queue_music_rounded,
  ),
];

/// The compact bottom bar carries Browse, Albums, Playlists and Queue. Settings
/// lives behind the header's overflow there instead of taking a slot.
const kBottomBarIds = ['browse', 'albums', 'playlists', 'queue'];

/// Settings is a pushed route, not a tab, so it is not part of
/// [allTabDestinations]. Both shells still need one button for it, and they
/// must not disagree about its label or icon — hence one constant
/// destination. `routeIndex` is -1 on purpose: nothing may select it through
/// the tabs router.
const kSettingsLabel = 'Settings';
const kSettingsIcon = Symbols.settings;

const kSettingsDestination = TabDestination(
  id: 'settings',
  routeIndex: -1,
  label: kSettingsLabel,
  icon: kSettingsIcon,
  selectedIcon: kSettingsIcon,
);

List<TabDestination> get bottomBarDestinations => allTabDestinations
    .where((destination) => kBottomBarIds.contains(destination.id))
    .toList();
