/// The app's view of the local library: songs it has seen, the lyrics they
/// carry and how they have been played.
///
/// This is the only place that talks to [LibraryDatabase] about songs. A
/// source adapter still answers *where* a song lives; this decides what the
/// app remembers about it, so a future local-files source can join the same
/// rows as the servers do today.
library;

import 'package:drift/drift.dart';

import '../data/local/library_database.dart';
import 'lyrics.dart';
import 'models.dart';
import 'track_identity.dart';

/// What a play-history row needs to be listed and replayed: the track, one
/// source that can still serve it, and when it was last played.
mixin _PlayableTrack {
  TrackRow get track;

  /// Null once every source that had this song is gone. The row still exists —
  /// the history is worth keeping — but there is nowhere to stream it from.
  TrackLinkRow? get link;

  /// The song as a source would hand it over, or null when no source can.
  LibrarySong? get song {
    final served = link;
    if (served == null) return null;
    return LibrarySong(
      sourceId: served.sourceId,
      id: served.externalId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      albumId: served.albumExternalId,
      artistId: served.artistExternalId,
      artId: served.artId,
      duration: Duration(milliseconds: track.durationMs),
      track: track.trackNumber,
      discNumber: track.discNumber,
      year: track.year,
      genre: track.genre,
      mbid: track.mbid,
    );
  }
}

/// One song the library has played, and when it last was.
class RecentPlay with _PlayableTrack {
  @override
  final TrackRow track;
  final DateTime playedAt;

  /// A source that can still serve it, for its artwork. Null once every
  /// source that had it is gone; the row is kept either way.
  @override
  final TrackLinkRow? link;

  const RecentPlay({required this.track, required this.playedAt, this.link});
}

/// One of the library's most played tracks.
class TopTrack with _PlayableTrack {
  @override
  final TrackRow track;
  final int plays;
  final Duration listened;
  @override
  final TrackLinkRow? link;

  const TopTrack({
    required this.track,
    required this.plays,
    required this.listened,
    this.link,
  });
}

/// One of the library's most played artists.
class TopArtist {
  final String name;
  final int plays;
  final Duration listened;

  const TopArtist({
    required this.name,
    required this.plays,
    required this.listened,
  });
}

/// How often a track has been played, and when it last was.
class PlayStats {
  final int count;
  final DateTime? lastPlayedAt;

  const PlayStats({required this.count, this.lastPlayedAt});

  static const none = PlayStats(count: 0);
}

/// Everything the stats page shows, read from the play history in one go.
class ListeningStats {
  final int plays;
  final int completedPlays;
  final Duration listened;

  /// Songs played at least once. One song played ten times counts once.
  final int distinctTracks;
  final List<TopTrack> topTracks;
  final List<TopArtist> topArtists;
  final List<RecentPlay> recent;

  /// Songs the local library knows, and how many of those no connected source
  /// can play any more.
  final int libraryTracks;
  final int orphaned;

  const ListeningStats({
    required this.plays,
    required this.completedPlays,
    required this.listened,
    required this.distinctTracks,
    required this.topTracks,
    required this.topArtists,
    required this.recent,
    required this.libraryTracks,
    required this.orphaned,
  });

  /// Nothing has played, or this device keeps no history.
  static const none = ListeningStats(
    plays: 0,
    completedPlays: 0,
    listened: Duration.zero,
    distinctTracks: 0,
    topTracks: [],
    topArtists: [],
    recent: [],
    libraryTracks: 0,
    orphaned: 0,
  );

  bool get isEmpty => plays == 0;
}

/// Writes and reads everything the app remembers about songs.
class LibraryCatalog {
  LibraryCatalog(this._db, {this.onLinksForgotten});

  final LibraryDatabase _db;

  /// Called with the external ids of every link a forgotten source dropped,
  /// so a sync can queue their tombstones. Null when nothing listens.
  final void Function(String sourceId, List<String> externalIds)?
  onLinksForgotten;

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

  /// Every known playable link for [song]'s canonical track.
  Future<List<TrackLinkRow>> linksOfSong(LibrarySong song) async {
    final trackId = await trackIdOf(song);
    return _db.linksOf(trackId);
  }

  /// Every connected library's copy of [song]'s canonical track.
  ///
  /// This is the "other versions" answer: the same song as each source holds
  /// it, newest sighting first, so an album's own listing and a playlist's
  /// duplicate collapse into one entry per library. Copies whose source is
  /// no longer connected are returned too, marked unplayable, because the
  /// catalog still knows they exist and hiding them would make a lookup
  /// silently lie about how many copies there were.
  Future<List<TrackCopy>> copiesOfSong(
    LibrarySong song, {
    Set<String>? connectedSourceIds,
  }) async {
    final trackId = await trackIdOf(song);
    final links = await _db.linksOf(trackId);
    // One entry per library: an album's listing and a playlist's copy of the
    // same track are two links to one row, and the user wants one choice per
    // library, not one per sighting.
    final seen = <String>{};
    return [
      for (final link in links)
        if (seen.add(link.sourceId))
          TrackCopy(
            sourceId: link.sourceId,
            externalId: link.externalId,
            song: LibrarySong(
              sourceId: link.sourceId,
              id: link.externalId,
              title: song.title,
              artist: song.artist,
              album: song.album,
              albumId: link.albumExternalId,
              artistId: link.artistExternalId,
              artId: link.artId ?? song.artId,
              duration: song.duration,
              track: song.track,
              discNumber: song.discNumber,
              year: song.year,
              genre: song.genre,
              mbid: song.mbid,
            ),
            playable:
                connectedSourceIds == null ||
                connectedSourceIds.contains(link.sourceId),
          ),
    ];
  }

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
      await _db.trackIdForLink(song.sourceId, song.id) ??
      await adoptRequest(song);

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
  }) => _db
      .into(_db.playEvents)
      .insert(
        PlayEventsCompanion.insert(
          trackId: trackId,
          sourceId: sourceId,
          startedAt: startedAt,
          listenedMs: Value(listened.inMilliseconds),
          positionMs: Value(position.inMilliseconds),
          completed: Value(completed),
          touchedAt: Value(DateTime.now()),
        ),
      );

  /// Updates the play that is still running, so an interrupted session leaves
  /// an honest row instead of the zero it was written with.
  Future<void> updatePlay(
    int playId, {
    required Duration listened,
    required Duration position,
    required bool completed,
  }) => (_db.update(_db.playEvents)..where((event) => event.id.equals(playId)))
      .write(
        PlayEventsCompanion(
          listenedMs: Value(listened.inMilliseconds),
          positionMs: Value(position.inMilliseconds),
          completed: Value(completed),
          touchedAt: Value(DateTime.now()),
        ),
      );

  Future<PlayStats> statsOf(int trackId) async => PlayStats(
    count: await _db.playCountOf(trackId),
    lastPlayedAt: await _db.lastPlayedAt(trackId),
  );

  /// The most recent plays, newest first, with the tracks they were of.
  Future<List<RecentPlay>> recentlyPlayed({int limit = 50}) async {
    final latest = await _db.latestPlays(limit: limit);
    if (latest.isEmpty) return const [];
    final tracks = await _db.tracksById(latest.map((play) => play.trackId));
    final links = await _db.preferredLinksOf(tracks.keys);
    return [
      for (final play in latest)
        if (tracks[play.trackId] case final track?)
          RecentPlay(
            track: track,
            playedAt: play.playedAt,
            link: links[track.id],
          ),
    ];
  }

  /// Everything the stats page shows, in one read.
  ///
  /// The lists are capped rather than paged: a stats page is a summary, and
  /// the top ten of anything is what a summary is for.
  Future<ListeningStats> listeningStats({
    int topTracks = 10,
    int topArtists = 6,
    int recent = 12,
  }) async {
    final totals = await _db.playTotals();
    final counts = await _db.playCountsByTrack(limit: topTracks);
    final artists = await _db.playCountsByArtist(limit: topArtists);
    final latest = await _db.latestPlays(limit: recent);
    final tracks = await _db.tracksById([
      ...counts.map((entry) => entry.trackId),
      ...latest.map((play) => play.trackId),
    ]);
    final links = await _db.preferredLinksOf(tracks.keys);
    final stats = await libraryCounts();

    return ListeningStats(
      plays: totals.plays,
      completedPlays: totals.completed,
      listened: totals.listened,
      distinctTracks: totals.tracks,
      topTracks: [
        for (final entry in counts)
          if (tracks[entry.trackId] case final track?)
            TopTrack(
              track: track,
              plays: entry.plays,
              listened: entry.listened,
              link: links[track.id],
            ),
      ],
      topArtists: [
        for (final entry in artists)
          TopArtist(
            name: entry.name,
            plays: entry.plays,
            listened: entry.listened,
          ),
      ],
      recent: [
        for (final play in latest)
          if (tracks[play.trackId] case final track?)
            RecentPlay(
              track: track,
              playedAt: play.playedAt,
              link: links[track.id],
            ),
      ],
      libraryTracks: stats.tracks,
      orphaned: stats.orphaned,
    );
  }

  /// How many songs the library knows, and how many of those no connected
  /// source can still play.
  Future<({int tracks, int orphaned})> libraryCounts() async =>
      (tracks: await _db.trackCount(), orphaned: await _db.orphanCount());

  /// Drops the links of a source that is no longer connected. Its tracks,
  /// lyrics and play history stay, so re-adding the same server — or adding a
  /// different one with the same songs — picks them up again by fingerprint.
  Future<void> forgetSource(String sourceId) async {
    // The pairs are read before the delete: a tombstone needs the source id
    // and the external id, and the rows that held them are about to go.
    final externalIds = await _db.externalIdsOfSource(sourceId);
    await _db.unlinkSource(sourceId);
    if (externalIds.isNotEmpty) onLinksForgotten?.call(sourceId, externalIds);
  }

  /// Songs the app knows about, whether or not a source still serves them.
  Future<int> trackCount() => _db.trackCount();

  /// Tracks no currently connected source can reach.
  Future<int> orphanCount() => _db.orphanCount();

  /// Loads the persisted playback session, if any.
  Future<PlaybackSessionRow?> loadPlaybackSession() =>
      _db.loadPlaybackSession();

  /// Persists the active playback session.
  Future<void> savePlaybackSession({
    required String queueJson,
    int? currentIndex,
    int positionMs = 0,
    int durationMs = 0,
    bool shuffle = false,
    String repeatMode = 'off',
  }) => _db.savePlaybackSession(
    queueJson: queueJson,
    currentIndex: currentIndex,
    positionMs: positionMs,
    durationMs: durationMs,
    shuffle: shuffle,
    repeatMode: repeatMode,
  );

  /// Random playable tracks known to the local database.
  Future<List<LibrarySong>> randomTracks({int limit = 30}) =>
      _db.randomTracks(limit: limit);
}
