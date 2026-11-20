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

  /// The title alone, normalized: see [trackTitleKey].
  String get titleKey => trackTitleKey(title);

  /// The artist credit as normalized words: see [trackArtistWords].
  Set<String> get artistWords => trackArtistWords(artist);

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

  /// Whether [other] could be the same recording under another library's tags.
  ///
  /// Looser than [matches] on purpose. [matches] is the rule the catalog
  /// *stores* by, and it is right there: two rows are one song only when the
  /// fingerprints — length bucket included — agree, or the lengths are within
  /// a few seconds. A lookup asks a different question, and two services
  /// describe one recording differently all the time: a featured credit on
  /// one and not the other, a length a second or two apart, a title carrying
  /// an edition credit the other drops, an album that is a reissue or a
  /// compilation on one side. Answering "nothing found" for those is the bug
  /// this exists to stop.
  ///
  /// The album is never part of the answer: the same recording is pressed on
  /// a hundred different ones, and a lookup that insisted on it would miss
  /// every copy another library files under its own release.
  ///
  /// The title must agree once normalized. When the lengths match within
  /// [copyDurationTolerance] the credits decide at their own strictness
  /// ([couldBeSameAct]); when they disagree the copy is still accepted if the
  /// lengths match within [matchingDurationTolerance], because a romanization,
  /// a translation or a stage name is a spelling difference this app cannot
  /// read its way through. The length is what keeps a live or re-recorded take
  /// out, and the lookup ranks the copy whose credit agrees first, so a cover
  /// is only ever the last resort.
  bool couldBeSameRecording(TrackIdentity other) {
    if (matches(other)) return true;
    if (titleKey != other.titleKey) return false;
    if (duration > Duration.zero && other.duration > Duration.zero) {
      final delta = (duration - other.duration).abs();
      if (delta > copyDurationTolerance) return false;
      if (couldBeSameAct(other)) return true;
      return delta <= matchingDurationTolerance;
    }
    return couldBeSameAct(other);
  }

  /// Whether the credits could name the same act despite how they are spelled.
  ///
  /// Two services spell one act differently all the time: a diacritic, an
  /// ampersand against "and", a featured credit on one side, a shortened or
  /// elongated name. One unknown credit is no evidence either way, subsetting
  /// credits are a duet listed in part ([trackArtistWords]), and a shared
  /// distinctive word catches the rest. A credit that shares nothing with the
  /// other is answered false — the caller then leans on the length alone.
  bool couldBeSameAct(TrackIdentity other) {
    final credited = artistWords;
    final theirs = other.artistWords;
    if (credited.isEmpty || theirs.isEmpty) return true;
    if (credited.containsAll(theirs) || theirs.containsAll(credited)) {
      return true;
    }
    final mine = _normalize(artist ?? '', isArtist: true);
    final others = _normalize(other.artist ?? '', isArtist: true);
    if (mine.isEmpty || others.isEmpty) return true;
    if (mine.contains(others) || others.contains(mine)) return true;
    return credited.intersection(theirs).any((word) => word.length >= 4);
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

/// How far two libraries' lengths may be apart and still be one recording,
/// once their credits agree.
///
/// Wider than [matchingDurationTolerance]: that compares two sightings of one
/// item, while a lookup compares two services' metadata — one may time the
/// master and the other a licensed copy.
const copyDurationTolerance = Duration(seconds: 10);

/// How far two lengths may be apart when the credits do not agree.
///
/// A copy whose artist is spelled in another script or under another name is
/// still this recording if it times the same; a cover, a live take and a
/// remix all drift further than this. The value is [TrackIdentity.matches]'
/// own tolerance, so nothing accepted here is looser than the catalog's idea
/// of "the same song".
const matchingDurationTolerance = Duration(seconds: 4);

/// The title alone, normalized the way the fingerprints normalize it.
///
/// Public so a lookup can rank candidates by title without building a whole
/// [TrackIdentity], and so `"Yellow - Live"` and `"Yellow"` meet.
String trackTitleKey(String title) => _normalize(title, isTitle: true);

/// The artist credit as its normalized words, for comparing two credits.
///
/// Not the squeezed fingerprint key: `"Simon & Garfunkel"` and `"Simon
/// Garfunkel"` normalize to the same word set but not to the same letters-run,
/// and a credit one service lists both halves of must still meet the other's
/// shorter one.
Set<String> trackArtistWords(String? artist) {
  final credit = artist ?? '';
  final stripped = _stripDiacritics(
    credit.replaceAll(_featuredRegex, ' '),
  ).toLowerCase();
  return {
    for (final word in stripped.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)))
      if (word.isNotEmpty) word,
  };
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
