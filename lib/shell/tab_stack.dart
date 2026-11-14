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
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// See [ExploreTab].
@RoutePage()
class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// The collection tab: albums and playlists, one page in two shapes.
///
/// See [ExploreTab].
@RoutePage()
class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// See [ExploreTab].
@RoutePage()
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// See [ExploreTab].
@RoutePage()
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}
