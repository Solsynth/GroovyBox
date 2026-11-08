// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_import.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One service for the session, so concurrent imports share one directory.

@ProviderFor(localImportService)
final localImportServiceProvider = LocalImportServiceProvider._();

/// One service for the session, so concurrent imports share one directory.

final class LocalImportServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<LocalImportService>,
          LocalImportService,
          FutureOr<LocalImportService>
        >
    with
        $FutureModifier<LocalImportService>,
        $FutureProvider<LocalImportService> {
  /// One service for the session, so concurrent imports share one directory.
  LocalImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localImportServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localImportServiceHash();

  @$internal
  @override
  $FutureProviderElement<LocalImportService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LocalImportService> create(Ref ref) {
    return localImportService(ref);
  }
}

String _$localImportServiceHash() =>
    r'd510987b51c40cbde26a8bc65738e487b2b2bb23';
