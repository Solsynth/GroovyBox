import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/glass.dart';
import '../core/router.gr.dart';
import '../core/responsive.dart';
import '../core/tab_navigation.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/now_playing_dock.dart';
import 'rail_scope.dart';
import 'tab_destinations.dart';
import 'window_frame.dart';

/// Shell that hosts the four root tabs.
///
/// Tab state lives in `AutoTabsRouter`, never in local widget state: the wide
/// rail and the compact bottom bar both drive the same router, and each tab
/// keeps its own navigation stack.
///
/// Compact layout: navigation and the now-playing dock *float* over the page
/// as glass capsules. The page scrolls underneath, which is what gives the
/// glass something to refract; pages reserve clearance themselves via
/// `solBottomChromeInset`.
///
/// Wide layout: the rail is a solid column beside the page, exactly like
/// Solian's — no second navigation surface, no divider, and menu requests from
/// page headers expand it in place (see [RailScope]).
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
          // Each tab is an `AutoRouter` with its own stack, so pushing an
          // album or playlist inside a tab keeps the shell — and the
          // now-playing capsule that floats in it — on screen.
          routes: const [BrowseTab(), AlbumsTab(), PlaylistsTab(), StatsTab()],
          duration: const Duration(milliseconds: 320),
          builder: (context, child) => _ShellFrame(child: child),
        );
      },
    );
  }
}

class _ShellFrame extends ConsumerStatefulWidget {
  final Widget child;

  const _ShellFrame({required this.child});

  @override
  ConsumerState<_ShellFrame> createState() => _ShellFrameState();
}

class _ShellFrameState extends ConsumerState<_ShellFrame> {
  /// Whether the wide rail is expanded over every destination.
  ///
  /// The rail stands in for a drawer, so a page's menu button expands it
  /// rather than opening a second navigation surface. Narrow layouts have no
  /// rail, so a stale expansion must not survive a width change.
  bool _railExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_railExpanded && !isWideScreen(context)) _railExpanded = false;
  }

  void _toggleRail() => setState(() => _railExpanded = !_railExpanded);

  @override
  Widget build(BuildContext context) {
    final tabs = AutoTabsRouter.of(context);
    final wide = isWideScreen(context);
    final isDesktop = DesktopWindowFrame.isPlatformDesktop;
    if (wide) {
      final page = Stack(
        children: [
          widget.child,
          // Mounted for keeps: the dock folds itself away when nothing
          // is playing, so the frame never swaps it out from under that
          // animation.
          const Positioned(
            bottom: SolSpace.sm,
            left: SolSpace.sm,
            right: SolSpace.sm,
            child: NowPlayingDock(),
          ),
        ],
      );

      return RailScope(
        available: true,
        expanded: _railExpanded,
        toggle: _toggleRail,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            // Desktop windows have no notch and already sit inside the title
            // bar.
            top: !isDesktop,
            bottom: false,
            child: Row(
              children: [
                _WideRail(
                  selectedIndex: tabs.activeIndex,
                  expanded: _railExpanded,
                  onSelected: tabs.setActiveIndex,
                ),
                Expanded(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: page,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        top: !isDesktop,
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // The dock and the tab capsule float over the same page plane,
              // so they share one backdrop capture instead of paying for a
              // full-screen readback each.
              child: BackdropGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NowPlayingDock(),
                    _PillBottomNav(
                      selectedIndex: _bottomIndexFor(tabs.activeIndex),
                      onSelected: (index) {
                        final destination = bottomBarDestinations[index];
                        tabs.setActiveIndex(destination.routeIndex);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
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

/// The wide layout's navigation column.
///
/// Modelled on Solian's rail: a quiet column of the same paper as the page,
/// separated from the content by tone rather than by a border or a shadow. It
/// has no glass — a persistent, always-visible navigation surface is exactly
/// where a sampled material is wasted work, and the page behind it is a flat
/// fill anyway.
///
/// Collapsed it shows icons with small labels; expanded ([RailScope.expanded])
/// it widens to carry full labels, which is what a page header's menu button
/// toggles.
class _WideRail extends StatelessWidget {
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelected;

  const _WideRail({
    required this.selectedIndex,
    required this.expanded,
    required this.onSelected,
  });

  static const double collapsedWidth = 88;
  static const double expandedWidth = 236;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final destinations = allTabDestinations;
    final railIndex = destinations.indexWhere(
      (destination) => destination.routeIndex == selectedIndex,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? expandedWidth : collapsedWidth,
      // Flush to the page: the same paper, one step deeper, and no divider.
      decoration: BoxDecoration(color: colorScheme.surfaceContainer),
      child: Column(
        children: [
          // The wordmark only. Expanding is the page header's menu button —
          // one control, where a drawer button would be on a phone. A second
          // toggle in the rail would be two ways to say the same thing an
          // inch apart.
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SolSpace.md),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const _RailWordmark(),
                  if (expanded) ...[
                    const SizedBox(width: SolSpace.sm),
                    Expanded(
                      child: Text(
                        'GroovyBox',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  _RailDestination(
                    destination: destinations[i],
                    selected: i == (railIndex < 0 ? 0 : railIndex),
                    expanded: expanded,
                    onTap: () => onSelected(destinations[i].routeIndex),
                  ),
                  const SizedBox(height: SolSpace.xs),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.sm,
              SolSpace.sm,
              SolSpace.sm,
              SolSpace.lg,
            ),
            child: _RailDestination(
              destination: kSettingsDestination,
              selected: false,
              expanded: expanded,
              // The rail is above the tabs, so its own router is the root
              // one: pushing here would put Settings *over* the shell and
              // hide the now-playing capsule. Open it in the active tab
              // instead, where the tabs' own pushes go.
              onTap: () => pushInActiveTab(context, const SettingsRoute()),
            ),
          ),
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

/// One destination in the rail. Selection is a tonal pill behind the row, so
/// the rail needs no indicator bar and no divider to say where you are.
class _RailDestination extends StatelessWidget {
  final TabDestination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _RailDestination({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    final icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 22,
      fill: selected ? 1 : 0,
      color: foreground,
    );

    return Tooltip(
      message: expanded ? '' : destination.label,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SolRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? SolSpace.md : 0,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.72)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(SolRadius.md),
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                icon,
                if (expanded) ...[
                  const SizedBox(width: SolSpace.md),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating capsule bar for the compact layout.
///
/// Each side is inset from the viewport, and the home-indicator inset is spent
/// below the capsule instead of inside it, so the bar floats clear of the
/// system chrome and the page keeps scrolling underneath the glass.
///
/// It holds the tabs and nothing else. Settings is reached from the Browse
/// header's gear, which is also where the wide layout offers it in the rail —
/// a second gear a few pixels lower was the same button twice.
class _PillBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PillBottomNav({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        kChromeGutter,
        SolSpace.sm,
        kChromeGutter,
        kChromeGutter + safeBottom,
      ),
      child: GlassSurface(
        cornerRadius: SolRadius.pill,
        padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
        child: SizedBox(
          height: kBottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < bottomBarDestinations.length; i++)
                _NavCapsuleButton(
                  destination: bottomBarDestinations[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab in the floating bar: the selection is a soft pill behind the icon,
/// so the bar needs no indicator rail or divider to say where you are.
class _NavCapsuleButton extends StatelessWidget {
  final TabDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavCapsuleButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: destination.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.secondaryContainer.withValues(alpha: 0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(SolRadius.pill),
          ),
          child: Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: 24,
            fill: selected ? 1 : 0,
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
