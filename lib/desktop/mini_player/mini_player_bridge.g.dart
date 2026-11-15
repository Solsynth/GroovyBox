// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mini_player_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Publishes the main engine's playback state to the mini player window and
/// answers its transport commands.
///
/// Started on demand — the first press of the player page's mini-player
/// button — and kept alive after that: the guest engine may outlive the
/// button's own widget, and a handler that died with it would leave a mini
/// window that renders but cannot act.

@ProviderFor(MiniPlayerBridge)
final miniPlayerBridgeProvider = MiniPlayerBridgeProvider._();

/// Publishes the main engine's playback state to the mini player window and
/// answers its transport commands.
///
/// Started on demand — the first press of the player page's mini-player
/// button — and kept alive after that: the guest engine may outlive the
/// button's own widget, and a handler that died with it would leave a mini
/// window that renders but cannot act.
final class MiniPlayerBridgeProvider
    extends $NotifierProvider<MiniPlayerBridge, void> {
  /// Publishes the main engine's playback state to the mini player window and
  /// answers its transport commands.
  ///
  /// Started on demand — the first press of the player page's mini-player
  /// button — and kept alive after that: the guest engine may outlive the
  /// button's own widget, and a handler that died with it would leave a mini
  /// window that renders but cannot act.
  MiniPlayerBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'miniPlayerBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$miniPlayerBridgeHash();

  @$internal
  @override
  MiniPlayerBridge create() => MiniPlayerBridge();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$miniPlayerBridgeHash() => r'7eaeb9281e4eedd70d2775796fc8df4409c4ee8a';

/// Publishes the main engine's playback state to the mini player window and
/// answers its transport commands.
///
/// Started on demand — the first press of the player page's mini-player
/// button — and kept alive after that: the guest engine may outlive the
/// button's own widget, and a handler that died with it would leave a mini
/// window that renders but cannot act.

abstract class _$MiniPlayerBridge extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
