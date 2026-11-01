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

/// Whether chrome draws liquid glass. On by default: it is the app's look,
/// and the flat fallback exists for machines where the shader pass is too
/// expensive to pay on every scroll frame.

@ProviderFor(GlassEffectsEnabled)
final glassEffectsEnabledProvider = GlassEffectsEnabledProvider._();

/// Whether chrome draws liquid glass. On by default: it is the app's look,
/// and the flat fallback exists for machines where the shader pass is too
/// expensive to pay on every scroll frame.
final class GlassEffectsEnabledProvider
    extends $NotifierProvider<GlassEffectsEnabled, bool> {
  /// Whether chrome draws liquid glass. On by default: it is the app's look,
  /// and the flat fallback exists for machines where the shader pass is too
  /// expensive to pay on every scroll frame.
  GlassEffectsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'glassEffectsEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$glassEffectsEnabledHash();

  @$internal
  @override
  GlassEffectsEnabled create() => GlassEffectsEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$glassEffectsEnabledHash() =>
    r'55f146f200366968a87c24a7d888330603034f2d';

/// Whether chrome draws liquid glass. On by default: it is the app's look,
/// and the flat fallback exists for machines where the shader pass is too
/// expensive to pay on every scroll frame.

abstract class _$GlassEffectsEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether lyrics show pronunciation (Romanization / Romaji / Pinyin / Hangul).
/// On by default.

@ProviderFor(LyricsPronunciationEnabled)
final lyricsPronunciationEnabledProvider =
    LyricsPronunciationEnabledProvider._();

/// Whether lyrics show pronunciation (Romanization / Romaji / Pinyin / Hangul).
/// On by default.
final class LyricsPronunciationEnabledProvider
    extends $NotifierProvider<LyricsPronunciationEnabled, bool> {
  /// Whether lyrics show pronunciation (Romanization / Romaji / Pinyin / Hangul).
  /// On by default.
  LyricsPronunciationEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lyricsPronunciationEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lyricsPronunciationEnabledHash();

  @$internal
  @override
  LyricsPronunciationEnabled create() => LyricsPronunciationEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$lyricsPronunciationEnabledHash() =>
    r'db7170e7e6917746904dc61c3aefbdd25a15b01b';

/// Whether lyrics show pronunciation (Romanization / Romaji / Pinyin / Hangul).
/// On by default.

abstract class _$LyricsPronunciationEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether lyrics show translations. On by default.

@ProviderFor(LyricsTranslationEnabled)
final lyricsTranslationEnabledProvider = LyricsTranslationEnabledProvider._();

/// Whether lyrics show translations. On by default.
final class LyricsTranslationEnabledProvider
    extends $NotifierProvider<LyricsTranslationEnabled, bool> {
  /// Whether lyrics show translations. On by default.
  LyricsTranslationEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lyricsTranslationEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lyricsTranslationEnabledHash();

  @$internal
  @override
  LyricsTranslationEnabled create() => LyricsTranslationEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$lyricsTranslationEnabledHash() =>
    r'0eda632836180ced24a893372bc2cb85b63bbb45';

/// Whether lyrics show translations. On by default.

abstract class _$LyricsTranslationEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether playback continues indefinitely with random library tracks when
/// the queue reaches the end. On by default.

@ProviderFor(InfinitePlaybackEnabled)
final infinitePlaybackEnabledProvider = InfinitePlaybackEnabledProvider._();

/// Whether playback continues indefinitely with random library tracks when
/// the queue reaches the end. On by default.
final class InfinitePlaybackEnabledProvider
    extends $NotifierProvider<InfinitePlaybackEnabled, bool> {
  /// Whether playback continues indefinitely with random library tracks when
  /// the queue reaches the end. On by default.
  InfinitePlaybackEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'infinitePlaybackEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$infinitePlaybackEnabledHash();

  @$internal
  @override
  InfinitePlaybackEnabled create() => InfinitePlaybackEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$infinitePlaybackEnabledHash() =>
    r'a771a6f06836c49d7a0a3df99c9bc66429429523';

/// Whether playback continues indefinitely with random library tracks when
/// the queue reaches the end. On by default.

abstract class _$InfinitePlaybackEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
