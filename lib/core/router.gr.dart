// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i15;
import 'package:groovy_box/screens/albums.dart' as _i1;
import 'package:groovy_box/screens/artists.dart' as _i2;
import 'package:groovy_box/screens/explore.dart' as _i3;
import 'package:groovy_box/screens/library.dart' as _i5;
import 'package:groovy_box/screens/owned_playlist.dart' as _i6;
import 'package:groovy_box/screens/player_screen.dart' as _i7;
import 'package:groovy_box/screens/playlists.dart' as _i8;
import 'package:groovy_box/screens/profile.dart' as _i9;
import 'package:groovy_box/screens/pulsar_playlist.dart' as _i10;
import 'package:groovy_box/screens/search.dart' as _i11;
import 'package:groovy_box/screens/settings.dart' as _i12;
import 'package:groovy_box/screens/setup.dart' as _i13;
import 'package:groovy_box/shell/shell_screen.dart' as _i14;
import 'package:groovy_box/shell/tab_stack.dart' as _i4;
import 'package:material_ui/material_ui.dart' as _i16;

/// generated route for
/// [_i1.AlbumDetailScreen]
class AlbumDetailRoute extends _i15.PageRouteInfo<AlbumDetailRouteArgs> {
  AlbumDetailRoute({
    _i16.Key? key,
    required String sourceId,
    required String albumId,
    String? albumName,
    List<_i15.PageRouteInfo>? children,
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

  static _i15.PageInfo page = _i15.PageInfo(
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

  final _i16.Key? key;

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
/// [_i2.ArtistDetailScreen]
class ArtistDetailRoute extends _i15.PageRouteInfo<ArtistDetailRouteArgs> {
  ArtistDetailRoute({
    _i16.Key? key,
    required String sourceId,
    required String artistId,
    String? artistName,
    List<_i15.PageRouteInfo>? children,
  }) : super(
         ArtistDetailRoute.name,
         args: ArtistDetailRouteArgs(
           key: key,
           sourceId: sourceId,
           artistId: artistId,
           artistName: artistName,
         ),
         rawPathParams: {'sourceId': sourceId, 'artistId': artistId},
         initialChildren: children,
       );

  static const String name = 'ArtistDetailRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ArtistDetailRouteArgs>(
        orElse: () => ArtistDetailRouteArgs(
          sourceId: pathParams.getString('sourceId'),
          artistId: pathParams.getString('artistId'),
        ),
      );
      return _i2.ArtistDetailScreen(
        key: args.key,
        sourceId: args.sourceId,
        artistId: args.artistId,
        artistName: args.artistName,
      );
    },
  );
}

class ArtistDetailRouteArgs {
  const ArtistDetailRouteArgs({
    this.key,
    required this.sourceId,
    required this.artistId,
    this.artistName,
  });

  final _i16.Key? key;

  final String sourceId;

  final String artistId;

  final String? artistName;

  @override
  String toString() {
    return 'ArtistDetailRouteArgs{key: $key, sourceId: $sourceId, artistId: $artistId, artistName: $artistName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArtistDetailRouteArgs) return false;
    return key == other.key &&
        sourceId == other.sourceId &&
        artistId == other.artistId &&
        artistName == other.artistName;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sourceId.hashCode ^
      artistId.hashCode ^
      artistName.hashCode;
}

/// generated route for
/// [_i3.ExploreScreen]
class ExploreRoute extends _i15.PageRouteInfo<void> {
  const ExploreRoute({List<_i15.PageRouteInfo>? children})
    : super(ExploreRoute.name, initialChildren: children);

  static const String name = 'ExploreRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i3.ExploreScreen();
    },
  );
}

/// generated route for
/// [_i4.ExploreTab]
class ExploreTab extends _i15.PageRouteInfo<void> {
  const ExploreTab({List<_i15.PageRouteInfo>? children})
    : super(ExploreTab.name, initialChildren: children);

  static const String name = 'ExploreTab';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i4.ExploreTab();
    },
  );
}

/// generated route for
/// [_i5.LibraryScreen]
class LibraryRoute extends _i15.PageRouteInfo<void> {
  const LibraryRoute({List<_i15.PageRouteInfo>? children})
    : super(LibraryRoute.name, initialChildren: children);

  static const String name = 'LibraryRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i5.LibraryScreen();
    },
  );
}

/// generated route for
/// [_i4.LibraryTab]
class LibraryTab extends _i15.PageRouteInfo<void> {
  const LibraryTab({List<_i15.PageRouteInfo>? children})
    : super(LibraryTab.name, initialChildren: children);

  static const String name = 'LibraryTab';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i4.LibraryTab();
    },
  );
}

/// generated route for
/// [_i6.OwnedPlaylistDetailScreen]
class OwnedPlaylistDetailRoute
    extends _i15.PageRouteInfo<OwnedPlaylistDetailRouteArgs> {
  OwnedPlaylistDetailRoute({
    _i16.Key? key,
    required int playlistId,
    String? playlistName,
    List<_i15.PageRouteInfo>? children,
  }) : super(
         OwnedPlaylistDetailRoute.name,
         args: OwnedPlaylistDetailRouteArgs(
           key: key,
           playlistId: playlistId,
           playlistName: playlistName,
         ),
         rawPathParams: {'playlistId': playlistId},
         initialChildren: children,
       );

  static const String name = 'OwnedPlaylistDetailRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<OwnedPlaylistDetailRouteArgs>(
        orElse: () => OwnedPlaylistDetailRouteArgs(
          playlistId: pathParams.getInt('playlistId'),
        ),
      );
      return _i6.OwnedPlaylistDetailScreen(
        key: args.key,
        playlistId: args.playlistId,
        playlistName: args.playlistName,
      );
    },
  );
}

class OwnedPlaylistDetailRouteArgs {
  const OwnedPlaylistDetailRouteArgs({
    this.key,
    required this.playlistId,
    this.playlistName,
  });

  final _i16.Key? key;

  final int playlistId;

  final String? playlistName;

  @override
  String toString() {
    return 'OwnedPlaylistDetailRouteArgs{key: $key, playlistId: $playlistId, playlistName: $playlistName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OwnedPlaylistDetailRouteArgs) return false;
    return key == other.key &&
        playlistId == other.playlistId &&
        playlistName == other.playlistName;
  }

  @override
  int get hashCode =>
      key.hashCode ^ playlistId.hashCode ^ playlistName.hashCode;
}

/// generated route for
/// [_i7.PlayerScreen]
class PlayerRoute extends _i15.PageRouteInfo<void> {
  const PlayerRoute({List<_i15.PageRouteInfo>? children})
    : super(PlayerRoute.name, initialChildren: children);

  static const String name = 'PlayerRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i7.PlayerScreen();
    },
  );
}

/// generated route for
/// [_i8.PlaylistDetailScreen]
class PlaylistDetailRoute extends _i15.PageRouteInfo<PlaylistDetailRouteArgs> {
  PlaylistDetailRoute({
    _i16.Key? key,
    required String sourceId,
    required String playlistId,
    String? playlistName,
    List<_i15.PageRouteInfo>? children,
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

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PlaylistDetailRouteArgs>(
        orElse: () => PlaylistDetailRouteArgs(
          sourceId: pathParams.getString('sourceId'),
          playlistId: pathParams.getString('playlistId'),
        ),
      );
      return _i8.PlaylistDetailScreen(
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

  final _i16.Key? key;

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
/// [_i9.ProfileScreen]
class ProfileRoute extends _i15.PageRouteInfo<void> {
  const ProfileRoute({List<_i15.PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i9.ProfileScreen();
    },
  );
}

/// generated route for
/// [_i4.ProfileTab]
class ProfileTab extends _i15.PageRouteInfo<void> {
  const ProfileTab({List<_i15.PageRouteInfo>? children})
    : super(ProfileTab.name, initialChildren: children);

  static const String name = 'ProfileTab';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i4.ProfileTab();
    },
  );
}

/// generated route for
/// [_i10.PulsarPlaylistDetailScreen]
class PulsarPlaylistDetailRoute
    extends _i15.PageRouteInfo<PulsarPlaylistDetailRouteArgs> {
  PulsarPlaylistDetailRoute({
    _i16.Key? key,
    required String playlistId,
    String? playlistName,
    List<_i15.PageRouteInfo>? children,
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

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PulsarPlaylistDetailRouteArgs>(
        orElse: () => PulsarPlaylistDetailRouteArgs(
          playlistId: pathParams.getString('playlistId'),
        ),
      );
      return _i10.PulsarPlaylistDetailScreen(
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

  final _i16.Key? key;

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
/// [_i11.SearchScreen]
class SearchRoute extends _i15.PageRouteInfo<void> {
  const SearchRoute({List<_i15.PageRouteInfo>? children})
    : super(SearchRoute.name, initialChildren: children);

  static const String name = 'SearchRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i11.SearchScreen();
    },
  );
}

/// generated route for
/// [_i4.SearchTab]
class SearchTab extends _i15.PageRouteInfo<void> {
  const SearchTab({List<_i15.PageRouteInfo>? children})
    : super(SearchTab.name, initialChildren: children);

  static const String name = 'SearchTab';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i4.SearchTab();
    },
  );
}

/// generated route for
/// [_i12.SettingsScreen]
class SettingsRoute extends _i15.PageRouteInfo<void> {
  const SettingsRoute({List<_i15.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i12.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i4.SettingsTab]
class SettingsTab extends _i15.PageRouteInfo<void> {
  const SettingsTab({List<_i15.PageRouteInfo>? children})
    : super(SettingsTab.name, initialChildren: children);

  static const String name = 'SettingsTab';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i4.SettingsTab();
    },
  );
}

/// generated route for
/// [_i13.SetupScreen]
class SetupRoute extends _i15.PageRouteInfo<void> {
  const SetupRoute({List<_i15.PageRouteInfo>? children})
    : super(SetupRoute.name, initialChildren: children);

  static const String name = 'SetupRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i13.SetupScreen();
    },
  );
}

/// generated route for
/// [_i14.ShellScreen]
class ShellRoute extends _i15.PageRouteInfo<void> {
  const ShellRoute({List<_i15.PageRouteInfo>? children})
    : super(ShellRoute.name, initialChildren: children);

  static const String name = 'ShellRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i14.ShellScreen();
    },
  );
}
