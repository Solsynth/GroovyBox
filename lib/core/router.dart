import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/shell/dock_morph.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final routerProvider = Provider<AppRouter>((ref) => AppRouter());

/// Every tab can open the same detail pages, and each opens them on its own
/// stack: switching tabs mid-album keeps the other tab where it was.
List<AutoRoute> _tabChildren(AutoRoute root) => [
  root,
  AutoRoute(page: AlbumDetailRoute.page, path: 'albums/:sourceId/:albumId'),
  AutoRoute(
    page: PlaylistDetailRoute.page,
    path: 'playlists/:sourceId/:playlistId',
  ),
  AutoRoute(
    page: ArtistDetailRoute.page,
    path: 'artists/:sourceId/:artistId',
  ),
  AutoRoute(
    page: PulsarPlaylistDetailRoute.page,
    path: 'cloud-playlists/:playlistId',
  ),
  AutoRoute(
    page: OwnedPlaylistDetailRoute.page,
    path: 'owned-playlists/:playlistId',
  ),
];

/// The app's route table.
///
/// The shell hosts five tabs, and each tab owns a navigation stack of its
/// own (see `tab_stack.dart`). Album and playlist pages are declared *inside*
/// those stacks rather than at the root: pushing them there keeps the shell —
/// and with it the now-playing capsule — on screen, which a root-level page
/// would cover.
///
/// Settings is its own tab: explore opens the window, search answers "do I
/// have this, and could I?", the library is the catalogue, the play history
/// keeps the last slot, and settings is where sources and preferences live.
/// The player is the exception. It is the expanded dock, so it is pushed above
/// the shell and grows out of the capsule it was opened from.
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType =>
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
      ? const RouteType.cupertino()
      : const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: ShellRoute.page,
      path: '/',
      initial: true,
      children: [
        AutoRoute(
          page: ExploreTab.page,
          initial: true,
          children: _tabChildren(
            AutoRoute(page: ExploreRoute.page, initial: true),
          ),
        ),
        AutoRoute(
          page: SearchTab.page,
          children: _tabChildren(
            AutoRoute(page: SearchRoute.page, initial: true),
          ),
        ),
        AutoRoute(
          page: LibraryTab.page,
          children: _tabChildren(
            AutoRoute(page: LibraryRoute.page, initial: true),
          ),
        ),
        AutoRoute(
          page: ProfileTab.page,
          children: _tabChildren(
            AutoRoute(page: ProfileRoute.page, initial: true),
          ),
        ),
        AutoRoute(
          page: SettingsTab.page,
          children: _tabChildren(
            AutoRoute(page: SettingsRoute.page, initial: true),
          ),
        ),
      ],
    ),
    // The player grows out of the dock capsule it was opened from: see
    // `dockMorphTransition`. Non-opaque so the page the capsule floated over
    // stays visible while the capsule expands.
    CustomRoute(
      page: PlayerRoute.page,
      path: '/now-playing',
      transitionsBuilder: dockMorphTransition,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    ),
    AutoRoute(page: SetupRoute.page, path: '/setup'),
  ];
}
