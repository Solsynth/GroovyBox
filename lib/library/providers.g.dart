// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where imported files live, injected by `main` once the platform has told
/// the app its support directory. Null in tests and on a platform that cannot
/// provide one, which simply means no local library.

@ProviderFor(localLibraryPath)
final localLibraryPathProvider = LocalLibraryPathProvider._();

/// Where imported files live, injected by `main` once the platform has told
/// the app its support directory. Null in tests and on a platform that cannot
/// provide one, which simply means no local library.

final class LocalLibraryPathProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Where imported files live, injected by `main` once the platform has told
  /// the app its support directory. Null in tests and on a platform that cannot
  /// provide one, which simply means no local library.
  LocalLibraryPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localLibraryPathProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localLibraryPathHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return localLibraryPath(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$localLibraryPathHash() => r'feb22e537a027a5fee048fe0a0b61b1bec4e0cd9';

/// The library this device owns, or null when it cannot exist (no database,
/// or no storage directory).

@ProviderFor(localLibrary)
final localLibraryProvider = LocalLibraryProvider._();

/// The library this device owns, or null when it cannot exist (no database,
/// or no storage directory).

final class LocalLibraryProvider
    extends
        $FunctionalProvider<
          LocalLibrarySource?,
          LocalLibrarySource?,
          LocalLibrarySource?
        >
    with $Provider<LocalLibrarySource?> {
  /// The library this device owns, or null when it cannot exist (no database,
  /// or no storage directory).
  LocalLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localLibraryHash();

  @$internal
  @override
  $ProviderElement<LocalLibrarySource?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalLibrarySource? create(Ref ref) {
    return localLibrary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalLibrarySource? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalLibrarySource?>(value),
    );
  }
}

String _$localLibraryHash() => r'2b88d4a4b494380fe6ce81b09b3ad43ed994f7ed';

/// Every connected library, in the order the user added them.
///
/// Servers only: [librarySourcesWithLocalProvider] is what reads from when the
/// question is "what music is there".

@ProviderFor(librarySources)
final librarySourcesProvider = LibrarySourcesProvider._();

/// Every connected library, in the order the user added them.
///
/// Servers only: [librarySourcesWithLocalProvider] is what reads from when the
/// question is "what music is there".

final class LibrarySourcesProvider
    extends
        $FunctionalProvider<
          List<LibrarySource>,
          List<LibrarySource>,
          List<LibrarySource>
        >
    with $Provider<List<LibrarySource>> {
  /// Every connected library, in the order the user added them.
  ///
  /// Servers only: [librarySourcesWithLocalProvider] is what reads from when the
  /// question is "what music is there".
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

/// Everything that can serve music: the local library first, then the servers.
///
/// Local files come first because they are the ones guaranteed to answer; a
/// dead server must not push a device's own music down a merged list.

@ProviderFor(librarySourcesWithLocal)
final librarySourcesWithLocalProvider = LibrarySourcesWithLocalProvider._();

/// Everything that can serve music: the local library first, then the servers.
///
/// Local files come first because they are the ones guaranteed to answer; a
/// dead server must not push a device's own music down a merged list.

final class LibrarySourcesWithLocalProvider
    extends
        $FunctionalProvider<
          List<LibrarySource>,
          List<LibrarySource>,
          List<LibrarySource>
        >
    with $Provider<List<LibrarySource>> {
  /// Everything that can serve music: the local library first, then the servers.
  ///
  /// Local files come first because they are the ones guaranteed to answer; a
  /// dead server must not push a device's own music down a merged list.
  LibrarySourcesWithLocalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySourcesWithLocalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySourcesWithLocalHash();

  @$internal
  @override
  $ProviderElement<List<LibrarySource>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<LibrarySource> create(Ref ref) {
    return librarySourcesWithLocal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<LibrarySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<LibrarySource>>(value),
    );
  }
}

String _$librarySourcesWithLocalHash() =>
    r'5dc4eb9ac9b8b9de06d27d8f9e16a2df08261f6a';

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

String _$librarySourceByIdHash() => r'a683ac40f05cc3393529e7f24838d993cb8465d5';

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

String _$sourceFailuresHash() => r'6a04ff6d3a92be569558c3806095321d726b4a99';

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

/// Folds every read into the local library, so songs are adopted as the user
/// browses rather than waiting for a full sync that does not exist yet.
///
/// Adoption is fire-and-forget: a read must never be slower, or fail, because
/// the local database did, and a song that was not adopted is picked up by the
/// next read that mentions it.

@ProviderFor(libraryAggregator)
final libraryAggregatorProvider = LibraryAggregatorProvider._();

/// Folds every read into the local library, so songs are adopted as the user
/// browses rather than waiting for a full sync that does not exist yet.
///
/// Adoption is fire-and-forget: a read must never be slower, or fail, because
/// the local database did, and a song that was not adopted is picked up by the
/// next read that mentions it.

final class LibraryAggregatorProvider
    extends
        $FunctionalProvider<
          LibraryAggregator,
          LibraryAggregator,
          LibraryAggregator
        >
    with $Provider<LibraryAggregator> {
  /// Folds every read into the local library, so songs are adopted as the user
  /// browses rather than waiting for a full sync that does not exist yet.
  ///
  /// Adoption is fire-and-forget: a read must never be slower, or fail, because
  /// the local database did, and a song that was not adopted is picked up by the
  /// next read that mentions it.
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

String _$libraryAggregatorHash() => r'f1ea87b7710d29925baf59385b113e91f5cf83fc';

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

String _$recentAlbumsHash() => r'5fcd7a62bd2cbcafc0bf7501e12a0e07cdf0ca64';

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

String _$randomSongsHash() => r'35c4aec12508dbde9e5efd9869048206890e343a';

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

String _$playlistsHash() => r'ef8de34fbb68a3980908d4fa16a12ec1a4298629';

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

String _$searchSongsHash() => r'411dfe1f6850fe1c019b0ac2c47d2dfc330b3ac3';

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

/// The local library, opened in `main` and injected into the container.
///
/// Overriding it keeps the catalog and the lyrics store synchronous to read,
/// and keeps the database out of widget tests, which have no platform channel
/// to open one through. A machine where it could not be opened gets null:
/// playback and lyrics still work, they just ask the network every time and
/// keep no history.

@ProviderFor(libraryDatabase)
final libraryDatabaseProvider = LibraryDatabaseProvider._();

/// The local library, opened in `main` and injected into the container.
///
/// Overriding it keeps the catalog and the lyrics store synchronous to read,
/// and keeps the database out of widget tests, which have no platform channel
/// to open one through. A machine where it could not be opened gets null:
/// playback and lyrics still work, they just ask the network every time and
/// keep no history.

final class LibraryDatabaseProvider
    extends
        $FunctionalProvider<
          LibraryDatabase?,
          LibraryDatabase?,
          LibraryDatabase?
        >
    with $Provider<LibraryDatabase?> {
  /// The local library, opened in `main` and injected into the container.
  ///
  /// Overriding it keeps the catalog and the lyrics store synchronous to read,
  /// and keeps the database out of widget tests, which have no platform channel
  /// to open one through. A machine where it could not be opened gets null:
  /// playback and lyrics still work, they just ask the network every time and
  /// keep no history.
  LibraryDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryDatabaseHash();

  @$internal
  @override
  $ProviderElement<LibraryDatabase?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LibraryDatabase? create(Ref ref) {
    return libraryDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryDatabase? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryDatabase?>(value),
    );
  }
}

String _$libraryDatabaseHash() => r'f5bf2d6304e0234366ad3d24af380df86624a09a';

/// The app's view of the local library.

@ProviderFor(libraryCatalog)
final libraryCatalogProvider = LibraryCatalogProvider._();

/// The app's view of the local library.

final class LibraryCatalogProvider
    extends
        $FunctionalProvider<LibraryCatalog?, LibraryCatalog?, LibraryCatalog?>
    with $Provider<LibraryCatalog?> {
  /// The app's view of the local library.
  LibraryCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryCatalogHash();

  @$internal
  @override
  $ProviderElement<LibraryCatalog?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LibraryCatalog? create(Ref ref) {
    return libraryCatalog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryCatalog? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryCatalog?>(value),
    );
  }
}

String _$libraryCatalogHash() => r'9ea566c633a47122b91f77e01c1ff890a6281fbc';

/// The stored lyrics of each track.

@ProviderFor(lyricsStore)
final lyricsStoreProvider = LyricsStoreProvider._();

/// The stored lyrics of each track.

final class LyricsStoreProvider
    extends $FunctionalProvider<LyricsStore?, LyricsStore?, LyricsStore?>
    with $Provider<LyricsStore?> {
  /// The stored lyrics of each track.
  LyricsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lyricsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lyricsStoreHash();

  @$internal
  @override
  $ProviderElement<LyricsStore?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LyricsStore? create(Ref ref) {
    return lyricsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LyricsStore? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LyricsStore?>(value),
    );
  }
}

String _$lyricsStoreHash() => r'0cc441b33f05c83ddebf28c9688374e25773db25';

/// The LRCLIB client, shared so its rate-limit state is too.

@ProviderFor(lrclib)
final lrclibProvider = LrclibProvider._();

/// The LRCLIB client, shared so its rate-limit state is too.

final class LrclibProvider extends $FunctionalProvider<Lrclib, Lrclib, Lrclib>
    with $Provider<Lrclib> {
  /// The LRCLIB client, shared so its rate-limit state is too.
  LrclibProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lrclibProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lrclibHash();

  @$internal
  @override
  $ProviderElement<Lrclib> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Lrclib create(Ref ref) {
    return lrclib(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Lrclib value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Lrclib>(value),
    );
  }
}

String _$lrclibHash() => r'2be44ac976f498e84546d0f61047ca77fda7de3e';

/// Resolves lyrics: stored answer first, then the library, then LRCLIB.

@ProviderFor(lyricsResolver)
final lyricsResolverProvider = LyricsResolverProvider._();

/// Resolves lyrics: stored answer first, then the library, then LRCLIB.

final class LyricsResolverProvider
    extends
        $FunctionalProvider<
          AsyncValue<LyricsResolver>,
          LyricsResolver,
          FutureOr<LyricsResolver>
        >
    with $FutureModifier<LyricsResolver>, $FutureProvider<LyricsResolver> {
  /// Resolves lyrics: stored answer first, then the library, then LRCLIB.
  LyricsResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lyricsResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lyricsResolverHash();

  @$internal
  @override
  $FutureProviderElement<LyricsResolver> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LyricsResolver> create(Ref ref) {
    return lyricsResolver(ref);
  }
}

String _$lyricsResolverHash() => r'515bb0a65e677a7a600483106f87ef8e229f219e';

/// Lyrics of one song, from the local library or the network.
///
/// Kept for the session as well as on disk: the pane is rebuilt on every
/// position tick's parent rebuild, and a family entry means it never asks
/// twice for the track it is already showing.
/// [languageCode] is the app's current language, so a translation is generated
/// in the language the interface is actually in. A language change gives the
/// family a new argument, which refetches instead of serving the old one.

@ProviderFor(songLyrics)
final songLyricsProvider = SongLyricsFamily._();

/// Lyrics of one song, from the local library or the network.
///
/// Kept for the session as well as on disk: the pane is rebuilt on every
/// position tick's parent rebuild, and a family entry means it never asks
/// twice for the track it is already showing.
/// [languageCode] is the app's current language, so a translation is generated
/// in the language the interface is actually in. A language change gives the
/// family a new argument, which refetches instead of serving the old one.

final class SongLyricsProvider
    extends $FunctionalProvider<AsyncValue<Lyrics>, Lyrics, FutureOr<Lyrics>>
    with $FutureModifier<Lyrics>, $FutureProvider<Lyrics> {
  /// Lyrics of one song, from the local library or the network.
  ///
  /// Kept for the session as well as on disk: the pane is rebuilt on every
  /// position tick's parent rebuild, and a family entry means it never asks
  /// twice for the track it is already showing.
  /// [languageCode] is the app's current language, so a translation is generated
  /// in the language the interface is actually in. A language change gives the
  /// family a new argument, which refetches instead of serving the old one.
  SongLyricsProvider._({
    required SongLyricsFamily super.from,
    required (LyricsRequest, {String? languageCode}) super.argument,
  }) : super(
         retry: null,
         name: r'songLyricsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$songLyricsHash();

  @override
  String toString() {
    return r'songLyricsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Lyrics> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Lyrics> create(Ref ref) {
    final argument = this.argument as (LyricsRequest, {String? languageCode});
    return songLyrics(ref, argument.$1, languageCode: argument.languageCode);
  }

  @override
  bool operator ==(Object other) {
    return other is SongLyricsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$songLyricsHash() => r'b6899bce9a05c28a0b1d8a37a99111164d1049fd';

/// Lyrics of one song, from the local library or the network.
///
/// Kept for the session as well as on disk: the pane is rebuilt on every
/// position tick's parent rebuild, and a family entry means it never asks
/// twice for the track it is already showing.
/// [languageCode] is the app's current language, so a translation is generated
/// in the language the interface is actually in. A language change gives the
/// family a new argument, which refetches instead of serving the old one.

final class SongLyricsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Lyrics>,
          (LyricsRequest, {String? languageCode})
        > {
  SongLyricsFamily._()
    : super(
        retry: null,
        name: r'songLyricsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Lyrics of one song, from the local library or the network.
  ///
  /// Kept for the session as well as on disk: the pane is rebuilt on every
  /// position tick's parent rebuild, and a family entry means it never asks
  /// twice for the track it is already showing.
  /// [languageCode] is the app's current language, so a translation is generated
  /// in the language the interface is actually in. A language change gives the
  /// family a new argument, which refetches instead of serving the old one.

  SongLyricsProvider call(LyricsRequest song, {String? languageCode}) =>
      SongLyricsProvider._(
        argument: (song, languageCode: languageCode),
        from: this,
      );

  @override
  String toString() => r'songLyricsProvider';
}

/// How many tracks have a stored lyric, for the settings row.
///
/// Auto-disposed rather than kept: a count read when the page opened would be
/// wrong once a track has played, and re-reading is one `COUNT(*)`.

@ProviderFor(storedLyrics)
final storedLyricsProvider = StoredLyricsProvider._();

/// How many tracks have a stored lyric, for the settings row.
///
/// Auto-disposed rather than kept: a count read when the page opened would be
/// wrong once a track has played, and re-reading is one `COUNT(*)`.

final class StoredLyricsProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many tracks have a stored lyric, for the settings row.
  ///
  /// Auto-disposed rather than kept: a count read when the page opened would be
  /// wrong once a track has played, and re-reading is one `COUNT(*)`.
  StoredLyricsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storedLyricsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storedLyricsHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return storedLyrics(ref);
  }
}

String _$storedLyricsHash() => r'b6779c52adea3ab45e43e37d1dc12b3e297586ce';

/// How many songs the local library knows, and how many of them no connected
/// source can play any more, for the settings row.

@ProviderFor(libraryStats)
final libraryStatsProvider = LibraryStatsProvider._();

/// How many songs the local library knows, and how many of them no connected
/// source can play any more, for the settings row.

final class LibraryStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({int orphaned, int tracks})>,
          ({int orphaned, int tracks}),
          FutureOr<({int orphaned, int tracks})>
        >
    with
        $FutureModifier<({int orphaned, int tracks})>,
        $FutureProvider<({int orphaned, int tracks})> {
  /// How many songs the local library knows, and how many of them no connected
  /// source can play any more, for the settings row.
  LibraryStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryStatsHash();

  @$internal
  @override
  $FutureProviderElement<({int orphaned, int tracks})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({int orphaned, int tracks})> create(Ref ref) {
    return libraryStats(ref);
  }
}

String _$libraryStatsHash() => r'0a527cb92be47e3406957d0381d87a38215b738a';

/// What the play history says, for the stats page.
///
/// Auto-disposed and rebuilt on open: the page is a summary of a database that
/// changes as music plays, and re-reading it is a handful of aggregate
/// queries, not a sync.

@ProviderFor(listeningStats)
final listeningStatsProvider = ListeningStatsProvider._();

/// What the play history says, for the stats page.
///
/// Auto-disposed and rebuilt on open: the page is a summary of a database that
/// changes as music plays, and re-reading it is a handful of aggregate
/// queries, not a sync.

final class ListeningStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ListeningStats>,
          ListeningStats,
          FutureOr<ListeningStats>
        >
    with $FutureModifier<ListeningStats>, $FutureProvider<ListeningStats> {
  /// What the play history says, for the stats page.
  ///
  /// Auto-disposed and rebuilt on open: the page is a summary of a database that
  /// changes as music plays, and re-reading it is a handful of aggregate
  /// queries, not a sync.
  ListeningStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listeningStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listeningStatsHash();

  @$internal
  @override
  $FutureProviderElement<ListeningStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ListeningStats> create(Ref ref) {
    return listeningStats(ref);
  }
}

String _$listeningStatsHash() => r'793553a868ec243c59e38e569d130ffb81505740';

/// Actions the library UI needs beyond reading: re-ask the network, forget a
/// removed source, empty the stored lyrics.

@ProviderFor(LyricsMaintenance)
final lyricsMaintenanceProvider = LyricsMaintenanceProvider._();

/// Actions the library UI needs beyond reading: re-ask the network, forget a
/// removed source, empty the stored lyrics.
final class LyricsMaintenanceProvider
    extends $NotifierProvider<LyricsMaintenance, void> {
  /// Actions the library UI needs beyond reading: re-ask the network, forget a
  /// removed source, empty the stored lyrics.
  LyricsMaintenanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lyricsMaintenanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lyricsMaintenanceHash();

  @$internal
  @override
  LyricsMaintenance create() => LyricsMaintenance();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$lyricsMaintenanceHash() => r'2f223327c32c1535924e176ba108e4ca4b3205cf';

/// Actions the library UI needs beyond reading: re-ask the network, forget a
/// removed source, empty the stored lyrics.

abstract class _$LyricsMaintenance extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
