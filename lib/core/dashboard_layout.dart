import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app.dart';

part 'dashboard_layout.g.dart';

/// The keys a dashboard section is addressed by.
///
/// Section ids name the shelf rather than its position, so reordering the page
/// never moves a fold, a hide or a pin. The built-ins are constant; a curated
/// shelf and a pinned playlist are keyed by what they are, not where they sit.
abstract final class DashboardSections {
  /// Songs drawn at random, refreshed in place.
  static const forYou = 'forYou';

  /// What the account's friends are playing right now.
  static const friends = 'friends';

  /// The newest records across every library.
  static const recentlyAdded = 'recentlyAdded';

  /// A shelf an account-backed library curates itself (Apple Music's mixes,
  /// NetEase's daily mix).
  static String curated(String sourceId, String title) =>
      'curated:$sourceId:$title';

  static String ownedPin(int playlistId) => 'pin:owned:$playlistId';

  static String serverPin(String sourceId, String playlistId) =>
      'pin:server:$sourceId:$playlistId';

  static String solinkPin(String playlistId) => 'pin:solink:$playlistId';
}

/// Which kind of playlist a pinned dashboard shelf draws.
enum DashboardPinKind { owned, server, solink }

/// A playlist the user put on the dashboard as a section of its own.
///
/// Pins carry everything the shelf needs to read itself later: the key is the
/// stable id the layout orders by, and the rest is the playlist's address.
class DashboardPin {
  final DashboardPinKind kind;

  /// The library a server playlist belongs to; empty for the other kinds.
  final String sourceId;

  /// The playlist id in its own source (a numeric one for this device).
  final String id;

  /// The name the section is titled with, remembered so the header survives
  /// the read that fills the shelf.
  final String title;

  const DashboardPin({
    required this.kind,
    required this.id,
    required this.title,
    this.sourceId = '',
  });

  String get key => switch (kind) {
    DashboardPinKind.owned => DashboardSections.ownedPin(int.parse(id)),
    DashboardPinKind.server => DashboardSections.serverPin(sourceId, id),
    DashboardPinKind.solink => DashboardSections.solinkPin(id),
  };

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    if (sourceId.isNotEmpty) 'sourceId': sourceId,
  };

  factory DashboardPin.fromJson(Map<String, dynamic> json) => DashboardPin(
    kind: DashboardPinKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => DashboardPinKind.owned,
    ),
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    sourceId: json['sourceId'] as String? ?? '',
  );
}

/// The dashboard as the user arranged it: section order, removed sections,
/// and the playlists pinned as sections.
///
/// Empty [order] means "never arranged": the page then shows its default
/// sections in their default order. Once the user moves anything the whole
/// list is written, so a section that is added later (a new curated shelf)
/// appears at the end rather than shuffling the page under them.
class DashboardLayout {
  final List<String> order;

  /// Sections the user removed. Kept rather than forgotten: a curated shelf
  /// is rebuilt from the account on every refresh, and a removal has to
  /// outlive the read that would otherwise bring it back.
  final Set<String> hidden;

  final Map<String, DashboardPin> pins;

  const DashboardLayout({
    this.order = const [],
    this.hidden = const {},
    this.pins = const {},
  });

  DashboardLayout copyWith({
    List<String>? order,
    Set<String>? hidden,
    Map<String, DashboardPin>? pins,
  }) => DashboardLayout(
    order: order ?? this.order,
    hidden: hidden ?? this.hidden,
    pins: pins ?? this.pins,
  );

  Map<String, dynamic> toJson() => {
    if (order.isNotEmpty) 'order': order,
    if (hidden.isNotEmpty) 'hidden': hidden.toList()..sort(),
    if (pins.isNotEmpty)
      'pins': {for (final pin in pins.values) pin.key: pin.toJson()},
  };

  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    final pins = <String, DashboardPin>{};
    final rawPins = json['pins'];
    if (rawPins is Map) {
      for (final entry in rawPins.entries) {
        if (entry.value case final Map<String, dynamic> value) {
          final pin = DashboardPin.fromJson(value);
          pins[entry.key as String] = pin;
        }
      }
    }
    return DashboardLayout(
      order: ((json['order'] as List?) ?? const []).whereType<String>().toList(),
      hidden: ((json['hidden'] as List?) ?? const []).whereType<String>().toSet(),
      pins: pins,
    );
  }
}

/// The persisted dashboard arrangement.
///
/// One JSON string in prefs, written whole on every change: the order, the
/// removed set and the pins are one decision about one page, and writing them
/// separately lets a crash leave them disagreeing.
@Riverpod(keepAlive: true)
class DashboardLayoutNotifier extends Notifier<DashboardLayout> {
  static const _key = 'app_dashboard_layout';

  @override
  DashboardLayout build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const DashboardLayout();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DashboardLayout.fromJson(decoded);
      }
    } on FormatException {
      // A hand-edited or truncated value is not worth a failed launch: the
      // page simply shows its default arrangement.
    }
    return const DashboardLayout();
  }

  /// Stores the sections in the order the customize sheet shows them.
  Future<void> setOrder(List<String> keys) async {
    await _save(state.copyWith(order: List.unmodifiable(keys)));
  }

  Future<void> hide(String key) async {
    await _save(state.copyWith(hidden: {...state.hidden, key}));
  }

  Future<void> show(String key) async {
    final hidden = {...state.hidden}..remove(key);
    await _save(state.copyWith(hidden: hidden));
  }

  Future<void> addPin(DashboardPin pin) async {
    await _save(
      state.copyWith(
        pins: {...state.pins, pin.key: pin},
        order: [...state.order, pin.key],
        hidden: {...state.hidden}..remove(pin.key),
      ),
    );
  }

  Future<void> removePin(String key) async {
    await _save(
      state.copyWith(
        pins: {...state.pins}..remove(key),
        order: [...state.order]..remove(key),
        hidden: {...state.hidden}..remove(key),
      ),
    );
  }

  /// Back to the page a fresh install shows: the default order, nothing
  /// hidden, no pins.
  Future<void> reset() async {
    state = const DashboardLayout();
    await ref.read(sharedPreferencesProvider).remove(_key);
  }

  Future<void> _save(DashboardLayout next) async {
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(next.toJson()));
  }
}
