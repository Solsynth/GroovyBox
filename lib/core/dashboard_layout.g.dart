// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_layout.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The persisted dashboard arrangement.
///
/// One JSON string in prefs, written whole on every change: the order, the
/// removed set and the pins are one decision about one page, and writing them
/// separately lets a crash leave them disagreeing.

@ProviderFor(DashboardLayoutNotifier)
final dashboardLayoutProvider = DashboardLayoutNotifierProvider._();

/// The persisted dashboard arrangement.
///
/// One JSON string in prefs, written whole on every change: the order, the
/// removed set and the pins are one decision about one page, and writing them
/// separately lets a crash leave them disagreeing.
final class DashboardLayoutNotifierProvider
    extends $NotifierProvider<DashboardLayoutNotifier, DashboardLayout> {
  /// The persisted dashboard arrangement.
  ///
  /// One JSON string in prefs, written whole on every change: the order, the
  /// removed set and the pins are one decision about one page, and writing them
  /// separately lets a crash leave them disagreeing.
  DashboardLayoutNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardLayoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardLayoutNotifierHash();

  @$internal
  @override
  DashboardLayoutNotifier create() => DashboardLayoutNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DashboardLayout value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DashboardLayout>(value),
    );
  }
}

String _$dashboardLayoutNotifierHash() =>
    r'1b3477de55c28e7573bc52eeca616fb9b89608bb';

/// The persisted dashboard arrangement.
///
/// One JSON string in prefs, written whole on every change: the order, the
/// removed set and the pins are one decision about one page, and writing them
/// separately lets a crash leave them disagreeing.

abstract class _$DashboardLayoutNotifier extends $Notifier<DashboardLayout> {
  DashboardLayout build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DashboardLayout, DashboardLayout>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DashboardLayout, DashboardLayout>,
              DashboardLayout,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
