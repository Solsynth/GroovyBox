import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'router.gr.dart';

final routerProvider = Provider<AppRouter>((ref) => AppRouter());

/// The app's route table.
///
/// Tabs live under the shell route so each keeps its own navigation stack. The
/// player, album and playlist details are standalone pushes above the shell.
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
          page: BrowseRoute.page,
          path: 'browse',
          initial: true,
          maintainState: false,
        ),
        AutoRoute(
          page: AlbumsRoute.page,
          path: 'albums',
          maintainState: false,
        ),
        AutoRoute(
          page: PlaylistsRoute.page,
          path: 'playlists',
          maintainState: false,
        ),
        AutoRoute(
          page: QueueRoute.page,
          path: 'queue',
          maintainState: false,
        ),
      ],
    ),
    AutoRoute(page: AlbumDetailRoute.page, path: '/albums/:albumId'),
    AutoRoute(page: PlaylistDetailRoute.page, path: '/playlists/:playlistId'),
    AutoRoute(page: PlayerRoute.page, path: '/now-playing'),
    AutoRoute(page: SetupRoute.page, path: '/setup'),
    AutoRoute(page: SettingsRoute.page, path: '/settings'),
  ];
}
