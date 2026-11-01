import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

/// A tab's own navigation stack.
///
/// The shell switches between tabs; pages opened *above* a tab — an album, a
/// playlist, settings — are pushed onto that tab's stack instead of the root
/// one. That keeps the shell mounted, so the now-playing capsule keeps
/// floating over every page inside the tabs. At the root the same pages would
/// cover the shell, and with it the dock.
///
/// Each class is only a nested [AutoRouter]; the pages themselves are declared
/// as children in `AppRouter`.
@RoutePage()
class BrowseTab extends StatelessWidget {
  const BrowseTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// See [BrowseTab].
@RoutePage()
class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// See [BrowseTab].
@RoutePage()
class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// See [BrowseTab].
@RoutePage()
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}
