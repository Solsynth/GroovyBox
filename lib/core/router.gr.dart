// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i13;
import 'package:groovy_box/screens/albums.dart' as _i1;
import 'package:groovy_box/screens/explore.dart' as _i2;
import 'package:groovy_box/screens/library.dart' as _i4;
import 'package:groovy_box/screens/player_screen.dart' as _i5;
import 'package:groovy_box/screens/playlists.dart' as _i6;
import 'package:groovy_box/screens/profile.dart' as _i7;
import 'package:groovy_box/screens/pulsar_playlist.dart' as _i8;
import 'package:groovy_box/screens/search.dart' as _i9;
import 'package:groovy_box/screens/settings.dart' as _i10;
import 'package:groovy_box/screens/setup.dart' as _i11;
import 'package:groovy_box/shell/shell_screen.dart' as _i12;
import 'package:groovy_box/shell/tab_stack.dart' as _i3;
import 'package:material_ui/material_ui.dart' as _i14;

/// generated route for
/// [_i1.AlbumDetailScreen]
class AlbumDetailRoute extends _i13.PageRouteInfo<AlbumDetailRouteArgs> {
  AlbumDetailRoute({
    _i14.Key? key,
    required String sourceId,
    required String albumId,
    String? albumName,
    List<_i13.PageRouteInfo>? children,
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

  static _i13.PageInfo page = _i13.PageInfo(
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

  final _i14.Key? key;

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
/// [_i2.ExploreScreen]
class ExploreRoute extends _i13.PageRouteInfo<void> {
  const ExploreRoute({List<_i13.PageRouteInfo>? children})
    : super(ExploreRoute.name, initialChildren: children);

  static const String name = 'ExploreRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i2.ExploreScreen();
    },
  );
}

/// generated route for
/// [_i3.ExploreTab]
class ExploreTab extends _i13.PageRouteInfo<void> {
  const ExploreTab({List<_i13.PageRouteInfo>? children})
    : super(ExploreTab.name, initialChildren: children);

  static const String name = 'ExploreTab';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i3.ExploreTab();
    },
  );
}

/// generated route for
/// [_i4.LibraryScreen]
class LibraryRoute extends _i13.PageRouteInfo<void> {
  const LibraryRoute({List<_i13.PageRouteInfo>? children})
    : super(LibraryRoute.name, initialChildren: children);

  static const String name = 'LibraryRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i4.LibraryScreen();
    },
  );
}

/// generated route for
/// [_i3.LibraryTab]
class LibraryTab extends _i13.PageRouteInfo<void> {
  const LibraryTab({List<_i13.PageRouteInfo>? children})
    : super(LibraryTab.name, initialChildren: children);

  static const String name = 'LibraryTab';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i3.LibraryTab();
    },
  );
}

/// generated route for
/// [_i5.PlayerScreen]
class PlayerRoute extends _i13.PageRouteInfo<void> {
  const PlayerRoute({List<_i13.PageRouteInfo>? children})
    : super(PlayerRoute.name, initialChildren: children);

  static const String name = 'PlayerRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i5.PlayerScreen();
    },
  );
}

/// generated route for
/// [_i6.PlaylistDetailScreen]
class PlaylistDetailRoute extends _i13.PageRouteInfo<PlaylistDetailRouteArgs> {
  PlaylistDetailRoute({
    _i14.Key? key,
    required String sourceId,
    required String playlistId,
    String? playlistName,
    List<_i13.PageRouteInfo>? children,
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

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PlaylistDetailRouteArgs>(
        orElse: () => PlaylistDetailRouteArgs(
          sourceId: pathParams.getString('sourceId'),
          playlistId: pathParams.getString('playlistId'),
        ),
      );
      return _i6.PlaylistDetailScreen(
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

  final _i14.Key? key;

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
/// [_i7.ProfileScreen]
class ProfileRoute extends _i13.PageRouteInfo<void> {
  const ProfileRoute({List<_i13.PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i7.ProfileScreen();
    },
  );
}

/// generated route for
/// [_i3.ProfileTab]
class ProfileTab extends _i13.PageRouteInfo<void> {
  const ProfileTab({List<_i13.PageRouteInfo>? children})
    : super(ProfileTab.name, initialChildren: children);

  static const String name = 'ProfileTab';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i3.ProfileTab();
    },
  );
}

/// generated route for
/// [_i8.PulsarPlaylistDetailScreen]
class PulsarPlaylistDetailRoute
    extends _i13.PageRouteInfo<PulsarPlaylistDetailRouteArgs> {
  PulsarPlaylistDetailRoute({
    _i14.Key? key,
    required String playlistId,
    String? playlistName,
    List<_i13.PageRouteInfo>? children,
  }) : super(
         PulsarPlaylistDetailRoute.name,
         args: PulsarPlaylistDetailRouteArgs(
           key: key,
           playlistId: playlistId,
           playlistName: playlistName,
         ),
         rawPathParams: {'playlistId': playlistId},
         initialChildren: children,
       );

  static const String name = 'PulsarPlaylistDetailRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PulsarPlaylistDetailRouteArgs>(
        orElse: () => PulsarPlaylistDetailRouteArgs(
          playlistId: pathParams.getString('playlistId'),
        ),
      );
      return _i8.PulsarPlaylistDetailScreen(
        key: args.key,
        playlistId: args.playlistId,
        playlistName: args.playlistName,
      );
    },
  );
}

class PulsarPlaylistDetailRouteArgs {
  const PulsarPlaylistDetailRouteArgs({
    this.key,
    required this.playlistId,
    this.playlistName,
  });

  final _i14.Key? key;

  final String playlistId;

  final String? playlistName;

  @override
  String toString() {
    return 'PulsarPlaylistDetailRouteArgs{key: $key, playlistId: $playlistId, playlistName: $playlistName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PulsarPlaylistDetailRouteArgs) return false;
    return key == other.key &&
        playlistId == other.playlistId &&
        playlistName == other.playlistName;
  }

  @override
  int get hashCode =>
      key.hashCode ^ playlistId.hashCode ^ playlistName.hashCode;
}

/// generated route for
/// [_i9.SearchScreen]
class SearchRoute extends _i13.PageRouteInfo<void> {
  const SearchRoute({List<_i13.PageRouteInfo>? children})
    : super(SearchRoute.name, initialChildren: children);

  static const String name = 'SearchRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i9.SearchScreen();
    },
  );
}

/// generated route for
/// [_i3.SearchTab]
class SearchTab extends _i13.PageRouteInfo<void> {
  const SearchTab({List<_i13.PageRouteInfo>? children})
    : super(SearchTab.name, initialChildren: children);

  static const String name = 'SearchTab';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i3.SearchTab();
    },
  );
}

/// generated route for
/// [_i10.SettingsScreen]
class SettingsRoute extends _i13.PageRouteInfo<void> {
  const SettingsRoute({List<_i13.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i10.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i3.SettingsTab]
class SettingsTab extends _i13.PageRouteInfo<void> {
  const SettingsTab({List<_i13.PageRouteInfo>? children})
    : super(SettingsTab.name, initialChildren: children);

  static const String name = 'SettingsTab';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i3.SettingsTab();
    },
  );
}

/// generated route for
/// [_i11.SetupScreen]
class SetupRoute extends _i13.PageRouteInfo<void> {
  const SetupRoute({List<_i13.PageRouteInfo>? children})
    : super(SetupRoute.name, initialChildren: children);

  static const String name = 'SetupRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i11.SetupScreen();
    },
  );
}

/// generated route for
/// [_i12.ShellScreen]
class ShellRoute extends _i13.PageRouteInfo<void> {
  const ShellRoute({List<_i13.PageRouteInfo>? children})
    : super(ShellRoute.name, initialChildren: children);

  static const String name = 'ShellRoute';

  static _i13.PageInfo page = _i13.PageInfo(
    name,
    builder: (data) {
      return const _i12.ShellScreen();
    },
  );
}
