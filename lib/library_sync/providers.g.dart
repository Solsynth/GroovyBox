// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// This device's persisted sync state.

@ProviderFor(librarySyncStateStore)
final librarySyncStateStoreProvider = LibrarySyncStateStoreProvider._();

/// This device's persisted sync state.

final class LibrarySyncStateStoreProvider
    extends
        $FunctionalProvider<
          LibrarySyncStateStore,
          LibrarySyncStateStore,
          LibrarySyncStateStore
        >
    with $Provider<LibrarySyncStateStore> {
  /// This device's persisted sync state.
  LibrarySyncStateStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySyncStateStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySyncStateStoreHash();

  @$internal
  @override
  $ProviderElement<LibrarySyncStateStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibrarySyncStateStore create(Ref ref) {
    return librarySyncStateStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySyncStateStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySyncStateStore>(value),
    );
  }
}

String _$librarySyncStateStoreHash() =>
    r'7328b71ae797f78749944db45b5ff745bc5b92bb';

/// The current sync state, kept in memory so a switch reads synchronously.

@ProviderFor(LibrarySyncStateNotifier)
final librarySyncStateProvider = LibrarySyncStateNotifierProvider._();

/// The current sync state, kept in memory so a switch reads synchronously.
final class LibrarySyncStateNotifierProvider
    extends $NotifierProvider<LibrarySyncStateNotifier, LibrarySyncState> {
  /// The current sync state, kept in memory so a switch reads synchronously.
  LibrarySyncStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySyncStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySyncStateNotifierHash();

  @$internal
  @override
  LibrarySyncStateNotifier create() => LibrarySyncStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySyncState>(value),
    );
  }
}

String _$librarySyncStateNotifierHash() =>
    r'1937740fb9433e7271b444287344a3ba6ff84451';

/// The current sync state, kept in memory so a switch reads synchronously.

abstract class _$LibrarySyncStateNotifier extends $Notifier<LibrarySyncState> {
  LibrarySyncState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibrarySyncState, LibrarySyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibrarySyncState, LibrarySyncState>,
              LibrarySyncState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The HTTP client, pointed at the one server setting Solarpass already owns.

@ProviderFor(librarySyncClient)
final librarySyncClientProvider = LibrarySyncClientProvider._();

/// The HTTP client, pointed at the one server setting Solarpass already owns.

final class LibrarySyncClientProvider
    extends
        $FunctionalProvider<
          LibrarySyncClient,
          LibrarySyncClient,
          LibrarySyncClient
        >
    with $Provider<LibrarySyncClient> {
  /// The HTTP client, pointed at the one server setting Solarpass already owns.
  LibrarySyncClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySyncClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySyncClientHash();

  @$internal
  @override
  $ProviderElement<LibrarySyncClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibrarySyncClient create(Ref ref) {
    return librarySyncClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySyncClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySyncClient>(value),
    );
  }
}

String _$librarySyncClientHash() => r'3c9865422d52a749abe7db43944dd87733760a22';

/// The engine, wired to the database, the client and the settings notifiers.

@ProviderFor(librarySyncEngine)
final librarySyncEngineProvider = LibrarySyncEngineProvider._();

/// The engine, wired to the database, the client and the settings notifiers.

final class LibrarySyncEngineProvider
    extends
        $FunctionalProvider<
          LibrarySyncEngine,
          LibrarySyncEngine,
          LibrarySyncEngine
        >
    with $Provider<LibrarySyncEngine> {
  /// The engine, wired to the database, the client and the settings notifiers.
  LibrarySyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySyncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySyncEngineHash();

  @$internal
  @override
  $ProviderElement<LibrarySyncEngine> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibrarySyncEngine create(Ref ref) {
    return librarySyncEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySyncEngine>(value),
    );
  }
}

String _$librarySyncEngineHash() => r'8e97c6c249fd24166ae65db5094975fe0922b87c';

/// The account's mirror summary plus the last local run.

@ProviderFor(LibrarySyncStatusView)
final librarySyncStatusViewProvider = LibrarySyncStatusViewProvider._();

/// The account's mirror summary plus the last local run.
final class LibrarySyncStatusViewProvider
    extends
        $NotifierProvider<LibrarySyncStatusView, LibrarySyncStatusViewState> {
  /// The account's mirror summary plus the last local run.
  LibrarySyncStatusViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySyncStatusViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySyncStatusViewHash();

  @$internal
  @override
  LibrarySyncStatusView create() => LibrarySyncStatusView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySyncStatusViewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySyncStatusViewState>(value),
    );
  }
}

String _$librarySyncStatusViewHash() =>
    r'15115cec14de7a79cd48bcfbd84b4fc6a7c7e84a';

/// The account's mirror summary plus the last local run.

abstract class _$LibrarySyncStatusView
    extends $Notifier<LibrarySyncStatusViewState> {
  LibrarySyncStatusViewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<LibrarySyncStatusViewState, LibrarySyncStatusViewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                LibrarySyncStatusViewState,
                LibrarySyncStatusViewState
              >,
              LibrarySyncStatusViewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Runs a sync when the window gains focus and the last push is stale, and
/// when a track ends.
///
/// Wired from `ShellScreen`, beside the scrobbler: both are session-level
/// listeners that must survive tab switches.

@ProviderFor(librarySyncAuto)
final librarySyncAutoProvider = LibrarySyncAutoProvider._();

/// Runs a sync when the window gains focus and the last push is stale, and
/// when a track ends.
///
/// Wired from `ShellScreen`, beside the scrobbler: both are session-level
/// listeners that must survive tab switches.

final class LibrarySyncAutoProvider
    extends
        $FunctionalProvider<LibrarySyncAuto, LibrarySyncAuto, LibrarySyncAuto>
    with $Provider<LibrarySyncAuto> {
  /// Runs a sync when the window gains focus and the last push is stale, and
  /// when a track ends.
  ///
  /// Wired from `ShellScreen`, beside the scrobbler: both are session-level
  /// listeners that must survive tab switches.
  LibrarySyncAutoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySyncAutoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySyncAutoHash();

  @$internal
  @override
  $ProviderElement<LibrarySyncAuto> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LibrarySyncAuto create(Ref ref) {
    return librarySyncAuto(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySyncAuto value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySyncAuto>(value),
    );
  }
}

String _$librarySyncAutoHash() => r'5bc79edee53c4961da1f5cb37d61c8c646a4d20b';
