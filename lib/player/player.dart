import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/track_identity.dart';
import 'package:groovy_box/library/apple_kit.dart';
import 'package:groovy_box/player/apple_player.dart';
import 'package:groovy_box/player/session.dart';
import 'package:groovy_box/player/play_tracker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final bool buffering;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final PlaybackRepeatMode repeatMode;
  final double volume;

  /// The run a radio station is playing right now, as the platform player
  /// holds it. Empty for every other kind of item: an app queue is [queue].
  ///
  /// A station generates tracks the app never asked for, so this is the only
  /// description of "what is coming" and the only thing next/previous can
  /// mean there.
  final List<LibrarySong> stationTracks;
  final int stationIndex;

  /// Whether the platform player owns the output level for the current track.
  /// MusicKit has no volume API, so the settings slider cannot move it.
  final bool volumeIsSystemControlled;

  const PlaybackState({
    this.queue = const [],
    this.currentIndex,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.volume = 100,
    this.volumeIsSystemControlled = false,
    this.stationTracks = const [],
    this.stationIndex = -1,
  });

  /// The song the app is playing, as everything that *describes* a track
  /// should read it.
  ///
  /// A station row is not a track: it has no length, no album and no lyrics
  /// of its own. Its [LibrarySong.radioTrack] is what is on the air, so this
  /// answers with that — artwork, lyrics, the scrobbler and the system's
  /// media item all get the real track's metadata from one place. The row
  /// itself stays in [queue], which is what the transport plays from.
  LibrarySong? get current {
    final row = queueRow;
    return row?.playing;
  }

  /// The queue entry at [currentIndex], station wrapper and all.
  ///
  /// This is the thing that is *loaded*, not necessarily the thing that is
  /// heard: see [current].
  LibrarySong? get queueRow =>
      currentIndex == null || currentIndex! >= queue.length
      ? null
      : queue[currentIndex!];

  /// Whether [song] is the one playing. Either the exact source item matches,
  /// or their canonical identities match (same song across different sources).
  bool isCurrentSong(LibrarySong song) {
    final now = current;
    if (now == null) return false;
    if (now.sourceId == song.sourceId && now.id == song.id) return true;
    return TrackIdentity.of(now).matches(TrackIdentity.of(song));
  }

  bool get hasNext =>
      queue.isNotEmpty && (currentIndex ?? -1) < queue.length - 1;

  bool get hasPrevious =>
      (currentIndex ?? 0) > 0 || repeatMode == PlaybackRepeatMode.all;

  PlaybackState copyWith({
    List<LibrarySong>? queue,
    int? currentIndex,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    bool? shuffle,
    PlaybackRepeatMode? repeatMode,
    double? volume,
    bool? volumeIsSystemControlled,
    List<LibrarySong>? stationTracks,
    int? stationIndex,
    bool clearIndex = false,
  }) => PlaybackState(
    queue: queue ?? this.queue,
    currentIndex: clearIndex ? null : currentIndex ?? this.currentIndex,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    shuffle: shuffle ?? this.shuffle,
    repeatMode: repeatMode ?? this.repeatMode,
    volume: volume ?? this.volume,
    volumeIsSystemControlled:
        volumeIsSystemControlled ?? this.volumeIsSystemControlled,
    stationTracks: stationTracks ?? this.stationTracks,
    stationIndex: stationIndex ?? this.stationIndex,
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
  Playback([Player? player]) : _injectedPlayer = player;

  final Player? _injectedPlayer;
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
  LibraryCatalog? _catalog;
  PlaybackState _lastState = const PlaybackState();

  AudioSession? _audioSession;
  StreamSubscription<dynamic>? _interruptionSub;
  StreamSubscription<dynamic>? _noisySub;
  bool _playInterrupted = false;
  bool _disposed = false;

  @override
  set state(PlaybackState value) {
    _lastState = value;
    super.state = value;
  }

  Duration _lastSavedPosition = Duration.zero;
  bool _hasOpenedCurrent = false;
  bool _isFetchingInfinite = false;

  /// Set while the current track is played by the platform's own player
  /// (Apple Music). The media-kit player is idle then, and every transport
  /// call has to go to [_apple] instead.
  bool _appleMode = false;

  /// Lazily built: a device that never opens an Apple Music library never
  /// touches the plugin.
  ApplePlayer? _apple;

  /// Whether the platform player's end-of-track was already acted on, so a
  /// second position tick past the duration does not fire the next track again.
  bool _appleCompleted = false;

  @override
  PlaybackState build() {
    _player = _injectedPlayer ?? Player();
    _catalog = ref.read(libraryCatalogProvider);
    _tracker = PlayTracker(_catalog);

    // Hand the transport over before any subscription fires: a media button
    // that arrived while the app was starting has been waiting for one.
    _session = ref.read(audioHandlerProvider);
    _session?.transport = this;

    _subscriptions.addAll([
      // The platform player owns the transport while it is playing, so
      // media-kit's streams are only meaningful when it is the one playing.
      _player.stream.playing.listen((playing) {
        if (_appleMode) return;
        state = state.copyWith(playing: playing);
        _publish();
      }),
      _player.stream.buffering.listen((buffering) {
        if (_appleMode) return;
        state = state.copyWith(buffering: buffering);
        _publish();
      }),
      _player.stream.position.listen(_onPosition),
      _player.stream.duration.listen((duration) {
        if (_appleMode) return;
        state = state.copyWith(duration: duration);
        _publish();
      }),
      _player.stream.completed.listen((completed) {
        if (_appleMode) return;
        if (completed) _onTrackCompleted();
      }),
      _player.stream.volume.listen((volume) {
        if (_appleMode) return;
        state = state.copyWith(volume: volume);
      }),
    ]);

    _initAudioSession();

    ref.onDispose(() {
      _disposed = true;
      for (final subscription in _subscriptions) {
        subscription.cancel();
      }
      _interruptionSub?.cancel();
      _noisySub?.cancel();
      _apple?.dispose();
      _saveSession();
      // Whatever the play reached is written before the database goes away,
      // so closing the window mid-track still leaves an honest row.
      _tracker.flush();
      if (identical(_session?.transport, this)) _session!.transport = null;
      _player.dispose();
    });

    _restoreSession();

    return const PlaybackState();
  }

  /// One position update, whichever player produced it: the state, the play
  /// history and the saved session all follow the same rules.
  /// Whether the system player has another entry to move to by itself: the
  /// run it was given was not cut short by the end of the queue.
  bool get _appleHasNext {
    final apple = _apple;
    if (apple == null || !apple.isLoaded) return false;
    final index = state.currentIndex;
    if (index == null) return false;
    final base = apple.base;
    final played = index - base;
    return base + played < state.queue.length - 1;
  }

  void _onPosition(Duration position) {
    state = state.copyWith(position: position);
    // The system player has no "completed" event the plugin forwards, so the
    // end of the last *reachable* track is read off the clock: one trigger per
    // track, only when a real duration is known, and never while the system
    // has another entry to advance to on its own.
    if (_appleMode && state.duration > Duration.zero && !_appleHasNext) {
      if (position >= state.duration - const Duration(milliseconds: 300)) {
        if (!_appleCompleted) {
          _appleCompleted = true;
          unawaited(_onTrackCompleted());
        }
      } else if (_appleCompleted &&
          position < state.duration - const Duration(seconds: 1)) {
        // A restart or a seek back past the end re-arms the trigger, so a
        // repeating track completes again instead of silently running on.
        _appleCompleted = false;
      }
    }
    // Fire and forget: history is written at its own pace, and playback must
    // never wait on a transaction.
    _tracker.observe(position, duration: state.duration);
    if ((position - _lastSavedPosition).abs() >= const Duration(seconds: 5)) {
      _lastSavedPosition = position;
      _saveSession();
    }
  }

  Future<void> _initAudioSession() async {
    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS)) {
      return;
    }
    try {
      final session = await AudioSession.instance;
      if (_disposed) return;
      _audioSession = session;
      await session.configure(const AudioSessionConfiguration.music());

      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(state.volume * 0.5);
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (state.playing) {
                _playInterrupted = true;
                pause();
              }
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(state.volume);
            case AudioInterruptionType.pause:
              if (_playInterrupted) {
                _playInterrupted = false;
                play();
              }
            case AudioInterruptionType.unknown:
              _playInterrupted = false;
          }
        }
      });

      _noisySub = session.becomingNoisyEventStream.listen((_) {
        pause();
      });
    } catch (e) {
      debugPrint('[Playback] AudioSession initialization error: $e');
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('[Playback] Notification permission check error: $e');
    }
  }

  Future<void> _activateAudioSession() async {
    if (_audioSession != null) {
      try {
        await _audioSession!.setActive(true);
      } catch (e) {
        debugPrint('[Playback] AudioSession activation error: $e');
      }
    }
  }

  /// Replaces the queue with [songs] and starts at [startIndex].
  Future<void> playQueue(List<LibrarySong> songs, {int startIndex = 0}) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;

    unawaited(_ensureNotificationPermission());
    if (!_appleMode && !songs[startIndex].isRadio) {
      await _activateAudioSession();
    }

    _order = List.of(songs);
    _sourceOrder = List.of(songs);
    _hasOpenedCurrent = true;
    state = state.copyWith(
      queue: _order,
      currentIndex: startIndex,
      duration: _order[startIndex].duration,
      position: Duration.zero,
    );

    await _openCurrent();
    _publish();
    _saveSession();
  }

  @override
  Future<void> play() async {
    unawaited(_ensureNotificationPermission());
    // The system player runs its own audio session; activating the app's on
    // top of it is the duplicate session that made Apple playback fight
    // itself. Everything streamed still needs it.
    if (!_appleMode) await _activateAudioSession();

    if (_appleMode) {
      final apple = _apple;
      if (!_hasOpenedCurrent && state.current != null) {
        final resumePosition = state.position;
        await _openCurrent();
        if (resumePosition > Duration.zero) await apple?.seek(resumePosition);
      } else {
        await apple?.play();
      }
      _publish();
      _saveSession();
      return;
    }

    if (!_hasOpenedCurrent && state.current != null) {
      final resumePosition = state.position;
      await _openCurrent();
      if (resumePosition > Duration.zero) {
        await _player.seek(resumePosition);
      }
    } else {
      await _player.play();
    }
    _publish();
    _saveSession();
  }

  @override
  Future<void> pause() async {
    if (_appleMode) {
      await _apple?.pause();
      state = state.copyWith(playing: false);
    } else {
      await _player.pause();
    }
    _publish();
    _saveSession();
  }

  Future<void> togglePlayPause() => state.playing ? pause() : play();

  @override
  Future<void> seek(Duration position) async {
    if (!_hasOpenedCurrent && state.current != null) {
      state = state.copyWith(position: position);
      _publish();
      _saveSession();
      return;
    }
    if (_appleMode) {
      await _apple?.seek(position);
    } else {
      await _player.seek(position);
    }
    _publish();
    _saveSession();
  }

  @override
  Future<void> next() async {
    // A station is an endless run the platform player generates: "next" there
    // means the next track *of the station*, never the next row of the app's
    // queue, which is what starting a station put behind it.
    if (state.queueRow?.isRadio ?? false) {
      await _apple?.skipNext();
      return;
    }
    if (!state.hasNext) {
      if (state.repeatMode == PlaybackRepeatMode.all &&
          state.queue.isNotEmpty) {
        await _jumpTo(0);
        _publish();
      } else if (state.repeatMode == PlaybackRepeatMode.off &&
          ref.read(infinitePlaybackEnabledProvider)) {
        final appended = await _appendInfiniteTracks();
        if (appended) {
          await _jumpTo((state.currentIndex ?? 0) + 1);
          _publish();
        }
      }
      return;
    }
    await _jumpTo((state.currentIndex ?? 0) + 1);
    _publish();
  }

  @override
  Future<void> previous() async {
    if (state.queueRow?.isRadio ?? false) {
      // Ten seconds in it restarts the station's current track, the same rule
      // the shared player follows.
      if (state.position > const Duration(seconds: 10)) {
        await _apple?.seek(Duration.zero);
      } else {
        await _apple?.skipPrevious();
      }
      return;
    }
    // Ten seconds in, "previous" means restart the track — the behaviour every
    // player shares — rather than jump back a row.
    if (state.position > const Duration(seconds: 10) || !state.hasPrevious) {
      if (_appleMode) {
        await _apple?.seek(Duration.zero);
      } else {
        await _player.seek(Duration.zero);
      }
      _publish();
      _saveSession();
      return;
    }
    final target = (state.currentIndex ?? 0) - 1;
    await _jumpTo(target < 0 ? state.queue.length - 1 : target);
    _publish();
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    final current = state.queueRow;
    if (current == null || shuffle == state.shuffle) {
      state = state.copyWith(shuffle: shuffle);
      _publish();
      _saveSession();
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
    _saveSession();
  }

  Future<void> cycleRepeatMode() async {
    final next = nextRepeatMode(state.repeatMode);
    state = state.copyWith(repeatMode: next);
    if (!_appleMode) {
      await _player.setPlaylistMode(switch (next) {
        PlaybackRepeatMode.off => PlaylistMode.none,
        PlaybackRepeatMode.all => PlaylistMode.loop,
        PlaybackRepeatMode.single => PlaylistMode.single,
      });
    }
    _publish();
    _saveSession();
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
      if (!_appleMode) {
        await _player.setPlaylistMode(switch (target) {
          PlaybackRepeatMode.off => PlaylistMode.none,
          PlaybackRepeatMode.all => PlaylistMode.loop,
          PlaybackRepeatMode.single => PlaylistMode.single,
        });
      }
    }
    _publish();
    _saveSession();
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

  /// Sets the app's own output level.
  ///
  /// The state follows the slider either way, so the control never snaps back
  /// under the user's finger; only a streamed track is actually attenuated.
  /// MusicKit exposes no volume — the system player's level belongs to the
  /// OS, and there is no API to reach it from here.
  Future<void> setVolume(double volume) async {
    state = state.copyWith(
      volume: volume,
      volumeIsSystemControlled: _appleMode,
    );
    if (_appleMode) return;
    await _player.setVolume(volume);
  }

  /// Plays another library's copy of the song that is already playing.
  ///
  /// The queue keeps its shape: the same slot is rewritten to point at the
  /// other source, so "next" and "previous" still mean what they meant and the
  /// history reads as one continuous listen. The position is carried over —
  /// two copies of one recording differ by a second at most — so switching
  /// mid-track does not start over.
  ///
  /// A copy of something *else* is not a switch: only a song whose canonical
  /// identity matches ([TrackIdentity.matches]) is accepted, so a lookup
  /// cannot quietly replace the track with a different one.
  Future<void> switchVersion(LibrarySong copy) async {
    final row = state.queueRow;
    final index = state.currentIndex;
    if (row == null || index == null) return;
    if (row.sourceId == copy.sourceId && row.id == copy.id) return;
    if (row.isRadio) return;
    if (!TrackIdentity.of(row).matches(TrackIdentity.of(copy))) return;

    final position = state.position;
    final wasPlaying = state.playing;
    final queue = List.of(state.queue);
    queue[index] = copy;
    _order[index] = copy;
    state = state.copyWith(
      queue: queue,
      duration: copy.duration == Duration.zero ? state.duration : copy.duration,
      position: position,
    );
    _hasOpenedCurrent = false;
    // Not awaited: opening is a network read of the other library's stream,
    // and the sheet closes as soon as the choice is made.
    unawaited(_openAndRestore(position: position, playing: wasPlaying));
  }

  /// Opens the row at the current index and lands it where it should be:
  /// a switched copy resumes at [position], and stays paused when the track
  /// it replaced was paused.
  Future<void> _openAndRestore({
    required Duration position,
    required bool playing,
  }) async {
    await _openCurrent();
    if (position > Duration.zero) {
      await seek(position);
    }
    if (!playing) await pause();
    _publish();
    _saveSession();
  }

  /// Opens the song at the current index through its library's stream
  /// endpoint, falling back to alternate sources that host the same canonical
  /// track if the primary source is missing or offline.
  Future<void> _openCurrent() async {
    final song = state.queueRow;
    if (song == null) return;
    _hasOpenedCurrent = true;
    _appleCompleted = false;
    // The play is recorded before the stream opens, so a source that has been
    // removed still leaves the row that says the user tried to play it. A
    // station is not a track — it has no length and no title of its own, and
    // the row that matters is the one the platform player reports for the
    // track it generates — so it opens no play of its own.
    if (!song.isRadio) await _tracker.start(song);
    final sources = ref.read(librarySourceByIdProvider);
    var source = sources[song.sourceId];
    var toPlay = song;

    // Whatever plays next, the platform player must not keep sounding under
    // a track the app thinks it started. This runs before the source lookup
    // can bail out, because a song whose source is gone still ends Apple's
    // playback.
    if (_appleMode) {
      _appleMode = false;
      state = state.copyWith(volumeIsSystemControlled: false);
      unawaited(_apple?.stop());
    }

    if (source == null) {
      final catalog = ref.read(libraryCatalogProvider);
      if (catalog != null) {
        final links = await catalog.linksOfSong(song);
        for (final link in links) {
          final altSource = sources[link.sourceId];
          if (altSource != null) {
            source = altSource;
            toPlay = LibrarySong(
              sourceId: link.sourceId,
              id: link.externalId,
              title: song.title,
              artist: song.artist,
              album: song.album,
              albumId: link.albumExternalId,
              artistId: link.artistExternalId,
              artId: link.artId,
              duration: song.duration,
              track: song.track,
              discNumber: song.discNumber,
              year: song.year,
              genre: song.genre,
              mbid: song.mbid,
            );
            break;
          }
        }
      }
    }

    if (source == null) return;

    // A source whose items the platform plays is not opened as a URL: the
    // item is handed to the system's own player, which brings its playback
    // time and its pause/interrupt handling with it.
    if (source is PlatformPlayedSource) {
      // The mirror of the hand-over above: a streamed track that is already
      // sounding must be stopped, or media-kit keeps playing under the system
      // player and two tracks are audible at once.
      if (!_appleMode) {
        await _player.stop();
        _hasOpenedCurrent = true;
      }
      _appleMode = true;
      state = state.copyWith(volumeIsSystemControlled: true);
      _apple ??= ApplePlayer(
        ref.read(musicKitClientProvider),
        onStatus: (status) {
          switch (status) {
            case ApplePlayerStatus.playing:
              state = state.copyWith(playing: true);
            case ApplePlayerStatus.paused:
            case ApplePlayerStatus.interrupted:
              state = state.copyWith(playing: false);
            case ApplePlayerStatus.stopped:
              state = state.copyWith(playing: false, buffering: false);
            case ApplePlayerStatus.seeking:
              state = state.copyWith(buffering: true);
          }
          _publish();
        },
        onPosition: _onPosition,
        onAdvance: _onAppleAdvance,
        onTrack: _onAppleTrack,
        onQueue: _onAppleQueue,
        // The source that owns the item spells it for the platform player;
        // the bridge never learns which kind it is.
        sourceFor: (song) =>
            ref.read(librarySourceByIdProvider)[song.sourceId]
                as PlatformPlayedSource?,
      );
      try {
        // The system player is handed everything from here on, so a track
        // ending advances *it* instead of leaving it stopped at a queue of
        // one. The app follows the index it reports.
        final index = state.currentIndex ?? 0;
        if (identical(state.queue[index], toPlay)) {
          await _apple!.open(state.queue, index);
        } else {
          await _apple!.open([toPlay], 0);
        }
      } catch (error) {
        logAppleFailure(error);
      }
      return;
    }

    try {
      await _player.open(Media(source.streamUri(toPlay).toString()));
    } catch (_) {
      final catalog = ref.read(libraryCatalogProvider);
      if (catalog != null) {
        final links = await catalog.linksOfSong(song);
        for (final link in links) {
          if (link.sourceId == toPlay.sourceId &&
              link.externalId == toPlay.id) {
            continue;
          }
          final altSource = sources[link.sourceId];
          if (altSource != null) {
            final fallbackSong = LibrarySong(
              sourceId: link.sourceId,
              id: link.externalId,
              title: song.title,
              artist: song.artist,
              album: song.album,
              albumId: link.albumExternalId,
              artistId: link.artistExternalId,
              artId: link.artId,
              duration: song.duration,
              track: song.track,
              discNumber: song.discNumber,
              year: song.year,
              genre: song.genre,
              mbid: song.mbid,
            );
            try {
              await _player.open(
                Media(altSource.streamUri(fallbackSong).toString()),
              );
              return;
            } catch (_) {
              // Try next link
            }
          }
        }
      }
    }
  }

  Future<void> _jumpTo(int index) async {
    state = state.copyWith(
      currentIndex: index,
      position: Duration.zero,
      duration: _order[index].duration,
    );
    await _openCurrent();
    _saveSession();
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
        buffering: state.buffering,
        position: state.position,
        repeatMode: switch (state.repeatMode) {
          PlaybackRepeatMode.off => AudioServiceRepeatMode.none,
          PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
          PlaybackRepeatMode.single => AudioServiceRepeatMode.one,
        },
        shuffle: state.shuffle,
        // The system player publishes its own now-playing entry; sending ours
        // as well is the duplicate the user sees in the system's media panel.
        platformOwned: _appleMode,
      ),
    );
  }

  /// The system player moved to another entry of the run it was given: a
  /// track ended and it advanced on its own.
  ///
  /// The app's queue is the same run, so this is the app following along.
  /// The play history is closed and restarted here rather than through
  /// [next], which would push the queue again and start the track twice.
  Future<void> _onAppleAdvance(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    if (index == state.currentIndex) return;
    // Inside a station the system advances through its *own* run, which the
    // app's queue knows nothing about: `_onAppleTrack` records those plays.
    if (state.queueRow?.isRadio ?? false) return;
    if (_appleCompleted) return;
    _appleCompleted = true;
    _tracker.finish();
    state = state.copyWith(
      currentIndex: index,
      position: Duration.zero,
      duration: state.queue[index].duration,
    );
    await _tracker.start(state.queue[index]);
    _appleCompleted = false;
    _publish();
    _saveSession();
  }

  /// The system player named the track it is on.
  ///
  /// For a streamed track that is the song the app already loaded. For a
  /// station it is news: the station generates its own run, so this is the
  /// first and only description of what is actually playing, and the queue
  /// row is rewritten to carry it.
  void _onAppleTrack(AppleQueueEntry entry) {
    final index = state.currentIndex;
    if (index == null || index >= state.queue.length) return;
    final station = state.queue[index];
    if (!station.isRadio) return;
    if (!entry.isTrack) return;
    final title = entry.title;
    if (title == null) return;
    if (station.radioTrack?.id == entry.id &&
        station.radioTrack?.title == title) {
      return;
    }

    final track = LibrarySong(
      sourceId: station.sourceId,
      id: entry.id!,
      title: title,
      artist: entry.artist,
      album: entry.album,
      artId: entry.artTemplate,
      catalogId: entry.catalogId,
      duration: entry.duration,
    );
    // A station's track is the thing that played, so the history row is for
    // the track: the station row has no length and no title worth counting.
    // Closing first keeps the previous track's play honest.
    unawaited(_tracker.finish().then((_) => _tracker.start(track)));
    // The player reports a `musicKit://` handle for a station's track, which
    // nothing but the system player can load; the source turns the catalog id
    // into a real cover. Resolved off the position tick, then folded in, so a
    // cover that takes a moment is not a cover that never arrives.
    unawaited(_resolveStationArt(station.sourceId, track));
    final queue = List.of(state.queue);
    queue[index] = LibrarySong(
      sourceId: station.sourceId,
      id: station.id,
      title: station.title,
      duration: Duration.zero,
      artId: station.artId,
      isRadio: true,
      radioUrl: station.radioUrl,
      radioPlayParams: station.radioPlayParams,
      radioTrack: track,
    );
    state = state.copyWith(
      queue: queue,
      duration: entry.duration,
      position: state.position,
    );
    _publish();
  }

  /// The platform player reported the run it holds.
  ///
  /// Only a station uses this: its tracks are generated, so the app cannot
  /// know what is coming without being told. The entries are shaped into the
  /// app's own song model so the queue panel draws them like any other row.
  void _onAppleQueue(AppleQueue queue) {
    final row = state.queueRow;
    if (row == null || !row.isRadio) {
      if (state.stationTracks.isNotEmpty) {
        state = state.copyWith(stationTracks: const [], stationIndex: -1);
      }
      return;
    }
    final tracks = [
      for (final entry in queue.entries)
        if (entry.isTrack)
          LibrarySong(
            sourceId: row.sourceId,
            id: entry.id!,
            title: entry.title!,
            artist: entry.artist,
            album: entry.album,
            artId: entry.artTemplate,
            catalogId: entry.catalogId,
            duration: entry.duration,
          ),
    ];
    if (tracks.isEmpty) return;
    state = state.copyWith(
      stationTracks: tracks,
      stationIndex: queue.currentIndex,
    );
    _publish();
    // The run reports `musicKit://` handles, so none of these rows has a
    // cover yet: the list is drawn from what the store says about each.
    unawaited(_resolveStationArtFor(row.sourceId, tracks));
  }

  /// Resolves covers for a station's whole run, a few at a time.
  ///
  /// One catalog read per track, so this walks them in order and folds each
  /// cover in as it arrives rather than waiting for the last one: the list is
  /// readable immediately and fills in behind the eye.
  Future<void> _resolveStationArtFor(
    String sourceId,
    List<LibrarySong> tracks,
  ) async {
    final source = ref.read(librarySourceByIdProvider)[sourceId];
    if (source is! PlatformPlayedSource) return;

    for (final track in tracks) {
      final art = await source.artworkTemplate(track);
      if (art == null) continue;
      if (!ref.mounted) return;
      final row = state.queueRow;
      if (row == null || !row.isRadio) return;
      final index = state.stationTracks.indexWhere(
        (candidate) => candidate.id == track.id,
      );
      if (index < 0) return;
      if (state.stationTracks[index].artId == art) continue;

      final next = List.of(state.stationTracks);
      next[index] = LibrarySong(
        sourceId: track.sourceId,
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        artId: art,
        catalogId: track.catalogId,
        duration: track.duration,
      );
      state = state.copyWith(stationTracks: next);
      _publish();
    }
  }

  /// Fills in a station track's cover once the source has resolved one.
  Future<void> _resolveStationArt(String sourceId, LibrarySong track) async {
    final source = ref.read(librarySourceByIdProvider)[sourceId];
    if (source is! PlatformPlayedSource) return;
    final art = await source.artworkTemplate(track);
    if (art == null || art == track.artId) return;

    final index = state.currentIndex;
    if (index == null || index >= state.queue.length) return;
    final row = state.queue[index];
    final current = row.radioTrack;
    // The station may have moved on while the cover was being fetched.
    if (current == null || current.id != track.id) return;

    final queue = List.of(state.queue);
    queue[index] = LibrarySong(
      sourceId: row.sourceId,
      id: row.id,
      title: row.title,
      duration: Duration.zero,
      artId: row.artId,
      isRadio: true,
      radioUrl: row.radioUrl,
      radioPlayParams: row.radioPlayParams,
      radioTrack: LibrarySong(
        sourceId: current.sourceId,
        id: current.id,
        title: current.title,
        artist: current.artist,
        album: current.album,
        artId: art,
        catalogId: current.catalogId,
        duration: current.duration,
      ),
    );
    state = state.copyWith(queue: queue);
    _publish();
  }

  Future<void> _onTrackCompleted() async {
    // Written before the repeat branch, which may start the track over and
    // reset the play this row describes.
    await _tracker.finish();
    switch (state.repeatMode) {
      case PlaybackRepeatMode.single:
        // media-kit already honours single mode on its own; this keeps the
        // state honest for the UI when we drive the transport manually. The
        // platform player has no repeat of its own, so it is driven the same
        // way here.
        if (_appleMode) {
          await _apple?.seek(Duration.zero);
          await _apple?.play();
        } else {
          await _player.seek(Duration.zero);
          await _player.play();
        }
      case PlaybackRepeatMode.all:
        await next();
      case PlaybackRepeatMode.off:
        if (state.hasNext) {
          await next();
        } else {
          if (ref.read(infinitePlaybackEnabledProvider)) {
            final appended = await _appendInfiniteTracks();
            if (appended) {
              await next();
              return;
            }
          }
          state = state.copyWith(playing: false, position: Duration.zero);
          _publish();
          _saveSession();
        }
    }
  }

  Future<void> _restoreSession() async {
    final catalog = _catalog;
    if (catalog == null) return;
    try {
      final session = await catalog.loadPlaybackSession();
      if (session == null) return;
      if (state.queue.isNotEmpty) return;

      final decoded = jsonDecode(session.queueJson);
      if (decoded is! List) return;
      final songs = [
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            LibrarySong.fromJson(item)
          else if (item is Map)
            LibrarySong.fromJson(item.cast<String, dynamic>()),
      ];
      if (songs.isEmpty) return;

      final index =
          (session.currentIndex != null &&
              session.currentIndex! >= 0 &&
              session.currentIndex! < songs.length)
          ? session.currentIndex!
          : 0;

      final repeat = switch (session.repeatMode) {
        'all' => PlaybackRepeatMode.all,
        'single' => PlaybackRepeatMode.single,
        _ => PlaybackRepeatMode.off,
      };

      _order = List.of(songs);
      _sourceOrder = List.of(songs);
      _hasOpenedCurrent = false;

      final restoredPosition = Duration(milliseconds: session.positionMs);
      final restoredDuration = Duration(milliseconds: session.durationMs);
      final songDuration = songs[index].duration;
      final duration = restoredDuration > Duration.zero
          ? restoredDuration
          : songDuration;

      state = state.copyWith(
        queue: _order,
        currentIndex: index,
        position: restoredPosition,
        duration: duration,
        shuffle: session.shuffle,
        repeatMode: repeat,
        playing: false,
      );
      _publish();
    } catch (_) {
      // Corrupted or unreadable session data: start empty
    }
  }

  void _saveSession() {
    final catalog = _catalog;
    final current = _lastState;
    if (catalog == null || current.queue.isEmpty) return;
    try {
      final queueJson = jsonEncode([
        for (final song in current.queue) song.toJson(),
      ]);
      catalog.savePlaybackSession(
        queueJson: queueJson,
        currentIndex: current.currentIndex,
        positionMs: current.position.inMilliseconds,
        durationMs: current.duration.inMilliseconds,
        shuffle: current.shuffle,
        repeatMode: current.repeatMode.name,
      );
    } catch (_) {
      // Session saving must never disrupt playback
    }
  }

  Future<bool> _appendInfiniteTracks() async {
    if (_isFetchingInfinite) return false;
    _isFetchingInfinite = true;
    try {
      final aggregator = ref.read(libraryAggregatorProvider);
      List<LibrarySong> songs = [];
      try {
        songs = await aggregator.randomSongs(size: 30);
      } catch (_) {
        // Network or source failure: try local database fallback
      }
      if (songs.isEmpty) {
        final catalog = _catalog;
        if (catalog != null) {
          songs = await catalog.randomTracks(limit: 30);
        }
      }
      if (songs.isEmpty) return false;

      final existingKeys = {
        for (final song in state.queue) '${song.sourceId}:${song.id}',
      };
      final candidates = songs
          .where((s) => !existingKeys.contains('${s.sourceId}:${s.id}'))
          .toList();
      final toAdd = candidates.isNotEmpty ? candidates : songs;
      if (toAdd.isEmpty) return false;

      _order = [..._order, ...toAdd];
      _sourceOrder = [..._sourceOrder, ...toAdd];
      state = state.copyWith(queue: _order);
      _saveSession();
      return true;
    } catch (_) {
      return false;
    } finally {
      _isFetchingInfinite = false;
    }
  }
}
