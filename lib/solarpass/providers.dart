import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/app.dart';
import '../library/models.dart';
import '../library/providers.dart';
import '../player/player.dart';
import '../pulsar/client.dart';
import 'client.dart';
import 'models.dart';

/// How much of a track must be heard before it counts as a scrobble.
///
/// Last.fm's own rule is a half; a quarter is what someone skipping through a
/// playlist still means by "I listened to that". The comparison is done in
/// milliseconds so no float rounding decides a borderline track.
const _kScrobbleFraction = 0.25;

/// Tracks shorter than this are never scrobbled, matching Last.fm, which
/// ignores anything under 30 seconds rather than logging a jingle.
const _kMinScrobbleDuration = Duration(seconds: 30);

/// A row with no length of its own (a station) has no fraction to reach, so
/// it needs this much listening instead.
const _kUnknownDurationThreshold = Duration(seconds: 30);

/// Now-playing broadcasts coalesce over this window: skipping through a list
/// announces the track the user settles on, not every one passed over.
const _kPresenceDebounce = Duration(seconds: 2);

/// How often the presence lease is renewed while a track plays. The lease
/// itself is five minutes; this leaves two renewals of slack.
const _kHeartbeatInterval = Duration(seconds: 150);

/// How long a paused track stays up as presence before it is cleared.
const _kPauseGrace = Duration(seconds: 30);

/// Whether a play counts as a scrobble.
///
/// A quarter of the track is the bar: it is what someone who skipped ahead
/// still heard enough of to mean it, and it keeps a browse-through playlist
/// from logging rows the listener passed over. A row with no length of its
/// own (a station) has no fraction to take, so it needs
/// [_kUnknownDurationThreshold] instead. Rows shorter than
/// [_kMinScrobbleDuration] never count.
bool isScrobbleEligible({
  required Duration duration,
  required Duration listened,
}) {
  if (duration > Duration.zero && duration < _kMinScrobbleDuration) {
    return false;
  }
  final needed = duration > Duration.zero
      ? Duration(
          microseconds: (duration.inMicroseconds * _kScrobbleFraction).round(),
        )
      : _kUnknownDurationThreshold;
  return listened >= needed;
}
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
  ///
  /// A caller can arrive before [build] has finished — a first frame that
  /// asks for a share link, the sync panel opening on launch — and this
  /// notifier's state is still `AsyncLoading` then. That is "not loaded yet",
  /// not "signed out", so the build is awaited rather than answered with the
  /// null it has not filled in.
  Future<OAuthSession?> validSession() async {
    var current = state.value;
    if (current == null && state.isLoading) current = await future;
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
      // The account notifier watches the session, so the saved state rebuilds
      // it; reading it back here would make the two providers depend on one
      // another, which Riverpod refuses.
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
      // Rebuilt by the session watch above; see signInBrowser.
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
    // The account notifier watches the session: its rebuild sees the null and
    // drops the profile, so nothing else is invalidated from here.
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

/// Central presence scrobbler that listens to [playbackProvider] and syncs with
/// Solar Network.
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
  Timer? _presenceTimer;
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
        _schedulePresence();
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
        _playStartedAt = clock.now();
        _listenedDuration = Duration.zero;
        _lastResumeTime = clock.now();
        _lastScrobbledKey = key;
        // Only a change or a resume arms the broadcast: position ticks land
        // here every second and would otherwise keep pushing it back.
        _schedulePresence();
      } else if (prev?.playing != true) {
        // Resumed playing same song
        _lastResumeTime = clock.now();
        _schedulePresence();
      }
      _ensureHeartbeat();
    } else {
      // Paused or playback stopped
      _presenceTimer?.cancel();
      _presenceTimer = null;
      if (_lastResumeTime != null) {
        _listenedDuration += clock.now().difference(_lastResumeTime!);
        _lastResumeTime = null;
      }

      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      if (song == null) {
        // Queue finished or cleared: commit pending scrobble and clear presence
        _commitPendingScrobble();
        _clearPresence();
      } else {
        // Paused on track: debounce clearing activity by [_kPauseGrace]
        _pauseDebounceTimer ??= Timer(_kPauseGrace, () {
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
      _listenedDuration += clock.now().difference(_lastResumeTime!);
      _lastResumeTime = null;
    }

    final song = _activeSong!;
    final listened = _listenedDuration;
    final playedAt = _playStartedAt ?? clock.now();

    if (isScrobbleEligible(duration: song.duration, listened: listened)) {
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
        trackId: pulsarTrackKey(song),
        playedAt: playedAt,
      );
    } catch (e) {
      debugPrint('[Solarpass] Submit scrobble error: $e');
    }
  }

  void _ensureHeartbeat() {
    // Renew the lease while the track plays. Position ticks re-enter here
    // every second, so the timer is created once and left alone: recreating
    // it on each tick would push the first renewal out forever.
    _heartbeatTimer ??= Timer.periodic(_kHeartbeatInterval, (_) {
      _schedulePresence();
    });
  }

  /// Broadcasts the current track after [_kPresenceDebounce] of quiet.
  ///
  /// Every track change and resume only arms the timer, so a listener
  /// skipping down a playlist announces the row they stop on rather than each
  /// one they pass. The heartbeat and the settings toggle go through here too,
  /// which keeps one place responsible for what presence says.
  void _schedulePresence() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer(_kPresenceDebounce, () {
      _presenceTimer = null;
      if (_disposed) return;
      final playback = _ref.read(playbackProvider);
      final song = playback.current;
      if (!playback.playing || song == null) return;
      _scrobbleTrack(song, playback.position);
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
        trackId: pulsarTrackKey(song),
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
    _presenceTimer?.cancel();
    _presenceTimer = null;
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
    _presenceTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pauseDebounceTimer?.cancel();
  }
}
