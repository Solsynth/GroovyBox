/// Provider-neutral library models.
///
/// Every adapter maps its own wire format onto these, so no screen ever sees
/// a Subsonic or Jellyfin field name. Ids are native to their backend and only
/// unique within one source, which is why every item carries [sourceId].
library;

/// Identifies an item across sources; used as a riverpod family argument and
/// as two route path segments.
typedef LibraryRef = ({String sourceId, String id});

/// The one source id files imported into this device are linked under.
///
/// Lives here rather than with the local source so the database can recognise
/// a device-local link without importing the source implementation.
const kLocalSourceId = 'local';

/// The source id a Solink (Pulsar) collection lives under. A cloud playlist
/// has no library behind it, and a heart on one still has to say where the
/// thing it names lives.
const kSolinkSourceId = 'solink';

/// What a favourite names: a recording, a record, or a list.
///
/// Albums and playlists are not rows in the local track table — they are
/// catalog records the account likes in their own right — so the kind is part
/// of a favourite's identity rather than a decoration on it.
enum FavouriteKind {
  track('track'),
  album('album'),
  playlist('playlist');

  const FavouriteKind(this.value);

  /// The wire value the fleet stores.
  final String value;

  /// Absent or unknown reads as [track]: what every entry written before
  /// albums and playlists could be hearts meant.
  static FavouriteKind parse(String? value) =>
      values.where((kind) => kind.value == value).firstOrNull ?? track;

  /// Whether this kind is a container of tracks rather than one.
  bool get isCollection => this != track;
}

/// One album or playlist the account likes.
///
/// Carries enough to draw its row without asking a library again: the account
/// is the record, and a row read on a second device has no other source to
/// describe it from.
class CollectionFavourite {
  final FavouriteKind kind;
  final String sourceId;
  final String id;
  final String name;
  final String? subtitle;

  /// A cover as the owning library spells the handle.
  final String? artId;

  /// A cover URL, for a thing no library can resolve (a Solink playlist's own
  /// `artwork_url`).
  final String? artworkUrl;
  final DateTime decidedAt;

  const CollectionFavourite({
    required this.kind,
    required this.sourceId,
    required this.id,
    required this.name,
    this.subtitle,
    this.artId,
    this.artworkUrl,
    required this.decidedAt,
  });

  /// The identity a heart is asked about.
  CollectionFavouriteKey get key =>
      (kind: kind, sourceId: sourceId, id: id);
}

/// A [CollectionFavourite]'s identity, usable as a riverpod family argument.
typedef CollectionFavouriteKey = ({
  FavouriteKind kind,
  String sourceId,
  String id,
});

class LibrarySong {
  /// Which [LibrarySource] owns this item.
  final String sourceId;

  /// Native id, unique only within [sourceId].
  final String id;
  final String title;
  final String? artist;
  final String? artistId;
  final String? album;
  final String? albumArtist;
  final String? albumId;
  final Duration duration;
  final int? track;
  final int? discNumber;
  final int? year;
  final String? genre;

  /// Opaque art handle; adapters interpret it.
  final String? artId;

  /// Optional MusicBrainz Recording ID or Track ID.
  final String? mbid;

  /// A live station rather than a track: it has no stream, no length and no
  /// end, and its source plays it by id. Apple Music's radio is the one
  /// source with these; a station travels through the queue as a song so the
  /// dock, the queue panel and the scrobbler need no special case.
  final bool isRadio;

  /// For a radio station, the resource's own `attributes.url` and
  /// `attributes.playParams`. Both are sent back to the platform player,
  /// which resolves a station by them instead of by a track id.
  final String? radioUrl;
  final Map<String, dynamic>? radioPlayParams;

  /// A catalog id, when the item exists in the store rather than the account's
  /// own library. A station's tracks only exist there, and the catalog is the
  /// only thing that can describe them — artwork included.
  final String? catalogId;

  /// The track a station is playing right now.
  ///
  /// A station has no tracklist: it generates one as it runs, and only the
  /// system player knows which track that is. The queue entry it reports is
  /// folded back into this song, so everything that draws "what is playing"
  /// — the dock, the player page, the scrobbler — names the track instead of
  /// the station. Null while the station is still starting up.
  final LibrarySong? radioTrack;
  const LibrarySong({
    required this.sourceId,
    required this.id,
    required this.title,
    required this.duration,
    this.artist,
    this.artistId,
    this.album,
    this.albumArtist,
    this.albumId,
    this.artId,
    this.track,
    this.discNumber,
    this.year,
    this.genre,
    this.mbid,
    this.isRadio = false,
    this.radioUrl,
    this.radioPlayParams,
    this.radioTrack,
    this.catalogId,
  });
  String get subtitle => artist ?? album ?? 'Unknown artist';

  /// What is actually playing: the station's current track, or the song
  /// itself for everything that is a track in its own right.
  LibrarySong get playing => radioTrack ?? this;

  /// A copy of this song with [other]'s credits where this one has none.
  ///
  /// A platform player reports a track it generated with little more than a
  /// title. The artist and album are on the *other* connected libraries'
  /// copies of the same recording, and a row that can name the act should.
  ///
  /// Names only. Ids and art handles are native to the library that issued
  /// them: this row plays from its own source, so an id borrowed from another
  /// one would open a page in the wrong library, and an art handle would be
  /// read by an adapter that never emitted it. What this song already says
  /// about itself always wins — a neighbour's spelling must not overwrite the
  /// playing library's own.
  LibrarySong withCreditsFrom(LibrarySong other) {
    if (identical(this, other)) return this;
    return LibrarySong(
      sourceId: sourceId,
      id: id,
      title: title,
      artist: artist ?? other.artist,
      artistId: artistId,
      album: album ?? other.album,
      albumArtist: albumArtist ?? other.albumArtist,
      albumId: albumId,
      duration: duration,
      track: track ?? other.track,
      discNumber: discNumber ?? other.discNumber,
      year: year ?? other.year,
      genre: genre ?? other.genre,
      artId: artId,
      mbid: mbid ?? other.mbid,
      isRadio: isRadio,
      radioUrl: radioUrl,
      radioPlayParams: radioPlayParams,
      radioTrack: radioTrack,
      catalogId: catalogId,
    );
  }

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'id': id,
    'title': title,
    if (artist != null) 'artist': artist,
    if (artistId != null) 'artistId': artistId,
    if (albumArtist != null) 'albumArtist': albumArtist,
    if (albumId != null) 'albumId': albumId,
    if (artId != null) 'artId': artId,
    'durationMs': duration.inMilliseconds,
    if (album != null) 'album': album,
    if (discNumber != null) 'discNumber': discNumber,
    if (year != null) 'year': year,
    if (genre != null) 'genre': genre,
    if (mbid != null) 'mbid': mbid,
    if (isRadio) 'isRadio': true,
    if (radioUrl != null) 'radioUrl': radioUrl,
    if (radioPlayParams != null) 'radioPlayParams': radioPlayParams,
    if (radioTrack != null) 'radioTrack': radioTrack!.toJson(),
    if (catalogId != null) 'catalogId': catalogId,
  };

  factory LibrarySong.fromJson(Map<String, dynamic> json) => LibrarySong(
    sourceId: json['sourceId'] as String,
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String?,
    artistId: json['artistId'] as String?,
    album: json['album'] as String?,
    albumArtist: json['albumArtist'] as String?,
    albumId: json['albumId'] as String?,
    artId: json['artId'] as String?,
    duration: Duration(
      milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
    ),
    track: (json['track'] as num?)?.toInt(),
    discNumber: (json['discNumber'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
    mbid: json['mbid'] as String?,
    isRadio: json['isRadio'] == true,
    radioUrl: json['radioUrl'] as String?,
    radioPlayParams: switch (json['radioPlayParams']) {
      final Map<String, dynamic> params => params,
      final Map params => Map<String, dynamic>.from(params),
      _ => null,
    },
    catalogId: json['catalogId'] as String?,
    radioTrack: switch (json['radioTrack']) {
      final Map<String, dynamic> track => LibrarySong.fromJson(track),
      final Map track => LibrarySong.fromJson(Map<String, dynamic>.from(track)),
      _ => null,
    },
  );
}

class LibraryAlbum {
  final String sourceId;
  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? artId;
  final int? songCount;
  final Duration duration;
  final int? year;
  final String? genre;

  const LibraryAlbum({
    required this.sourceId,
    required this.id,
    required this.name,
    required this.duration,
    this.artist,
    this.artistId,
    this.artId,
    this.songCount,
    this.year,
    this.genre,
  });
}

class LibraryArtist {
  /// The library that listed the act, and whose id addresses its page.
  final String sourceId;
  final String id;
  final String name;
  final String? artId;
  final int? albumCount;

  /// Which library can resolve [artId], when it is not [sourceId].
  ///
  /// A listing answers a portrait only where the service filed one, so an act
  /// with none borrows the cover of a record it made — and a cover handle means
  /// nothing outside the library that minted it. Null says the handle is this
  /// source's own, which is the ordinary case.
  final String? artSourceId;

  const LibraryArtist({
    required this.sourceId,
    required this.id,
    required this.name,
    this.artId,
    this.artSourceId,
    this.albumCount,
  });

  /// The source a cover is resolved through: the one that minted the handle.
  String get coverSourceId => artSourceId ?? sourceId;
}

class LibraryPlaylist {
  final String sourceId;
  final String id;
  final String name;
  final String? owner;
  final int? songCount;
  final Duration duration;
  final String? artId;

  const LibraryPlaylist({
    required this.sourceId,
    required this.id,
    required this.name,
    required this.duration,
    this.owner,
    this.songCount,
    this.artId,
  });
}

/// Thrown when a library answers with an error or returns an unusable
/// response. Carries the server's own code and message so the UI can show what
/// the server said instead of a generic failure. Adapters throw only this.
///
/// [messageKey] names the translation for failures the app diagnoses itself
/// (a timeout, a bad certificate); [message] stays as the English text and the
/// fallback for servers that send their own words. The UI resolves the key, so
/// adapters never need the current locale.
class LibraryException implements Exception {
  final int? code;
  final String message;
  final String? messageKey;
  final List<String> messageArgs;

  const LibraryException(
    this.message, {
    this.code,
    this.messageKey,
    this.messageArgs = const [],
  });

  @override
  String toString() => code == null ? message : 'Library error $code: $message';
}

/// A provider holds the track but will not sell it to this account: the URL
/// it minted plays a trial excerpt.
///
/// A refusal with the excerpt attached rather than a plain failure: the
/// caller can still sound the preview when no other library has the track in
/// full, which is better than silence.
class PreviewOnlyException extends LibraryException {
  /// The trial URL the provider minted.
  final Uri previewUri;

  const PreviewOnlyException(
    this.previewUri,
    String message, {
    super.messageKey,
  }) : super(message);
}

/// One shelf a source curates for the landing page.
///
/// The page renders a shelf as a horizontal run of cards; [songs] are what it
/// shows and plays, and [title] is the source's own name for the run ("专属推荐
/// 歌单", "Heavy Rotation"). It is deliberately the same card shape as the
/// merged shelves, so Apple Music's curation does not look like a second app.
class LandingShelf {
  final String title;
  final String sourceId;

  /// Filled when the shelf is a mix or a list rather than a plain set of
  /// tracks: the same run is then also reachable as a queue.
  final List<LibrarySong> songs;

  const LandingShelf({
    required this.title,
    required this.sourceId,
    required this.songs,
  });

  bool get isEmpty => songs.isEmpty;
}

/// What an account-backed source says about itself, in the row that manages
/// its connection.
///
/// Only a source that owns a whole cloud account has anything of its own to
/// report; a server library's numbers are the app's, not the server's.
class LibraryDigest {
  final String sourceId;

  /// How many tracks the account holds. The account's *curation* is not
  /// counted here: those numbers are the shelves the landing page renders,
  /// and counting them twice would let the two disagree.
  final int? libraryTracks;

  const LibraryDigest({required this.sourceId, this.libraryTracks});

  bool get isEmpty => libraryTracks == null;
}

/// One library's copy of a canonical track.
///
/// A lookup answers with these: the same song as each connected library holds
/// it, so the user can pick the version they want — a streamed one that plays
/// now, an Apple Music one that carries the account's own licensing, a local
/// file that needs no network at all.
class TrackCopy {
  /// The library this copy lives in.
  final String sourceId;

  /// The item's id inside that library, which is what playback needs.
  final String externalId;

  /// What that library's own copy says about itself: its title, artist,
  /// album, length and cover. Two copies of one song are often not tagged
  /// identically, and the row should show what it would play.
  final LibrarySong song;

  /// Whether this copy is the one the app is playing, or can be played at all:
  /// a copy whose source is no longer connected is still listed (it exists in
  /// the catalog) but cannot be chosen.
  final bool playable;

  const TrackCopy({
    required this.sourceId,
    required this.externalId,
    required this.song,
    this.playable = true,
  });
}

/// One song asked about across every library.
///
/// The song itself is carried rather than a [LibraryRef]: a lookup needs the
/// title and artist to ask other libraries, and the caller already has them.
/// [LibrarySong] is not usable as a riverpod family argument (it has no
/// value equality), so this wraps it with one.
class TrackLookup {
  final LibrarySong song;

  const TrackLookup(this.song);

  @override
  bool operator ==(Object other) =>
      other is TrackLookup &&
      other.song.sourceId == song.sourceId &&
      other.song.id == song.id;

  @override
  int get hashCode => Object.hash(song.sourceId, song.id);
}

/// What one library holds whose artists or albums match a query.
///
/// Songs are not here: the songs search already answers those, and a page
/// that mixed a third list in would be back to one undifferentiated result.
class LibraryGroups {
  final List<LibraryArtist> artists;
  final List<LibraryAlbum> albums;

  const LibraryGroups({this.artists = const [], this.albums = const []});

  bool get isEmpty => artists.isEmpty && albums.isEmpty;

  LibraryGroups merge(LibraryGroups other) => LibraryGroups(
    artists: [...artists, ...other.artists],
    albums: [...albums, ...other.albums],
  );
}
