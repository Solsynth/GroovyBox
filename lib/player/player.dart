import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/session.dart';
import 'package:groovy_box/player/play_tracker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  final List<LibrarySong> queue;
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

  LibrarySong? get current =>
      currentIndex == null || currentIndex! >= queue.length
          ? null
          : queue[currentIndex!];

  /// Whether [song] is the one playing. Ids are only unique per source, so
  /// both halves of the identity have to match.
  bool isCurrentSong(LibrarySong song) =>
      current?.sourceId == song.sourceId && current?.id == song.id;

  bool get hasNext =>
      queue.isNotEmpty && (currentIndex ?? -1) < queue.length - 1;

  bool get hasPrevious =>
      (currentIndex ?? 0) > 0 || repeatMode == PlaybackRepeatMode.all;

  PlaybackState copyWith({
    List<LibrarySong>? queue,
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
/// Streams are remote URLs, so a track is opened with its own library's signed
/// stream URL rather than a local path. Nothing is downloaded first.
/// The transport. Created lazily and kept alive for the whole session.
@Riverpod(keepAlive: true)
class Playback extends Notifier<PlaybackState> implements AudioTransport {
  late final Player _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// The media session this transport reports to. The handler is built in
  /// `main`, before this container, so it is looked up here instead of being
  /// constructed with the notifier.
  GroovyBoxAudioHandler? _session;

  /// Play order is index order: shuffling reorders [PlaybackState.queue]
  /// rather than asking media-kit to shuffle, so the queue the user sees is
  /// always the queue that plays.
  List<LibrarySong> _order = [];

  /// The queue as handed to [playQueue], used to undo a shuffle.
  List<LibrarySong> _sourceOrder = [];

  /// Writes what the transport plays into the local library's history.
  late final PlayTracker _tracker;

  @override
  PlaybackState build() {
    _player = Player();
    _tracker = PlayTracker(ref.read(libraryCatalogProvider));

    // Hand the transport over before any subscription fires: a media button
    // that arrived while the app was starting has been waiting for one.
    _session = ref.read(audioHandlerProvider);
    _session?.transport = this;

    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        state = state.copyWith(playing: playing);
        _publish();
      }),
      _player.stream.position.listen((position) {
        state = state.copyWith(position: position);
        // Fire and forget: history is written at its own pace, and playback
        // must never wait on a transaction.
        _tracker.observe(position, duration: state.duration);
      }),
      _player.stream.duration.listen((duration) {
        state = state.copyWith(duration: duration);
        _publish();
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
      // Whatever the play reached is written before the database goes away,
      // so closing the window mid-track still leaves an honest row.
      _tracker.flush();
      if (identical(_session?.transport, this)) _session!.transport = null;
      _player.dispose();
    });

    return const PlaybackState();
  }

  /// Replaces the queue with [songs] and starts at [startIndex].
  Future<void> playQueue(List<LibrarySong> songs, {int startIndex = 0}) async {
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
    _publish();
  }

  @override
  Future<void> play() async {
    await _player.play();
    _publish();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _publish();
  }

  Future<void> togglePlayPause() => state.playing ? pause() : play();

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _publish();
  }

  @override
  Future<void> next() async {
    if (!state.hasNext) {
      if (state.repeatMode == PlaybackRepeatMode.all && state.queue.isNotEmpty) {
        await _jumpTo(0);
        _publish();
      }
      return;
    }
    await _jumpTo((state.currentIndex ?? 0) + 1);
    _publish();
  }

  @override
  Future<void> previous() async {
    // Ten seconds in, "previous" means restart the track — the behaviour every
    // player shares — rather than jump back a row.
    if (state.position > const Duration(seconds: 10) ||
        !state.hasPrevious) {
      await _player.seek(Duration.zero);
      _publish();
      return;
    }
    final target = (state.currentIndex ?? 0) - 1;
    await _jumpTo(target < 0 ? state.queue.length - 1 : target);
    _publish();
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    final current = state.current;
    if (current == null || shuffle == state.shuffle) {
      state = state.copyWith(shuffle: shuffle);
      _publish();
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
    _publish();
  }

  Future<void> cycleRepeatMode() async {
    final next = nextRepeatMode(state.repeatMode);
    state = state.copyWith(repeatMode: next);
    await _player.setPlaylistMode(switch (next) {
      PlaybackRepeatMode.off => PlaylistMode.none,
      PlaybackRepeatMode.all => PlaylistMode.loop,
      PlaybackRepeatMode.single => PlaylistMode.single,
    });
    _publish();
  }

  /// The system's repeat switch is the same three-state cycle the button
  /// drives, entered from a different side.
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    final target = switch (mode) {
      AudioServiceRepeatMode.one => PlaybackRepeatMode.single,
      AudioServiceRepeatMode.all => PlaybackRepeatMode.all,
      _ => PlaybackRepeatMode.off,
    };
    if (target != state.repeatMode) {
      state = state.copyWith(repeatMode: target);
      await _player.setPlaylistMode(switch (target) {
        PlaybackRepeatMode.off => PlaylistMode.none,
        PlaybackRepeatMode.all => PlaylistMode.loop,
        PlaybackRepeatMode.single => PlaylistMode.single,
      });
    }
    _publish();
  }

  @override
  Future<void> skipToQueueIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    if (index == state.currentIndex) {
      await seek(Duration.zero);
      return;
    }
    await _jumpTo(index);
    _publish();
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// Opens the song at the current index through its library's stream
  /// endpoint. A source that has since been removed leaves the transport
  /// stopped rather than throwing.
  Future<void> _openCurrent() async {
    final song = state.current;
    if (song == null) return;
    // The play is recorded before the stream opens, so a source that has been
    // removed still leaves the row that says the user tried to play it.
    await _tracker.start(song);
    final source = ref.read(librarySourceByIdProvider)[song.sourceId];
    if (source == null) return;

    await _player.open(Media(source.streamUri(song).toString()));
  }

  Future<void> _jumpTo(int index) async {
    state = state.copyWith(
      currentIndex: index,
      position: Duration.zero,
      duration: _order[index].duration,
    );
    await _openCurrent();
  }

  /// Tells the media session what is playing and where.
  ///
  /// Called on discrete events — track change, play/pause, seek, queue edits —
  /// not on the position tick: between events the system advances the clock
  /// itself, and a notification rebuild per tick would be pure cost.
  void _publish() {
    final session = _session;
    if (session == null) return;
    final sources = ref.read(librarySourceByIdProvider);
    session.publish(
      AudioSnapshot(
        items: [
          for (final song in state.queue)
            AudioSnapshot.itemOf(
              song,
              artUri: sources[song.sourceId]?.artworkUri(song.artId),
            ),
        ],
        index: state.currentIndex,
        playing: state.playing,
        position: state.position,
        repeatMode: switch (state.repeatMode) {
          PlaybackRepeatMode.off => AudioServiceRepeatMode.none,
          PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
          PlaybackRepeatMode.single => AudioServiceRepeatMode.one,
        },
        shuffle: state.shuffle,
      ),
    );
  }

  Future<void> _onTrackCompleted() async {
    // Written before the repeat branch, which may start the track over and
    // reset the play this row describes.
    await _tracker.finish();
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
          _publish();
        }
    }
  }
}
