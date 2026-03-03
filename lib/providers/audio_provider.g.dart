// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(audioHandler)
final audioHandlerProvider = AudioHandlerProvider._();

final class AudioHandlerProvider
    extends $FunctionalProvider<AudioHandler, AudioHandler, AudioHandler>
    with $Provider<AudioHandler> {
  AudioHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioHandlerHash();

  @$internal
  @override
  $ProviderElement<AudioHandler> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioHandler create(Ref ref) {
    return audioHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioHandler>(value),
    );
  }
}

String _$audioHandlerHash() => r'65fbd92e049fe4f3a0763516f1e68e1614f7630f';

@ProviderFor(CurrentTrackNotifier)
final currentTrackProvider = CurrentTrackNotifierProvider._();

final class CurrentTrackNotifierProvider
    extends $NotifierProvider<CurrentTrackNotifier, CurrentTrackData?> {
  CurrentTrackNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTrackProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTrackNotifierHash();

  @$internal
  @override
  CurrentTrackNotifier create() => CurrentTrackNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrentTrackData? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrentTrackData?>(value),
    );
  }
}

String _$currentTrackNotifierHash() =>
    r'faa718574ece8c3c4b8f19b70d79d142b4b7f3e9';

abstract class _$CurrentTrackNotifier extends $Notifier<CurrentTrackData?> {
  CurrentTrackData? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CurrentTrackData?, CurrentTrackData?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CurrentTrackData?, CurrentTrackData?>,
              CurrentTrackData?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(CurrentTrackMetadataNotifier)
final currentTrackMetadataProvider = CurrentTrackMetadataNotifierProvider._();

final class CurrentTrackMetadataNotifierProvider
    extends $NotifierProvider<CurrentTrackMetadataNotifier, TrackMetadata?> {
  CurrentTrackMetadataNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTrackMetadataProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTrackMetadataNotifierHash();

  @$internal
  @override
  CurrentTrackMetadataNotifier create() => CurrentTrackMetadataNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackMetadata? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackMetadata?>(value),
    );
  }
}

String _$currentTrackMetadataNotifierHash() =>
    r'0a491bd4edda2b010ed3d6f7dd459f4ac8689a5f';

abstract class _$CurrentTrackMetadataNotifier
    extends $Notifier<TrackMetadata?> {
  TrackMetadata? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TrackMetadata?, TrackMetadata?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TrackMetadata?, TrackMetadata?>,
              TrackMetadata?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(RemoteTrackLoadingNotifier)
final remoteTrackLoadingProvider = RemoteTrackLoadingNotifierProvider._();

final class RemoteTrackLoadingNotifierProvider
    extends $NotifierProvider<RemoteTrackLoadingNotifier, bool> {
  RemoteTrackLoadingNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteTrackLoadingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteTrackLoadingNotifierHash();

  @$internal
  @override
  RemoteTrackLoadingNotifier create() => RemoteTrackLoadingNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$remoteTrackLoadingNotifierHash() =>
    r'e7eda5cbbf3c37e0127960bbc09b121ab3b02afa';

abstract class _$RemoteTrackLoadingNotifier extends $Notifier<bool> {
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
