/// The local library: what the app knows about songs, independently of the
/// server that happens to serve them.
///
/// Everything here is keyed by a canonical track — one row per song, whoever
/// streams it. A track's native id on a particular library lives in
/// [TrackLinks], so changing source (a different Jellyfin, a re-installed
/// server, eventually local files) re-links the same row instead of orphaning
/// its lyrics and its play history.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../library/models.dart';
import '../../library/track_identity.dart';

part 'library_database.g.dart';

/// One song, as this device knows it.
///
/// Metadata is whatever the last source that described it said. Columns are
/// nullable because a play can be recorded from a song the library's list
/// endpoint never returned — lyrics lookup carries only a title and artist.
@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// Optional MusicBrainz Recording ID or Track ID.
  TextColumn get mbid => text().nullable()();

  /// [trackFingerprint] at first sight. It is the key a second source is
  /// matched on, and it is deliberately not recomputed when metadata is
  /// re-tagged: the row's identity is what it was when it was first adopted.
  TextColumn get fingerprint => text().unique()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// The row a source just described, without its identity columns: those
/// belong to the track, not to the description.
extension TrackIdentityRow on TrackIdentity {
  TracksCompanion toCompanion(DateTime at) => TracksCompanion.insert(
    title: title,
    fingerprint: fingerprint,
    createdAt: at,
    updatedAt: at,
    artist: Value.absentIfNull(artist),
    albumArtist: Value.absentIfNull(albumArtist),
    album: Value.absentIfNull(album),
    genre: Value.absentIfNull(genre),
    year: Value.absentIfNull(year),
    trackNumber: Value.absentIfNull(trackNumber),
    discNumber: Value.absentIfNull(discNumber),
    durationMs: Value(duration.inMilliseconds),
    mbid: Value.absentIfNull(mbid),
  );
}

/// Where one track can be played from: a source id (the connected library's
/// id, which lives with its credentials in prefs) and that source's own id
/// for the item.
///
/// No foreign key to the source table, because there is none: connections and
/// their secrets stay in `SourceStore`, and this table must not become a
/// second place they can drift out of date. Removing a source deletes its
/// links; the canonical track, its lyrics and its history stay.
@DataClassName('TrackLinkRow')
@TableIndex(name: 'track_links_track', columns: {#trackId})
class TrackLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceId => text()();
  TextColumn get externalId => text()();
  TextColumn get albumExternalId => text().nullable()();
  TextColumn get artistExternalId => text().nullable()();
  TextColumn get artId => text().nullable()();
  DateTimeColumn get linkedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  /// A source id is only unique inside itself, so identity needs both halves.
  @override
  List<Set<Column>> get uniqueKeys => [
    {sourceId, externalId},
  ];
}

/// The stored answer for one track's lyrics, whatever asked for them.
///
/// One row per track: a better answer replaces the old one, and a confirmed
/// miss is a row too (origin `none`), so a replay does not walk the network
/// again. Lines are JSON because the library's structured response carries
/// romanization and translation layers that LRC cannot express.
@DataClassName('LyricsRow')
class LyricsEntries extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get lines => text()();
  BoolColumn get synced => boolean()();
  TextColumn get language => text().nullable()();
  TextColumn get origin => text()();
  IntColumn get remoteId => integer().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  /// The language the translation layer was generated in, or null when the
  /// lyrics carry no generated translation. Translations are cached *with*
  /// their target language so a row written for English is not served to a
  /// reader who has since switched to Chinese.
  TextColumn get translationLanguage => text().nullable()();

  @override
  Set<Column> get primaryKey => {trackId};
}

/// One play: when, from which source, how long, and whether it reached the
/// end. Play counts and "you have not played this in a while" are aggregate
/// queries over this table, so no counter column can fall out of step.
@DataClassName('PlayEventRow')
@TableIndex(name: 'play_events_track', columns: {#trackId})
@TableIndex(name: 'play_events_started', columns: {#startedAt})
class PlayEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceId => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get listenedMs => integer().withDefault(const Constant(0))();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

/// The last active playback session: the full queue in play order, the active
/// index, and the scrubber position.
///
/// Recovered on startup so relaunching the app leaves the user's queue and
/// dock ready right where they left off.
@DataClassName('PlaybackSessionRow')
class PlaybackSessions extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get queueJson => text()();
  IntColumn get currentIndex => integer().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  BoolColumn get shuffle => boolean().withDefault(const Constant(false))();
  TextColumn get repeatMode => text().withDefault(const Constant('off'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Everything the app remembers about songs, in one SQLite file.
///
/// [executor] exists for tests, which open `NativeDatabase.memory()` on a
/// plain Dart VM. The app passes nothing and gets the file under the app's
/// support directory (or IndexedDB on the web, with the wasm assets in `web/`).
@DriftDatabase(
  tables: [Tracks, TrackLinks, LyricsEntries, PlayEvents, PlaybackSessions],
)
class LibraryDatabase extends _$LibraryDatabase {
  LibraryDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Name of the file (`library.sqlite` on native) and of the IndexedDB
  /// database on the web.
  static const databaseName = 'library';

  /// The absolute path to the SQLite file on native platforms, or null if on web.
  static Future<String?> databaseFilePath() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return p.join(directory.path, '$databaseName.sqlite');
    } catch (_) {
      return null;
    }
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tracks, tracks.mbid);
      }
      if (from < 3) {
        await m.createTable(playbackSessions);
      }
      if (from < 4) {
        await m.addColumn(lyricsEntries, lyricsEntries.translationLanguage);
      }
    },
    beforeOpen: (details) async {
      // Links, lyrics and plays are owned by their track; deleting a track
      // must never leave rows pointing at nothing.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The support directory rather than documents: this is app state, not a
  /// file the user opens.
  static QueryExecutor _open() => driftDatabase(
    name: databaseName,
    native: DriftNativeOptions(
      databasePath: () async {
        final directory = await getApplicationSupportDirectory();
        await directory.create(recursive: true);
        return p.join(directory.path, '$databaseName.sqlite');
      },
    ),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );

  /// The track this source's item is already linked to, if any.
  Future<int?> trackIdForLink(String sourceId, String externalId) async {
    final row =
        await (select(trackLinks)..where(
              (link) =>
                  link.sourceId.equals(sourceId) &
                  link.externalId.equals(externalId),
            ))
            .getSingleOrNull();
    return row?.trackId;
  }

  /// Every link of one track, i.e. every source that can play it.
  Future<List<TrackLinkRow>> linksOf(int trackId) => (select(
    trackLinks,
  )..where((link) => link.trackId.equals(trackId))).get();

  /// Adopts one item seen on one source and returns the canonical track.
  ///
  /// Three cases, in order: the item is already linked (its metadata is
  /// refreshed), a track with the same [TrackIdentity.fingerprint] exists (it
  /// is linked, so a second source joins the same row), or a track is created.
  Future<int> resolveTrack(
    TrackIdentity identity, {
    required String sourceId,
    required String externalId,
    String? albumExternalId,
    String? artistExternalId,
    String? artId,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final companion = identity.toCompanion(at);
    return transaction(() async {
      final existing = await trackIdForLink(sourceId, externalId);
      if (existing != null) {
        await _updateTrack(existing, companion);
        await _touchLink(
          sourceId: sourceId,
          externalId: externalId,
          trackId: existing,
          albumExternalId: albumExternalId,
          artistExternalId: artistExternalId,
          artId: artId,
          at: at,
        );
        return existing;
      }

      final matched = await findMatchingTrack(identity);
      final trackId = matched?.id ?? await into(tracks).insert(companion);
      if (matched != null) await _updateTrack(matched.id, companion);

      await _touchLink(
        sourceId: sourceId,
        externalId: externalId,
        trackId: trackId,
        albumExternalId: albumExternalId,
        artistExternalId: artistExternalId,
        artId: artId,
        at: at,
      );
      return trackId;
    });
  }

  /// Metadata from the source that just described the track. Only fields the
  /// source actually has overwrite; a lyrics lookup's title-and-artist must
  /// not blank an album a full listing already supplied.
  Future<void> _updateTrack(int trackId, TracksCompanion companion) =>
      (update(tracks)..where((track) => track.id.equals(trackId))).write(
        companion.copyWith(
          id: const Value.absent(),
          fingerprint: const Value.absent(),
          createdAt: const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Links [trackId] to one source's item, or refreshes the link it already
  /// has. Identity columns are left alone on a conflict: an existing link owns
  /// them, and this call only has fresher metadata.
  Future<void> _touchLink({
    required String sourceId,
    required String externalId,
    required int trackId,
    required String? albumExternalId,
    required String? artistExternalId,
    required String? artId,
    required DateTime at,
  }) => into(trackLinks).insert(
    TrackLinksCompanion.insert(
      trackId: trackId,
      sourceId: sourceId,
      externalId: externalId,
      albumExternalId: Value.absentIfNull(albumExternalId),
      artistExternalId: Value.absentIfNull(artistExternalId),
      artId: Value.absentIfNull(artId),
      linkedAt: at,
      lastSeenAt: at,
    ),
    onConflict: DoUpdate(
      (old) => TrackLinksCompanion(
        lastSeenAt: Value(at),
        albumExternalId: Value.absentIfNull(albumExternalId),
        artistExternalId: Value.absentIfNull(artistExternalId),
        artId: Value.absentIfNull(artId),
      ),
      target: [trackLinks.sourceId, trackLinks.externalId],
    ),
  );

  /// Forgets that one source can serve anything, e.g. when it is removed.
  ///
  /// Tracks, their lyrics and their play history outlive the link: the same
  /// server re-added, or a different one, re-adopts them by fingerprint.
  Future<void> unlinkSource(String sourceId) =>
      (delete(trackLinks)..where((link) => link.sourceId.equals(sourceId))).go();

  /// Tracks that no source can reach any more. Not an error — a song that was
  /// only ever known through a removed server is still history worth keeping.
  Future<int> orphanCount() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM tracks '
      'WHERE id NOT IN (SELECT DISTINCT track_id FROM track_links)',
    ).getSingle();
    return row.read<int>('n');
  }

  Future<int> trackCount() async =>
      (await customSelect('SELECT COUNT(*) AS n FROM tracks').getSingle())
          .read<int>('n');

  /// When [trackId] was last played, or null if it never was.
  Future<DateTime?> lastPlayedAt(int trackId) async {
    final row =
        await (select(playEvents)
              ..where((event) => event.trackId.equals(trackId))
              ..orderBy([(event) => OrderingTerm.desc(event.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.startedAt;
  }

  Future<int> playCountOf(int trackId) async {
    final row =
        await customSelect(
          'SELECT COUNT(*) AS n FROM play_events WHERE track_id = ?',
          variables: [Variable.withInt(trackId)],
        ).getSingle();
    return row.read<int>('n');
  }

  /// Totals over every play this device has recorded.
  ///
  /// One row, four scalars: the stats page's headline numbers, which no
  /// per-track query can answer.
  Future<({int plays, int completed, Duration listened, int tracks})>
  playTotals() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS plays, '
      'COALESCE(SUM(completed), 0) AS completed, '
      'COALESCE(SUM(listened_ms), 0) AS listened, '
      'COUNT(DISTINCT track_id) AS tracks '
      'FROM play_events',
    ).getSingle();
    return (
      plays: row.read<int>('plays'),
      completed: row.read<int>('completed'),
      listened: Duration(milliseconds: row.read<int>('listened')),
      tracks: row.read<int>('tracks'),
    );
  }

  /// How often each track was played, most played first.
  ///
  /// Ties go to whichever played most recently, so a list of songs played
  /// once is also a list of what was played last.
  Future<List<({int trackId, int plays, Duration listened})>>
  playCountsByTrack({int limit = 10}) async {
    if (limit <= 0) return const [];
    final rows = await customSelect(
      'SELECT track_id, COUNT(*) AS plays, '
      'COALESCE(SUM(listened_ms), 0) AS listened '
      'FROM play_events GROUP BY track_id '
      'ORDER BY plays DESC, MAX(started_at) DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return [
      for (final row in rows)
        (
          trackId: row.read<int>('track_id'),
          plays: row.read<int>('plays'),
          listened: Duration(milliseconds: row.read<int>('listened')),
        ),
    ];
  }

  /// How often each artist was played, most played first.
  ///
  /// A play is attributed to the track's own artist column, so a song with no
  /// artist tag lands in one bucket rather than vanishing from the list.
  Future<List<({String name, int plays, Duration listened})>>
  playCountsByArtist({int limit = 10}) async {
    if (limit <= 0) return const [];
    final rows = await customSelect(
      "SELECT COALESCE(NULLIF(TRIM(t.artist), ''), 'Unknown artist') AS name, "
      'COUNT(*) AS plays, COALESCE(SUM(p.listened_ms), 0) AS listened '
      'FROM play_events p JOIN tracks t ON t.id = p.track_id '
      'GROUP BY name ORDER BY plays DESC, listened DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return [
      for (final row in rows)
        (
          name: row.read<String>('name'),
          plays: row.read<int>('plays'),
          listened: Duration(milliseconds: row.read<int>('listened')),
        ),
    ];
  }

  /// When each track was last played, most recent first.
  Future<List<({int trackId, DateTime playedAt})>> latestPlays({
    int limit = 12,
  }) async {
    if (limit <= 0) return const [];
    final rows = await customSelect(
      'SELECT track_id, MAX(started_at) AS played_at FROM play_events '
      'GROUP BY track_id ORDER BY played_at DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return [
      for (final row in rows)
        (
          trackId: row.read<int>('track_id'),
          playedAt: row.read<DateTime>('played_at'),
        ),
    ];
  }

  /// The tracks with [ids], keyed by id. Missing ids are simply absent.
  Future<Map<int, TrackRow>> tracksById(Iterable<int> ids) async {
    final wanted = ids.toSet().toList();
    if (wanted.isEmpty) return const {};
    final rows = await (select(
      tracks,
    )..where((track) => track.id.isIn(wanted))).get();
    return {for (final row in rows) row.id: row};
  }

  /// One link per track, keyed by track id.
  ///
  /// A track can be served by several sources; a list row only needs one that
  /// still exists, and artwork when any source has it.
  Future<Map<int, TrackLinkRow>> preferredLinksOf(
    Iterable<int> trackIds,
  ) async {
    final wanted = trackIds.toSet().toList();
    if (wanted.isEmpty) return const {};
    final rows = await (select(
      trackLinks,
    )..where((link) => link.trackId.isIn(wanted))).get();
    final preferred = <int, TrackLinkRow>{};
    for (final link in rows) {
      final current = preferred[link.trackId];
      if (current == null || (current.artId == null && link.artId != null)) {
        preferred[link.trackId] = link;
      }
    }
    return preferred;
  }

  /// The saved active playback session, or null if none was saved.
  Future<PlaybackSessionRow?> loadPlaybackSession() =>
      (select(playbackSessions)..where((s) => s.id.equals(1))).getSingleOrNull();

  /// Persists the active playback session in a single row.
  Future<void> savePlaybackSession({
    required String queueJson,
    int? currentIndex,
    int positionMs = 0,
    int durationMs = 0,
    bool shuffle = false,
    String repeatMode = 'off',
    DateTime? updatedAt,
  }) async {
    final at = updatedAt ?? DateTime.now();
    await into(playbackSessions).insert(
      PlaybackSessionsCompanion(
        id: const Value(1),
        queueJson: Value(queueJson),
        currentIndex: Value(currentIndex),
        positionMs: Value(positionMs),
        durationMs: Value(durationMs),
        shuffle: Value(shuffle),
        repeatMode: Value(repeatMode),
        updatedAt: Value(at),
      ),
      onConflict: DoUpdate(
        (old) => PlaybackSessionsCompanion(
          queueJson: Value(queueJson),
          currentIndex: Value(currentIndex),
          positionMs: Value(positionMs),
          durationMs: Value(durationMs),
          shuffle: Value(shuffle),
          repeatMode: Value(repeatMode),
          updatedAt: Value(at),
        ),
        target: [playbackSessions.id],
      ),
    );
  }

  /// Random playable tracks known to the local library.
  Future<List<LibrarySong>> randomTracks({int limit = 30}) async {
    if (limit <= 0) return const [];
    final rows = await customSelect(
      'SELECT t.title, t.artist, t.album, t.genre, t.year, '
      't.track_number, t.disc_number, t.duration_ms, t.mbid, '
      'l.source_id, l.external_id, l.album_external_id, l.artist_external_id, l.art_id '
      'FROM tracks t '
      'JOIN track_links l ON t.id = l.track_id '
      'GROUP BY t.id '
      'ORDER BY RANDOM() LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return [
      for (final row in rows)
        LibrarySong(
          sourceId: row.read<String>('source_id'),
          id: row.read<String>('external_id'),
          title: row.read<String>('title'),
          artist: row.readNullable<String>('artist'),
          album: row.readNullable<String>('album'),
          albumId: row.readNullable<String>('album_external_id'),
          artistId: row.readNullable<String>('artist_external_id'),
          artId: row.readNullable<String>('art_id'),
          duration: Duration(milliseconds: row.read<int>('duration_ms')),
          track: row.readNullable<int>('track_number'),
          discNumber: row.readNullable<int>('disc_number'),
          year: row.readNullable<int>('year'),
          genre: row.readNullable<String>('genre'),
          mbid: row.readNullable<String>('mbid'),
        ),
    ];
  }

  /// Finds an existing canonical track matching [identity], using:
  /// 1) MusicBrainz ID (if present)
  /// 2) Exact fingerprint
  /// 3) Fingerprint base prefix with continuous duration window
  Future<TrackRow?> findMatchingTrack(TrackIdentity identity) async {
    if (identity.mbid != null && identity.mbid!.isNotEmpty) {
      final matched = await (select(tracks)
            ..where((track) => track.mbid.equals(identity.mbid!)))
          .getSingleOrNull();
      if (matched != null) return matched;
    }

    final byFp = await (select(tracks)
          ..where((track) => track.fingerprint.equals(identity.fingerprint)))
        .getSingleOrNull();
    if (byFp != null) return byFp;

    if (identity.duration > Duration.zero) {
      final base = identity.baseFingerprint;
      final candidates = await (select(tracks)
            ..where(
              (track) =>
                  track.fingerprint.equals(base) |
                  track.fingerprint.like('$base|%'),
            ))
          .get();
      for (final candidate in candidates) {
        final candidateIdentity = TrackIdentity(
          title: candidate.title,
          artist: candidate.artist,
          duration: Duration(milliseconds: candidate.durationMs),
          mbid: candidate.mbid,
        );
        if (identity.matches(candidateIdentity)) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Exports all tracks, links, cached lyrics, and play events as a JSON-encodable map.
  Future<Map<String, dynamic>> exportData() async {
    final allTracks = await select(tracks).get();
    final allLinks = await select(trackLinks).get();
    final allLyrics = await select(lyricsEntries).get();
    final allPlays = await select(playEvents).get();

    return {
      'tracks': [
        for (final t in allTracks)
          {
            'id': t.id,
            'title': t.title,
            'artist': t.artist,
            'albumArtist': t.albumArtist,
            'album': t.album,
            'genre': t.genre,
            'year': t.year,
            'trackNumber': t.trackNumber,
            'discNumber': t.discNumber,
            'durationMs': t.durationMs,
            'mbid': t.mbid,
            'fingerprint': t.fingerprint,
            'createdAt': t.createdAt.toIso8601String(),
            'updatedAt': t.updatedAt.toIso8601String(),
          },
      ],
      'links': [
        for (final l in allLinks)
          {
            'trackId': l.trackId,
            'sourceId': l.sourceId,
            'externalId': l.externalId,
            'albumExternalId': l.albumExternalId,
            'artistExternalId': l.artistExternalId,
            'artId': l.artId,
            'linkedAt': l.linkedAt.toIso8601String(),
            'lastSeenAt': l.lastSeenAt.toIso8601String(),
          },
      ],
      'lyrics': [
        for (final e in allLyrics)
          {
            'trackId': e.trackId,
            'lines': e.lines,
            'synced': e.synced,
            'language': e.language,
            'origin': e.origin,
            'remoteId': e.remoteId,
            'fetchedAt': e.fetchedAt.toIso8601String(),
            'translationLanguage': e.translationLanguage,
          },
      ],
      'plays': [
        for (final p in allPlays)
          {
            'trackId': p.trackId,
            'sourceId': p.sourceId,
            'startedAt': p.startedAt.toIso8601String(),
            'listenedMs': p.listenedMs,
            'positionMs': p.positionMs,
            'completed': p.completed,
          },
      ],
    };
  }

  /// Imports and merges tracks, links, lyrics, and play events from an export map.
  /// Track IDs are dynamically re-mapped to avoid foreign key collisions.
  /// Returns counts of merged/inserted entities.
  Future<({int tracks, int links, int lyrics, int plays})> importData(
    Map<String, dynamic> data,
  ) {
    return transaction(() async {
      final idMap = <int, int>{};
      var tracksCount = 0;
      var linksCount = 0;
      var lyricsCount = 0;
      var playsCount = 0;

      final rawTracks = data['tracks'];
      if (rawTracks is List) {
        for (final raw in rawTracks) {
          if (raw is! Map) continue;
          final oldId = raw['id'];
          if (oldId is! int) continue;

          final title = raw['title'] as String? ?? 'Unknown';
          final artist = raw['artist'] as String?;
          final albumArtist = raw['albumArtist'] as String?;
          final album = raw['album'] as String?;
          final genre = raw['genre'] as String?;
          final year = raw['year'] as int?;
          final trackNumber = raw['trackNumber'] as int?;
          final discNumber = raw['discNumber'] as int?;
          final durationMs = (raw['durationMs'] as num?)?.toInt() ?? 0;
          final mbid = raw['mbid'] as String?;
          final fingerprint = raw['fingerprint'] as String? ??
              trackFingerprint(
                title: title,
                artist: artist,
                duration: Duration(milliseconds: durationMs),
              );
          final createdAtStr = raw['createdAt'] as String?;
          final createdAt = createdAtStr != null
              ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
              : DateTime.now();
          final updatedAtStr = raw['updatedAt'] as String?;
          final updatedAt = updatedAtStr != null
              ? DateTime.tryParse(updatedAtStr) ?? DateTime.now()
              : DateTime.now();

          final identity = TrackIdentity(
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber,
            duration: Duration(milliseconds: durationMs),
            mbid: mbid,
          );

          final matched = await findMatchingTrack(identity);
          if (matched != null) {
            idMap[oldId] = matched.id;
            final needsUpdate = (matched.album == null && album != null) ||
                (matched.albumArtist == null && albumArtist != null) ||
                (matched.genre == null && genre != null) ||
                (matched.year == null && year != null) ||
                (matched.trackNumber == null && trackNumber != null) ||
                (matched.discNumber == null && discNumber != null) ||
                (matched.mbid == null && mbid != null);
            if (needsUpdate) {
              await (update(tracks)..where((t) => t.id.equals(matched.id)))
                  .write(
                TracksCompanion(
                  albumArtist: Value.absentIfNull(albumArtist),
                  album: Value.absentIfNull(album),
                  genre: Value.absentIfNull(genre),
                  year: Value.absentIfNull(year),
                  trackNumber: Value.absentIfNull(trackNumber),
                  discNumber: Value.absentIfNull(discNumber),
                  mbid: Value.absentIfNull(mbid),
                  updatedAt: Value(DateTime.now()),
                ),
              );
            }
          } else {
            final newId = await into(tracks).insert(
              TracksCompanion.insert(
                title: title,
                fingerprint: fingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                artist: Value.absentIfNull(artist),
                albumArtist: Value.absentIfNull(albumArtist),
                album: Value.absentIfNull(album),
                genre: Value.absentIfNull(genre),
                year: Value.absentIfNull(year),
                trackNumber: Value.absentIfNull(trackNumber),
                discNumber: Value.absentIfNull(discNumber),
                durationMs: Value(durationMs),
                mbid: Value.absentIfNull(mbid),
              ),
            );
            idMap[oldId] = newId;
            tracksCount++;
          }
        }
      }

      final rawLinks = data['links'];
      if (rawLinks is List) {
        for (final raw in rawLinks) {
          if (raw is! Map) continue;
          final oldTrackId = raw['trackId'];
          if (oldTrackId is! int) continue;
          final localTrackId = idMap[oldTrackId];
          if (localTrackId == null) continue;

          final sourceId = raw['sourceId'] as String?;
          final externalId = raw['externalId'] as String?;
          if (sourceId == null || externalId == null) continue;

          final albumExternalId = raw['albumExternalId'] as String?;
          final artistExternalId = raw['artistExternalId'] as String?;
          final artId = raw['artId'] as String?;
          final linkedAtStr = raw['linkedAt'] as String?;
          final linkedAt = linkedAtStr != null
              ? DateTime.tryParse(linkedAtStr) ?? DateTime.now()
              : DateTime.now();
          final lastSeenAtStr = raw['lastSeenAt'] as String?;
          final lastSeenAt = lastSeenAtStr != null
              ? DateTime.tryParse(lastSeenAtStr) ?? linkedAt
              : linkedAt;

          await into(trackLinks).insert(
            TrackLinksCompanion.insert(
              trackId: localTrackId,
              sourceId: sourceId,
              externalId: externalId,
              albumExternalId: Value.absentIfNull(albumExternalId),
              artistExternalId: Value.absentIfNull(artistExternalId),
              artId: Value.absentIfNull(artId),
              linkedAt: linkedAt,
              lastSeenAt: lastSeenAt,
            ),
            onConflict: DoUpdate(
              (old) => TrackLinksCompanion(
                trackId: Value(localTrackId),
                lastSeenAt: Value(lastSeenAt),
                albumExternalId: Value.absentIfNull(albumExternalId),
                artistExternalId: Value.absentIfNull(artistExternalId),
                artId: Value.absentIfNull(artId),
              ),
              target: [trackLinks.sourceId, trackLinks.externalId],
            ),
          );
          linksCount++;
        }
      }

      final rawLyrics = data['lyrics'];
      if (rawLyrics is List) {
        for (final raw in rawLyrics) {
          if (raw is! Map) continue;
          final oldTrackId = raw['trackId'];
          if (oldTrackId is! int) continue;
          final localTrackId = idMap[oldTrackId];
          if (localTrackId == null) continue;

          final lines = raw['lines'];
          if (lines is! String) continue;
          final synced = raw['synced'] == true;
          final language = raw['language'] as String?;
          final origin = raw['origin'] as String? ?? 'library';
          final remoteId = raw['remoteId'] as int?;
          final fetchedAtStr = raw['fetchedAt'] as String?;
          final fetchedAt = fetchedAtStr != null
              ? DateTime.tryParse(fetchedAtStr) ?? DateTime.now()
              : DateTime.now();
          final translationLanguage = raw['translationLanguage'] as String?;

          final existing = await (select(lyricsEntries)
                ..where((e) => e.trackId.equals(localTrackId)))
              .getSingleOrNull();

          if (existing == null) {
            await into(lyricsEntries).insert(
              LyricsEntriesCompanion.insert(
                trackId: Value(localTrackId),
                lines: lines,
                synced: synced,
                language: Value.absentIfNull(language),
                origin: origin,
                remoteId: Value.absentIfNull(remoteId),
                fetchedAt: fetchedAt,
                translationLanguage: Value.absentIfNull(translationLanguage),
              ),
            );
            lyricsCount++;
          } else {
            final existingOrigin = existing.origin;
            final incomingHasLyrics = origin != 'none';
            if (existingOrigin == 'none' && incomingHasLyrics) {
              await (update(lyricsEntries)
                    ..where((e) => e.trackId.equals(localTrackId)))
                  .write(
                LyricsEntriesCompanion(
                  lines: Value(lines),
                  synced: Value(synced),
                  language: Value(language),
                  origin: Value(origin),
                  remoteId: Value(remoteId),
                  fetchedAt: Value(fetchedAt),
                  translationLanguage: Value(translationLanguage),
                ),
              );
              lyricsCount++;
            } else if (fetchedAt.isAfter(existing.fetchedAt) && incomingHasLyrics) {
              await (update(lyricsEntries)
                    ..where((e) => e.trackId.equals(localTrackId)))
                  .write(
                LyricsEntriesCompanion(
                  lines: Value(lines),
                  synced: Value(synced),
                  language: Value(language),
                  origin: Value(origin),
                  remoteId: Value(remoteId),
                  fetchedAt: Value(fetchedAt),
                  translationLanguage: Value(translationLanguage),
                ),
              );
              lyricsCount++;
            }
          }
        }
      }

      final rawPlays = data['plays'];
      if (rawPlays is List) {
        for (final raw in rawPlays) {
          if (raw is! Map) continue;
          final oldTrackId = raw['trackId'];
          if (oldTrackId is! int) continue;
          final localTrackId = idMap[oldTrackId];
          if (localTrackId == null) continue;

          final sourceId = raw['sourceId'] as String? ?? '';
          final startedAtStr = raw['startedAt'] as String?;
          if (startedAtStr == null) continue;
          final startedAt = DateTime.tryParse(startedAtStr);
          if (startedAt == null) continue;

          final listenedMs = (raw['listenedMs'] as num?)?.toInt() ?? 0;
          final positionMs = (raw['positionMs'] as num?)?.toInt() ?? 0;
          final completed = raw['completed'] == true;

          final existing = await (select(playEvents)
                ..where(
                  (p) =>
                      p.trackId.equals(localTrackId) &
                      p.startedAt.equals(startedAt),
                ))
              .getSingleOrNull();

          if (existing == null) {
            await into(playEvents).insert(
              PlayEventsCompanion.insert(
                trackId: localTrackId,
                sourceId: sourceId,
                startedAt: startedAt,
                listenedMs: Value(listenedMs),
                positionMs: Value(positionMs),
                completed: Value(completed),
              ),
            );
            playsCount++;
          }
        }
      }

      return (
        tracks: tracksCount,
        links: linksCount,
        lyrics: lyricsCount,
        plays: playsCount,
      );
    });
  }
}
