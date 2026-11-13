import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:music_kit/music_kit.dart';

import 'models.dart';

/// What the Apple Music integration needs from the platform, behind one
/// interface.
///
/// The library layer talks to this rather than to `music_kit` directly: reads
/// are plain REST and testable off-device, and only the token/playback calls
/// reach the plugin. Tests and unsupported platforms get [SilentMusicKit].
abstract interface class MusicKitClient {
  factory MusicKitClient() => PluginMusicKit();

  /// Asks the system for permission and returns whether it was granted.
  Future<bool> requestAuthorization();

  Future<String> developerToken();

  Future<String> userToken(String developerToken);

  /// Replaces the system player's queue with [items] and starts at [startingAt].
  ///
  /// [itemType] is the resource kind the player resolves the items as: a
  /// library song is `'songs'`, a station is `'stations'`.
  Future<void> setQueue(
    List<Map<String, dynamic>> items, {
    int startingAt = 0,
    String itemType = 'songs',
  });

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<Duration> playbackTime();

  /// The player's own status, mapped onto the few states the app reasons about.
  Stream<ApplePlayerStatus> get status;

  /// Index of the entry the system player is on, inside the queue it was
  /// given. The system advances through its own queue, so this is how an
  /// automatic move to the next track reaches the app.
  Stream<int> get queueIndex;
}

/// The states of the system player the app acts on.
enum ApplePlayerStatus { stopped, playing, paused, interrupted, seeking }

/// The plugin-backed client. Only constructed on iOS and macOS 14+, which is
/// what [AppleMusicSource.isSupported] gates on.
class PluginMusicKit implements MusicKitClient {
  final MusicKit _kit = MusicKit();

  @override
  Future<bool> requestAuthorization() async {
    final status = await _kit.requestAuthorizationStatus();
    return status is MusicAuthorizationStatusAuthorized;
  }

  @override
  Future<String> developerToken() => _kit.requestDeveloperToken();

  @override
  Future<String> userToken(String developerToken) =>
      _kit.requestUserToken(developerToken);

  /// The plugin hands `startingAt` to the system as an item looked up *in*
  /// the queue; passing the first item explicitly makes MediaPlayer reject
  /// the queue ("unexpected start item"), so a start at zero is expressed by
  /// leaving it out.
  @override
  Future<void> setQueue(
    List<Map<String, dynamic>> items, {
    int startingAt = 0,
    String itemType = 'songs',
  }) => _kit.setQueueWithItems(
    itemType,
    items: items,
    startingAt: startingAt == 0 ? null : startingAt,
  );

  @override
  Future<void> play() => _kit.play();

  @override
  Future<void> pause() => _kit.pause();

  @override
  Future<void> stop() => _kit.stop();

  @override
  Future<void> seek(Duration position) => _kit.setPlaybackTime(
    position.inMicroseconds / Duration.microsecondsPerSecond,
  );

  @override
  Future<Duration> playbackTime() async {
    final seconds = await _kit.playbackTime;
    if (!seconds.isFinite || seconds < 0) return Duration.zero;
    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }

  @override
  Stream<ApplePlayerStatus> get status => _kit.onMusicPlayerStateChanged.map(
    (state) => switch (state.playbackStatus) {
      MusicPlayerPlaybackStatus.playing => ApplePlayerStatus.playing,
      MusicPlayerPlaybackStatus.paused => ApplePlayerStatus.paused,
      MusicPlayerPlaybackStatus.interrupted => ApplePlayerStatus.interrupted,
      MusicPlayerPlaybackStatus.seekingBackward ||
      MusicPlayerPlaybackStatus.seekingForward => ApplePlayerStatus.seeking,
      MusicPlayerPlaybackStatus.stopped => ApplePlayerStatus.stopped,
    },
  );

  /// The entry list keeps the order it was submitted in, and `currentEntry`
  /// moves along it as tracks finish; the index is read from the entry's
  /// identity rather than its id, which the system rewrites to the catalog's.
  @override
  Stream<int> get queueIndex => _kit.onPlayerQueueChanged
      .where((queue) => queue.currentEntry != null)
      .map((queue) {
        final current = queue.currentEntry!;
        return queue.entries.indexWhere((entry) => entry.id == current.id);
      })
      .where((index) => index >= 0)
      .distinct();
}

/// A client that refuses everything: a platform without MusicKit, or a test.
///
/// Returns cleanly rather than throwing, so a provider that builds it eagerly
/// cannot crash an app that never opens an Apple Music library.
class SilentMusicKit implements MusicKitClient {
  const SilentMusicKit();

  @override
  Future<bool> requestAuthorization() async => false;

  @override
  Future<String> developerToken() async => '';

  @override
  Future<String> userToken(String developerToken) async => '';

  @override
  Future<void> setQueue(
    List<Map<String, dynamic>> items, {
    int startingAt = 0,
    String itemType = 'songs',
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<Duration> playbackTime() async => Duration.zero;

  @override
  Stream<ApplePlayerStatus> get status => const Stream.empty();

  @override
  Stream<int> get queueIndex => const Stream.empty();
}

/// The JSON resource the system player needs to play a library song.
///
///
/// [MusicKit] addresses items by their raw resource, so a song the app read
/// over REST has to be handed back the way Apple describes it: an id, the
/// attributes that name it, and the `playParams` that say it is a *library*
/// item. The library id is what the player resolves; the catalog id of the
/// original recording is not needed to play a song already in the account's
/// library.
/// The same for a radio station: the player resolves it from the URL and play
/// params the recommendation carried, and generates the station's own run of
/// tracks itself.
Map<String, dynamic> appleRadioItem(LibrarySong song) => {
  'id': song.id,
  'type': 'stations',
  'attributes': {
    'name': song.title,
    'isLive': false,
    'mediaKind': 'audio',
    if (song.radioUrl != null) 'url': song.radioUrl,
    if (song.radioPlayParams != null) 'playParams': song.radioPlayParams,
  },
};

/// The resource for whichever kind [song] is.
Map<String, dynamic> appleQueueItem(LibrarySong song) => song.isRadio
    ? appleRadioItem(song)
    : {
        'id': song.id,
        'type': 'songs',
        'attributes': {
          'name': song.title,
          if (song.artist != null) 'artistName': song.artist,
          if (song.album != null) 'albumName': song.album,
          'durationInMillis': song.duration.inMilliseconds,
          'playParams': {'id': song.id, 'kind': 'song', 'isLibrary': true},
        },
      };

/// Logs and swallows a platform failure the transport cannot recover from.
///
/// The player has no error surface of its own; a failed Apple Music open is
/// reported through the source failure map instead, so Settings says why the
/// provider went quiet.
void logAppleFailure(Object error) =>
    debugPrint('[AppleMusic] playback failed: $error');
