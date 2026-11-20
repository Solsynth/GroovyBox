// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What every download is doing right now, keyed `'sourceId:externalId'`.

@ProviderFor(DownloadsController)
final downloadsControllerProvider = DownloadsControllerProvider._();

/// What every download is doing right now, keyed `'sourceId:externalId'`.
final class DownloadsControllerProvider
    extends
        $NotifierProvider<DownloadsController, Map<String, DownloadProgress>> {
  /// What every download is doing right now, keyed `'sourceId:externalId'`.
  DownloadsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadsControllerHash();

  @$internal
  @override
  DownloadsController create() => DownloadsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, DownloadProgress> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, DownloadProgress>>(
        value,
      ),
    );
  }
}

String _$downloadsControllerHash() =>
    r'fbbde6bc7dae7806bb276ea78d2af52a3bd12393';

/// What every download is doing right now, keyed `'sourceId:externalId'`.

abstract class _$DownloadsController
    extends $Notifier<Map<String, DownloadProgress>> {
  Map<String, DownloadProgress> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, DownloadProgress>,
              Map<String, DownloadProgress>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, DownloadProgress>,
                Map<String, DownloadProgress>
              >,
              Map<String, DownloadProgress>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether one library item is on this device.
///
/// Keyed by the source's own id pair rather than by [LibrarySong], which has
/// no value equality: a family keyed by the song would mint a new entry per
/// rebuild.

@ProviderFor(isDownloaded)
final isDownloadedProvider = IsDownloadedFamily._();

/// Whether one library item is on this device.
///
/// Keyed by the source's own id pair rather than by [LibrarySong], which has
/// no value equality: a family keyed by the song would mint a new entry per
/// rebuild.

final class IsDownloadedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether one library item is on this device.
  ///
  /// Keyed by the source's own id pair rather than by [LibrarySong], which has
  /// no value equality: a family keyed by the song would mint a new entry per
  /// rebuild.
  IsDownloadedProvider._({
    required IsDownloadedFamily super.from,
    required ({String id, String sourceId}) super.argument,
  }) : super(
         retry: null,
         name: r'isDownloadedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isDownloadedHash();

  @override
  String toString() {
    return r'isDownloadedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as ({String id, String sourceId});
    return isDownloaded(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsDownloadedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isDownloadedHash() => r'3468aa63276f65215d2357335d9a62095f6dc63d';

/// Whether one library item is on this device.
///
/// Keyed by the source's own id pair rather than by [LibrarySong], which has
/// no value equality: a family keyed by the song would mint a new entry per
/// rebuild.

final class IsDownloadedFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<bool>,
          ({String id, String sourceId})
        > {
  IsDownloadedFamily._()
    : super(
        retry: null,
        name: r'isDownloadedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether one library item is on this device.
  ///
  /// Keyed by the source's own id pair rather than by [LibrarySong], which has
  /// no value equality: a family keyed by the song would mint a new entry per
  /// rebuild.

  IsDownloadedProvider call(({String id, String sourceId}) item) =>
      IsDownloadedProvider._(argument: item, from: this);

  @override
  String toString() => r'isDownloadedProvider';
}

/// The download service, or null when the device cannot keep files.
///
/// Null in tests and on a platform without a support directory: downloads are
/// then simply not offered, and playback streams as it always did.

@ProviderFor(downloadService)
final downloadServiceProvider = DownloadServiceProvider._();

/// The download service, or null when the device cannot keep files.
///
/// Null in tests and on a platform without a support directory: downloads are
/// then simply not offered, and playback streams as it always did.

final class DownloadServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadService?>,
          DownloadService?,
          FutureOr<DownloadService?>
        >
    with $FutureModifier<DownloadService?>, $FutureProvider<DownloadService?> {
  /// The download service, or null when the device cannot keep files.
  ///
  /// Null in tests and on a platform without a support directory: downloads are
  /// then simply not offered, and playback streams as it always did.
  DownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadServiceHash();

  @$internal
  @override
  $FutureProviderElement<DownloadService?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadService?> create(Ref ref) {
    return downloadService(ref);
  }
}

String _$downloadServiceHash() => r'5f902cc8a4d63b79592c76b1ff6929c7da52edbd';

/// Where downloads live, injected by `main` beside the local music directory.

@ProviderFor(downloadDirectory)
final downloadDirectoryProvider = DownloadDirectoryProvider._();

/// Where downloads live, injected by `main` beside the local music directory.

final class DownloadDirectoryProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Where downloads live, injected by `main` beside the local music directory.
  DownloadDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadDirectoryHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return downloadDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$downloadDirectoryHash() => r'853d23e762fe1a9ff512f7507fc36b813e84ef15';

/// Every downloaded track, newest first.

@ProviderFor(DownloadedTracks)
final downloadedTracksProvider = DownloadedTracksProvider._();

/// Every downloaded track, newest first.
final class DownloadedTracksProvider
    extends $AsyncNotifierProvider<DownloadedTracks, List<DownloadedTrack>> {
  /// Every downloaded track, newest first.
  DownloadedTracksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedTracksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedTracksHash();

  @$internal
  @override
  DownloadedTracks create() => DownloadedTracks();
}

String _$downloadedTracksHash() => r'91039ddc47ee45c2cd7a335bb72cf21420c6089a';

/// Every downloaded track, newest first.

abstract class _$DownloadedTracks
    extends $AsyncNotifier<List<DownloadedTrack>> {
  FutureOr<List<DownloadedTrack>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<DownloadedTrack>>, List<DownloadedTrack>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<DownloadedTrack>>,
                List<DownloadedTrack>
              >,
              AsyncValue<List<DownloadedTrack>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// How many tracks are kept and how much room they take, for Settings.

@ProviderFor(downloadTotals)
final downloadTotalsProvider = DownloadTotalsProvider._();

/// How many tracks are kept and how much room they take, for Settings.

final class DownloadTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({int bytes, int count})>,
          ({int bytes, int count}),
          FutureOr<({int bytes, int count})>
        >
    with
        $FutureModifier<({int bytes, int count})>,
        $FutureProvider<({int bytes, int count})> {
  /// How many tracks are kept and how much room they take, for Settings.
  DownloadTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadTotalsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadTotalsHash();

  @$internal
  @override
  $FutureProviderElement<({int bytes, int count})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({int bytes, int count})> create(Ref ref) {
    return downloadTotals(ref);
  }
}

String _$downloadTotalsHash() => r'a53dabb4b2642e0ee69275af8d4c5750d0ae32cb';
