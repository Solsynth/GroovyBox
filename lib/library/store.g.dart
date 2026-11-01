// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every connected library, in the order the user added them.
///
/// Merged reads (see `LibraryAggregator`) use this order, so it is also the
/// order sections appear in the UI.

@ProviderFor(SourceStore)
final sourceStoreProvider = SourceStoreProvider._();

/// Every connected library, in the order the user added them.
///
/// Merged reads (see `LibraryAggregator`) use this order, so it is also the
/// order sections appear in the UI.
final class SourceStoreProvider
    extends $NotifierProvider<SourceStore, List<SourceConfig>> {
  /// Every connected library, in the order the user added them.
  ///
  /// Merged reads (see `LibraryAggregator`) use this order, so it is also the
  /// order sections appear in the UI.
  SourceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceStoreHash();

  @$internal
  @override
  SourceStore create() => SourceStore();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SourceConfig> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SourceConfig>>(value),
    );
  }
}

String _$sourceStoreHash() => r'13beb8ce7fba82b31bbffcedd81c946ad075fac7';

/// Every connected library, in the order the user added them.
///
/// Merged reads (see `LibraryAggregator`) use this order, so it is also the
/// order sections appear in the UI.

abstract class _$SourceStore extends $Notifier<List<SourceConfig>> {
  List<SourceConfig> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<SourceConfig>, List<SourceConfig>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<SourceConfig>, List<SourceConfig>>,
              List<SourceConfig>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
