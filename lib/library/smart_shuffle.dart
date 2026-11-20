/// The smart shuffle: what to play next, drawn from the tracks this device
/// loves, holds and is being recommended, arranged by genre and mood.
///
/// Pure planning, no Riverpod and no database: the caller hands over what it
/// knows, and this decides the queue and the groups. Keeping it a function
/// makes the interview rules (score, dedupe, artist spacing) testable without
/// a library or a fake adapter.
library;

import 'dart:math';

import 'models.dart';
import 'track_identity.dart';

/// The feel of a genre, for the grouping the page shows.
///
/// Five buckets rather than a taxonomy: the point is to mix a queue out of
/// different moods, and a listener recognises "chill" and "energetic" far
/// faster than a sub-genre they would have to read.
enum ShuffleMood { energetic, chill, melancholy, romantic, focus, festive }

/// A genre's mood. Matched on the genre's words, because services spell their
/// genres differently ("R&B/Soul", "Alternative Rock", "Lo-Fi Hip Hop").
///
/// Order matters: a compound genre takes the first bucket that names it, so
/// "Holiday Rock" is festive before it is energetic and "Rock Ballad" is
/// melancholy before it is rock.
ShuffleMood? moodForGenre(String? genre) {
  final words = (genre ?? '').toLowerCase();
  if (words.isEmpty) return null;
  bool has(String stem) => words.contains(stem);

  // Checked in this order so a compound genre lands where its character is:
  // "Holiday Rock" is festive, "Ambient Techno" is chill, "Jazz Funk" is
  // chill rather than energetic.
  if (has('holiday') || has('christmas') || has('festive')) {
    return ShuffleMood.festive;
  }
  if (has('ambient') ||
      has('chill') ||
      has('lofi') ||
      has('lo-fi') ||
      has('downtempo') ||
      has('lounge') ||
      has('acoustic') ||
      has('folk') ||
      has('bossa') ||
      has('jazz') ||
      has('easy')) {
    return ShuffleMood.chill;
  }
  if (has('classical') ||
      has('instrumental') ||
      has('soundtrack') ||
      has('piano') ||
      has('meditation') ||
      has('new age')) {
    return ShuffleMood.focus;
  }
  // Ballads before rock: "Rock Ballad" is a sad song with a guitar, and a
  // listener grouping by mood would file it there.
  if (has('ballad') ||
      has('blues') ||
      has('sad') ||
      has('indie') ||
      has('gospel')) {
    return ShuffleMood.melancholy;
  }
  if (has('r&b') ||
      has('rnb') ||
      has('soul') ||
      has('romance') ||
      has('romantic') ||
      has('love') ||
      has('vocal')) {
    return ShuffleMood.romantic;
  }
  if (has('rock') ||
      has('metal') ||
      has('punk') ||
      has('electronic') ||
      has('edm') ||
      has('dance') ||
      has('house') ||
      has('techno') ||
      has('drum') ||
      has('hip hop') ||
      has('hip-hop') ||
      has('rap') ||
      has('pop') ||
      has('funk') ||
      has('upbeat')) {
    return ShuffleMood.energetic;
  }
  return null;
}

/// One recording the shuffle may consider, with what the device knows about
/// it. [plays] is the play history's count; [recentlyPlayed] keeps a track
/// from landing twice in a row across shuffles.
class ShuffleSeed {
  final LibrarySong song;
  final bool favourite;
  final bool recommended;
  final int plays;
  final bool recentlyPlayed;

  const ShuffleSeed({
    required this.song,
    this.favourite = false,
    this.recommended = false,
    this.plays = 0,
    this.recentlyPlayed = false,
  });

  String get fingerprint =>
      trackBaseFingerprint(title: song.title, artist: song.artist);
}

/// Which question a group answers: "what do I have in this genre" or "what
/// do I have for this mood".
enum ShuffleGroupKind { genre, mood }

/// One row the page draws: a name and the tracks that answer it.
class ShuffleGroup {
  final String title;
  final ShuffleGroupKind kind;
  final List<LibrarySong> songs;

  const ShuffleGroup({
    required this.title,
    required this.kind,
    required this.songs,
  });
}

/// The planned mix: the queue to hand the transport, and the groups to show.
class SmartShuffle {
  final List<LibrarySong> queue;
  final List<ShuffleGroup> groups;

  const SmartShuffle({this.queue = const [], this.groups = const []});

  bool get isEmpty => queue.isEmpty;
}

/// Plans a mix from [seeds].
///
/// The rules, in order:
/// - One copy of a recording: two libraries' copies are one song, and its
///   signals add up rather than competing.
/// - Score: a heart outranks a recommendation, which outranks a plain library
///   row; play count adds taste, a recent play subtracts, so the mix rotates
///   instead of replaying yesterday's queue.
/// - Selection: the best [size] songs, walked with the seed so a second press
///   explores a different slice of an equally-scored library.
/// - Queue order: no two tracks by the same artist back to back while another
///   artist remains, so the shuffle does not become an album.
/// - Groups: all genres and moods with at least [minimumGroupSize] songs, the
///   largest first, capped — a view of the same selection, not a second queue.
SmartShuffle planSmartShuffle(
  List<ShuffleSeed> seeds, {
  int size = 60,
  int seed = 0,
  int minimumGroupSize = 3,
  int maxGenreGroups = 6,
  int maxMoodGroups = 3,
}) {
  if (seeds.isEmpty || size <= 0) return const SmartShuffle();
  final random = Random(seed);

  // Merge copies: the same recording named by two libraries is one entry,
  // and its signals add rather than compete. The copy seen first keeps the
  // song fields — they describe the same recording — so a merged row does not
  // rename itself by whichever link happened to be scanned last.
  final merged = <String, _Scored>{};
  for (final entry in seeds) {
    final song = entry.song;
    if (song.isRadio) continue;
    final key = entry.fingerprint;
    final existing = merged[key];
    final mergedSeed = ShuffleSeed(
      song: existing?.seed.song ?? song,
      favourite: entry.favourite || (existing?.seed.favourite ?? false),
      recommended: entry.recommended || (existing?.seed.recommended ?? false),
      plays: (existing?.seed.plays ?? 0) + entry.plays,
      recentlyPlayed:
          entry.recentlyPlayed || (existing?.seed.recentlyPlayed ?? false),
    );
    merged[key] = _Scored(
      seed: mergedSeed,
      // The jitter breaks ties between equally-liked songs, so a second
      // press with another seed walks a different slice of the library.
      score: _score(mergedSeed) + random.nextInt(3),
    );
  }

  final scored = merged.values.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.artistKey.compareTo(b.artistKey);
    });

  // The queue: the best [size] songs, placed so no artist repeats back to
  // back while another artist still has a song waiting. Score decides who is
  // in the mix; this only decides the running order, which keeps a library
  // heavy in one artist from reading as that artist's album.
  final remaining = scored.take(size).toList();
  final selection = <_Scored>[];
  String? lastArtist;
  while (remaining.isNotEmpty) {
    final pick = remaining.firstWhere(
      (candidate) => candidate.artistKey != lastArtist,
      orElse: () => remaining.first,
    );
    remaining.remove(pick);
    selection.add(pick);
    lastArtist = pick.artistKey;
  }

  final songs = [for (final entry in selection) entry.seed.song];
  return SmartShuffle(
    queue: songs,
    groups: _groups(
      songs,
      minimumGroupSize: minimumGroupSize,
      maxGenreGroups: maxGenreGroups,
      maxMoodGroups: maxMoodGroups,
    ),
  );
}

List<ShuffleGroup> _groups(
  List<LibrarySong> songs, {
  required int minimumGroupSize,
  required int maxGenreGroups,
  required int maxMoodGroups,
}) {
  final genres = <String, List<LibrarySong>>{};
  final moods = <ShuffleMood, List<LibrarySong>>{};
  for (final song in songs) {
    final genre = song.genre?.trim();
    if (genre != null && genre.isNotEmpty) {
      genres.putIfAbsent(genre, () => []).add(song);
    }
    final mood = moodForGenre(genre);
    if (mood != null) moods.putIfAbsent(mood, () => []).add(song);
  }

  final genreGroups = [
    for (final entry in genres.entries)
      if (entry.value.length >= minimumGroupSize)
        ShuffleGroup(
          title: entry.key,
          kind: ShuffleGroupKind.genre,
          songs: entry.value,
        ),
  ]..sort((a, b) => b.songs.length.compareTo(a.songs.length));

  final moodGroups = [
    for (final entry
        in (moods.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length))))
      if (entry.value.length >= minimumGroupSize)
        ShuffleGroup(
          // The page translates the mood; the group carries the bucket, not a
          // word, so the same plan works in any language.
          title: entry.key.name,
          kind: ShuffleGroupKind.mood,
          songs: entry.value,
        ),
  ];

  // Two caps, not one: a genre-rich library must not crowd the moods out, and
  // each list is already sorted by how much it has to say.
  return [
    ...genreGroups.take(maxGenreGroups),
    ...moodGroups.take(maxMoodGroups),
  ];
}

/// The taste score. Weights are relative, not absolute: the ordering they
/// produce is what the page promises, and a change here is a change of that
/// promise.
int _score(ShuffleSeed seed) {
  var score = 5;
  if (seed.favourite) score += 40;
  if (seed.recommended) score += 25;
  score += min(seed.plays, 10) * 3;
  if (seed.recentlyPlayed) score -= 20;
  return score;
}

class _Scored {
  final ShuffleSeed seed;
  final int score;

  const _Scored({required this.seed, required this.score});

  String get artistKey =>
      (seed.song.artist ?? seed.song.albumArtist ?? '').trim().toLowerCase();
}
