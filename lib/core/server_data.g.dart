// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_data.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Recently added albums, refreshed on demand and after a pull-to-refresh.

@ProviderFor(RecentAlbums)
final recentAlbumsProvider = RecentAlbumsProvider._();

/// Recently added albums, refreshed on demand and after a pull-to-refresh.
final class RecentAlbumsProvider
    extends $AsyncNotifierProvider<RecentAlbums, List<SubsonicAlbum>> {
  /// Recently added albums, refreshed on demand and after a pull-to-refresh.
  RecentAlbumsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentAlbumsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentAlbumsHash();

  @$internal
  @override
  RecentAlbums create() => RecentAlbums();
}

String _$recentAlbumsHash() => r'a0fd9222ef08b340b7b54938c5f2c1eb90d930da';

/// Recently added albums, refreshed on demand and after a pull-to-refresh.

abstract class _$RecentAlbums extends $AsyncNotifier<List<SubsonicAlbum>> {
  FutureOr<List<SubsonicAlbum>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<SubsonicAlbum>>, List<SubsonicAlbum>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SubsonicAlbum>>, List<SubsonicAlbum>>,
              AsyncValue<List<SubsonicAlbum>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Songs from a random draw, used as the browse page's instant-play shelf.

@ProviderFor(RandomSongs)
final randomSongsProvider = RandomSongsProvider._();

/// Songs from a random draw, used as the browse page's instant-play shelf.
final class RandomSongsProvider
    extends $AsyncNotifierProvider<RandomSongs, List<SubsonicSong>> {
  /// Songs from a random draw, used as the browse page's instant-play shelf.
  RandomSongsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'randomSongsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$randomSongsHash();

  @$internal
  @override
  RandomSongs create() => RandomSongs();
}

String _$randomSongsHash() => r'6bf12d69a6cc611f90ff8b7d1bac04fe7bba292c';

/// Songs from a random draw, used as the browse page's instant-play shelf.

abstract class _$RandomSongs extends $AsyncNotifier<List<SubsonicSong>> {
  FutureOr<List<SubsonicSong>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<SubsonicSong>>, List<SubsonicSong>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SubsonicSong>>, List<SubsonicSong>>,
              AsyncValue<List<SubsonicSong>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Songs of one album, cached per album id.

@ProviderFor(albumSongs)
final albumSongsProvider = AlbumSongsFamily._();

/// Songs of one album, cached per album id.

final class AlbumSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SubsonicSong>>,
          List<SubsonicSong>,
          FutureOr<List<SubsonicSong>>
        >
    with
        $FutureModifier<List<SubsonicSong>>,
        $FutureProvider<List<SubsonicSong>> {
  /// Songs of one album, cached per album id.
  AlbumSongsProvider._({
    required AlbumSongsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'albumSongsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$albumSongsHash();

  @override
  String toString() {
    return r'albumSongsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<SubsonicSong>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SubsonicSong>> create(Ref ref) {
    final argument = this.argument as String;
    return albumSongs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AlbumSongsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$albumSongsHash() => r'37be00691c7a3bbd5997965019079280cffbb997';

/// Songs of one album, cached per album id.

final class AlbumSongsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<SubsonicSong>>, String> {
  AlbumSongsFamily._()
    : super(
        retry: null,
        name: r'albumSongsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Songs of one album, cached per album id.

  AlbumSongsProvider call(String albumId) =>
      AlbumSongsProvider._(argument: albumId, from: this);

  @override
  String toString() => r'albumSongsProvider';
}

/// The user's playlists.

@ProviderFor(Playlists)
final playlistsProvider = PlaylistsProvider._();

/// The user's playlists.
final class PlaylistsProvider
    extends $AsyncNotifierProvider<Playlists, List<SubsonicPlaylist>> {
  /// The user's playlists.
  PlaylistsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playlistsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playlistsHash();

  @$internal
  @override
  Playlists create() => Playlists();
}

String _$playlistsHash() => r'ebd0962a76e80d78aa138f60a69af8a975247ae5';

/// The user's playlists.

abstract class _$Playlists extends $AsyncNotifier<List<SubsonicPlaylist>> {
  FutureOr<List<SubsonicPlaylist>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<SubsonicPlaylist>>, List<SubsonicPlaylist>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<SubsonicPlaylist>>,
                List<SubsonicPlaylist>
              >,
              AsyncValue<List<SubsonicPlaylist>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Songs of one playlist, cached per playlist id.

@ProviderFor(playlistSongs)
final playlistSongsProvider = PlaylistSongsFamily._();

/// Songs of one playlist, cached per playlist id.

final class PlaylistSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SubsonicSong>>,
          List<SubsonicSong>,
          FutureOr<List<SubsonicSong>>
        >
    with
        $FutureModifier<List<SubsonicSong>>,
        $FutureProvider<List<SubsonicSong>> {
  /// Songs of one playlist, cached per playlist id.
  PlaylistSongsProvider._({
    required PlaylistSongsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'playlistSongsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$playlistSongsHash();

  @override
  String toString() {
    return r'playlistSongsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<SubsonicSong>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SubsonicSong>> create(Ref ref) {
    final argument = this.argument as String;
    return playlistSongs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlaylistSongsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$playlistSongsHash() => r'4bc45660f252f7038f8242a6a62aa17a198f711a';

/// Songs of one playlist, cached per playlist id.

final class PlaylistSongsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<SubsonicSong>>, String> {
  PlaylistSongsFamily._()
    : super(
        retry: null,
        name: r'playlistSongsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Songs of one playlist, cached per playlist id.

  PlaylistSongsProvider call(String playlistId) =>
      PlaylistSongsProvider._(argument: playlistId, from: this);

  @override
  String toString() => r'playlistSongsProvider';
}

/// Search results for the browse page's field. Empty query = no request.

@ProviderFor(searchSongs)
final searchSongsProvider = SearchSongsFamily._();

/// Search results for the browse page's field. Empty query = no request.

final class SearchSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SubsonicSong>>,
          List<SubsonicSong>,
          FutureOr<List<SubsonicSong>>
        >
    with
        $FutureModifier<List<SubsonicSong>>,
        $FutureProvider<List<SubsonicSong>> {
  /// Search results for the browse page's field. Empty query = no request.
  SearchSongsProvider._({
    required SearchSongsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchSongsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchSongsHash();

  @override
  String toString() {
    return r'searchSongsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<SubsonicSong>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SubsonicSong>> create(Ref ref) {
    final argument = this.argument as String;
    return searchSongs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchSongsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchSongsHash() => r'de910a30ad80f21d838064006cd8c74785a490c3';

/// Search results for the browse page's field. Empty query = no request.

final class SearchSongsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<SubsonicSong>>, String> {
  SearchSongsFamily._()
    : super(
        retry: null,
        name: r'searchSongsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Search results for the browse page's field. Empty query = no request.

  SearchSongsProvider call(String query) =>
      SearchSongsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchSongsProvider';
}
