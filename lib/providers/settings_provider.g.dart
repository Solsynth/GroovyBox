// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SettingsNotifier)
final settingsProvider = SettingsNotifierProvider._();

final class SettingsNotifierProvider
    extends $AsyncNotifierProvider<SettingsNotifier, SettingsState> {
  SettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsNotifierHash();

  @$internal
  @override
  SettingsNotifier create() => SettingsNotifier();
}

String _$settingsNotifierHash() => r'6825709a9c6ccdb5b2402aac1c75d742f5344527';

abstract class _$SettingsNotifier extends $AsyncNotifier<SettingsState> {
  FutureOr<SettingsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SettingsState>, SettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SettingsState>, SettingsState>,
              AsyncValue<SettingsState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(ImportModeNotifier)
final importModeProvider = ImportModeNotifierProvider._();

final class ImportModeNotifierProvider
    extends $NotifierProvider<ImportModeNotifier, ImportMode> {
  ImportModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importModeNotifierHash();

  @$internal
  @override
  ImportModeNotifier create() => ImportModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportMode>(value),
    );
  }
}

String _$importModeNotifierHash() =>
    r'4a4f8d3bb378e964f1d67159a650a2d7addeab69';

abstract class _$ImportModeNotifier extends $Notifier<ImportMode> {
  ImportMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ImportMode, ImportMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImportMode, ImportMode>,
              ImportMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(AutoScanNotifier)
final autoScanProvider = AutoScanNotifierProvider._();

final class AutoScanNotifierProvider
    extends $NotifierProvider<AutoScanNotifier, bool> {
  AutoScanNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoScanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoScanNotifierHash();

  @$internal
  @override
  AutoScanNotifier create() => AutoScanNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$autoScanNotifierHash() => r'e8d7c9bd7059e0117979b120616addcd5c1abb8d';

abstract class _$AutoScanNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(WatchForChangesNotifier)
final watchForChangesProvider = WatchForChangesNotifierProvider._();

final class WatchForChangesNotifierProvider
    extends $NotifierProvider<WatchForChangesNotifier, bool> {
  WatchForChangesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchForChangesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchForChangesNotifierHash();

  @$internal
  @override
  WatchForChangesNotifier create() => WatchForChangesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$watchForChangesNotifierHash() =>
    r'1f15ffac52a0401b14d8cd4e04d39c69d5a2e704';

abstract class _$WatchForChangesNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(DefaultPlayerScreenNotifier)
final defaultPlayerScreenProvider = DefaultPlayerScreenNotifierProvider._();

final class DefaultPlayerScreenNotifierProvider
    extends
        $NotifierProvider<DefaultPlayerScreenNotifier, DefaultPlayerScreen> {
  DefaultPlayerScreenNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultPlayerScreenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultPlayerScreenNotifierHash();

  @$internal
  @override
  DefaultPlayerScreenNotifier create() => DefaultPlayerScreenNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DefaultPlayerScreen value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DefaultPlayerScreen>(value),
    );
  }
}

String _$defaultPlayerScreenNotifierHash() =>
    r'cddfe0510ec38b3d5800901bd018728ca2567d54';

abstract class _$DefaultPlayerScreenNotifier
    extends $Notifier<DefaultPlayerScreen> {
  DefaultPlayerScreen build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DefaultPlayerScreen, DefaultPlayerScreen>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DefaultPlayerScreen, DefaultPlayerScreen>,
              DefaultPlayerScreen,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(LyricsModeNotifier)
final lyricsModeProvider = LyricsModeNotifierProvider._();

final class LyricsModeNotifierProvider
    extends $NotifierProvider<LyricsModeNotifier, LyricsMode> {
  LyricsModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lyricsModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lyricsModeNotifierHash();

  @$internal
  @override
  LyricsModeNotifier create() => LyricsModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LyricsMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LyricsMode>(value),
    );
  }
}

String _$lyricsModeNotifierHash() =>
    r'b3f77739bfab6bb7551cb31bebfef5c8b6dcb423';

abstract class _$LyricsModeNotifier extends $Notifier<LyricsMode> {
  LyricsMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LyricsMode, LyricsMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LyricsMode, LyricsMode>,
              LyricsMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(ContinuePlaysNotifier)
final continuePlaysProvider = ContinuePlaysNotifierProvider._();

final class ContinuePlaysNotifierProvider
    extends $NotifierProvider<ContinuePlaysNotifier, bool> {
  ContinuePlaysNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continuePlaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continuePlaysNotifierHash();

  @$internal
  @override
  ContinuePlaysNotifier create() => ContinuePlaysNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$continuePlaysNotifierHash() =>
    r'17e5f9c933d67837301775ac5beda25462130775';

abstract class _$ContinuePlaysNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
