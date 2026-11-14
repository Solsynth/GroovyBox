// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dynamic_color.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The seed the player's current cover yields, or null when there is nothing
/// to read: no track, no cover, no server that can name one, or an image that
/// would not decode.
///
/// Rebuilt when the playing track changes, not on every position tick: the
/// transport's `current` is the same song instance until the track does.

@ProviderFor(coverSeed)
final coverSeedProvider = CoverSeedProvider._();

/// The seed the player's current cover yields, or null when there is nothing
/// to read: no track, no cover, no server that can name one, or an image that
/// would not decode.
///
/// Rebuilt when the playing track changes, not on every position tick: the
/// transport's `current` is the same song instance until the track does.

final class CoverSeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<ui.Color?>,
          ui.Color?,
          FutureOr<ui.Color?>
        >
    with $FutureModifier<ui.Color?>, $FutureProvider<ui.Color?> {
  /// The seed the player's current cover yields, or null when there is nothing
  /// to read: no track, no cover, no server that can name one, or an image that
  /// would not decode.
  ///
  /// Rebuilt when the playing track changes, not on every position tick: the
  /// transport's `current` is the same song instance until the track does.
  CoverSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coverSeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coverSeedHash();

  @$internal
  @override
  $FutureProviderElement<ui.Color?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ui.Color?> create(Ref ref) {
    return coverSeed(ref);
  }
}

String _$coverSeedHash() => r'25214c534198965617ce22b6882ee4fa25a34ef6';
