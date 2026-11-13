import 'dart:async';

import 'package:groovy_box/library/apple_kit.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apple_player.g.dart';

/// The platform players the app can hand a queue to.
///
/// One seam for every source that has no stream URL: today only Apple Music,
/// but the transport asks the *source* which engine it wants
/// ([LibrarySource.usesPlatformPlayer]) and never the kind.
@Riverpod(keepAlive: true)
MusicKitClient musicKitClient(Ref ref) => MusicKitClient();

/// Drives the system's Apple Music player on behalf of the transport.
///
/// The app's queue and the system's are kept equal: the system player is
/// handed the run of tracks from the current one onward, so when a track ends
/// it advances *itself* — the app then follows the index it reports. Handing
/// it a single item instead (the obvious reading of "the app owns the queue")
/// makes it stop dead at the end of that item, because it has nothing to
/// advance to.
///
/// What the system adds on top is playback itself, its position clock, its
/// pause/interrupt handling and its own end-of-track behaviour.
class ApplePlayer {
  ApplePlayer(
    this._client, {
    required this.onStatus,
    required this.onPosition,
    required this.onAdvance,
  });

  final MusicKitClient _client;
  final void Function(ApplePlayerStatus status) onStatus;
  final void Function(Duration position) onPosition;

  /// Called with the index in the *app's* queue when the system player moved
  /// there by itself.
  final void Function(int index) onAdvance;

  StreamSubscription<ApplePlayerStatus>? _statusSub;
  StreamSubscription<int>? _queueSub;
  Timer? _clock;
  bool _started = false;

  /// Whether a song is loaded in the system player.
  bool get isLoaded => _started;

  /// Loads [queue] starting at [startingAt] and plays it.
  ///
  /// The queue is the app's own order, so the two stay in step; [startingAt]
  /// is the position in it to begin at.
  Future<void> open(List<LibrarySong> queue, int startingAt) async {
    if (queue.isEmpty || startingAt < 0 || startingAt >= queue.length) return;
    _listen();
    _started = true;
    await _pushQueue(queue, startingAt);
    await _client.play();
    _startClock();
  }

  Future<void> play() async {
    if (!_started) return;
    await _client.play();
    _startClock();
  }

  Future<void> pause() async {
    await _client.pause();
    _stopClock();
  }

  Future<void> stop() async {
    _stopClock();
    _started = false;
    await _client.stop();
  }

  /// Seeks inside the current track.
  ///
  /// Seeking is one of the operations that *pauses* the system player, so a
  /// player that was running is started again afterwards; otherwise the first
  /// drag of the scrubber would silently stop the music.
  Future<void> seek(Duration position) async {
    if (!_started) return;
    final wasPlaying = _wasPlaying;
    await _client.seek(position);
    onPosition(position);
    if (wasPlaying) await _client.play();
  }

  /// The system player is on a different index of the app's queue than the
  /// one the app loaded, because a track ended and it advanced.
  ///
  /// [queue] is the app's current order; the system's index and the app's
  /// agree because they were pushed together, so only tracks that are still
  /// where they were can be followed this way.
  Future<void> resync(List<LibrarySong> queue, int startingAt) async {
    if (!_started) return;
    if (queue.isEmpty || startingAt < 0 || startingAt >= queue.length) return;
    await _pushQueue(queue, startingAt);
  }

  /// Replaces the system queue with [queue] from [startingAt] onward.
  ///
  /// Items are converted per kind: a radio station is not a track and the
  /// player resolves it from its own resource shape.
  Future<void> _pushQueue(List<LibrarySong> queue, int startingAt) async {
    // The app's queue and the system's are the same order from this point:
    // system index 0 is app index [startingAt], and the system reports its
    // index, so an automatic advance is one addition.
    _base = startingAt;
    _systemIndex = 0;
    final songs = queue.sublist(startingAt);
    // A station is queued alone: the system generates the station's own
    // endless run, and handing it a second item would cut that run short.
    final radio = songs.first.isRadio;
    final items = radio
        ? [appleQueueItem(songs.first)]
        : [for (final song in songs) appleQueueItem(song)];
    await _client.setQueue(items, itemType: radio ? 'stations' : 'songs');
  }

  /// The app-queue index that the system queue's first entry stands for.
  int get base => _base;
  int _base = 0;

  /// Where the system says it is, counted from its own first entry.
  int _systemIndex = 0;

  /// The last reported play state, so a seek knows whether to resume.
  bool _wasPlaying = false;

  void dispose() {
    _stopClock();
    _statusSub?.cancel();
    _statusSub = null;
    _queueSub?.cancel();
    _queueSub = null;
    _wasPlaying = false;
    _started = false;
  }

  void _listen() {
    _statusSub ??= _client.status.listen(
      (status) {
        _wasPlaying =
            status == ApplePlayerStatus.playing ||
            status == ApplePlayerStatus.seeking;
        onStatus(status);
        if (status == ApplePlayerStatus.playing) {
          _startClock();
        } else if (status == ApplePlayerStatus.stopped ||
            status == ApplePlayerStatus.paused) {
          _stopClock();
        }
      },
      // A platform that refuses the stream must not take the transport down
      // with it: playback simply stays where the app put it.
      onError: (Object error) => logAppleFailure(error),
    );
    _queueSub ??= _client.queueIndex.listen((index) {
      // The first notification describes the queue just pushed, so it says
      // nothing new; anything later is the system having advanced.
      if (index == _systemIndex) return;
      _systemIndex = index;
      onAdvance(_base + index);
    }, onError: (Object error) => logAppleFailure(error));
  }

  /// The system player reports no position stream, so the clock is polled
  /// while it is running. One read per second is what a scrubber needs, and
  /// it stops the moment playback does.
  void _startClock() {
    if (_clock?.isActive ?? false) return;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        onPosition(await _client.playbackTime());
      } catch (error) {
        logAppleFailure(error);
      }
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }
}
