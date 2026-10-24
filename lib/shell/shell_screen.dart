import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/router.gr.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/now_playing_dock.dart';
import 'tab_destinations.dart';
import 'window_frame.dart';

/// Shell that hosts the four root tabs.
///
/// Tab state lives in `AutoTabsRouter`, never in local widget state: the wide
/// rail, the compact bottom bar and the drawer all drive the same router, and
/// each tab keeps its own navigation stack.
@RoutePage()
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // The transport is created with the shell, not with the dock, so audio
        // starts the moment the window does and keeps running when the dock is
        // rebuilt.
        ref.read(playbackProvider);

        return AutoTabsRouter(
          routes: const [
            BrowseRoute(),
            AlbumsRoute(),
            PlaylistsRoute(),
            QueueRoute(),
          ],
          duration: const Duration(milliseconds: 320),
          builder: (context, child) => _ShellFrame(child: child),
        );
      },
    );
  }
}

class _ShellFrame extends ConsumerWidget {
  final Widget child;

  const _ShellFrame({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = AutoTabsRouter.of(context);
    final wide = isWideScreen(context);
    final isDesktop = DesktopWindowFrame.isPlatformDesktop;

    final body = Column(
      children: [
        Expanded(child: child),
        const NowPlayingDock(),
      ],
    );

    if (wide) {
      return _WideShell(
        selectedIndex: tabs.activeIndex,
        onSelected: tabs.setActiveIndex,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        // Desktop windows have no notch and already sit inside the title bar.
        top: !isDesktop,
        child: body,
      ),
      bottomNavigationBar: _PillBottomNav(
        selectedIndex: _bottomIndexFor(tabs.activeIndex),
        onSelected: (index) {
          final destination = bottomBarDestinations[index];
          tabs.setActiveIndex(destination.routeIndex);
        },
        onSettings: () => tabs.setActiveIndex(
          allTabDestinations.firstWhere((d) => d.id == 'settings').routeIndex,
        ),
      ),
    );
  }

  /// The bottom bar carries a subset of destinations, so the router's active
  /// index has to be mapped onto the bar's own index.
  int _bottomIndexFor(int routeIndex) {
    final index = bottomBarDestinations.indexWhere(
      (destination) => destination.routeIndex == routeIndex,
    );
    return index < 0 ? 0 : index;
  }
}

class _WideShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  const _WideShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = allTabDestinations;
    final railIndex = destinations.indexWhere(
      (destination) => destination.routeIndex == selectedIndex,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // The rail is the wide layout's navigation: a quiet column of icons
          // over the same paper the page uses, separated by tone, not by a
          // border or a shadow.
          NavigationRail(
            backgroundColor: Colors.transparent,
            extended: false,
            labelType: NavigationRailLabelType.all,
            scrollable: true,
            groupAlignment: -0.9,
            leading: const Padding(
              padding: EdgeInsets.fromLTRB(0, SolSpace.lg, 0, SolSpace.xl),
              child: _RailWordmark(),
            ),
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: destination.iconFor(false),
                  selectedIcon: destination.iconFor(true),
                  label: Text(destination.label),
                ),
            ],
            selectedIndex: railIndex < 0 ? 0 : railIndex,
            onDestinationSelected: (index) =>
                onSelected(destinations[index].routeIndex),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RailWordmark extends StatelessWidget {
  const _RailWordmark();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Symbols.graphic_eq_rounded,
      size: 26,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

/// Floating capsule bar for the compact layout.
///
/// Each side is inset from the viewport, and the home-indicator inset is spent
/// below the capsule instead of inside it, so the bar floats clear of the
/// system chrome.
class _PillBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettings;

  const _PillBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
  });

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SolSpace.md,
        SolSpace.md,
        SolSpace.md,
        SolSpace.md + safeBottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: SolRadius.pillRadius,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: _height,
          child: Row(
            children: [
              Expanded(
                child: NavigationBar(
                  height: _height,
                  backgroundColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  destinations: [
                    for (var i = 0; i < bottomBarDestinations.length; i++)
                      NavigationDestination(
                        tooltip: '',
                        icon: bottomBarDestinations[i].iconFor(
                          selectedIndex == i,
                        ),
                        label: bottomBarDestinations[i].label,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Symbols.settings),
                tooltip: 'Settings',
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: SolSpace.sm),
            ],
          ),
        ),
      ),
    );
  }
}
