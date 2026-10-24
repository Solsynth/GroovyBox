library;

/// Models for the Subsonic / OpenSubsonic API.
///
/// Field names follow the wire format (`coverArt`, `artistId`, …) rather than
/// Dart conventions, so responses can be read with no translation layer and
/// the mapping stays readable next to the API documentation.

class SubsonicSong {
  final String id;
  final String title;
  final String? artist;
  final String? artistId;
  final String? album;
  final String? albumId;
  final String? coverArt;
  final Duration duration;
  final int? track;
  final int? discNumber;
  final int? year;
  final String? genre;

  const SubsonicSong({
    required this.id,
    required this.title,
    required this.duration,
    this.artist,
    this.artistId,
    this.album,
    this.albumId,
    this.coverArt,
    this.track,
    this.discNumber,
    this.year,
    this.genre,
  });

  String get subtitle => artist ?? album ?? 'Unknown artist';

  factory SubsonicSong.fromJson(Map<String, dynamic> json) => SubsonicSong(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled',
    artist: json['artist'] as String?,
    artistId: json['artistId'] as String?,
    album: json['album'] as String?,
    albumId: json['albumId'] as String?,
    coverArt: json['coverArt'] as String?,
    duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
    track: (json['track'] as num?)?.toInt(),
    discNumber: (json['discNumber'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
  );
}

class SubsonicAlbum {
  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int? songCount;
  final Duration duration;
  final int? year;
  final String? genre;

  const SubsonicAlbum({
    required this.id,
    required this.name,
    required this.duration,
    this.artist,
    this.artistId,
    this.coverArt,
    this.songCount,
    this.year,
    this.genre,
  });

  factory SubsonicAlbum.fromJson(Map<String, dynamic> json) => SubsonicAlbum(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['title'] as String? ?? 'Untitled',
    artist: json['artist'] as String?,
    artistId: json['artistId'] as String?,
    coverArt: json['coverArt'] as String?,
    songCount: (json['songCount'] as num?)?.toInt(),
    duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
  );
}

class SubsonicArtist {
  final String id;
  final String name;
  final String? coverArt;
  final int? albumCount;

  const SubsonicArtist({
    required this.id,
    required this.name,
    this.coverArt,
    this.albumCount,
  });

  factory SubsonicArtist.fromJson(Map<String, dynamic> json) => SubsonicArtist(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Unknown artist',
    coverArt: json['coverArt'] as String?,
    albumCount: (json['albumCount'] as num?)?.toInt(),
  );
}

class SubsonicPlaylist {
  final String id;
  final String name;
  final String? owner;
  final int? songCount;
  final Duration duration;
  final String? coverArt;

  const SubsonicPlaylist({
    required this.id,
    required this.name,
    required this.duration,
    this.owner,
    this.songCount,
    this.coverArt,
  });

  factory SubsonicPlaylist.fromJson(Map<String, dynamic> json) =>
      SubsonicPlaylist(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled playlist',
        owner: json['owner'] as String?,
        songCount: (json['songCount'] as num?)?.toInt(),
        duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
        coverArt: json['coverArt'] as String?,
      );
}

/// Thrown when the server answers with a Subsonic error envelope or returns an
/// unusable response. Carries the server's own code and message so the UI can
/// show what the server said instead of a generic failure.
class SubsonicException implements Exception {
  final int? code;
  final String message;

  const SubsonicException(this.message, {this.code});

  @override
  String toString() =>
      code == null ? message : 'Subsonic error $code: $message';
}
