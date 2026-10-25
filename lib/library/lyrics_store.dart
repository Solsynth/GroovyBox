/// Local lyrics cache.
///
/// Servers answer lyrics slowly, badly, or not at all, and LRCLIB is a shared
/// public service that asks clients not to repeat themselves. So every answer
/// — from the library or from LRCLIB — is written here once and read from
/// disk on every later play, including across restarts.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart'
    show
        ConflictAlgorithm,
        Database,
        DatabaseFactory,
        OpenDatabaseOptions,
        databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

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

/// The SQLite-backed lyrics cache.
///
/// One row per song identity — the same `sourceId`/`id` pair the library uses
/// — because a song's title, artist and album can be re-tagged on the server
/// without it becoming a different song.
class LyricsCache {
  LyricsCache._(this._db, this._clock);

  final Database _db;

  /// Read through on every use so a test can move time without a rebuild.
  final DateTime Function() _clock;

  /// How long a "nobody has these lyrics" answer is trusted. LRCLIB's
  /// background fetcher picks up missing tracks over time, so a miss is not
  /// permanent; asking once a day keeps the cache from growing stale without
  /// re-asking on every play.
  static const missTtl = Duration(days: 1);

  /// Opens (or creates) the database under the app's support directory.
  ///
  /// [factory] and [path] exist for tests, which run in a plain Dart VM with
  /// no Flutter plugin and use an in-memory database.
  static Future<LyricsCache> open({
    String? path,
    DatabaseFactory? factory,
    DateTime Function() clock = DateTime.now,
  }) async {
    final file = path ?? await _defaultPath();
    final db = await (factory ?? defaultLyricsFactory()).openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE lyrics (
            source TEXT NOT NULL,
            id TEXT NOT NULL,
            lines TEXT NOT NULL,
            synced INTEGER NOT NULL,
            language TEXT,
            origin TEXT NOT NULL,
            fetched_at INTEGER NOT NULL,
            PRIMARY KEY (source, id)
          )
        '''),
      ),
    );
    return LyricsCache._(db, clock);
  }

  /// Apple's platforms and Android ship SQLite through their own plugin;
  /// Linux and Windows have no such plugin, so the FFI build is used there.
  static DatabaseFactory defaultLyricsFactory() {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  static Future<String> _defaultPath() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return p.join(directory.path, 'lyrics.db');
  }

  /// The stored answer for one song, or null when there is none worth using.
  Future<CachedLyrics?> read(String sourceId, String id) async {
    final rows = await _db.query(
      'lyrics',
      where: 'source = ? AND id = ?',
      whereArgs: [sourceId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.single;
    final origin = LyricsOrigin.values.firstWhere(
      (value) => value.name == row['origin'],
      orElse: () => LyricsOrigin.library,
    );
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
      row['fetched_at']! as int,
    );

    // A miss is a hint, not a fact: expire it so a track LRCLIB gained later
    // still gets a chance on a future play.
    if (origin == LyricsOrigin.none && _clock().difference(fetchedAt) > missTtl) {
      return null;
    }

    return CachedLyrics(
      lyrics: Lyrics(
        lines: _decodeLines(row['lines']! as String),
        synced: row['synced'] == 1,
        language: row['language'] as String?,
      ),
      origin: origin,
      fetchedAt: fetchedAt,
    );
  }

  /// Writes one answer, replacing any earlier one for the same song.
  Future<void> write(
    String sourceId,
    String id,
    Lyrics lyrics, {
    required LyricsOrigin origin,
  }) async {
    await _db.insert('lyrics', {
      'source': sourceId,
      'id': id,
      'lines': _encodeLines(lyrics.lines),
      'synced': lyrics.synced ? 1 : 0,
      'language': lyrics.language,
      'origin': origin.name,
      'fetched_at': _clock().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Drops one song's answer, so the next play asks again.
  Future<void> remove(String sourceId, String id) => _db.delete(
    'lyrics',
    where: 'source = ? AND id = ?',
    whereArgs: [sourceId, id],
  );

  /// Drops every answer downloaded for one library, e.g. when it is removed.
  Future<void> removeSource(String sourceId) => _db.delete(
    'lyrics',
    where: 'source = ?',
    whereArgs: [sourceId],
  );

  /// How many songs have an answer stored, for the settings row.
  Future<int> count() async =>
      (await _db.rawQuery('SELECT COUNT(*) AS n FROM lyrics')).first['n']
          as int? ??
      0;

  /// Empties the cache and vacuum-packs the file it left behind.
  Future<void> clear() async {
    await _db.delete('lyrics');
    await _db.execute('VACUUM');
  }

  Future<void> close() => _db.close();

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
