/// Where a song's lyrics come from, and in what order.
///
/// The library is asked first — it is the server the user already pays for and
/// its lyrics are usually the ones that line up with the master it streams —
/// but only the cache and LRCLIB can turn a timed lyric into a *better* timed
/// lyric, so the preferences are:
///
///   1. a stored answer, whatever its origin;
///   2. the library's own lyrics, if it produced timed lines;
///   3. LRCLIB, whose records are vetted and usually timed;
///   4. the library's plain block, when LRCLIB had nothing.
///
/// Every answer is written to [LyricsCache], including "nobody has it", so a
/// replay never walks the network again. Nothing here throws: a lyrics pane
/// with no words is a normal state, and a dead server must not turn it into an
/// error card.
library;

import 'lrclib.dart';
import 'lyrics.dart';
import 'lyrics_store.dart';
import 'source.dart';

/// Resolves one song's lyrics through the cache and then the network.
class LyricsResolver {
  LyricsResolver({
    required this.cache,
    required this.lrclib,
    this.sourceFor,
  });

  final LyricsCache? cache;
  final Lrclib lrclib;
  final LibrarySource? Function(String sourceId)? sourceFor;

  /// The library's answer, or null when it has none or cannot be reached.
  Future<Lyrics?> _fromLibrary(LyricsRequest song) async {
    final source = sourceFor?.call(song.sourceId);
    if (source == null) return null;
    try {
      final lyrics = await source.lyrics(song.stub);
      return lyrics.isEmpty ? null : lyrics;
    } catch (_) {
      return null;
    }
  }

  /// The song's lyrics, never failing and never returning null.
  ///
  /// [refresh] skips the cache for this call: the user asked for the lyrics
  /// again because the ones on screen are wrong.
  Future<Lyrics> resolve(LyricsRequest song, {bool refresh = false}) async {
    if (!refresh) {
      final stored = await cache?.read(song.sourceId, song.id);
      if (stored != null) return stored.lyrics;
    }

    final library = await _fromLibrary(song);
    if (library != null && library.synced) {
      await cache?.write(
        song.sourceId,
        song.id,
        library,
        origin: LyricsOrigin.library,
      );
      return library;
    }

    final found = await lrclib.find(song);
    final remote = found.result?.lyrics;
    if (remote != null) {
      // A plain block from the library is still a lyric worth keeping; LRCLIB
      // only wins because its version is timed.
      final useRemote = remote.synced || library == null;
      final lyrics = useRemote ? remote : library;
      await cache?.write(
        song.sourceId,
        song.id,
        lyrics,
        origin: useRemote ? LyricsOrigin.lrclib : LyricsOrigin.library,
      );
      return lyrics;
    }

    if (library != null) {
      await cache?.write(
        song.sourceId,
        song.id,
        library,
        origin: LyricsOrigin.library,
      );
      return library;
    }

    // Only a miss the service confirmed is worth remembering; an offline
    // answer must be asked again on the next play.
    if (found.settled) {
      await cache?.write(
        song.sourceId,
        song.id,
        Lyrics.empty,
        origin: LyricsOrigin.none,
      );
    }
    return Lyrics.empty;
  }

  /// Forgets one song so the next play asks the network again.
  Future<void> forget(LyricsRequest song) async =>
      cache?.remove(song.sourceId, song.id);

  /// Forgets everything downloaded for the given source.
  Future<void> forgetSource(String sourceId) async =>
      cache?.removeSource(sourceId);
}
