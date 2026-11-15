/// Looking a song's words up by title and artist, across a whole catalogue.
///
/// A [LibrarySource] answers `lyrics(song)` for a track it *holds*, which is
/// only useful for the songs that library already streams. This capability is
/// the other question — "does any service know this song's words?" — asked of
/// a service that indexes a catalogue far larger than any one account's
/// library. LRCLIB is the reference implementation; a connected account that
/// can answer the same question joins it without the resolver knowing which
/// is which.
library;

import 'lyrics.dart';
import 'lyrics_store.dart';

/// One song's lyrics, found by a service.
class LyricsHit {
  final Lyrics lyrics;

  /// Where these words came from, named by the service that answered, so a
  /// stored row can say which one it was without the resolver knowing the
  /// service's name.
  final LyricsOrigin origin;

  /// The service's own id for the record, for naming what a stored lyric came
  /// from. Null when the service does not number its rows.
  final int? id;

  const LyricsHit({required this.lyrics, required this.origin, this.id});
}

/// One lookup's outcome.
///
/// [settled] separates "the service says it has no such lyric" from "we could
/// not find out": a timeout or a rate limit must not be cached as an answer,
/// or a track the service does have would stay blank until the entry expired.
class LyricsLookup {
  final LyricsHit? result;
  final bool settled;

  const LyricsLookup({required this.result, required this.settled});

  static const unknown = LyricsLookup(result: null, settled: false);
  static const missing = LyricsLookup(result: null, settled: true);
}

/// One row of a manual search, as the lyrics picker shows it.
///
/// The words are already parsed, so picking a row is writing it, not asking
/// for it a second time.
class LyricsCandidate {
  final int? id;
  final String title;
  final String? artistName;
  final String? albumName;

  /// Where this row came from, so a picker that searches several services can
  /// say which one offered it.
  final LyricsOrigin origin;

  /// The row's own runtime, which may disagree with the playing track's.
  final Duration? duration;
  final Lyrics lyrics;

  const LyricsCandidate({
    required this.title,
    required this.lyrics,
    required this.origin,
    this.id,
    this.artistName,
    this.albumName,
    this.duration,
  });
}

/// A service that can find words for a song it does not necessarily hold.
abstract interface class LyricsQuerySource {
  /// Looks [song] up by title and artist.
  ///
  /// Never throws: a service that cannot be reached answers
  /// [LyricsLookup.unknown], which the resolver does not cache as a miss.
  Future<LyricsLookup> findLyrics(LyricsRequest song);

  /// Free-text search for the manual picker: what the service ranks for
  /// [query], each row with its words already parsed.
  ///
  /// Null when the answer could not be had — a rate limit or a dead network —
  /// so the picker can offer a retry instead of claiming there is nothing.
  Future<List<LyricsCandidate>?> searchLyrics(String query);
}
