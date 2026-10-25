import 'package:audio_service/audio_service.dart';
import 'package:groovy_box/library/models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// What the system's media session can ask the app's transport to do.
///
/// Implemented by the transport and driven by [GroovyBoxAudioHandler]: the
/// notification, the lock screen, the headset buttons and CarPlay all reach
/// the player through this one seam.
abstract interface class AudioTransport {
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> setShuffle(bool shuffle);
  Future<void> setRepeatMode(AudioServiceRepeatMode mode);
  Future<void> skipToQueueIndex(int index);
}

/// The playback the media session shows, in the system's own vocabulary.
///
/// A snapshot rather than a live view: the handler is a plain object that
/// outlives every widget, so it never reads app state itself.
class AudioSnapshot {
  final List<MediaItem> items;
  final int? index;
  final bool playing;
  final Duration position;
  final AudioServiceRepeatMode repeatMode;
  final bool shuffle;

  const AudioSnapshot({
    required this.items,
    required this.index,
    required this.playing,
    required this.position,
    required this.repeatMode,
    required this.shuffle,
  });

  /// The id the system uses for [song]. A song id is only unique inside its
  /// own library, so the source is part of the identity.
  static String idOf(LibrarySong song) => '${song.sourceId}:${song.id}';

  /// One queue row, as the notification and the lock screen draw it.
  static MediaItem itemOf(LibrarySong song, {Uri? artUri}) => MediaItem(
    id: idOf(song),
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: song.duration,
    artUri: artUri,
  );
}

/// The app's [AudioHandler]: one object for the whole session, translating
/// system callbacks into [AudioTransport] calls and the app's playback into
/// the state the notification and the lock screen show.
///
/// It exists before the first frame, because the platform can deliver a media
/// button before any widget does. What it needs from the app arrives later,
/// through [transport] and [publish]; callbacks that arrive before that are
/// answered with silence rather than an exception.
class GroovyBoxAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioTransport? transport;

  /// Pushes a new snapshot to the system.
  ///
  /// Called on discrete events — track change, play/pause, seek, queue edits —
  /// not on the position tick: the system advances the clock itself while
  /// playing, and a notification rebuild per tick would be pure cost.
  void publish(AudioSnapshot snapshot) {
    queue.add(snapshot.items);

    final index = snapshot.index;
    final item = index == null || index < 0 || index >= snapshot.items.length
        ? null
        : snapshot.items[index];
    mediaItem.add(item);

    playbackState.add(
      PlaybackState(
        // A loaded but paused track is `ready`, not idle: idle hides the
        // notification, and pausing is not the same as unloading.
        processingState: item == null
            ? AudioProcessingState.idle
            : AudioProcessingState.ready,
        playing: snapshot.playing,
        controls: item == null
            ? const <MediaControl>[]
            : <MediaControl>[
                MediaControl.skipToPrevious,
                snapshot.playing ? MediaControl.pause : MediaControl.play,
                MediaControl.skipToNext,
              ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        updatePosition: snapshot.position,
        repeatMode: snapshot.repeatMode,
        shuffleMode: snapshot.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        queueIndex: index,
      ),
    );
  }

  @override
  Future<void> play() async => transport?.play();

  @override
  Future<void> pause() async => transport?.pause();

  @override
  Future<void> seek(Duration position) async => transport?.seek(position);

  @override
  Future<void> skipToNext() async => transport?.next();

  @override
  Future<void> skipToPrevious() async => transport?.previous();

  @override
  Future<void> skipToQueueItem(int index) async =>
      transport?.skipToQueueIndex(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async =>
      transport?.setRepeatMode(repeatMode);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async =>
      transport?.setShuffle(shuffleMode != AudioServiceShuffleMode.none);

  @override
  Future<void> stop() async {
    await transport?.pause();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }
}

/// The handler for this session, or null where there is no media session
/// (tests, and any platform the plugin does not cover).
///
/// Overridden in `main` with the instance `AudioService.init` built, so widget
/// tests never touch a platform channel.
final audioHandlerProvider = Provider<GroovyBoxAudioHandler?>((ref) => null);
