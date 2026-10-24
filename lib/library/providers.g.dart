// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every connected library, in the order the user added them.

@ProviderFor(librarySources)
final librarySourcesProvider = LibrarySourcesProvider._();

/// Every connected library, in the order the user added them.

final class LibrarySourcesProvider
    extends
        $FunctionalProvider<
          List<LibrarySource>,
          List<LibrarySource>,
          List<LibrarySource>
        >
    with $Provider<List<LibrarySource>> {
  /// Every connected library, in the order the user added them.
  LibrarySourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySourcesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySourcesHash();

  @$internal
  @override
  $ProviderElement<List<LibrarySource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<LibrarySource> create(Ref ref) {
    return librarySources(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<LibrarySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<LibrarySource>>(value),
    );
  }
}

String _$librarySourcesHash() => r'c79aaf9f2061f5b44592a30768758528bbd5e83b';

/// The same sources keyed by id, for resolving a stream or art URL from an
/// item that only carries `sourceId`.

@ProviderFor(librarySourceById)
final librarySourceByIdProvider = LibrarySourceByIdProvider._();

/// The same sources keyed by id, for resolving a stream or art URL from an
/// item that only carries `sourceId`.

final class LibrarySourceByIdProvider
    extends
        $FunctionalProvider<
          Map<String, LibrarySource>,
          Map<String, LibrarySource>,
          Map<String, LibrarySource>
        >
    with $Provider<Map<String, LibrarySource>> {
  /// The same sources keyed by id, for resolving a stream or art URL from an
  /// item that only carries `sourceId`.
  LibrarySourceByIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySourceByIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySourceByIdHash();

  @$internal
  @override
  $ProviderElement<Map<String, LibrarySource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, LibrarySource> create(Ref ref) {
    return librarySourceById(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, LibrarySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, LibrarySource>>(value),
    );
  }
}

String _$librarySourceByIdHash() => r'358b629591f619ef4c61c41761b87225d9ce132f';

/// The last failure of each source, so settings can show why it went quiet.

@ProviderFor(SourceFailures)
final sourceFailuresProvider = SourceFailuresProvider._();

/// The last failure of each source, so settings can show why it went quiet.
final class SourceFailuresProvider
    extends $NotifierProvider<SourceFailures, Map<String, String>> {
  /// The last failure of each source, so settings can show why it went quiet.
  SourceFailuresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceFailuresProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceFailuresHash();

  @$internal
  @override
  SourceFailures create() => SourceFailures();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$sourceFailuresHash() => r'722ee7b9bd7b342d62e114c5e1c6f3943f598e85';

/// The last failure of each source, so settings can show why it went quiet.

abstract class _$SourceFailures extends $Notifier<Map<String, String>> {
  Map<String, String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<String, String>, Map<String, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, String>, Map<String, String>>,
              Map<String, String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(libraryAggregator)
final libraryAggregatorProvider = LibraryAggregatorProvider._();

final class LibraryAggregatorProvider
    extends
        $FunctionalProvider<
          LibraryAggregator,
          LibraryAggregator,
          LibraryAggregator
        >
    with $Provider<LibraryAggregator> {
  LibraryAggregatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryAggregatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryAggregatorHash();

  @$internal
  @override
  $ProviderElement<LibraryAggregator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibraryAggregator create(Ref ref) {
    return libraryAggregator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryAggregator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryAggregator>(value),
    );
  }
}

String _$libraryAggregatorHash() => r'e0a9f6fd7d6b1aad4d658858b890c239300dbcd0';

/// Recently added albums, merged across every library.

@ProviderFor(RecentAlbums)
final recentAlbumsProvider = RecentAlbumsProvider._();

/// Recently added albums, merged across every library.
final class RecentAlbumsProvider
    extends $AsyncNotifierProvider<RecentAlbums, List<LibraryAlbum>> {
  /// Recently added albums, merged across every library.
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

String _$recentAlbumsHash() => r'fdb623d5e93c716a03dd0ffdd87268cf017aa586';

/// Recently added albums, merged across every library.

abstract class _$RecentAlbums extends $AsyncNotifier<List<LibraryAlbum>> {
  FutureOr<List<LibraryAlbum>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<LibraryAlbum>>, List<LibraryAlbum>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<LibraryAlbum>>, List<LibraryAlbum>>,
              AsyncValue<List<LibraryAlbum>>,
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
    extends $AsyncNotifierProvider<RandomSongs, List<LibrarySong>> {
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

String _$randomSongsHash() => r'9845bc9ed1c643e10874b240a56ec5070edefa62';

/// Songs from a random draw, used as the browse page's instant-play shelf.

abstract class _$RandomSongs extends $AsyncNotifier<List<LibrarySong>> {
  FutureOr<List<LibrarySong>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<LibrarySong>>, List<LibrarySong>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<LibrarySong>>, List<LibrarySong>>,
              AsyncValue<List<LibrarySong>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The user's playlists, merged across every library.

@ProviderFor(Playlists)
final playlistsProvider = PlaylistsProvider._();

/// The user's playlists, merged across every library.
final class PlaylistsProvider
    extends $AsyncNotifierProvider<Playlists, List<LibraryPlaylist>> {
  /// The user's playlists, merged across every library.
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

String _$playlistsHash() => r'c3cfd2608e943a59422d95cd69cadae50f5cb153';

/// The user's playlists, merged across every library.

abstract class _$Playlists extends $AsyncNotifier<List<LibraryPlaylist>> {
  FutureOr<List<LibraryPlaylist>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<LibraryPlaylist>>, List<LibraryPlaylist>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<LibraryPlaylist>>,
                List<LibraryPlaylist>
              >,
              AsyncValue<List<LibraryPlaylist>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Songs of one album, read straight from its own source.

@ProviderFor(albumSongs)
final albumSongsProvider = AlbumSongsFamily._();

/// Songs of one album, read straight from its own source.

final class AlbumSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibrarySong>>,
          List<LibrarySong>,
          FutureOr<List<LibrarySong>>
        >
    with
        $FutureModifier<List<LibrarySong>>,
        $FutureProvider<List<LibrarySong>> {
  /// Songs of one album, read straight from its own source.
  AlbumSongsProvider._({
    required AlbumSongsFamily super.from,
    required LibraryRef super.argument,
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
  $FutureProviderElement<List<LibrarySong>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LibrarySong>> create(Ref ref) {
    final argument = this.argument as LibraryRef;
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

String _$albumSongsHash() => r'5cab94c4eb64798bd714ed44349a629670b5b2ba';

/// Songs of one album, read straight from its own source.

final class AlbumSongsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LibrarySong>>, LibraryRef> {
  AlbumSongsFamily._()
    : super(
        retry: null,
        name: r'albumSongsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Songs of one album, read straight from its own source.

  AlbumSongsProvider call(LibraryRef album) =>
      AlbumSongsProvider._(argument: album, from: this);

  @override
  String toString() => r'albumSongsProvider';
}

/// Songs of one playlist, read straight from its own source.

@ProviderFor(playlistSongs)
final playlistSongsProvider = PlaylistSongsFamily._();

/// Songs of one playlist, read straight from its own source.

final class PlaylistSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibrarySong>>,
          List<LibrarySong>,
          FutureOr<List<LibrarySong>>
        >
    with
        $FutureModifier<List<LibrarySong>>,
        $FutureProvider<List<LibrarySong>> {
  /// Songs of one playlist, read straight from its own source.
  PlaylistSongsProvider._({
    required PlaylistSongsFamily super.from,
    required LibraryRef super.argument,
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
  $FutureProviderElement<List<LibrarySong>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LibrarySong>> create(Ref ref) {
    final argument = this.argument as LibraryRef;
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

String _$playlistSongsHash() => r'807dd95a6eab6ef276eff8f86eaa3b3550e1b3d6';

/// Songs of one playlist, read straight from its own source.

final class PlaylistSongsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LibrarySong>>, LibraryRef> {
  PlaylistSongsFamily._()
    : super(
        retry: null,
        name: r'playlistSongsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Songs of one playlist, read straight from its own source.

  PlaylistSongsProvider call(LibraryRef playlist) =>
      PlaylistSongsProvider._(argument: playlist, from: this);

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
          AsyncValue<List<LibrarySong>>,
          List<LibrarySong>,
          FutureOr<List<LibrarySong>>
        >
    with
        $FutureModifier<List<LibrarySong>>,
        $FutureProvider<List<LibrarySong>> {
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
  $FutureProviderElement<List<LibrarySong>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LibrarySong>> create(Ref ref) {
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

String _$searchSongsHash() => r'76e0819fc6808fc4fa9807823f096c58eefc4c59';

/// Search results for the browse page's field. Empty query = no request.

final class SearchSongsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LibrarySong>>, String> {
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
