// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artwork_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where covers live, injected by `main` beside the other storage paths.

@ProviderFor(artworkCacheDirectory)
final artworkCacheDirectoryProvider = ArtworkCacheDirectoryProvider._();

/// Where covers live, injected by `main` beside the other storage paths.

final class ArtworkCacheDirectoryProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Where covers live, injected by `main` beside the other storage paths.
  ArtworkCacheDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'artworkCacheDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$artworkCacheDirectoryHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return artworkCacheDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$artworkCacheDirectoryHash() =>
    r'8ed001c67702bf9dbd8543f7c6324f94f2eb9be0';

/// The device's cover cache, or null when it cannot keep files.

@ProviderFor(artworkCache)
final artworkCacheProvider = ArtworkCacheProvider._();

/// The device's cover cache, or null when it cannot keep files.

final class ArtworkCacheProvider
    extends $FunctionalProvider<ArtworkCache?, ArtworkCache?, ArtworkCache?>
    with $Provider<ArtworkCache?> {
  /// The device's cover cache, or null when it cannot keep files.
  ArtworkCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'artworkCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$artworkCacheHash();

  @$internal
  @override
  $ProviderElement<ArtworkCache?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArtworkCache? create(Ref ref) {
    return artworkCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArtworkCache? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArtworkCache?>(value),
    );
  }
}

String _$artworkCacheHash() => r'38b5153eee61287f912a00bd8f5cebdade0a1640';

/// The cover one source's handle names, for a widget that just wants a file.
///
/// Keyed by the source and handle rather than by [LibrarySource], which has no
/// value equality: the source is looked up per resolution.

@ProviderFor(artworkFile)
final artworkFileProvider = ArtworkFileFamily._();

/// The cover one source's handle names, for a widget that just wants a file.
///
/// Keyed by the source and handle rather than by [LibrarySource], which has no
/// value equality: the source is looked up per resolution.

final class ArtworkFileProvider
    extends $FunctionalProvider<AsyncValue<File?>, File?, FutureOr<File?>>
    with $FutureModifier<File?>, $FutureProvider<File?> {
  /// The cover one source's handle names, for a widget that just wants a file.
  ///
  /// Keyed by the source and handle rather than by [LibrarySource], which has no
  /// value equality: the source is looked up per resolution.
  ArtworkFileProvider._({
    required ArtworkFileFamily super.from,
    required ({String? artId, int size, String sourceId}) super.argument,
  }) : super(
         retry: null,
         name: r'artworkFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$artworkFileHash();

  @override
  String toString() {
    return r'artworkFileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<File?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<File?> create(Ref ref) {
    final argument =
        this.argument as ({String? artId, int size, String sourceId});
    return artworkFile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ArtworkFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$artworkFileHash() => r'c5343f5427357e3aa9023dd432565dc9691d99c7';

/// The cover one source's handle names, for a widget that just wants a file.
///
/// Keyed by the source and handle rather than by [LibrarySource], which has no
/// value equality: the source is looked up per resolution.

final class ArtworkFileFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<File?>,
          ({String? artId, int size, String sourceId})
        > {
  ArtworkFileFamily._()
    : super(
        retry: null,
        name: r'artworkFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The cover one source's handle names, for a widget that just wants a file.
  ///
  /// Keyed by the source and handle rather than by [LibrarySource], which has no
  /// value equality: the source is looked up per resolution.

  ArtworkFileProvider call(({String? artId, int size, String sourceId}) art) =>
      ArtworkFileProvider._(argument: art, from: this);

  @override
  String toString() => r'artworkFileProvider';
}
