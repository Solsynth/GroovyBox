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
/// The app's own queue stays authoritative: the system queue is replaced with
/// the one song about to play, so skip, repeat and shuffle keep behaving the
/// way they do for a streamed track, and the media session keeps drawing its
/// own queue. What the system adds on top is playback itself, its position
/// clock and its own pause/interrupt handling.
class ApplePlayer {
  ApplePlayer(this._client, {required this.onStatus, required this.onPosition});

  final MusicKitClient _client;
  final void Function(ApplePlayerStatus status) onStatus;
  final void Function(Duration position) onPosition;

  StreamSubscription<ApplePlayerStatus>? _statusSub;
  Timer? _clock;
  bool _started = false;

  /// Whether a song is loaded in the system player.
  bool get isLoaded => _started;

  /// Loads [song] and starts it. The system player requires the item's own
  /// resource shape, so the app's neutral model is converted here.
  Future<void> open(LibrarySong song) async {
    _listen();
    _started = true;
    await _client.setQueue([appleQueueItem(song)]);
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

  Future<void> seek(Duration position) async {
    if (!_started) return;
    await _client.seek(position);
    onPosition(position);
  }

  void dispose() {
    _stopClock();
    _statusSub?.cancel();
    _statusSub = null;
  }

  void _listen() {
    _statusSub ??= _client.status.listen(
      (status) {
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
