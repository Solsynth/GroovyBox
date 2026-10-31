/// The lyrics half of the local library: every answer any source gave, kept
/// on the track's own row.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/local/library_database.dart';
import 'lyrics.dart';

/// Where a stored lyric came from.
enum LyricsOrigin {
  /// The connected library answered it.
  library,

  /// Downloaded from LRCLIB.
  lrclib,

  /// Both asked, neither had it. Kept so a replay does not ask again.
  none,
}

/// One cached answer.
class CachedLyrics {
  final Lyrics lyrics;
  final LyricsOrigin origin;
  final DateTime fetchedAt;

  const CachedLyrics({
    required this.lyrics,
    required this.origin,
    required this.fetchedAt,
  });
}

/// The stored lyrics of each track, read and written through
/// [LibraryDatabase].
///
/// One row per track — not per `(source, id)` pair — because the track is what
/// the words belong to: re-tagged metadata, a re-linked server or a second
/// source serving the same song all read the same answer.
class LyricsStore {
  LyricsStore(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LibraryDatabase _db;

  /// Read through on every use so a test can move time without a rebuild.
  final DateTime Function() _clock;

  /// How long a "nobody has these lyrics" answer is trusted. LRCLIB's
  /// background fetcher picks up missing tracks over time, so a miss is not
  /// permanent; asking once a day keeps the cache from growing stale without
  /// re-asking on every play.
  static const missTtl = Duration(days: 1);

  /// The stored answer for [trackId], or null when there is none worth using.
  Future<CachedLyrics?> read(int trackId) async {
    final row = await (_db.select(
      _db.lyricsEntries,
    )..where((entry) => entry.trackId.equals(trackId))).getSingleOrNull();
    if (row == null) return null;

    final origin = LyricsOrigin.values.firstWhere(
      (value) => value.name == row.origin,
      orElse: () => LyricsOrigin.library,
    );

    // A miss is a hint, not a fact: expire it so a track LRCLIB gained later
    // still gets a chance on a future play.
    if (origin == LyricsOrigin.none &&
        _clock().difference(row.fetchedAt) > missTtl) {
      return null;
    }

    return CachedLyrics(
      lyrics: Lyrics(
        lines: _decodeLines(row.lines),
        synced: row.synced,
        language: row.language,
      ),
      origin: origin,
      fetchedAt: row.fetchedAt,
    );
  }

  /// Writes one answer, replacing any earlier one for the same track.
  Future<void> write(
    int trackId,
    Lyrics lyrics, {
    required LyricsOrigin origin,
    int? remoteId,
  }) => _db
      .into(_db.lyricsEntries)
      .insertOnConflictUpdate(
        LyricsEntriesCompanion.insert(
          trackId: Value(trackId),
          lines: _encodeLines(lyrics.lines),
          synced: lyrics.synced,
          language: Value(lyrics.language),
          origin: origin.name,
          remoteId: Value(remoteId),
          fetchedAt: _clock(),
        ),
      );

  /// Drops one track's answer, so the next play asks again.
  Future<void> remove(int trackId) => (_db.delete(
    _db.lyricsEntries,
  )..where((entry) => entry.trackId.equals(trackId))).go();

  /// How many tracks have an answer stored, for the settings row.
  Future<int> count() async =>
      (await _db.customSelect(
        'SELECT COUNT(*) AS n FROM lyrics_entries',
      ).getSingle())
          .read<int>('n');

  /// Empties the cache and vacuum-packs the file it left behind.
  Future<void> clear() async {
    await _db.delete(_db.lyricsEntries).go();
    await _db.customStatement('VACUUM');
  }

  /// Lines are stored as JSON rather than as LRC text: the library's structured
  /// response carries romanization and translation layers that LRC cannot
  /// express, and re-rendering them to text would throw those away.
  static String _encodeLines(List<LyricLine> lines) => jsonEncode([
    for (final line in lines)
      {
        'at': line.at.inMilliseconds,
        't': line.text,
        if (line.pronunciation != null) 'p': line.pronunciation,
        if (line.translation != null) 'x': line.translation,
      },
  ]);

  static List<LyricLine> _decodeLines(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map)
          LyricLine(
            Duration(milliseconds: (entry['at'] as num?)?.toInt() ?? 0),
            entry['t'] as String? ?? '',
            pronunciation: entry['p'] as String?,
            translation: entry['x'] as String?,
          ),
    ];
  }
}
