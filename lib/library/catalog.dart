/// The app's view of the local library: songs it has seen, the lyrics they
/// carry and how they have been played.
///
/// This is the only place that talks to [LibraryDatabase] about songs. A
/// source adapter still answers *where* a song lives; this decides what the
/// app remembers about it, so a future local-files source can join the same
/// rows as the servers do today.
library;

import 'package:drift/drift.dart' show Variable, Value;

import '../data/local/library_database.dart';
import 'lyrics.dart';
import 'models.dart';
import 'track_identity.dart';

/// One song, as the app knows it locally, plus where each source can find it.
class CatalogEntry {
  final TrackRow track;
  final List<TrackLinkRow> links;

  const CatalogEntry({required this.track, required this.links});
}

/// How often a track has been played, and when it last was.
class PlayStats {
  final int count;
  final DateTime? lastPlayedAt;

  const PlayStats({required this.count, this.lastPlayedAt});

  static const none = PlayStats(count: 0);
}

/// Writes and reads everything the app remembers about songs.
class LibraryCatalog {
  LibraryCatalog(this._db);

  final LibraryDatabase _db;

  /// Adopts [song] as seen on its own source and returns its track id.
  Future<int> adopt(LibrarySong song) => _db.resolveTrack(
    TrackIdentity.of(song),
    sourceId: song.sourceId,
    externalId: song.id,
    albumExternalId: song.albumId,
    artistExternalId: song.artistId,
    artId: song.artId,
  );

  /// Adopts a page of songs in one transaction.
  ///
  /// Called after a library read, so the local library fills itself as the
  /// user browses rather than waiting for a full sync. Re-adopting is cheap:
  /// a song already linked is one update of metadata that is already there.
  Future<void> adoptAll(Iterable<LibrarySong> songs) async {
    if (songs.isEmpty) return;
    await _db.transaction(() async {
      for (final song in songs) {
        await adopt(song);
      }
    });
  }

  /// The track [song] already is, adopting it if this is the first sight.
  Future<int> trackIdOf(LibrarySong song) async =>
      await _db.trackIdForLink(song.sourceId, song.id) ?? await adopt(song);

  /// Adopts the song a lyrics lookup is about. The request carries only what
  /// a lookup needs, so a row it creates has a title, maybe an artist, and no
  /// album id — the next full read fills the rest in.
  Future<int> adoptRequest(LyricsRequest song) => _db.resolveTrack(
    TrackIdentity.ofRequest(
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
    ),
    sourceId: song.sourceId,
    externalId: song.id,
  );

  /// The track [song] already is, adopting only what a lyrics request knows.
  Future<int> requestTrackId(LyricsRequest song) async =>
      await _db.trackIdForLink(song.sourceId, song.id) ?? await adoptRequest(song);

  /// Records one play of [trackId].
  ///
  /// A play is written once, when a track is opened, and updated in place as
  /// it is listened to: [listened] and [completed] describe the latest
  /// position, so a skip after ten seconds is a row that says exactly that.
  Future<int> recordPlay({
    required int trackId,
    required String sourceId,
    required DateTime startedAt,
    Duration listened = Duration.zero,
    Duration position = Duration.zero,
    bool completed = false,
  }) => _db.into(_db.playEvents).insert(
    PlayEventsCompanion.insert(
      trackId: trackId,
      sourceId: sourceId,
      startedAt: startedAt,
      listenedMs: Value(listened.inMilliseconds),
      positionMs: Value(position.inMilliseconds),
      completed: Value(completed),
    ),
  );

  /// Updates the play that is still running, so an interrupted session leaves
  /// an honest row instead of the zero it was written with.
  Future<void> updatePlay(
    int playId, {
    required Duration listened,
    required Duration position,
    required bool completed,
  }) => (_db.update(
    _db.playEvents,
  )..where((event) => event.id.equals(playId))).write(
    PlayEventsCompanion(
      listenedMs: Value(listened.inMilliseconds),
      positionMs: Value(position.inMilliseconds),
      completed: Value(completed),
    ),
  );

  Future<PlayStats> statsOf(int trackId) async => PlayStats(
    count: await _db.playCountOf(trackId),
    lastPlayedAt: await _db.lastPlayedAt(trackId),
  );

  /// The most recent plays, newest first, with the tracks they were of.
  Future<List<CatalogEntry>> recentlyPlayed({int limit = 50}) async {
    if (limit <= 0) return const [];
    final rows = await _db.customSelect(
      'SELECT DISTINCT track_id FROM play_events '
      'GROUP BY track_id ORDER BY MAX(started_at) DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    final ids = [for (final row in rows) row.read<int>('track_id')];
    if (ids.isEmpty) return const [];

    final tracks = await (_db.select(
      _db.tracks,
    )..where((track) => track.id.isIn(ids))).get();
    final byId = {for (final track in tracks) track.id: track};
    return [
      for (final id in ids)
        if (byId[id] case final track?)
          CatalogEntry(track: track, links: await _db.linksOf(track.id)),
    ];
  }

  /// Drops the links of a source that is no longer connected. Its tracks,
  /// lyrics and play history stay, so re-adding the same server — or adding a
  /// different one with the same songs — picks them up again by fingerprint.
  Future<void> forgetSource(String sourceId) => _db.unlinkSource(sourceId);

  /// Songs the app knows about, whether or not a source still serves them.
  Future<int> trackCount() => _db.trackCount();

  /// Tracks no currently connected source can reach.
  Future<int> orphanCount() => _db.orphanCount();
}
