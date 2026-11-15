import 'dart:async';

import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';

/// The mini window's read-only mirror of the main engine's transport.
///
/// It subclasses [Playback] only so it can be injected through
/// `playbackProvider.overrideWith` — every widget that renders playback reads
/// that one provider. [build] returns a plain snapshot instead of constructing
/// a media-kit `Player`, and each transport method forwards a command across
/// the link instead of touching libmpv. A dropped message leaves a stale panel
/// for a moment — the host's next tick corrects it — and is otherwise
/// invisible, which is why nothing here waits for a reply.
class MiniPlayback extends Playback {
  /// The link into the host engine, attached by the mini window's first frame.
  MiniPlayerLink? link;

  /// Test hook: records commands instead of crossing the engine boundary.
  Future<void> Function(String, [Object?])? send;

  /// Points the mirror at [link] and asks the host for the current state.
  ///
  /// The host publishes on change, so a window opening between two changes
  /// would otherwise sit empty until something moved. Asking once on attach is
  /// what makes opening the window itself enough to fill it.
  ///
  /// Retried until answered: the guest's engine boots before the host has
  /// registered its handler (the window is created first, then shown), and a
  /// single fire-and-forget ask that lost that race left the window blank
  /// until the next track change — the "it cannot read state when music was
  /// already playing" report.
  void attach(MiniPlayerLink link) {
    this.link = link;
    link.onSnapshot = applySnapshot;
    link.onTick = applyTick;
    _hasSnapshot = false;
    _askGeneration++;
    final generation = _askGeneration;
    var attempts = 0;
    Future<void> ask() async {
      while (generation == _askGeneration && !_hasSnapshot) {
        final answered = await link.command<bool>('requestSnapshot');
        if (answered != true) {
          // No host handler yet. Keep trying briefly; the window is shown as
          // soon as the engine boots, so this is a startup race, not an
          // outage.
          if (++attempts > 20) return;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        return;
      }
    }

    unawaited(ask());
  }

  /// Bumped by every [attach]; an older loop stops asking once it moves.
  int _askGeneration = 0;

  /// Whether the host has answered at least once.
  bool _hasSnapshot = false;

  /// Applies a full snapshot from the host.
  void applySnapshot(Map<String, dynamic> json) {
    _hasSnapshot = true;
    state = decodeSnapshot(json);
  }

  /// Applies a position tick from the host.
  void applyTick(Duration position, Duration duration, bool playing) {
    state = state.copyWith(
      position: position,
      duration: duration,
      playing: playing,
    );
  }

  Future<void> _dispatch(String method, [Object? arguments]) async {
    final override = send;
    if (override != null) {
      await override(method, arguments);
      return;
    }
    await link?.command<void>(method, arguments);
  }

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> play() => _dispatch('play');
  @override
  Future<void> pause() => _dispatch('pause');
  @override
  Future<void> togglePlayPause() => _dispatch('togglePlayPause');
  @override
  Future<void> next() => _dispatch('next');
  @override
  Future<void> previous() => _dispatch('previous');
  @override
  Future<void> seek(Duration position) =>
      _dispatch('seek', position.inMilliseconds);
  @override
  Future<void> setShuffle(bool shuffle) => _dispatch('setShuffle', shuffle);
  @override
  Future<void> cycleRepeatMode() => _dispatch('cycleRepeatMode');
  @override
  Future<void> skipToQueueIndex(int index) =>
      _dispatch('skipToQueueIndex', index);
  @override
  Future<void> setVolume(double volume) => _dispatch('setVolume', volume);

  @override
  Future<void> playQueue(List<LibrarySong> songs, {int startIndex = 0}) =>
      _dispatch('playQueue', {
        'songs': [for (final song in songs) song.toJson()],
        'startIndex': startIndex,
      });
}
