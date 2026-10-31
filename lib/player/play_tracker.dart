/// Playback history: when a song was started, how far it got, whether it
/// reached the end.
///
/// Written by the transport, read by anything that wants "recently played" or
/// a play count. It deliberately knows nothing about media-kit: the transport
/// calls [start], [observe] and [finish], and this turns them into rows.
library;

import '../library/catalog.dart';
import '../library/models.dart';

/// Records the play of the track the transport has open.
///
/// One row per start, updated in place as the track plays, so a skip after ten
/// seconds leaves an honest row instead of a fake complete play. Nothing here
/// ever throws or delays playback: a machine whose local database refused to
/// open plays exactly as before, it just keeps no history.
class PlayTracker {
  PlayTracker(this._catalog);

  /// Null when the local library could not be opened.
  final LibraryCatalog? _catalog;

  /// How often a running play's row is rewritten. A position tick arrives
  /// about once a second; writing every one of them would be a transaction per
  /// second for a number nobody reads live.
  static const checkpoint = Duration(seconds: 10);

  int? _playId;

  /// Bumped on every [start], so a write that was still in flight when the
  /// track changed cannot land on the new track's row.
  int _generation = 0;

  Duration _reached = Duration.zero;
  Duration _lastCheckpoint = Duration.zero;
  Duration _duration = Duration.zero;
  bool _completed = false;

  /// Begins a play of [song]: adopts it, writes the opening row, and returns
  /// once the row exists. Safe to call before the stream is opened.
  Future<void> start(LibrarySong song) async {
    final catalog = _catalog;
    final generation = ++_generation;
    _playId = null;
    _reached = Duration.zero;
    _lastCheckpoint = Duration.zero;
    _completed = false;
    _duration = song.duration;
    if (catalog == null) return;

    try {
      final trackId = await catalog.trackIdOf(song);
      final playId = await catalog.recordPlay(
        trackId: trackId,
        sourceId: song.sourceId,
        startedAt: DateTime.now(),
      );
      if (generation != _generation) {
        // The track changed while this row was being written; the row is still
        // correct, it just describes a play that is no longer running, so it
        // is closed as it stands.
        return;
      }
      _playId = playId;
    } catch (_) {
      // History is a nicety; a database that refuses a write must not stop
      // the music.
    }
  }

  /// Notes how far the current track has played. Called from the position
  /// stream; only the furthest point reached counts, so seeking back and forth
  /// cannot inflate the total.
  Future<void> observe(Duration position, {Duration? duration}) async {
    if (duration != null && duration > Duration.zero) _duration = duration;
    if (position > _reached) _reached = position;
    if (_completed) return;
    if (_reached - _lastCheckpoint < checkpoint) return;
    _lastCheckpoint = _reached;
    await _write();
  }

  /// The track reached its end.
  Future<void> finish() async {
    _completed = true;
    await _write();
  }

  /// The transport is going away (app closing, notifier disposed). Writes what
  /// the play got to, then forgets it.
  Future<void> flush() async {
    await _write();
    _playId = null;
  }

  Future<void> _write() async {
    final catalog = _catalog;
    final playId = _playId;
    if (catalog == null || playId == null) return;
    final reached = _reached;
    // A play "completed" only when it reached the end; a track shorter than
    // the checkpoint can otherwise never look finished.
    final completed =
        _completed || (_duration > Duration.zero && reached >= _duration);
    try {
      await catalog.updatePlay(
        playId,
        listened: reached,
        position: reached,
        completed: completed,
      );
    } catch (_) {
      // Same reason as [start]: history must never break playback.
    }
  }
}
