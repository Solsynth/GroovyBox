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

/// Everything the app remembers about songs, in one SQLite file.
///
/// [executor] exists for tests, which open `NativeDatabase.memory()` on a
/// plain Dart VM. The app passes nothing and gets the file under the app's
/// support directory (or IndexedDB on the web, with the wasm assets in `web/`).
@DriftDatabase(tables: [Tracks, TrackLinks, LyricsEntries, PlayEvents])
class LibraryDatabase extends _$LibraryDatabase {
  LibraryDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Name of the file (`library.sqlite` on native) and of the IndexedDB
  /// database on the web.
  static const databaseName = 'library';

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
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

      final matched =
          await (select(tracks)
                ..where((track) => track.fingerprint.equals(identity.fingerprint)))
              .getSingleOrNull();
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
}
