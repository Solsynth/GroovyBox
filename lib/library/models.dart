/// Provider-neutral library models.
///
/// Every adapter maps its own wire format onto these, so no screen ever sees
/// a Subsonic or Jellyfin field name. Ids are native to their backend and only
/// unique within one source, which is why every item carries [sourceId].
library;


/// Identifies an item across sources; used as a riverpod family argument and
/// as two route path segments.
typedef LibraryRef = ({String sourceId, String id});

class LibrarySong {
  /// Which [LibrarySource] owns this item.
  final String sourceId;

  /// Native id, unique only within [sourceId].
  final String id;
  final String title;
  final String? artist;
  final String? artistId;
  final String? album;
  final String? albumId;

  /// Opaque art handle; adapters interpret it.
  final String? artId;
  final Duration duration;
  final int? track;
  final int? discNumber;
  final int? year;
  final String? genre;

  /// Optional MusicBrainz Recording ID or Track ID.
  final String? mbid;

  const LibrarySong({
    required this.sourceId,
    required this.id,
    required this.title,
    required this.duration,
    this.artist,
    this.artistId,
    this.album,
    this.albumId,
    this.artId,
    this.track,
    this.discNumber,
    this.year,
    this.genre,
    this.mbid,
  });

  String get subtitle => artist ?? album ?? 'Unknown artist';

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'id': id,
    'title': title,
    if (artist != null) 'artist': artist,
    if (artistId != null) 'artistId': artistId,
    if (album != null) 'album': album,
    if (albumId != null) 'albumId': albumId,
    if (artId != null) 'artId': artId,
    'durationMs': duration.inMilliseconds,
    if (track != null) 'track': track,
    if (discNumber != null) 'discNumber': discNumber,
    if (year != null) 'year': year,
    if (genre != null) 'genre': genre,
    if (mbid != null) 'mbid': mbid,
  };

  factory LibrarySong.fromJson(Map<String, dynamic> json) => LibrarySong(
    sourceId: json['sourceId'] as String,
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String?,
    artistId: json['artistId'] as String?,
    album: json['album'] as String?,
    albumId: json['albumId'] as String?,
    artId: json['artId'] as String?,
    duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
    track: (json['track'] as num?)?.toInt(),
    discNumber: (json['discNumber'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
    mbid: json['mbid'] as String?,
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
  final String sourceId;
  final String id;
  final String name;
  final String? artId;
  final int? albumCount;

  const LibraryArtist({
    required this.sourceId,
    required this.id,
    required this.name,
    this.artId,
    this.albumCount,
  });
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
