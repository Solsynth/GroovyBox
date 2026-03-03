// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lrc_fetcher_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LyricsFetcher)
final lyricsFetcherProvider = LyricsFetcherProvider._();

final class LyricsFetcherProvider
    extends $NotifierProvider<LyricsFetcher, LyricsFetcherState> {
  LyricsFetcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lyricsFetcherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lyricsFetcherHash();

  @$internal
  @override
  LyricsFetcher create() => LyricsFetcher();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LyricsFetcherState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LyricsFetcherState>(value),
    );
  }
}

String _$lyricsFetcherHash() => r'0b279b6294947cc0460c9fa8a5ef3863e24677f9';

abstract class _$LyricsFetcher extends $Notifier<LyricsFetcherState> {
  LyricsFetcherState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LyricsFetcherState, LyricsFetcherState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LyricsFetcherState, LyricsFetcherState>,
              LyricsFetcherState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
