/// What makes two items from two libraries *the same song*.
library;

import 'models.dart';

/// The metadata of one song, as any source describes it.
///
/// Both a full [LibrarySong] and a lyrics lookup's [LyricsRequest] narrow to
/// this, so the database has one shape to store and one identity to match on.
class TrackIdentity {
  final String title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final Duration duration;

  const TrackIdentity({
    required this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.duration = Duration.zero,
  });

  factory TrackIdentity.of(LibrarySong song) => TrackIdentity(
    title: song.title,
    artist: song.artist,
    album: song.album,
    genre: song.genre,
    year: song.year,
    trackNumber: song.track,
    discNumber: song.discNumber,
    duration: song.duration,
  );

  /// The identity a lyrics request can offer: no album artist, genre, year or
  /// position, since the request never carries them.
  factory TrackIdentity.ofRequest({
    required String title,
    String? artist,
    String? album,
    Duration duration = Duration.zero,
  }) => TrackIdentity(
    title: title,
    artist: artist,
    album: album,
    duration: duration,
  );

  /// See [trackFingerprint].
  String get fingerprint => trackFingerprint(
    title: title,
    artist: artist,
    duration: duration,
  );
}

/// A stable key for "this same song", used to join two libraries' copies of
/// it onto one row.
///
/// Title and artist are case-folded, stripped of bracketed credits and
/// punctuation, so `"Yellow (Live)"` from one server and `"yellow"` from
/// another still meet, and the length is bucketed to
/// [fingerprintDurationBucket] so a second's rounding difference between two
/// scanners does not split a song in half. A zero length (a lyrics request
/// that never learned it) omits the bucket rather than pinning every such
/// track to the same key twice over.
String trackFingerprint({
  required String title,
  String? artist,
  Duration duration = Duration.zero,
}) {
  final parts = [
    _normalize(artist ?? ''),
    _normalize(title),
    if (duration > Duration.zero)
      '${duration.inSeconds ~/ fingerprintDurationBucket}',
  ];
  return parts.join('|');
}

/// How coarsely lengths are compared when deciding two items are one song.
const fingerprintDurationBucket = 5;

/// Credits in brackets vary by source (`(feat. X)`, `[Remastered 2011]`) and
/// say nothing about which song it is.
final _bracketed = RegExp(r'[\(\[][^\)\]]*[\)\]]');

/// Punctuation, spacing and case vary by source too. Letters and digits of
/// every script survive; an empty result (a title that is all punctuation)
/// falls back to the raw text so it can never collide with every other one.
String _normalize(String value) {
  final stripped = value
      .replaceAll(_bracketed, ' ')
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
  return stripped.isEmpty ? value.trim().toLowerCase() : stripped;
}
