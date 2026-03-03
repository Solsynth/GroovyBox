// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThemeNotifier)
final themeProvider = ThemeNotifierProvider._();

final class ThemeNotifierProvider
    extends $NotifierProvider<ThemeNotifier, ThemeMode> {
  ThemeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeNotifierHash();

  @$internal
  @override
  ThemeNotifier create() => ThemeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeNotifierHash() => r'5ba92ae22271e01ef165260fc7dc1cce6d1d72e0';

abstract class _$ThemeNotifier extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(SeedColorNotifier)
final seedColorProvider = SeedColorNotifierProvider._();

final class SeedColorNotifierProvider
    extends $NotifierProvider<SeedColorNotifier, Color> {
  SeedColorNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seedColorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seedColorNotifierHash();

  @$internal
  @override
  SeedColorNotifier create() => SeedColorNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Color value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Color>(value),
    );
  }
}

String _$seedColorNotifierHash() => r'2ab1da635e2528459e9bfc26db7eaf5c4ac6e701';

abstract class _$SeedColorNotifier extends $Notifier<Color> {
  Color build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Color, Color>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Color, Color>,
              Color,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(currentTheme)
final currentThemeProvider = CurrentThemeProvider._();

final class CurrentThemeProvider
    extends $FunctionalProvider<ThemeData, ThemeData, ThemeData>
    with $Provider<ThemeData> {
  CurrentThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentThemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeData> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeData create(Ref ref) {
    return currentTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeData>(value),
    );
  }
}

String _$currentThemeHash() => r'29c9080ae24ba144ebb6e0aac60b16bebcc8a919';

@ProviderFor(lightTheme)
final lightThemeProvider = LightThemeProvider._();

final class LightThemeProvider
    extends $FunctionalProvider<ThemeData, ThemeData, ThemeData>
    with $Provider<ThemeData> {
  LightThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lightThemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lightThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeData> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeData create(Ref ref) {
    return lightTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeData>(value),
    );
  }
}

String _$lightThemeHash() => r'be4e02c30ddc60a134ed2a1f7124caf162894889';

@ProviderFor(darkTheme)
final darkThemeProvider = DarkThemeProvider._();

final class DarkThemeProvider
    extends $FunctionalProvider<ThemeData, ThemeData, ThemeData>
    with $Provider<ThemeData> {
  DarkThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'darkThemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$darkThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeData> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeData create(Ref ref) {
    return darkTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeData>(value),
    );
  }
}

String _$darkThemeHash() => r'edc0e042521cc60d1d1bb026100ac46094825f7c';
