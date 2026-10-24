// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform prefs store, opened in `main` and injected into the container.
///
/// Overriding it (instead of calling `getInstance` inside providers) keeps the
/// store synchronous to read, so the first frame already knows the theme and
/// whether a server is configured.

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

/// The platform prefs store, opened in `main` and injected into the container.
///
/// Overriding it (instead of calling `getInstance` inside providers) keeps the
/// store synchronous to read, so the first frame already knows the theme and
/// whether a server is configured.

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          SharedPreferences,
          SharedPreferences,
          SharedPreferences
        >
    with $Provider<SharedPreferences> {
  /// The platform prefs store, opened in `main` and injected into the container.
  ///
  /// Overriding it (instead of calling `getInstance` inside providers) keeps the
  /// store synchronous to read, so the first frame already knows the theme and
  /// whether a server is configured.
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SharedPreferences create(Ref ref) {
    return sharedPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences>(value),
    );
  }
}

String _$sharedPreferencesHash() => r'202c01c26ca87869b7483dea241401711caea82b';

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, AppThemeMode> {
  ThemeModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$themeModeNotifierHash() => r'903366b15ec0790d3b12e7876e964939243ada15';

abstract class _$ThemeModeNotifier extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppThemeMode, AppThemeMode>,
              AppThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(appTheme)
final appThemeProvider = AppThemeProvider._();

final class AppThemeProvider
    extends $FunctionalProvider<ThemeSet, ThemeSet, ThemeSet>
    with $Provider<ThemeSet> {
  AppThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appThemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeSet> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeSet create(Ref ref) {
    return appTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeSet value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeSet>(value),
    );
  }
}

String _$appThemeHash() => r'919629fe3e460d470280dc4ed7d873aa9d087ada';

/// The configured server, or null before the first sign-in.
///
/// The stored form holds the Subsonic token and salt rather than the password:
/// signing out simply drops the whole record.

@ProviderFor(ServerConnection)
final serverConnectionProvider = ServerConnectionProvider._();

/// The configured server, or null before the first sign-in.
///
/// The stored form holds the Subsonic token and salt rather than the password:
/// signing out simply drops the whole record.
final class ServerConnectionProvider
    extends $NotifierProvider<ServerConnection, ServerConfig?> {
  /// The configured server, or null before the first sign-in.
  ///
  /// The stored form holds the Subsonic token and salt rather than the password:
  /// signing out simply drops the whole record.
  ServerConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverConnectionHash();

  @$internal
  @override
  ServerConnection create() => ServerConnection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerConfig? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerConfig?>(value),
    );
  }
}

String _$serverConnectionHash() => r'1e498caaf9c99b83cbb3e54befdcbbcc02f79dfc';

/// The configured server, or null before the first sign-in.
///
/// The stored form holds the Subsonic token and salt rather than the password:
/// signing out simply drops the whole record.

abstract class _$ServerConnection extends $Notifier<ServerConfig?> {
  ServerConfig? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ServerConfig?, ServerConfig?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServerConfig?, ServerConfig?>,
              ServerConfig?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The active API client, or null when not signed in.
///
/// Rebuilt whenever the connection changes, which is what makes every screen
/// follow a server switch without any manual refresh.

@ProviderFor(subsonicClient)
final subsonicClientProvider = SubsonicClientProvider._();

/// The active API client, or null when not signed in.
///
/// Rebuilt whenever the connection changes, which is what makes every screen
/// follow a server switch without any manual refresh.

final class SubsonicClientProvider
    extends
        $FunctionalProvider<SubsonicClient?, SubsonicClient?, SubsonicClient?>
    with $Provider<SubsonicClient?> {
  /// The active API client, or null when not signed in.
  ///
  /// Rebuilt whenever the connection changes, which is what makes every screen
  /// follow a server switch without any manual refresh.
  SubsonicClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subsonicClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subsonicClientHash();

  @$internal
  @override
  $ProviderElement<SubsonicClient?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SubsonicClient? create(Ref ref) {
    return subsonicClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubsonicClient? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubsonicClient?>(value),
    );
  }
}

String _$subsonicClientHash() => r'65b104ed5f86ce928120e58a7df748a4d418fc3b';

/// Last volume, restored so the window does not startle the user.

@ProviderFor(initialVolume)
final initialVolumeProvider = InitialVolumeProvider._();

/// Last volume, restored so the window does not startle the user.

final class InitialVolumeProvider
    extends $FunctionalProvider<double, double, double>
    with $Provider<double> {
  /// Last volume, restored so the window does not startle the user.
  InitialVolumeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialVolumeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialVolumeHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return initialVolume(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$initialVolumeHash() => r'6f6f08d339403948fd5aa2eaa53a8a8b3e226e74';
