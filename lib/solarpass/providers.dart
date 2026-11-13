import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/app.dart';
import '../library/models.dart';
import '../library/providers.dart';
import '../player/player.dart';
import 'client.dart';
import 'models.dart';

const _kSolarpassSessionKey = 'solarpass_oauth_session';
const _kSolarpassAccountKey = 'solarpass_user_account';
const _kSolarpassConfigKey = 'solarpass_settings_config';

final solarpassConfigProvider =
    NotifierProvider<SolarpassConfigNotifier, SolarpassConfig>(
      SolarpassConfigNotifier.new,
    );

class SolarpassConfigNotifier extends Notifier<SolarpassConfig> {
  @override
  SolarpassConfig build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_kSolarpassConfigKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return SolarpassConfig.fromJson(map);
      } catch (_) {}
    }
    return const SolarpassConfig();
  }

  Future<void> update(SolarpassConfig config) async {
    state = config;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kSolarpassConfigKey, jsonEncode(config.toJson()));
  }

  Future<void> setScrobbleEnabled(bool enabled) async {
    await update(state.copyWith(scrobbleEnabled: enabled));
  }
}

final solarpassClientProvider = Provider<SolarpassClient>((ref) {
  final config = ref.watch(solarpassConfigProvider);
  return SolarpassClient(config: config);
});

final solarpassSessionProvider =
    AsyncNotifierProvider<SolarpassSessionNotifier, OAuthSession?>(
      SolarpassSessionNotifier.new,
    );

class SolarpassSessionNotifier extends AsyncNotifier<OAuthSession?> {
  @override
  Future<OAuthSession?> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_kSolarpassSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = OAuthSession.fromJson(json);
      return session;
    } catch (_) {
      await prefs.remove(_kSolarpassSessionKey);
      return null;
    }
  }

  Future<void> _saveSession(OAuthSession session) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kSolarpassSessionKey, jsonEncode(session.toJson()));
    state = AsyncData(session);
  }

  /// Ensures a valid access token, refreshing if needed.
  Future<OAuthSession?> validSession() async {
    final current = state.value;
    if (current == null) return null;
    if (!current.needsRefresh) return current;

    if (current.refreshToken == null || current.refreshToken!.isEmpty) {
      if (current.isExpired) {
        await signOut();
        return null;
      }
      return current;
    }

    try {
      final client = ref.read(solarpassClientProvider);
      final refreshed = await client.refresh(current);
      await _saveSession(refreshed);
      return refreshed;
    } catch (e) {
      debugPrint('[Solarpass] Refresh failed: $e');
      if (current.isExpired) {
        await signOut();
        return null;
      }
      return current;
    }
  }

  Future<OAuthSession> signInBrowser() async {
    final client = ref.read(solarpassClientProvider);
    state = const AsyncLoading();
    try {
      final session = await client.authorizeBrowser();
      await _saveSession(session);
      await ref.read(solarpassAccountProvider.notifier).refresh();
      return session;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<OAuthSession> signInDevice({
    required void Function(DeviceAuthorization authorization) onDeviceCode,
  }) async {
    final client = ref.read(solarpassClientProvider);
    state = const AsyncLoading();
    try {
      final session = await client.authorizeDevice(onDeviceCode: onDeviceCode);
      await _saveSession(session);
      await ref.read(solarpassAccountProvider.notifier).refresh();
      return session;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    final current = state.value;
    final client = ref.read(solarpassClientProvider);
    if (current != null) {
      try {
        await client.clearPresenceActivity(session: current);
      } catch (_) {}
    }
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kSolarpassSessionKey);
    await prefs.remove(_kSolarpassAccountKey);
    state = const AsyncData(null);
    ref.invalidate(solarpassAccountProvider);
  }
}

final solarpassAccountProvider =
    AsyncNotifierProvider<SolarpassAccountNotifier, SolarpassAccount?>(
      SolarpassAccountNotifier.new,
    );

class SolarpassAccountNotifier extends AsyncNotifier<SolarpassAccount?> {
  @override
  Future<SolarpassAccount?> build() async {
    final sessionAsync = ref.watch(solarpassSessionProvider);
    final session = sessionAsync.value;
    if (session == null) return null;

    final prefs = ref.watch(sharedPreferencesProvider);
    final cached = prefs.getString(_kSolarpassAccountKey);
    SolarpassAccount? account;
    if (cached != null && cached.isNotEmpty) {
      try {
        account = SolarpassAccount.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    // Refresh account asynchronously in background
    _fetchAndUpdate(session);
    return account;
  }

  Future<void> refresh() async {
    final session = await ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (session == null) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchAndUpdate(session));
  }

  Future<SolarpassAccount?> _fetchAndUpdate(OAuthSession session) async {
    try {
      final client = ref.read(solarpassClientProvider);
      final account = await client.fetchCurrentAccount(session);
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(
        _kSolarpassAccountKey,
        jsonEncode(account.toJson()),
      );
      state = AsyncData(account);
      return account;
    } catch (e, stack) {
      debugPrint('[Solarpass] Error fetching account profile: $e');
      if (state.value == null) {
        state = AsyncError(e, stack);
      }
      return state.value;
    }
  }
}

/// Status text for current presence scrobble.
class ScrobbleStatus {
  const ScrobbleStatus({
    required this.isScrobbling,
    this.currentTrack,
    this.lastError,
  });

  final bool isScrobbling;
  final String? currentTrack;
  final String? lastError;
}

final solarpassScrobbleStatusProvider =
    NotifierProvider<SolarpassScrobbleStatusNotifier, ScrobbleStatus>(
      SolarpassScrobbleStatusNotifier.new,
    );

class SolarpassScrobbleStatusNotifier extends Notifier<ScrobbleStatus> {
  @override
  ScrobbleStatus build() => const ScrobbleStatus(isScrobbling: false);

  void update({
    required bool isScrobbling,
    String? currentTrack,
    String? lastError,
  }) {
    state = ScrobbleStatus(
      isScrobbling: isScrobbling,
      currentTrack: currentTrack,
      lastError: lastError,
    );
  }
}

/// Central presence scrobbler that listens to [playbackProvider] and syncs with Solar Network.
final solarpassScrobblerProvider = Provider<SolarpassScrobbler>((ref) {
  final scrobbler = SolarpassScrobbler(ref);
  ref.onDispose(scrobbler.dispose);
  scrobbler.init();
  return scrobbler;
});

class SolarpassScrobbler {
  SolarpassScrobbler(this._ref);

  final Ref _ref;
  Timer? _heartbeatTimer;
  Timer? _pauseDebounceTimer;
  String? _lastScrobbledKey;
  bool _disposed = false;

  LibrarySong? _activeSong;
  DateTime? _playStartedAt;
  Duration _listenedDuration = Duration.zero;
  DateTime? _lastResumeTime;

  void init() {
    _ref.listen<PlaybackState>(playbackProvider, (prev, next) {
      _onPlaybackChanged(prev, next);
    });
    // Listen to scrobble settings toggle
    _ref.listen<SolarpassConfig>(solarpassConfigProvider, (prev, next) {
      if (prev?.scrobbleEnabled == true && !next.scrobbleEnabled) {
        _clearPresence();
      } else if (prev?.scrobbleEnabled == false && next.scrobbleEnabled) {
        final playback = _ref.read(playbackProvider);
        if (playback.playing && playback.current != null) {
          _scrobbleTrack(playback.current!, playback.position);
        }
      }
    });
  }

  void _onPlaybackChanged(PlaybackState? prev, PlaybackState next) {
    if (_disposed) return;
    final config = _ref.read(solarpassConfigProvider);
    if (!config.scrobbleEnabled) return;

    final song = next.current;
    final isPlaying = next.playing && song != null;

    if (isPlaying) {
      _pauseDebounceTimer?.cancel();
      _pauseDebounceTimer = null;

      final key = '${song.sourceId}:${song.id}';
      if (_lastScrobbledKey != key) {
        // Different song started: finalize previous song scrobble if eligible
        _commitPendingScrobble();

        _activeSong = song;
        _playStartedAt = DateTime.now();
        _listenedDuration = Duration.zero;
        _lastResumeTime = DateTime.now();
        _lastScrobbledKey = key;

        _scrobbleTrack(song, next.position);
      } else if (prev?.playing != true) {
        // Resumed playing same song
        _lastResumeTime = DateTime.now();
        _scrobbleTrack(song, next.position);
      }
      _ensureHeartbeat();
    } else {
      // Paused or playback stopped
      if (_lastResumeTime != null) {
        _listenedDuration += DateTime.now().difference(_lastResumeTime!);
        _lastResumeTime = null;
      }

      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      if (song == null) {
        // Queue finished or cleared: commit pending scrobble and clear presence
        _commitPendingScrobble();
        _clearPresence();
      } else {
        // Paused on track: debounce clearing activity by 30 seconds
        _pauseDebounceTimer ??= Timer(const Duration(seconds: 30), () {
          if (!_disposed && !_ref.read(playbackProvider).playing) {
            _clearPresence();
          }
        });
      }
    }
  }

  void _commitPendingScrobble() {
    if (_activeSong == null) return;
    if (_lastResumeTime != null) {
      _listenedDuration += DateTime.now().difference(_lastResumeTime!);
      _lastResumeTime = null;
    }

    final song = _activeSong!;
    final listened = _listenedDuration;
    final playedAt = _playStartedAt ?? DateTime.now();

    // Check Last.fm standard rule: listened >= 30s or >= 50% track duration
    final songSec = song.duration.inSeconds;
    final listenedSec = listened.inSeconds;
    final isEligible =
        listenedSec >= 30 || (songSec > 0 && listenedSec >= (songSec / 2));

    if (isEligible) {
      _submitPermanentScrobble(song, listened, playedAt);
    }

    _activeSong = null;
    _listenedDuration = Duration.zero;
    _playStartedAt = null;
  }

  Future<void> _submitPermanentScrobble(
    LibrarySong song,
    Duration listened,
    DateTime playedAt,
  ) async {
    final session = await _ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (session == null) return;

    final client = _ref.read(solarpassClientProvider);
    final sources = _ref.read(librarySourceByIdProvider);
    final artUri = sources[song.sourceId]?.artworkUri(song.artId);

    try {
      await client.submitScrobble(
        session: session,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        listened: listened,
        artworkUrl: artUri?.toString(),
        trackId: song.id,
        playedAt: playedAt,
      );
    } catch (e) {
      debugPrint('[Solarpass] Submit scrobble error: $e');
    }
  }

  void _ensureHeartbeat() {
    _heartbeatTimer?.cancel();
    // Renew lease every 2.5 minutes (Stargate lease duration is 5 minutes)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 150), (_) {
      final playback = _ref.read(playbackProvider);
      if (playback.playing && playback.current != null) {
        _scrobbleTrack(playback.current!, playback.position);
      }
    });
  }

  Future<void> _scrobbleTrack(LibrarySong song, Duration position) async {
    final session = await _ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (session == null) {
      _ref
          .read(solarpassScrobbleStatusProvider.notifier)
          .update(isScrobbling: false, currentTrack: null);
      return;
    }

    final client = _ref.read(solarpassClientProvider);
    final sources = _ref.read(librarySourceByIdProvider);
    final artUri = sources[song.sourceId]?.artworkUri(song.artId);

    try {
      await client.setPresenceActivity(
        session: session,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        position: position,
        artworkUrl: artUri?.toString(),
        trackId: song.id,
      );
      final displayTrack = song.artist != null
          ? '${song.title} · ${song.artist}'
          : song.title;
      _ref
          .read(solarpassScrobbleStatusProvider.notifier)
          .update(
            isScrobbling: true,
            currentTrack: displayTrack,
            lastError: null,
          );
    } catch (e) {
      debugPrint('[Solarpass] Scrobble error: $e');
      final displayTrack = song.artist != null
          ? '${song.title} · ${song.artist}'
          : song.title;
      _ref
          .read(solarpassScrobbleStatusProvider.notifier)
          .update(
            isScrobbling: false,
            currentTrack: displayTrack,
            lastError: e.toString(),
          );
    }
  }

  Future<void> _clearPresence() async {
    _lastScrobbledKey = null;
    _pauseDebounceTimer?.cancel();
    _pauseDebounceTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final session = await _ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (session == null) return;

    final client = _ref.read(solarpassClientProvider);
    try {
      await client.clearPresenceActivity(session: session);
    } catch (_) {}

    _ref
        .read(solarpassScrobbleStatusProvider.notifier)
        .update(isScrobbling: false, currentTrack: null);
  }

  void dispose() {
    _disposed = true;
    _commitPendingScrobble();
    _heartbeatTimer?.cancel();
    _pauseDebounceTimer?.cancel();
  }
}
