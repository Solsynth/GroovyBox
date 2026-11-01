// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i10;
import 'package:groovy_box/screens/albums.dart' as _i1;
import 'package:groovy_box/screens/browse.dart' as _i3;
import 'package:groovy_box/screens/player_screen.dart' as _i4;
import 'package:groovy_box/screens/playlists.dart' as _i5;
import 'package:groovy_box/screens/settings.dart' as _i6;
import 'package:groovy_box/screens/setup.dart' as _i7;
import 'package:groovy_box/screens/stats.dart' as _i9;
import 'package:groovy_box/shell/shell_screen.dart' as _i8;
import 'package:groovy_box/shell/tab_stack.dart' as _i2;
import 'package:material_ui/material_ui.dart' as _i11;

/// generated route for
/// [_i1.AlbumDetailScreen]
class AlbumDetailRoute extends _i10.PageRouteInfo<AlbumDetailRouteArgs> {
  AlbumDetailRoute({
    _i11.Key? key,
    required String sourceId,
    required String albumId,
    String? albumName,
    List<_i10.PageRouteInfo>? children,
  }) : super(
         AlbumDetailRoute.name,
         args: AlbumDetailRouteArgs(
           key: key,
           sourceId: sourceId,
           albumId: albumId,
           albumName: albumName,
         ),
         rawPathParams: {'sourceId': sourceId, 'albumId': albumId},
         initialChildren: children,
       );

  static const String name = 'AlbumDetailRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<AlbumDetailRouteArgs>(
        orElse: () => AlbumDetailRouteArgs(
          sourceId: pathParams.getString('sourceId'),
          albumId: pathParams.getString('albumId'),
        ),
      );
      return _i1.AlbumDetailScreen(
        key: args.key,
        sourceId: args.sourceId,
        albumId: args.albumId,
        albumName: args.albumName,
      );
    },
  );
}

class AlbumDetailRouteArgs {
  const AlbumDetailRouteArgs({
    this.key,
    required this.sourceId,
    required this.albumId,
    this.albumName,
  });

  final _i11.Key? key;

  final String sourceId;

  final String albumId;

  final String? albumName;

  @override
  String toString() {
    return 'AlbumDetailRouteArgs{key: $key, sourceId: $sourceId, albumId: $albumId, albumName: $albumName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AlbumDetailRouteArgs) return false;
    return key == other.key &&
        sourceId == other.sourceId &&
        albumId == other.albumId &&
        albumName == other.albumName;
  }

  @override
  int get hashCode =>
      key.hashCode ^ sourceId.hashCode ^ albumId.hashCode ^ albumName.hashCode;
}

/// generated route for
/// [_i1.AlbumsScreen]
class AlbumsRoute extends _i10.PageRouteInfo<void> {
  const AlbumsRoute({List<_i10.PageRouteInfo>? children})
    : super(AlbumsRoute.name, initialChildren: children);

  static const String name = 'AlbumsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i1.AlbumsScreen();
    },
  );
}

/// generated route for
/// [_i2.AlbumsTab]
class AlbumsTab extends _i10.PageRouteInfo<void> {
  const AlbumsTab({List<_i10.PageRouteInfo>? children})
    : super(AlbumsTab.name, initialChildren: children);

  static const String name = 'AlbumsTab';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i2.AlbumsTab();
    },
  );
}

/// generated route for
/// [_i3.BrowseScreen]
class BrowseRoute extends _i10.PageRouteInfo<void> {
  const BrowseRoute({List<_i10.PageRouteInfo>? children})
    : super(BrowseRoute.name, initialChildren: children);

  static const String name = 'BrowseRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i3.BrowseScreen();
    },
  );
}

/// generated route for
/// [_i2.BrowseTab]
class BrowseTab extends _i10.PageRouteInfo<void> {
  const BrowseTab({List<_i10.PageRouteInfo>? children})
    : super(BrowseTab.name, initialChildren: children);

  static const String name = 'BrowseTab';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i2.BrowseTab();
    },
  );
}

/// generated route for
/// [_i4.PlayerScreen]
class PlayerRoute extends _i10.PageRouteInfo<void> {
  const PlayerRoute({List<_i10.PageRouteInfo>? children})
    : super(PlayerRoute.name, initialChildren: children);

  static const String name = 'PlayerRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i4.PlayerScreen();
    },
  );
}

/// generated route for
/// [_i5.PlaylistDetailScreen]
class PlaylistDetailRoute extends _i10.PageRouteInfo<PlaylistDetailRouteArgs> {
  PlaylistDetailRoute({
    _i11.Key? key,
    required String sourceId,
    required String playlistId,
    String? playlistName,
    List<_i10.PageRouteInfo>? children,
  }) : super(
         PlaylistDetailRoute.name,
         args: PlaylistDetailRouteArgs(
           key: key,
           sourceId: sourceId,
           playlistId: playlistId,
           playlistName: playlistName,
         ),
         rawPathParams: {'sourceId': sourceId, 'playlistId': playlistId},
         initialChildren: children,
       );

  static const String name = 'PlaylistDetailRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PlaylistDetailRouteArgs>(
        orElse: () => PlaylistDetailRouteArgs(
          sourceId: pathParams.getString('sourceId'),
          playlistId: pathParams.getString('playlistId'),
        ),
      );
      return _i5.PlaylistDetailScreen(
        key: args.key,
        sourceId: args.sourceId,
        playlistId: args.playlistId,
        playlistName: args.playlistName,
      );
    },
  );
}

class PlaylistDetailRouteArgs {
  const PlaylistDetailRouteArgs({
    this.key,
    required this.sourceId,
    required this.playlistId,
    this.playlistName,
  });

  final _i11.Key? key;

  final String sourceId;

  final String playlistId;

  final String? playlistName;

  @override
  String toString() {
    return 'PlaylistDetailRouteArgs{key: $key, sourceId: $sourceId, playlistId: $playlistId, playlistName: $playlistName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlaylistDetailRouteArgs) return false;
    return key == other.key &&
        sourceId == other.sourceId &&
        playlistId == other.playlistId &&
        playlistName == other.playlistName;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sourceId.hashCode ^
      playlistId.hashCode ^
      playlistName.hashCode;
}

/// generated route for
/// [_i5.PlaylistsScreen]
class PlaylistsRoute extends _i10.PageRouteInfo<void> {
  const PlaylistsRoute({List<_i10.PageRouteInfo>? children})
    : super(PlaylistsRoute.name, initialChildren: children);

  static const String name = 'PlaylistsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i5.PlaylistsScreen();
    },
  );
}

/// generated route for
/// [_i2.PlaylistsTab]
class PlaylistsTab extends _i10.PageRouteInfo<void> {
  const PlaylistsTab({List<_i10.PageRouteInfo>? children})
    : super(PlaylistsTab.name, initialChildren: children);

  static const String name = 'PlaylistsTab';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i2.PlaylistsTab();
    },
  );
}

/// generated route for
/// [_i6.SettingsScreen]
class SettingsRoute extends _i10.PageRouteInfo<void> {
  const SettingsRoute({List<_i10.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i6.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i7.SetupScreen]
class SetupRoute extends _i10.PageRouteInfo<void> {
  const SetupRoute({List<_i10.PageRouteInfo>? children})
    : super(SetupRoute.name, initialChildren: children);

  static const String name = 'SetupRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i7.SetupScreen();
    },
  );
}

/// generated route for
/// [_i8.ShellScreen]
class ShellRoute extends _i10.PageRouteInfo<void> {
  const ShellRoute({List<_i10.PageRouteInfo>? children})
    : super(ShellRoute.name, initialChildren: children);

  static const String name = 'ShellRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i8.ShellScreen();
    },
  );
}

/// generated route for
/// [_i9.StatsScreen]
class StatsRoute extends _i10.PageRouteInfo<void> {
  const StatsRoute({List<_i10.PageRouteInfo>? children})
    : super(StatsRoute.name, initialChildren: children);

  static const String name = 'StatsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i9.StatsScreen();
    },
  );
}

/// generated route for
/// [_i2.StatsTab]
class StatsTab extends _i10.PageRouteInfo<void> {
  const StatsTab({List<_i10.PageRouteInfo>? children})
    : super(StatsTab.name, initialChildren: children);

  static const String name = 'StatsTab';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i2.StatsTab();
    },
  );
}
