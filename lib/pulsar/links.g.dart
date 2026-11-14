// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'links.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The link store, over the one preferences instance the app already owns.

@ProviderFor(pulsarPlaylistLinks)
final pulsarPlaylistLinksProvider = PulsarPlaylistLinksProvider._();

/// The link store, over the one preferences instance the app already owns.

final class PulsarPlaylistLinksProvider
    extends
        $FunctionalProvider<
          PulsarPlaylistLinks,
          PulsarPlaylistLinks,
          PulsarPlaylistLinks
        >
    with $Provider<PulsarPlaylistLinks> {
  /// The link store, over the one preferences instance the app already owns.
  PulsarPlaylistLinksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulsarPlaylistLinksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulsarPlaylistLinksHash();

  @$internal
  @override
  $ProviderElement<PulsarPlaylistLinks> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PulsarPlaylistLinks create(Ref ref) {
    return pulsarPlaylistLinks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PulsarPlaylistLinks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PulsarPlaylistLinks>(value),
    );
  }
}

String _$pulsarPlaylistLinksHash() =>
    r'48531ad7777d72c7b2882fe3eed6f2a5833d7321';
