import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/app.dart';
import 'source.dart';

part 'store.g.dart';

/// The persisted list of connected libraries.
const _kSourcesKey = 'app_sources';

/// The single-server record written by older builds.
const _kLegacyServerKey = 'app_server';

/// Every connected library, in the order the user added them.
///
/// Merged reads (see `LibraryAggregator`) use this order, so it is also the
/// order sections appear in the UI.
@Riverpod(keepAlive: true)
class SourceStore extends Notifier<List<SourceConfig>> {
  @override
  List<SourceConfig> build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final rawSources = prefs.getString(_kSourcesKey);
    if (rawSources != null) {
      try {
        final decoded = jsonDecode(rawSources);
        if (decoded is List) {
          return [
            for (final entry in decoded)
              ?SourceConfig.fromJson(entry),
          ];
        }
      } on FormatException {
        // A corrupt list is treated as empty rather than crashing the app.
      }
    }

    final migrated = _migrateLegacyServer(prefs.getString(_kLegacyServerKey));
    if (migrated != null) {
      // Fire and forget: the migration is idempotent, and `build` must stay
      // synchronous so the first frame already knows the library list.
      prefs.setString(_kSourcesKey, jsonEncode(migrated.map((c) => c.toJson()).toList()));
      prefs.remove(_kLegacyServerKey);
      return migrated;
    }

    return const [];
  }

  /// The old single Subsonic record: `{baseUrl, username, token, salt}`.
  List<SourceConfig>? _migrateLegacyServer(String? raw) {
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final baseUrl = decoded['baseUrl'];
    final username = decoded['username'];
    final token = decoded['token'];
    final salt = decoded['salt'];
    if (baseUrl is! String || username is! String) return null;
    if (token is! String || salt is! String) return null;
    return [
      SourceConfig(
        id: newSourceId(LibraryKind.subsonic),
        kind: LibraryKind.subsonic,
        baseUrl: baseUrl,
        displayName: Uri.parse(baseUrl).host,
        auth: {'username': username, 'token': token, 'salt': salt},
      ),
    ];
  }

  Future<void> add(SourceConfig config) async {
    final next = [...state, config];
    await _persist(next);
  }

  Future<void> remove(String sourceId) async {
    final next = [
      for (final config in state)
        if (config.id != sourceId) config,
    ];
    await _persist(next);
  }

  /// Merges a list of sources from a backup: adds new sources and updates
  /// existing ones if changed.
  Future<int> mergeSources(List<SourceConfig> incoming) async {
    final currentMap = {for (final s in state) s.id: s};
    var addedOrUpdated = 0;
    for (final source in incoming) {
      final existing = currentMap[source.id];
      if (existing == null) {
        currentMap[source.id] = source;
        addedOrUpdated++;
      } else {
        if (existing.baseUrl != source.baseUrl ||
            existing.displayName != source.displayName ||
            !mapEquals(existing.auth, source.auth)) {
          currentMap[source.id] = source;
          addedOrUpdated++;
        }
      }
    }
    if (addedOrUpdated > 0) {
      final next = currentMap.values.toList();
      await _persist(next);
    }
    return addedOrUpdated;
  }

  Future<void> _persist(List<SourceConfig> configs) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _kSourcesKey,
          jsonEncode([for (final config in configs) config.toJson()]),
        );
    state = configs;
  }
}
