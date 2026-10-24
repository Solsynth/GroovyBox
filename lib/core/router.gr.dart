// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i9;
import 'package:groovy_box/screens/albums.dart' as _i1;
import 'package:groovy_box/screens/browse.dart' as _i2;
import 'package:groovy_box/screens/player_screen.dart' as _i3;
import 'package:groovy_box/screens/playlists.dart' as _i4;
import 'package:groovy_box/screens/queue.dart' as _i5;
import 'package:groovy_box/screens/settings.dart' as _i6;
import 'package:groovy_box/screens/setup.dart' as _i7;
import 'package:groovy_box/shell/shell_screen.dart' as _i8;
import 'package:material_ui/material_ui.dart' as _i10;

/// generated route for
/// [_i1.AlbumDetailScreen]
class AlbumDetailRoute extends _i9.PageRouteInfo<AlbumDetailRouteArgs> {
  AlbumDetailRoute({
    _i10.Key? key,
    required String albumId,
    String? albumName,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         AlbumDetailRoute.name,
         args: AlbumDetailRouteArgs(
           key: key,
           albumId: albumId,
           albumName: albumName,
         ),
         rawPathParams: {'albumId': albumId},
         initialChildren: children,
       );

  static const String name = 'AlbumDetailRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<AlbumDetailRouteArgs>(
        orElse: () =>
            AlbumDetailRouteArgs(albumId: pathParams.getString('albumId')),
      );
      return _i1.AlbumDetailScreen(
        key: args.key,
        albumId: args.albumId,
        albumName: args.albumName,
      );
    },
  );
}

class AlbumDetailRouteArgs {
  const AlbumDetailRouteArgs({this.key, required this.albumId, this.albumName});

  final _i10.Key? key;

  final String albumId;

  final String? albumName;

  @override
  String toString() {
    return 'AlbumDetailRouteArgs{key: $key, albumId: $albumId, albumName: $albumName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AlbumDetailRouteArgs) return false;
    return key == other.key &&
        albumId == other.albumId &&
        albumName == other.albumName;
  }

  @override
  int get hashCode => key.hashCode ^ albumId.hashCode ^ albumName.hashCode;
}

/// generated route for
/// [_i1.AlbumsScreen]
class AlbumsRoute extends _i9.PageRouteInfo<void> {
  const AlbumsRoute({List<_i9.PageRouteInfo>? children})
    : super(AlbumsRoute.name, initialChildren: children);

  static const String name = 'AlbumsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i1.AlbumsScreen();
    },
  );
}

/// generated route for
/// [_i2.BrowseScreen]
class BrowseRoute extends _i9.PageRouteInfo<void> {
  const BrowseRoute({List<_i9.PageRouteInfo>? children})
    : super(BrowseRoute.name, initialChildren: children);

  static const String name = 'BrowseRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i2.BrowseScreen();
    },
  );
}

/// generated route for
/// [_i3.PlayerScreen]
class PlayerRoute extends _i9.PageRouteInfo<void> {
  const PlayerRoute({List<_i9.PageRouteInfo>? children})
    : super(PlayerRoute.name, initialChildren: children);

  static const String name = 'PlayerRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i3.PlayerScreen();
    },
  );
}

/// generated route for
/// [_i4.PlaylistDetailScreen]
class PlaylistDetailRoute extends _i9.PageRouteInfo<PlaylistDetailRouteArgs> {
  PlaylistDetailRoute({
    _i10.Key? key,
    required String playlistId,
    String? playlistName,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         PlaylistDetailRoute.name,
         args: PlaylistDetailRouteArgs(
           key: key,
           playlistId: playlistId,
           playlistName: playlistName,
         ),
         rawPathParams: {'playlistId': playlistId},
         initialChildren: children,
       );

  static const String name = 'PlaylistDetailRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PlaylistDetailRouteArgs>(
        orElse: () => PlaylistDetailRouteArgs(
          playlistId: pathParams.getString('playlistId'),
        ),
      );
      return _i4.PlaylistDetailScreen(
        key: args.key,
        playlistId: args.playlistId,
        playlistName: args.playlistName,
      );
    },
  );
}

class PlaylistDetailRouteArgs {
  const PlaylistDetailRouteArgs({
    this.key,
    required this.playlistId,
    this.playlistName,
  });

  final _i10.Key? key;

  final String playlistId;

  final String? playlistName;

  @override
  String toString() {
    return 'PlaylistDetailRouteArgs{key: $key, playlistId: $playlistId, playlistName: $playlistName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlaylistDetailRouteArgs) return false;
    return key == other.key &&
        playlistId == other.playlistId &&
        playlistName == other.playlistName;
  }

  @override
  int get hashCode =>
      key.hashCode ^ playlistId.hashCode ^ playlistName.hashCode;
}

/// generated route for
/// [_i4.PlaylistsScreen]
class PlaylistsRoute extends _i9.PageRouteInfo<void> {
  const PlaylistsRoute({List<_i9.PageRouteInfo>? children})
    : super(PlaylistsRoute.name, initialChildren: children);

  static const String name = 'PlaylistsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i4.PlaylistsScreen();
    },
  );
}

/// generated route for
/// [_i5.QueueScreen]
class QueueRoute extends _i9.PageRouteInfo<void> {
  const QueueRoute({List<_i9.PageRouteInfo>? children})
    : super(QueueRoute.name, initialChildren: children);

  static const String name = 'QueueRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i5.QueueScreen();
    },
  );
}

/// generated route for
/// [_i6.SettingsScreen]
class SettingsRoute extends _i9.PageRouteInfo<void> {
  const SettingsRoute({List<_i9.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i6.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i7.SetupScreen]
class SetupRoute extends _i9.PageRouteInfo<void> {
  const SetupRoute({List<_i9.PageRouteInfo>? children})
    : super(SetupRoute.name, initialChildren: children);

  static const String name = 'SetupRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i7.SetupScreen();
    },
  );
}

/// generated route for
/// [_i8.ShellScreen]
class ShellRoute extends _i9.PageRouteInfo<void> {
  const ShellRoute({List<_i9.PageRouteInfo>? children})
    : super(ShellRoute.name, initialChildren: children);

  static const String name = 'ShellRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i8.ShellScreen();
    },
  );
}
