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
///
/// Watches the session's state, not its notifier: the notifier's own `build`
/// is a future, so a first read of it is `AsyncLoading` and [validSession]
/// answers null from that. Watched that way the answer was captured once by
/// this `keepAlive` provider and stayed "signed out" for the rest of the
/// process — including right after a successful login — which is why a
/// logged-in user was still told to log in.

@ProviderFor(pulsarSession)
final pulsarSessionProvider = PulsarSessionProvider._();

/// The signed-in session or null, unwrapped once for every Pulsar call.
///
/// Watches the session's state, not its notifier: the notifier's own `build`
/// is a future, so a first read of it is `AsyncLoading` and [validSession]
/// answers null from that. Watched that way the answer was captured once by
/// this `keepAlive` provider and stayed "signed out" for the rest of the
/// process — including right after a successful login — which is why a
/// logged-in user was still told to log in.

final class PulsarSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<OAuthSession?>,
          OAuthSession?,
          FutureOr<OAuthSession?>
        >
    with $FutureModifier<OAuthSession?>, $FutureProvider<OAuthSession?> {
  /// The signed-in session or null, unwrapped once for every Pulsar call.
  ///
  /// Watches the session's state, not its notifier: the notifier's own `build`
  /// is a future, so a first read of it is `AsyncLoading` and [validSession]
  /// answers null from that. Watched that way the answer was captured once by
  /// this `keepAlive` provider and stayed "signed out" for the rest of the
  /// process — including right after a successful login — which is why a
  /// logged-in user was still told to log in.
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

String _$pulsarSessionHash() => r'0f47f92904600208e14dfb12761846b9ae929966';

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

String _$pulsarPlaylistsHash() => r'a2eaec104bfe7d3ad297157a5bf342d1825d6578';

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

@ProviderFor(PulsarPlaylistDetail)
final pulsarPlaylistDetailProvider = PulsarPlaylistDetailFamily._();

/// One cloud playlist as the detail page reads it: the collection itself
/// with its items preloaded, from the one endpoint that returns both.
final class PulsarPlaylistDetailProvider
    extends $AsyncNotifierProvider<PulsarPlaylistDetail, PulsarPlaylist> {
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
  PulsarPlaylistDetail create() => PulsarPlaylistDetail();

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
    r'2f77ab173498520e6bdf4d5e0c94887a4cbe7031';

/// One cloud playlist as the detail page reads it: the collection itself
/// with its items preloaded, from the one endpoint that returns both.

final class PulsarPlaylistDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          PulsarPlaylistDetail,
          AsyncValue<PulsarPlaylist>,
          PulsarPlaylist,
          FutureOr<PulsarPlaylist>,
          String
        > {
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

/// One cloud playlist as the detail page reads it: the collection itself
/// with its items preloaded, from the one endpoint that returns both.

abstract class _$PulsarPlaylistDetail extends $AsyncNotifier<PulsarPlaylist> {
  late final _$args = ref.$arg as String;
  String get playlistId => _$args;

  FutureOr<PulsarPlaylist> build(String playlistId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PulsarPlaylist>, PulsarPlaylist>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PulsarPlaylist>, PulsarPlaylist>,
              AsyncValue<PulsarPlaylist>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// One cover URL per cloud playlist, for lists that draw the item.
///
/// A collection record carries `artwork_url` only when someone set it, and a
/// playlist made by uploading tracks never did: the list response is a bare
/// array with no items, so the row had nothing to draw and every Solar
/// playlist read as a grey cloud. The cover a playlist actually shows is its
/// first track's artwork, which only the detail read knows — so the ones
/// missing a cover ask for it once, and a failure costs a cover, never the
/// list.

@ProviderFor(pulsarPlaylistCovers)
final pulsarPlaylistCoversProvider = PulsarPlaylistCoversProvider._();

/// One cover URL per cloud playlist, for lists that draw the item.
///
/// A collection record carries `artwork_url` only when someone set it, and a
/// playlist made by uploading tracks never did: the list response is a bare
/// array with no items, so the row had nothing to draw and every Solar
/// playlist read as a grey cloud. The cover a playlist actually shows is its
/// first track's artwork, which only the detail read knows — so the ones
/// missing a cover ask for it once, and a failure costs a cover, never the
/// list.

final class PulsarPlaylistCoversProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// One cover URL per cloud playlist, for lists that draw the item.
  ///
  /// A collection record carries `artwork_url` only when someone set it, and a
  /// playlist made by uploading tracks never did: the list response is a bare
  /// array with no items, so the row had nothing to draw and every Solar
  /// playlist read as a grey cloud. The cover a playlist actually shows is its
  /// first track's artwork, which only the detail read knows — so the ones
  /// missing a cover ask for it once, and a failure costs a cover, never the
  /// list.
  PulsarPlaylistCoversProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulsarPlaylistCoversProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulsarPlaylistCoversHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return pulsarPlaylistCovers(ref);
  }
}

String _$pulsarPlaylistCoversHash() =>
    r'db26680b9f905bb873dcc5d35a50b1bbae9e5247';

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.

@ProviderFor(PulsarPlaylistSongs)
final pulsarPlaylistSongsProvider = PulsarPlaylistSongsFamily._();

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.
final class PulsarPlaylistSongsProvider
    extends $AsyncNotifierProvider<PulsarPlaylistSongs, List<LibrarySong?>> {
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
  PulsarPlaylistSongs create() => PulsarPlaylistSongs();

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
    r'f55ad6e0bdea4aca7412f3e5598e8882b3a6525a';

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.

final class PulsarPlaylistSongsFamily extends $Family
    with
        $ClassFamilyOverride<
          PulsarPlaylistSongs,
          AsyncValue<List<LibrarySong?>>,
          List<LibrarySong?>,
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

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.
///
/// The result is index-aligned with [PulsarPlaylist.items], with null where
/// no library holds the track: the playlist's order is the server's, and a
/// dropped entry would shift every row after it onto the wrong track.

abstract class _$PulsarPlaylistSongs
    extends $AsyncNotifier<List<LibrarySong?>> {
  late final _$args = ref.$arg as PulsarPlaylist;
  PulsarPlaylist get playlist => _$args;

  FutureOr<List<LibrarySong?>> build(PulsarPlaylist playlist);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<LibrarySong?>>, List<LibrarySong?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<LibrarySong?>>, List<LibrarySong?>>,
              AsyncValue<List<LibrarySong?>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
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
    r'8085dae0a75d938c053308006f6fec02b68e3b9b';

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

String _$pulsarTasteHash() => r'353bcc129daf44d26fca6203512d8d345dc5476e';

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

String _$pulsarFavouritesHash() => r'44139fe67e6fab1d49e51bd4160ab6675fb9fd98';

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

/// The account's favourite recordings, as the source-scoped keys every Solar
/// write spells a track with. One key set is what the heart reads, so the
/// question costs no request per redraw.

@ProviderFor(solarFavouriteKeys)
final solarFavouriteKeysProvider = SolarFavouriteKeysProvider._();

/// The account's favourite recordings, as the source-scoped keys every Solar
/// write spells a track with. One key set is what the heart reads, so the
/// question costs no request per redraw.

final class SolarFavouriteKeysProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// The account's favourite recordings, as the source-scoped keys every Solar
  /// write spells a track with. One key set is what the heart reads, so the
  /// question costs no request per redraw.
  SolarFavouriteKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'solarFavouriteKeysProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$solarFavouriteKeysHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return solarFavouriteKeys(ref);
  }
}

String _$solarFavouriteKeysHash() =>
    r'4e228d6ff278d6a76863ff0e4e6ac50af29289d3';

/// Whether the account holds [song] as a favourite.
///
/// Solar Network is the record when this device is signed in: a heart set on
/// any device, or imported from another provider, is the answer every surface
/// draws. Signed out there is no account to ask, so the device's own record
/// answers instead of the heart going blank.

@ProviderFor(solarFavouriteState)
final solarFavouriteStateProvider = SolarFavouriteStateFamily._();

/// Whether the account holds [song] as a favourite.
///
/// Solar Network is the record when this device is signed in: a heart set on
/// any device, or imported from another provider, is the answer every surface
/// draws. Signed out there is no account to ask, so the device's own record
/// answers instead of the heart going blank.

final class SolarFavouriteStateProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the account holds [song] as a favourite.
  ///
  /// Solar Network is the record when this device is signed in: a heart set on
  /// any device, or imported from another provider, is the answer every surface
  /// draws. Signed out there is no account to ask, so the device's own record
  /// answers instead of the heart going blank.
  SolarFavouriteStateProvider._({
    required SolarFavouriteStateFamily super.from,
    required LibrarySong super.argument,
  }) : super(
         retry: null,
         name: r'solarFavouriteStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$solarFavouriteStateHash();

  @override
  String toString() {
    return r'solarFavouriteStateProvider'
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
    return solarFavouriteState(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SolarFavouriteStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$solarFavouriteStateHash() =>
    r'9477f186fc6bcc0ce1de7cdab706621d05264d50';

/// Whether the account holds [song] as a favourite.
///
/// Solar Network is the record when this device is signed in: a heart set on
/// any device, or imported from another provider, is the answer every surface
/// draws. Signed out there is no account to ask, so the device's own record
/// answers instead of the heart going blank.

final class SolarFavouriteStateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, LibrarySong> {
  SolarFavouriteStateFamily._()
    : super(
        retry: null,
        name: r'solarFavouriteStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether the account holds [song] as a favourite.
  ///
  /// Solar Network is the record when this device is signed in: a heart set on
  /// any device, or imported from another provider, is the answer every surface
  /// draws. Signed out there is no account to ask, so the device's own record
  /// answers instead of the heart going blank.

  SolarFavouriteStateProvider call(LibrarySong song) =>
      SolarFavouriteStateProvider._(argument: song, from: this);

  @override
  String toString() => r'solarFavouriteStateProvider';
}

/// The account's favourites, resolved to the copies this device can play.
///
/// Index-aligned with [pulsarFavouritesProvider]: null where no connected
/// library holds the recording. Dropping the entry instead would shift every
/// row after it onto the wrong track, and the account's order is the truth.

@ProviderFor(solarFavouriteSongs)
final solarFavouriteSongsProvider = SolarFavouriteSongsProvider._();

/// The account's favourites, resolved to the copies this device can play.
///
/// Index-aligned with [pulsarFavouritesProvider]: null where no connected
/// library holds the recording. Dropping the entry instead would shift every
/// row after it onto the wrong track, and the account's order is the truth.

final class SolarFavouriteSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibrarySong?>>,
          List<LibrarySong?>,
          FutureOr<List<LibrarySong?>>
        >
    with
        $FutureModifier<List<LibrarySong?>>,
        $FutureProvider<List<LibrarySong?>> {
  /// The account's favourites, resolved to the copies this device can play.
  ///
  /// Index-aligned with [pulsarFavouritesProvider]: null where no connected
  /// library holds the recording. Dropping the entry instead would shift every
  /// row after it onto the wrong track, and the account's order is the truth.
  SolarFavouriteSongsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'solarFavouriteSongsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$solarFavouriteSongsHash();

  @$internal
  @override
  $FutureProviderElement<List<LibrarySong?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LibrarySong?>> create(Ref ref) {
    return solarFavouriteSongs(ref);
  }
}

String _$solarFavouriteSongsHash() =>
    r'5d207cb11ff1132099a1b6be3787ad78191ae13c';

/// The account's favourite albums and playlists, newest decision first.
///
/// The same list [pulsarFavouritesProvider] holds, narrowed to the entries
/// whose kind is a collection: one read is the truth for every heart in the
/// app, and which of them a page shows is a filter, not a second request.

@ProviderFor(solarCollectionFavourites)
final solarCollectionFavouritesProvider = SolarCollectionFavouritesProvider._();

/// The account's favourite albums and playlists, newest decision first.
///
/// The same list [pulsarFavouritesProvider] holds, narrowed to the entries
/// whose kind is a collection: one read is the truth for every heart in the
/// app, and which of them a page shows is a filter, not a second request.

final class SolarCollectionFavouritesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CollectionFavourite>>,
          List<CollectionFavourite>,
          FutureOr<List<CollectionFavourite>>
        >
    with
        $FutureModifier<List<CollectionFavourite>>,
        $FutureProvider<List<CollectionFavourite>> {
  /// The account's favourite albums and playlists, newest decision first.
  ///
  /// The same list [pulsarFavouritesProvider] holds, narrowed to the entries
  /// whose kind is a collection: one read is the truth for every heart in the
  /// app, and which of them a page shows is a filter, not a second request.
  SolarCollectionFavouritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'solarCollectionFavouritesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$solarCollectionFavouritesHash();

  @$internal
  @override
  $FutureProviderElement<List<CollectionFavourite>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CollectionFavourite>> create(Ref ref) {
    return solarCollectionFavourites(ref);
  }
}

String _$solarCollectionFavouritesHash() =>
    r'4504de559a57f6f717b8f94f44171313cd9bee87';

/// Whether this album or playlist is a favourite.
///
/// The account is the record when signed in, exactly as it is for a track: a
/// heart set on another device is what every surface draws. Signed out the
/// device's own row answers, so the heart still works with no account.

@ProviderFor(collectionFavouriteState)
final collectionFavouriteStateProvider = CollectionFavouriteStateFamily._();

/// Whether this album or playlist is a favourite.
///
/// The account is the record when signed in, exactly as it is for a track: a
/// heart set on another device is what every surface draws. Signed out the
/// device's own row answers, so the heart still works with no account.

final class CollectionFavouriteStateProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether this album or playlist is a favourite.
  ///
  /// The account is the record when signed in, exactly as it is for a track: a
  /// heart set on another device is what every surface draws. Signed out the
  /// device's own row answers, so the heart still works with no account.
  CollectionFavouriteStateProvider._({
    required CollectionFavouriteStateFamily super.from,
    required CollectionFavouriteKey super.argument,
  }) : super(
         retry: null,
         name: r'collectionFavouriteStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$collectionFavouriteStateHash();

  @override
  String toString() {
    return r'collectionFavouriteStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as CollectionFavouriteKey;
    return collectionFavouriteState(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionFavouriteStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionFavouriteStateHash() =>
    r'dae70bc9df1afaaf0eea8c50b213ca87b645cb07';

/// Whether this album or playlist is a favourite.
///
/// The account is the record when signed in, exactly as it is for a track: a
/// heart set on another device is what every surface draws. Signed out the
/// device's own row answers, so the heart still works with no account.

final class CollectionFavouriteStateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, CollectionFavouriteKey> {
  CollectionFavouriteStateFamily._()
    : super(
        retry: null,
        name: r'collectionFavouriteStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether this album or playlist is a favourite.
  ///
  /// The account is the record when signed in, exactly as it is for a track: a
  /// heart set on another device is what every surface draws. Signed out the
  /// device's own row answers, so the heart still works with no account.

  CollectionFavouriteStateProvider call(CollectionFavouriteKey key) =>
      CollectionFavouriteStateProvider._(argument: key, from: this);

  @override
  String toString() => r'collectionFavouriteStateProvider';
}

/// The device's own heart for one album or playlist.

@ProviderFor(deviceCollectionFavouriteState)
final deviceCollectionFavouriteStateProvider =
    DeviceCollectionFavouriteStateFamily._();

/// The device's own heart for one album or playlist.

final class DeviceCollectionFavouriteStateProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// The device's own heart for one album or playlist.
  DeviceCollectionFavouriteStateProvider._({
    required DeviceCollectionFavouriteStateFamily super.from,
    required CollectionFavouriteKey super.argument,
  }) : super(
         retry: null,
         name: r'deviceCollectionFavouriteStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$deviceCollectionFavouriteStateHash();

  @override
  String toString() {
    return r'deviceCollectionFavouriteStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as CollectionFavouriteKey;
    return deviceCollectionFavouriteState(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DeviceCollectionFavouriteStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$deviceCollectionFavouriteStateHash() =>
    r'd6a783f6610eeadd3b3ad0125586baf7f8c9ac76';

/// The device's own heart for one album or playlist.

final class DeviceCollectionFavouriteStateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, CollectionFavouriteKey> {
  DeviceCollectionFavouriteStateFamily._()
    : super(
        retry: null,
        name: r'deviceCollectionFavouriteStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The device's own heart for one album or playlist.

  DeviceCollectionFavouriteStateProvider call(CollectionFavouriteKey key) =>
      DeviceCollectionFavouriteStateProvider._(argument: key, from: this);

  @override
  String toString() => r'deviceCollectionFavouriteStateProvider';
}

/// The fleet's view of [name]. Null when signed out, when nothing matches,
/// or when the fleet is unreachable — each a reason the section stays quiet,
/// never a failure of the page.

@ProviderFor(pulsarArtistMetadata)
final pulsarArtistMetadataProvider = PulsarArtistMetadataFamily._();

/// The fleet's view of [name]. Null when signed out, when nothing matches,
/// or when the fleet is unreachable — each a reason the section stays quiet,
/// never a failure of the page.

final class PulsarArtistMetadataProvider
    extends
        $FunctionalProvider<
          AsyncValue<PulsarArtistMetadata?>,
          PulsarArtistMetadata?,
          FutureOr<PulsarArtistMetadata?>
        >
    with
        $FutureModifier<PulsarArtistMetadata?>,
        $FutureProvider<PulsarArtistMetadata?> {
  /// The fleet's view of [name]. Null when signed out, when nothing matches,
  /// or when the fleet is unreachable — each a reason the section stays quiet,
  /// never a failure of the page.
  PulsarArtistMetadataProvider._({
    required PulsarArtistMetadataFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pulsarArtistMetadataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulsarArtistMetadataHash();

  @override
  String toString() {
    return r'pulsarArtistMetadataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PulsarArtistMetadata?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PulsarArtistMetadata?> create(Ref ref) {
    final argument = this.argument as String;
    return pulsarArtistMetadata(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PulsarArtistMetadataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulsarArtistMetadataHash() =>
    r'3babe44d7b625c755ef0632e6cf055f535a1f0fd';

/// The fleet's view of [name]. Null when signed out, when nothing matches,
/// or when the fleet is unreachable — each a reason the section stays quiet,
/// never a failure of the page.

final class PulsarArtistMetadataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PulsarArtistMetadata?>, String> {
  PulsarArtistMetadataFamily._()
    : super(
        retry: null,
        name: r'pulsarArtistMetadataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The fleet's view of [name]. Null when signed out, when nothing matches,
  /// or when the fleet is unreachable — each a reason the section stays quiet,
  /// never a failure of the page.

  PulsarArtistMetadataProvider call(String name) =>
      PulsarArtistMetadataProvider._(argument: name, from: this);

  @override
  String toString() => r'pulsarArtistMetadataProvider';
}

/// The fleet's record for one artist, as the artist page reads it.
///
/// Signed out is not a failure: the endpoint is public, and the section
/// simply shows what the request answered. Any failure — the fleet being
/// down, a name MusicBrainz does not know — answers null so the page keeps
/// the device's own libraries and never turns into an error screen.

@ProviderFor(pulsarArtistProfile)
final pulsarArtistProfileProvider = PulsarArtistProfileFamily._();

/// The fleet's record for one artist, as the artist page reads it.
///
/// Signed out is not a failure: the endpoint is public, and the section
/// simply shows what the request answered. Any failure — the fleet being
/// down, a name MusicBrainz does not know — answers null so the page keeps
/// the device's own libraries and never turns into an error screen.

final class PulsarArtistProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<PulsarEntityMetadata?>,
          PulsarEntityMetadata?,
          FutureOr<PulsarEntityMetadata?>
        >
    with
        $FutureModifier<PulsarEntityMetadata?>,
        $FutureProvider<PulsarEntityMetadata?> {
  /// The fleet's record for one artist, as the artist page reads it.
  ///
  /// Signed out is not a failure: the endpoint is public, and the section
  /// simply shows what the request answered. Any failure — the fleet being
  /// down, a name MusicBrainz does not know — answers null so the page keeps
  /// the device's own libraries and never turns into an error screen.
  PulsarArtistProfileProvider._({
    required PulsarArtistProfileFamily super.from,
    required (String, {String? language}) super.argument,
  }) : super(
         retry: null,
         name: r'pulsarArtistProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulsarArtistProfileHash();

  @override
  String toString() {
    return r'pulsarArtistProfileProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PulsarEntityMetadata?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PulsarEntityMetadata?> create(Ref ref) {
    final argument = this.argument as (String, {String? language});
    return pulsarArtistProfile(ref, argument.$1, language: argument.language);
  }

  @override
  bool operator ==(Object other) {
    return other is PulsarArtistProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulsarArtistProfileHash() =>
    r'3005adb64960e6d7c7d4d25b3c0e3290de5a2cad';

/// The fleet's record for one artist, as the artist page reads it.
///
/// Signed out is not a failure: the endpoint is public, and the section
/// simply shows what the request answered. Any failure — the fleet being
/// down, a name MusicBrainz does not know — answers null so the page keeps
/// the device's own libraries and never turns into an error screen.

final class PulsarArtistProfileFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PulsarEntityMetadata?>,
          (String, {String? language})
        > {
  PulsarArtistProfileFamily._()
    : super(
        retry: null,
        name: r'pulsarArtistProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The fleet's record for one artist, as the artist page reads it.
  ///
  /// Signed out is not a failure: the endpoint is public, and the section
  /// simply shows what the request answered. Any failure — the fleet being
  /// down, a name MusicBrainz does not know — answers null so the page keeps
  /// the device's own libraries and never turns into an error screen.

  PulsarArtistProfileProvider call(String name, {String? language}) =>
      PulsarArtistProfileProvider._(
        argument: (name, language: language),
        from: this,
      );

  @override
  String toString() => r'pulsarArtistProfileProvider';
}

/// The fleet's record for one album, asked by title and artist — the pair
/// every connected library spells.

@ProviderFor(pulsarAlbumProfile)
final pulsarAlbumProfileProvider = PulsarAlbumProfileFamily._();

/// The fleet's record for one album, asked by title and artist — the pair
/// every connected library spells.

final class PulsarAlbumProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<PulsarEntityMetadata?>,
          PulsarEntityMetadata?,
          FutureOr<PulsarEntityMetadata?>
        >
    with
        $FutureModifier<PulsarEntityMetadata?>,
        $FutureProvider<PulsarEntityMetadata?> {
  /// The fleet's record for one album, asked by title and artist — the pair
  /// every connected library spells.
  PulsarAlbumProfileProvider._({
    required PulsarAlbumProfileFamily super.from,
    required ({String title, String? artist, String? language}) super.argument,
  }) : super(
         retry: null,
         name: r'pulsarAlbumProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulsarAlbumProfileHash();

  @override
  String toString() {
    return r'pulsarAlbumProfileProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PulsarEntityMetadata?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PulsarEntityMetadata?> create(Ref ref) {
    final argument =
        this.argument as ({String title, String? artist, String? language});
    return pulsarAlbumProfile(
      ref,
      title: argument.title,
      artist: argument.artist,
      language: argument.language,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PulsarAlbumProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulsarAlbumProfileHash() =>
    r'bd7c9681956d43cca86ccc070aee7e43d5460689';

/// The fleet's record for one album, asked by title and artist — the pair
/// every connected library spells.

final class PulsarAlbumProfileFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PulsarEntityMetadata?>,
          ({String title, String? artist, String? language})
        > {
  PulsarAlbumProfileFamily._()
    : super(
        retry: null,
        name: r'pulsarAlbumProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The fleet's record for one album, asked by title and artist — the pair
  /// every connected library spells.

  PulsarAlbumProfileProvider call({
    required String title,
    String? artist,
    String? language,
  }) => PulsarAlbumProfileProvider._(
    argument: (title: title, artist: artist, language: language),
    from: this,
  );

  @override
  String toString() => r'pulsarAlbumProfileProvider';
}
