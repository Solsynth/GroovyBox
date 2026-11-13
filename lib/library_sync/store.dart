/// The persisted sync state of this device.
///
/// Backed by `shared_preferences`, not a drift table, because the cursor has to
/// survive a database that failed to open: re-syncing from zero is heavier than
/// losing the queue of local changes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kStateKey = 'library_sync_state';

/// One deletion waiting for the next push.
class PendingDelete {
  const PendingDelete({
    required this.entity,
    required this.fields,
    required this.deletedAt,
  });

  /// The entity wire name: "link" or "lyrics".
  final String entity;

  /// The record's natural-key fields.
  final Map<String, String> fields;

  /// RFC3339 UTC, the tombstone clock.
  final String deletedAt;

  Map<String, dynamic> toJson() => {
    'entity': entity,
    ...fields,
    'deleted_at': deletedAt,
  };

  /// Reads a queued delete. An entry missing its key is dropped: a tombstone
  /// without a natural key would delete the wrong row.
  static PendingDelete? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final entity = raw['entity'];
    final deletedAt = raw['deleted_at'];
    if (entity is! String || deletedAt is! String) return null;
    final fields = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (entry.key == 'entity' || entry.key == 'deleted_at') continue;
      if (value is String) fields[entry.key.toString()] = value;
    }
    if (fields.isEmpty) return null;
    return PendingDelete(entity: entity, fields: fields, deletedAt: deletedAt);
  }
}

/// Everything one device remembers about its own sync, in one JSON blob.
class LibrarySyncState {
  const LibrarySyncState({
    this.enabled = true,
    required this.deviceId,
    this.lastRev = 0,
    this.lastPushAt,
    this.lastPullAt,
    this.remoteSettingsClock,
    this.remoteSessionClock,
    this.pushedSettings,
    this.pendingDeletes = const [],
  });

  /// Whether the user wants this device to sync.
  final bool enabled;

  /// Stable per-install id; generated once and never regenerated.
  final String deviceId;

  /// The pull cursor: the highest revision this device has fully written.
  final int lastRev;

  /// The newest clock the last successful push sent; the next push reads
  /// everything newer.
  final String? lastPushAt;
  final String? lastPullAt;

  /// The clock of the last settings document this device adopted or pushed.
  final String? remoteSettingsClock;

  /// The clock of the last session document this device adopted or pushed.
  final String? remoteSessionClock;

  /// The settings map as of the last successful push, so an unchanged map
  /// produces no change.
  final Map<String, dynamic>? pushedSettings;

  /// Deletions drained by the next push.
  final List<PendingDelete> pendingDeletes;

  LibrarySyncState copyWith({
    bool? enabled,
    String? deviceId,
    int? lastRev,
    String? lastPushAt,
    String? lastPullAt,
    String? remoteSettingsClock,
    String? remoteSessionClock,
    Map<String, dynamic>? pushedSettings,
    List<PendingDelete>? pendingDeletes,
  }) => LibrarySyncState(
    enabled: enabled ?? this.enabled,
    deviceId: deviceId ?? this.deviceId,
    lastRev: lastRev ?? this.lastRev,
    lastPushAt: lastPushAt ?? this.lastPushAt,
    lastPullAt: lastPullAt ?? this.lastPullAt,
    remoteSettingsClock: remoteSettingsClock ?? this.remoteSettingsClock,
    remoteSessionClock: remoteSessionClock ?? this.remoteSessionClock,
    pushedSettings: pushedSettings ?? this.pushedSettings,
    pendingDeletes: pendingDeletes ?? this.pendingDeletes,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'device_id': deviceId,
    'last_rev': lastRev,
    'last_push_at': lastPushAt,
    'last_pull_at': lastPullAt,
    'remote_settings_clock': remoteSettingsClock,
    'remote_session_clock': remoteSessionClock,
    'pushed_settings': pushedSettings,
    'pending_deletes': [for (final entry in pendingDeletes) entry.toJson()],
  };

  factory LibrarySyncState.fromJson(Map<String, dynamic> json) =>
      LibrarySyncState(
        enabled: json['enabled'] != false,
        deviceId: json['device_id'] as String? ?? '',
        lastRev: (json['last_rev'] as num?)?.toInt() ?? 0,
        lastPushAt: json['last_push_at'] as String?,
        lastPullAt: json['last_pull_at'] as String?,
        remoteSettingsClock: json['remote_settings_clock'] as String?,
        remoteSessionClock: json['remote_session_clock'] as String?,
        pushedSettings: (json['pushed_settings'] as Map?)
            ?.cast<String, dynamic>(),
        pendingDeletes: [
          for (final raw in (json['pending_deletes'] as List?) ?? const [])
            ?PendingDelete.tryFromJson(raw),
        ],
      );
}

/// Reads and writes [LibrarySyncState] under one prefs key.
class LibrarySyncStateStore {
  LibrarySyncStateStore(SharedPreferences prefs, {this.deviceId})
    : _prefs = prefs;

  final SharedPreferences _prefs;

  /// A fixed device id, for tests. Null generates one on first save.
  final String? deviceId;

  LibrarySyncState load() {
    final raw = _prefs.getString(_kStateKey);
    Map<String, dynamic>? decoded;
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) decoded = parsed.cast<String, dynamic>();
      } on FormatException {
        decoded = null;
      }
    }
    final loaded = decoded == null
        ? LibrarySyncState(deviceId: _newDeviceId())
        : LibrarySyncState.fromJson(decoded);
    final withDevice = loaded.deviceId.isEmpty
        ? loaded.copyWith(deviceId: _newDeviceId())
        : loaded;
    if (decoded == null || loaded.deviceId.isEmpty) save(withDevice);
    return withDevice;
  }

  Future<void> save(LibrarySyncState state) async {
    await _prefs.setString(_kStateKey, jsonEncode(state.toJson()));
  }

  String _newDeviceId() =>
      deviceId ??
      '${_platformName()}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  static String _platformName() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }
}
