import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/app.dart';
import '../server/models.dart';


part 'player.g.dart';

/// What the transport does at the end of a track.
enum PlaybackRepeatMode { off, all, single }

/// The button's cycle: off -> queue -> one song -> off.
PlaybackRepeatMode nextRepeatMode(PlaybackRepeatMode mode) => switch (mode) {
  PlaybackRepeatMode.off => PlaybackRepeatMode.all,
  PlaybackRepeatMode.all => PlaybackRepeatMode.single,
  PlaybackRepeatMode.single => PlaybackRepeatMode.off,
};

/// Immutable view of the transport, rebuilt on every stream event.
///
/// Screens read this and nothing else: the underlying [Player] is a media-kit
/// instance whose streams are wired in one place ([PlaybackController]), so no
/// widget ever subscribes to libmpv itself.
class PlaybackState {
  /// The playable queue, in play order.
  final List<SubsonicSong> queue;
  final int? currentIndex;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final PlaybackRepeatMode repeatMode;
  final double volume;

  const PlaybackState({
    this.queue = const [],
    this.currentIndex,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.volume = 100,
  });

  SubsonicSong? get current =>
      currentIndex == null || currentIndex! >= queue.length
          ? null
          : queue[currentIndex!];

  bool get hasNext =>
      queue.isNotEmpty && (currentIndex ?? -1) < queue.length - 1;

  bool get hasPrevious =>
      (currentIndex ?? 0) > 0 || repeatMode == PlaybackRepeatMode.all;

  PlaybackState copyWith({
    List<SubsonicSong>? queue,
    int? currentIndex,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? shuffle,
    PlaybackRepeatMode? repeatMode,
    double? volume,
    bool clearIndex = false,
  }) => PlaybackState(
    queue: queue ?? this.queue,
    currentIndex: clearIndex ? null : currentIndex ?? this.currentIndex,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    shuffle: shuffle ?? this.shuffle,
    repeatMode: repeatMode ?? this.repeatMode,
    volume: volume ?? this.volume,
  );
}

/// Owns the one [Player] for the app's lifetime and translates its streams
/// into [PlaybackState].
///
/// Exposed as `playbackProvider` (the state) and
/// `playbackProvider.notifier` (the transport).
///
/// Kept out of the widget tree on purpose: the audio session outlives the dock,
/// the player page, and any route pushed above them.
///
/// Streams are remote URLs, so a track is opened with its signed Subsonic
/// stream URL rather than a local path. Nothing is downloaded first.
/// The transport. Created lazily and kept alive for the whole session.
@Riverpod(keepAlive: true)
class Playback extends Notifier<PlaybackState> {
  late final Player _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Play order is index order: shuffling reorders [PlaybackState.queue]
  /// rather than asking media-kit to shuffle, so the queue the user sees is
  /// always the queue that plays.
  List<SubsonicSong> _order = [];

  /// The queue as handed to [playQueue], used to undo a shuffle.
  List<SubsonicSong> _sourceOrder = [];

  @override
  PlaybackState build() {
    _player = Player();

    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        state = state.copyWith(playing: playing);
      }),
      _player.stream.position.listen((position) {
        state = state.copyWith(position: position);
      }),
      _player.stream.duration.listen((duration) {
        state = state.copyWith(duration: duration);
      }),
      _player.stream.completed.listen((completed) {
        if (completed) _onTrackCompleted();
      }),
      _player.stream.volume.listen((volume) {
        state = state.copyWith(volume: volume);
      }),
    ]);

    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        subscription.cancel();
      }
      _player.dispose();
    });

    return const PlaybackState();
  }

  /// Replaces the queue with [songs] and starts at [startIndex].
  Future<void> playQueue(List<SubsonicSong> songs, {int startIndex = 0}) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;

    _order = List.of(songs);
    _sourceOrder = List.of(songs);
    state = state.copyWith(
      queue: _order,
      currentIndex: startIndex,
      duration: _order[startIndex].duration,
      position: Duration.zero,
    );

    await _openCurrent();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> togglePlayPause() =>
      state.playing ? _player.pause() : _player.play();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next() async {
    if (!state.hasNext) {
      if (state.repeatMode == PlaybackRepeatMode.all && state.queue.isNotEmpty) {
        await _jumpTo(0);
      }
      return;
    }
    await _jumpTo((state.currentIndex ?? 0) + 1);
  }

  Future<void> previous() async {
    // Ten seconds in, "previous" means restart the track — the behaviour every
    // player shares — rather than jump back a row.
    if (state.position > const Duration(seconds: 10) ||
        !state.hasPrevious) {
      await _player.seek(Duration.zero);
      return;
    }
    final target = (state.currentIndex ?? 0) - 1;
    await _jumpTo(target < 0 ? state.queue.length - 1 : target);
  }

  Future<void> setShuffle(bool shuffle) async {
    final current = state.current;
    if (current == null || shuffle == state.shuffle) {
      state = state.copyWith(shuffle: shuffle);
      return;
    }

    if (shuffle) {
      // Park the current song first so playback continues uninterrupted; the
      // rest is a random order of everything else.
      final rest = List.of(_order)..removeAt(state.currentIndex!);
      rest.shuffle();
      _order = [current, ...rest];
    } else {
      final rest = List.of(_order)..removeAt(0);
      rest.sort(
        (a, b) => _sourceOrder.indexOf(a).compareTo(_sourceOrder.indexOf(b)),
      );
      _order = [current, ...rest];
    }

    state = state.copyWith(
      shuffle: shuffle,
      queue: _order,
      currentIndex: 0,
      duration: current.duration,
    );
  }

  Future<void> cycleRepeatMode() async {
    final next = nextRepeatMode(state.repeatMode);
    state = state.copyWith(repeatMode: next);
    await _player.setPlaylistMode(switch (next) {
      PlaybackRepeatMode.off => PlaylistMode.none,
      PlaybackRepeatMode.all => PlaylistMode.loop,
      PlaybackRepeatMode.single => PlaylistMode.single,
    });
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// Opens the song at the current index through the server's stream endpoint.
  Future<void> _openCurrent() async {
    final song = state.current;
    final client = ref.read(subsonicClientProvider);
    if (song == null || client == null) return;

    await _player.open(Media(client.streamUrl(song.id)));
  }

  Future<void> _jumpTo(int index) async {
    state = state.copyWith(
      currentIndex: index,
      position: Duration.zero,
      duration: _order[index].duration,
    );
    await _openCurrent();
  }

  Future<void> _onTrackCompleted() async {
    switch (state.repeatMode) {
      case PlaybackRepeatMode.single:
        // media-kit already honours single mode on its own; this keeps the
        // state honest for the UI when we drive the transport manually.
        await _player.seek(Duration.zero);
        await _player.play();
      case PlaybackRepeatMode.all:
        await next();
      case PlaybackRepeatMode.off:
        if (state.hasNext) {
          await next();
        } else {
          state = state.copyWith(playing: false, position: Duration.zero);
        }
    }
  }
}
