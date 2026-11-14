// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The HTTP client, pointed at the one server setting Solarpass already owns.

@ProviderFor(pulsarClient)
final pulsarClientProvider = PulsarClientProvider._();

/// The HTTP client, pointed at the one server setting Solarpass already owns.

final class PulsarClientProvider
    extends $FunctionalProvider<PulsarClient, PulsarClient, PulsarClient>
    with $Provider<PulsarClient> {
  /// The HTTP client, pointed at the one server setting Solarpass already owns.
  PulsarClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulsarClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulsarClientHash();

  @$internal
  @override
  $ProviderElement<PulsarClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PulsarClient create(Ref ref) {
    return pulsarClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PulsarClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PulsarClient>(value),
    );
  }
}

String _$pulsarClientHash() => r'058da766c8a97d138e6dba2a277055d55576d658';

/// The signed-in session or null, unwrapped once for every Pulsar call.

@ProviderFor(pulsarSession)
final pulsarSessionProvider = PulsarSessionProvider._();

/// The signed-in session or null, unwrapped once for every Pulsar call.

final class PulsarSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<OAuthSession?>,
          OAuthSession?,
          FutureOr<OAuthSession?>
        >
    with $FutureModifier<OAuthSession?>, $FutureProvider<OAuthSession?> {
  /// The signed-in session or null, unwrapped once for every Pulsar call.
  PulsarSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulsarSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulsarSessionHash();

  @$internal
  @override
  $FutureProviderElement<OAuthSession?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OAuthSession?> create(Ref ref) {
    return pulsarSession(ref);
  }
}

String _$pulsarSessionHash() => r'3404d122a8a1be026b9544e8b50b9765b62c5b01';

/// The account's playlists, as Pulsar holds them. Empty without a session:
/// a signed-out window has no cloud playlists and that is not an error.

@ProviderFor(PulsarPlaylists)
final pulsarPlaylistsProvider = PulsarPlaylistsProvider._();

/// The account's playlists, as Pulsar holds them. Empty without a session:
/// a signed-out window has no cloud playlists and that is not an error.
final class PulsarPlaylistsProvider
    extends $AsyncNotifierProvider<PulsarPlaylists, List<PulsarPlaylist>> {
  /// The account's playlists, as Pulsar holds them. Empty without a session:
  /// a signed-out window has no cloud playlists and that is not an error.
  PulsarPlaylistsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulsarPlaylistsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulsarPlaylistsHash();

  @$internal
  @override
  PulsarPlaylists create() => PulsarPlaylists();
}

String _$pulsarPlaylistsHash() => r'23a0980ee839f2e469c5c1086c3e54be7fc20506';

/// The account's playlists, as Pulsar holds them. Empty without a session:
/// a signed-out window has no cloud playlists and that is not an error.

abstract class _$PulsarPlaylists extends $AsyncNotifier<List<PulsarPlaylist>> {
  FutureOr<List<PulsarPlaylist>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<PulsarPlaylist>>, List<PulsarPlaylist>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PulsarPlaylist>>,
                List<PulsarPlaylist>
              >,
              AsyncValue<List<PulsarPlaylist>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// One cloud playlist as the detail page reads it: the collection itself
/// with its items preloaded, from the one endpoint that returns both.

@ProviderFor(pulsarPlaylistDetail)
final pulsarPlaylistDetailProvider = PulsarPlaylistDetailFamily._();

/// One cloud playlist as the detail page reads it: the collection itself
/// with its items preloaded, from the one endpoint that returns both.

final class PulsarPlaylistDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<PulsarPlaylist>,
          PulsarPlaylist,
          FutureOr<PulsarPlaylist>
        >
    with $FutureModifier<PulsarPlaylist>, $FutureProvider<PulsarPlaylist> {
  /// One cloud playlist as the detail page reads it: the collection itself
  /// with its items preloaded, from the one endpoint that returns both.
  PulsarPlaylistDetailProvider._({
    required PulsarPlaylistDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pulsarPlaylistDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulsarPlaylistDetailHash();

  @override
  String toString() {
    return r'pulsarPlaylistDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PulsarPlaylist> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PulsarPlaylist> create(Ref ref) {
    final argument = this.argument as String;
    return pulsarPlaylistDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PulsarPlaylistDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulsarPlaylistDetailHash() =>
    r'42d08798baf0d9190d0dbf15a721caac56aa8c32';

/// One cloud playlist as the detail page reads it: the collection itself
/// with its items preloaded, from the one endpoint that returns both.

final class PulsarPlaylistDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PulsarPlaylist>, String> {
  PulsarPlaylistDetailFamily._()
    : super(
        retry: null,
        name: r'pulsarPlaylistDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One cloud playlist as the detail page reads it: the collection itself
  /// with its items preloaded, from the one endpoint that returns both.

  PulsarPlaylistDetailProvider call(String playlistId) =>
      PulsarPlaylistDetailProvider._(argument: playlistId, from: this);

  @override
  String toString() => r'pulsarPlaylistDetailProvider';
}

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.

@ProviderFor(pulsarPlaylistSongs)
final pulsarPlaylistSongsProvider = PulsarPlaylistSongsFamily._();

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.

final class PulsarPlaylistSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibrarySong?>>,
          List<LibrarySong?>,
          FutureOr<List<LibrarySong?>>
        >
    with
        $FutureModifier<List<LibrarySong?>>,
        $FutureProvider<List<LibrarySong?>> {
  /// The songs of one Pulsar playlist, resolved against the connected library
  /// sources. A catalog entry is a record of a track, not a playable stream:
  /// matching is on title + artist, which is how the server dedupes too.
  ///
  /// The result is index-aligned with [PulsarPlaylist.items], with null where
  /// no library holds the track: the playlist's order is the server's, and a
  /// dropped entry would shift every row after it onto the wrong track.
  PulsarPlaylistSongsProvider._({
    required PulsarPlaylistSongsFamily super.from,
    required PulsarPlaylist super.argument,
  }) : super(
         retry: null,
         name: r'pulsarPlaylistSongsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulsarPlaylistSongsHash();

  @override
  String toString() {
    return r'pulsarPlaylistSongsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LibrarySong?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LibrarySong?>> create(Ref ref) {
    final argument = this.argument as PulsarPlaylist;
    return pulsarPlaylistSongs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PulsarPlaylistSongsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulsarPlaylistSongsHash() =>
    r'ee273a45a9eda1a5c86362cefaf44eb196826844';

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.

final class PulsarPlaylistSongsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<LibrarySong?>>,
          PulsarPlaylist
        > {
  PulsarPlaylistSongsFamily._()
    : super(
        retry: null,
        name: r'pulsarPlaylistSongsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The songs of one Pulsar playlist, resolved against the connected library
  /// sources. A catalog entry is a record of a track, not a playable stream:
  /// matching is on title + artist, which is how the server dedupes too.
  ///
  /// The result is index-aligned with [PulsarPlaylist.items], with null where
  /// no library holds the track: the playlist's order is the server's, and a
  /// dropped entry would shift every row after it onto the wrong track.

  PulsarPlaylistSongsProvider call(PulsarPlaylist playlist) =>
      PulsarPlaylistSongsProvider._(argument: playlist, from: this);

  @override
  String toString() => r'pulsarPlaylistSongsProvider';
}

/// What the account's friends are listening to. Empty without a session.

@ProviderFor(FriendListeningFeed)
final friendListeningFeedProvider = FriendListeningFeedProvider._();

/// What the account's friends are listening to. Empty without a session.
final class FriendListeningFeedProvider
    extends $AsyncNotifierProvider<FriendListeningFeed, List<FriendListening>> {
  /// What the account's friends are listening to. Empty without a session.
  FriendListeningFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'friendListeningFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$friendListeningFeedHash();

  @$internal
  @override
  FriendListeningFeed create() => FriendListeningFeed();
}

String _$friendListeningFeedHash() =>
    r'e816562d7ba511cb1b4b198d5f636ca9113fd1f1';

/// What the account's friends are listening to. Empty without a session.

abstract class _$FriendListeningFeed
    extends $AsyncNotifier<List<FriendListening>> {
  FutureOr<List<FriendListening>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<FriendListening>>, List<FriendListening>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<FriendListening>>,
                List<FriendListening>
              >,
              AsyncValue<List<FriendListening>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The account's taste, aggregated by Pulsar over every scrobble the fleet
/// has. Empty-without-session is silence, not an error: the profile page
/// still shows the local listening story when the account is signed out.

@ProviderFor(pulsarTaste)
final pulsarTasteProvider = PulsarTasteFamily._();

/// The account's taste, aggregated by Pulsar over every scrobble the fleet
/// has. Empty-without-session is silence, not an error: the profile page
/// still shows the local listening story when the account is signed out.

final class PulsarTasteProvider
    extends
        $FunctionalProvider<
          AsyncValue<PulsarMediaStats?>,
          PulsarMediaStats?,
          FutureOr<PulsarMediaStats?>
        >
    with
        $FutureModifier<PulsarMediaStats?>,
        $FutureProvider<PulsarMediaStats?> {
  /// The account's taste, aggregated by Pulsar over every scrobble the fleet
  /// has. Empty-without-session is silence, not an error: the profile page
  /// still shows the local listening story when the account is signed out.
  PulsarTasteProvider._({
    required PulsarTasteFamily super.from,
    required TasteWindow super.argument,
  }) : super(
         retry: null,
         name: r'pulsarTasteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulsarTasteHash();

  @override
  String toString() {
    return r'pulsarTasteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PulsarMediaStats?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PulsarMediaStats?> create(Ref ref) {
    final argument = this.argument as TasteWindow;
    return pulsarTaste(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PulsarTasteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulsarTasteHash() => r'6b6a6e92f2f8ab15393c9b91e29d725bdad6a3ff';

/// The account's taste, aggregated by Pulsar over every scrobble the fleet
/// has. Empty-without-session is silence, not an error: the profile page
/// still shows the local listening story when the account is signed out.

final class PulsarTasteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PulsarMediaStats?>, TasteWindow> {
  PulsarTasteFamily._()
    : super(
        retry: null,
        name: r'pulsarTasteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The account's taste, aggregated by Pulsar over every scrobble the fleet
  /// has. Empty-without-session is silence, not an error: the profile page
  /// still shows the local listening story when the account is signed out.

  PulsarTasteProvider call(TasteWindow window) =>
      PulsarTasteProvider._(argument: window, from: this);

  @override
  String toString() => r'pulsarTasteProvider';
}

/// The account's favourites, as Pulsar holds them: the same heart the device
/// keeps, in the fleet where a second device can read it.

@ProviderFor(PulsarFavourites)
final pulsarFavouritesProvider = PulsarFavouritesProvider._();

/// The account's favourites, as Pulsar holds them: the same heart the device
/// keeps, in the fleet where a second device can read it.
final class PulsarFavouritesProvider
    extends $AsyncNotifierProvider<PulsarFavourites, List<PlaylistItem>> {
  /// The account's favourites, as Pulsar holds them: the same heart the device
  /// keeps, in the fleet where a second device can read it.
  PulsarFavouritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulsarFavouritesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulsarFavouritesHash();

  @$internal
  @override
  PulsarFavourites create() => PulsarFavourites();
}

String _$pulsarFavouritesHash() => r'f93a84749b0d702434524420f66617237f1048c5';

/// The account's favourites, as Pulsar holds them: the same heart the device
/// keeps, in the fleet where a second device can read it.

abstract class _$PulsarFavourites extends $AsyncNotifier<List<PlaylistItem>> {
  FutureOr<List<PlaylistItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<PlaylistItem>>, List<PlaylistItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<PlaylistItem>>, List<PlaylistItem>>,
              AsyncValue<List<PlaylistItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether Pulsar knows [song] as one of the account's favourites.

@ProviderFor(pulsarFavouriteState)
final pulsarFavouriteStateProvider = PulsarFavouriteStateFamily._();

/// Whether Pulsar knows [song] as one of the account's favourites.

final class PulsarFavouriteStateProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether Pulsar knows [song] as one of the account's favourites.
  PulsarFavouriteStateProvider._({
    required PulsarFavouriteStateFamily super.from,
    required LibrarySong super.argument,
  }) : super(
         retry: null,
         name: r'pulsarFavouriteStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulsarFavouriteStateHash();

  @override
  String toString() {
    return r'pulsarFavouriteStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as LibrarySong;
    return pulsarFavouriteState(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PulsarFavouriteStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulsarFavouriteStateHash() =>
    r'10d2d2ea21861919bcc447228626aa96ca159127';

/// Whether Pulsar knows [song] as one of the account's favourites.

final class PulsarFavouriteStateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, LibrarySong> {
  PulsarFavouriteStateFamily._()
    : super(
        retry: null,
        name: r'pulsarFavouriteStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether Pulsar knows [song] as one of the account's favourites.

  PulsarFavouriteStateProvider call(LibrarySong song) =>
      PulsarFavouriteStateProvider._(argument: song, from: this);

  @override
  String toString() => r'pulsarFavouriteStateProvider';
}
