// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the one [Player] for the app's lifetime and translates its streams
/// into [PlaybackState].
///
/// Exposed as `playbackProvider` (the state) and
/// `playbackProvider.notifier` (the transport).
///
/// Kept out of the widget tree on purpose: the audio session outlives the dock,
/// the player page, and any route pushed above them.
///
/// Streams are remote URLs, so a track is opened with its own library's signed
/// stream URL rather than a local path. Nothing is downloaded first.
/// The transport. Created lazily and kept alive for the whole session.

@ProviderFor(Playback)
final playbackProvider = PlaybackProvider._();

/// Owns the one [Player] for the app's lifetime and translates its streams
/// into [PlaybackState].
///
/// Exposed as `playbackProvider` (the state) and
/// `playbackProvider.notifier` (the transport).
///
/// Kept out of the widget tree on purpose: the audio session outlives the dock,
/// the player page, and any route pushed above them.
///
/// Streams are remote URLs, so a track is opened with its own library's signed
/// stream URL rather than a local path. Nothing is downloaded first.
/// The transport. Created lazily and kept alive for the whole session.
final class PlaybackProvider
    extends $NotifierProvider<Playback, PlaybackState> {
  /// Owns the one [Player] for the app's lifetime and translates its streams
  /// into [PlaybackState].
  ///
  /// Exposed as `playbackProvider` (the state) and
  /// `playbackProvider.notifier` (the transport).
  ///
  /// Kept out of the widget tree on purpose: the audio session outlives the dock,
  /// the player page, and any route pushed above them.
  ///
  /// Streams are remote URLs, so a track is opened with its own library's signed
  /// stream URL rather than a local path. Nothing is downloaded first.
  /// The transport. Created lazily and kept alive for the whole session.
  PlaybackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackHash();

  @$internal
  @override
  Playback create() => Playback();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackState>(value),
    );
  }
}

String _$playbackHash() => r'7eb67910889bac8f84b9ae95bf57945be773a613';

/// Owns the one [Player] for the app's lifetime and translates its streams
/// into [PlaybackState].
///
/// Exposed as `playbackProvider` (the state) and
/// `playbackProvider.notifier` (the transport).
///
/// Kept out of the widget tree on purpose: the audio session outlives the dock,
/// the player page, and any route pushed above them.
///
/// Streams are remote URLs, so a track is opened with its own library's signed
/// stream URL rather than a local path. Nothing is downloaded first.
/// The transport. Created lazily and kept alive for the whole session.

abstract class _$Playback extends $Notifier<PlaybackState> {
  PlaybackState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlaybackState, PlaybackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlaybackState, PlaybackState>,
              PlaybackState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
