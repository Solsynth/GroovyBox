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

String _$pulsarPlaylistsHash() => r'ea40091f66b32d1a8e56e07a9ebcc9879db6f450';

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

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.

@ProviderFor(pulsarPlaylistSongs)
final pulsarPlaylistSongsProvider = PulsarPlaylistSongsFamily._();

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.

final class PulsarPlaylistSongsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibrarySong>>,
          List<LibrarySong>,
          FutureOr<List<LibrarySong>>
        >
    with
        $FutureModifier<List<LibrarySong>>,
        $FutureProvider<List<LibrarySong>> {
  /// The songs of one Pulsar playlist, resolved against the connected library
  /// sources. A catalog entry is a record of a track, not a playable stream:
  /// matching is on title + artist, which is how the server dedupes too.
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
  $FutureProviderElement<List<LibrarySong>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LibrarySong>> create(Ref ref) {
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
    r'db13bea5cd8d26e8a5defbe970e7fa33ca0599d0';

/// The songs of one Pulsar playlist, resolved against the connected library
/// sources. A catalog entry is a record of a track, not a playable stream:
/// matching is on title + artist, which is how the server dedupes too.

final class PulsarPlaylistSongsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<LibrarySong>>, PulsarPlaylist> {
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
