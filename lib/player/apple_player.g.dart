// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform players the app can hand a queue to.
///
/// One seam for every source that has no stream URL: today only Apple Music,
/// but the transport asks the *source* which engine it wants
/// ([LibrarySource.usesPlatformPlayer]) and never the kind.

@ProviderFor(musicKitClient)
final musicKitClientProvider = MusicKitClientProvider._();

/// The platform players the app can hand a queue to.
///
/// One seam for every source that has no stream URL: today only Apple Music,
/// but the transport asks the *source* which engine it wants
/// ([LibrarySource.usesPlatformPlayer]) and never the kind.

final class MusicKitClientProvider
    extends $FunctionalProvider<MusicKitClient, MusicKitClient, MusicKitClient>
    with $Provider<MusicKitClient> {
  /// The platform players the app can hand a queue to.
  ///
  /// One seam for every source that has no stream URL: today only Apple Music,
  /// but the transport asks the *source* which engine it wants
  /// ([LibrarySource.usesPlatformPlayer]) and never the kind.
  MusicKitClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'musicKitClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$musicKitClientHash();

  @$internal
  @override
  $ProviderElement<MusicKitClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MusicKitClient create(Ref ref) {
    return musicKitClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MusicKitClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MusicKitClient>(value),
    );
  }
}

String _$musicKitClientHash() => r'3e382bd2ad9c7845e70ed7d981171b7eb28248d6';
