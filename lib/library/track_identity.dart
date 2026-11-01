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
  final String? mbid;

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
    this.mbid,
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
    mbid: song.mbid,
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

  /// See [trackBaseFingerprint].
  String get baseFingerprint => trackBaseFingerprint(
    title: title,
    artist: artist,
  );

  /// Whether two identities describe the same canonical song.
  ///
  /// Matches if both share a MusicBrainz ID ([mbid]), or have matching
  /// fingerprints, or have identical base fingerprints with a duration
  /// within [durationToleranceSeconds].
  bool matches(TrackIdentity other, {int durationToleranceSeconds = 4}) {
    if (mbid != null && other.mbid != null && mbid == other.mbid) {
      return true;
    }
    if (fingerprint == other.fingerprint) return true;
    if (baseFingerprint == other.baseFingerprint) {
      if (duration == Duration.zero || other.duration == Duration.zero) {
        return true;
      }
      return (duration.inSeconds - other.duration.inSeconds).abs() <=
          durationToleranceSeconds;
    }
    return false;
  }
}

/// The artist and title portion of the fingerprint, independent of length.
String trackBaseFingerprint({
  required String title,
  String? artist,
}) {
  return [
    _normalize(artist ?? '', isArtist: true),
    _normalize(title, isTitle: true),
  ].join('|');
}

/// A stable key for "this same song", used to join two libraries' copies of
/// it onto one row.
///
/// Title and artist are case-folded, stripped of bracketed credits, edition
/// suffixes, and punctuation, so `"Yellow (Live)"` or `"Yellow - 2021 Remaster"`
/// from one server and `"yellow"` from another still meet, and the length is
/// bucketed to [fingerprintDurationBucket] so minor rounding differences
/// between two scanners do not split a song in half.
String trackFingerprint({
  required String title,
  String? artist,
  Duration duration = Duration.zero,
}) {
  final base = trackBaseFingerprint(title: title, artist: artist);
  if (duration <= Duration.zero) return base;
  return '$base|${duration.inSeconds ~/ fingerprintDurationBucket}';
}

/// How coarsely lengths are compared when deciding two items are one song.
const fingerprintDurationBucket = 5;

/// Credits in brackets vary by source (`(feat. X)`, `[Remastered 2011]`, `{Live}`)
/// and say nothing about which song it is.
final _bracketed = RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]');

/// Common edition/remaster/live suffixes separated by dash or slash.
/// e.g. " - Remastered", " - 2021 Remaster", " - Live", " - Radio Edit".
final _titleSuffixRegex = RegExp(
  r'\s*[-–—/]\s*(?:(?:\d{4}\s+)?remaster(?:ed)?(?:\s*\d{4})?|live(?:\s+.*)?|radio\s+edit|single\s+version|album\s+version|original\s+mix|mono|stereo|deluxe(?:\s+edition)?).*$',
  caseSensitive: false,
);

/// Featuring mentions in titles or artist strings.
/// e.g. " ft. Drake", " feat. Drake", " featuring Drake".
final _featuredRegex = RegExp(
  r'\s*(?:[-–—/]\s*)?(?:feat\.?|ft\.?|featuring)\s+.*$',
  caseSensitive: false,
);

String _stripDiacritics(String str) {
  const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñÝý';
  const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNnYy';
  var result = str;
  for (int i = 0; i < withDia.length; i++) {
    result = result.replaceAll(withDia[i], withoutDia[i]);
  }
  return result;
}

/// Punctuation, spacing and case vary by source too. Letters and digits of
/// every script survive; an empty result (a title that is all punctuation)
/// falls back to the raw text so it can never collide with every other one.
String _normalize(String value, {bool isTitle = false, bool isArtist = false}) {
  var stripped = value.replaceAll(_bracketed, ' ');
  if (isTitle) {
    stripped = stripped.replaceAll(_titleSuffixRegex, ' ');
    stripped = stripped.replaceAll(_featuredRegex, ' ');
  } else if (isArtist) {
    stripped = stripped.replaceAll(_featuredRegex, ' ');
  }
  stripped = _stripDiacritics(stripped)
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
  return stripped.isEmpty ? value.trim().toLowerCase() : stripped;
}
