/// Riverpod wiring for Library Sync.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/app.dart';
import '../library/providers.dart';
import '../library/store.dart';
import '../player/player.dart';
import '../solarpass/providers.dart';
import 'client.dart';
import 'engine.dart';
import 'models.dart';
import 'store.dart';

part 'providers.g.dart';

/// Where the last completed run is remembered, for the Settings subtitle.
const _kLastRunKey = 'library_sync_last_run';

/// The sync-enabled volume and the four booleans, read as one document.
const _kVolumeKey = 'app_volume';

/// This device's persisted sync state.
@Riverpod(keepAlive: true)
LibrarySyncStateStore librarySyncStateStore(Ref ref) =>
    LibrarySyncStateStore(ref.watch(sharedPreferencesProvider));

/// The current sync state, kept in memory so a switch reads synchronously.
@Riverpod(keepAlive: true)
class LibrarySyncStateNotifier extends Notifier<LibrarySyncState> {
  @override
  LibrarySyncState build() => ref.watch(librarySyncStateStoreProvider).load();

  /// Flips the sync switch and persists it.
  Future<void> setEnabled(bool enabled) async {
    final next = state.copyWith(enabled: enabled);
    state = next;
    await ref.read(librarySyncStateStoreProvider).save(next);
  }

  /// Re-reads the persisted state, after the engine wrote to it.
  void reload() => state = ref.read(librarySyncStateStoreProvider).load();

  /// Queues one deletion for the next push.
  Future<void> queueDelete(PendingDelete delete) async {
    final next = state.copyWith(
      pendingDeletes: [...state.pendingDeletes, delete],
    );
    state = next;
    await ref.read(librarySyncStateStoreProvider).save(next);
  }
}

/// The HTTP client, pointed at the one server setting Solarpass already owns.
@Riverpod(keepAlive: true)
LibrarySyncClient librarySyncClient(Ref ref) {
  final config = ref.watch(solarpassConfigProvider);
  return LibrarySyncClient(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
    baseUrl: config.serverUrl,
  );
}

/// The engine, wired to the database, the client and the settings notifiers.
@Riverpod(keepAlive: true)
LibrarySyncEngine librarySyncEngine(Ref ref) => LibrarySyncEngine(
  db: ref.watch(libraryDatabaseProvider),
  client: ref.watch(librarySyncClientProvider),
  state: ref.watch(librarySyncStateStoreProvider),
  connectedSourceIds: () => [
    for (final config in ref.read(sourceStoreProvider)) config.id,
  ],
  readSettings: () => _readSettings(ref),
  applySettings: (values) => _applySettings(ref, values),
  invalidate: () => _invalidateLibraries(ref),
);

/// The account's mirror summary plus the last local run.
@Riverpod(keepAlive: true)
class LibrarySyncStatusView extends Notifier<LibrarySyncStatusViewState> {
  @override
  LibrarySyncStatusViewState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_kLastRunKey);
    final lastRun = raw == null ? null : SyncRunResult.fromJson(_decode(raw));
    // Opened from Settings: the subtitle should reflect the account, not the
    // cached value, so the fetch starts with the build.
    Future.microtask(refresh);
    return LibrarySyncStatusViewState(lastRun: lastRun);
  }

  /// Re-reads the last run from prefs and re-fetches the server summary.
  Future<void> refresh() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_kLastRunKey);
    final lastRun = raw == null ? null : SyncRunResult.fromJson(_decode(raw));
    state = LibrarySyncStatusViewState(lastRun: lastRun, status: state.status);

    final session = await ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (session == null) {
      state = LibrarySyncStatusViewState(lastRun: lastRun);
      return;
    }
    try {
      final status = await ref.read(librarySyncClientProvider).status(session);
      state = LibrarySyncStatusViewState(lastRun: lastRun, status: status);
    } catch (_) {
      state = LibrarySyncStatusViewState(lastRun: lastRun);
    }
  }

  /// Runs one sync and records its outcome.
  Future<SyncRunResult?> run() async {
    final engine = ref.read(librarySyncEngineProvider);
    final session = await ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (session == null) {
      state = LibrarySyncStatusViewState(
        lastRun: SyncRunResult(at: DateTime.now(), error: 'needs-sign-in'),
        status: state.status,
      );
      return null;
    }
    state = state.copyWith(running: true);
    final result = await engine.run(
      session: session,
      refreshSession: () =>
          ref.read(solarpassSessionProvider.notifier).validSession(),
    );
    state = state.copyWith(running: false, lastRun: result);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kLastRunKey, jsonEncode(result.toJson()));
    ref.read(librarySyncStateProvider.notifier).reload();
    await refresh();
    return result;
  }
}

/// What the Settings row renders.
class LibrarySyncStatusViewState {
  const LibrarySyncStatusViewState({
    this.status,
    this.lastRun,
    this.running = false,
  });

  final LibrarySyncStatus? status;
  final SyncRunResult? lastRun;

  /// Whether a run is in flight, so the button can say so.
  final bool running;

  LibrarySyncStatusViewState copyWith({
    LibrarySyncStatus? status,
    SyncRunResult? lastRun,
    bool? running,
  }) => LibrarySyncStatusViewState(
    status: status ?? this.status,
    lastRun: lastRun ?? this.lastRun,
    running: running ?? this.running,
  );
}

/// Runs a sync when the window gains focus and the last push is stale, and
/// when a track ends.
///
/// Wired from `ShellScreen`, beside the scrobbler: both are session-level
/// listeners that must survive tab switches.
@Riverpod(keepAlive: true)
LibrarySyncAuto librarySyncAuto(Ref ref) {
  final auto = LibrarySyncAuto(ref);
  ref.onDispose(auto.dispose);
  auto.init();
  return auto;
}

/// Session-level trigger for background syncs.
class LibrarySyncAuto {
  LibrarySyncAuto(this._ref);

  final Ref _ref;
  bool _disposed = false;
  AppLifecycleListener? _lifecycle;

  void init() {
    _ref.listen<PlaybackState>(playbackProvider, (previous, next) {
      if (_disposed) return;
      // A track ended: the play row's final progress is worth pushing now.
      if (previous?.playing == true && !next.playing) _run('track-ended');
    });
    // Coming back to the window is the moment a device is most likely to be
    // behind: the other one played something while this one was in the
    // background.
    _lifecycle = AppLifecycleListener(onResume: () => _run('focus'));
  }

  /// Runs a sync unless one just ran or the user turned it off.
  Future<void> _run(String reason) async {
    if (_disposed) return;
    final syncState = _ref.read(librarySyncStateProvider);
    if (!syncState.enabled) return;
    final lastPush = DateTime.tryParse(syncState.lastPushAt ?? '');
    if (reason == 'focus' &&
        lastPush != null &&
        DateTime.now().difference(lastPush) < const Duration(minutes: 5)) {
      return;
    }
    await _ref.read(librarySyncStatusViewProvider.notifier).run();
  }

  /// The window gained focus, or a sync was asked for explicitly.
  Future<void> onFocus() => _run('focus');

  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

/// The six settings this app keeps, read straight from prefs and the notifiers.
Map<String, dynamic> _readSettings(Ref ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return {
    'themeMode': ref.read(themeModeProvider).name,
    'volume': prefs.getDouble(_kVolumeKey) ?? 65,
    'glassEffects': ref.read(glassEffectsEnabledProvider),
    'lyricsPronunciation': ref.read(lyricsPronunciationEnabledProvider),
    'lyricsTranslation': ref.read(lyricsTranslationEnabledProvider),
    'infinitePlayback': ref.read(infinitePlaybackEnabledProvider),
  };
}

/// Writes a settings document a remote device owns.
Future<void> _applySettings(Ref ref, Map<String, dynamic> values) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final theme = values['themeMode'];
  if (theme is String) {
    final mode = AppThemeMode.values.where((mode) => mode.name == theme);
    if (mode.isNotEmpty) {
      await ref.read(themeModeProvider.notifier).set(mode.first);
    }
  }
  final volume = values['volume'];
  if (volume is num) {
    await prefs.setDouble(_kVolumeKey, volume.toDouble());
    ref.read(playbackProvider.notifier).setVolume(volume.toDouble());
  }
  final glass = values['glassEffects'];
  if (glass is bool) {
    await ref.read(glassEffectsEnabledProvider.notifier).set(glass);
  }
  final pronunciation = values['lyricsPronunciation'];
  if (pronunciation is bool) {
    await ref
        .read(lyricsPronunciationEnabledProvider.notifier)
        .set(pronunciation);
  }
  final translation = values['lyricsTranslation'];
  if (translation is bool) {
    await ref.read(lyricsTranslationEnabledProvider.notifier).set(translation);
  }
  final infinite = values['infinitePlayback'];
  if (infinite is bool) {
    await ref.read(infinitePlaybackEnabledProvider.notifier).set(infinite);
  }
}

/// Invalidates the same providers a restored backup does, so a pull shows up.
void _invalidateLibraries(Ref ref) {
  ref.invalidate(librarySourcesProvider);
  ref.invalidate(librarySourceByIdProvider);
  ref.invalidate(libraryStatsProvider);
  ref.invalidate(storedLyricsProvider);
  ref.invalidate(listeningStatsProvider);
  ref.invalidate(recentAlbumsProvider);
  ref.invalidate(randomSongsProvider);
  ref.invalidate(playlistsProvider);
}

Map<String, dynamic> _decode(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } on FormatException {
    // A corrupt record is treated as absent.
  }
  return const {};
}
