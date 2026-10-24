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
  });

  String get subtitle => artist ?? album ?? 'Unknown artist';
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
class LibraryException implements Exception {
  final int? code;
  final String message;

  const LibraryException(this.message, {this.code});

  @override
  String toString() => code == null ? message : 'Library error $code: $message';
}
