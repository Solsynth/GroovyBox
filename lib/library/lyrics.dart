/// Lyrics, normalized across libraries.
///
/// Two shapes have to fit in one model: timestamped lines that follow the
/// transport, and plain blocks that only scroll by hand. A synced lyric is
/// still just an ordered list where [LyricLine.at] is meaningful; unsynced
/// text is stored with [Lyrics.synced] false and every line at zero, so a view
/// never has to branch on the type.
library;

import 'dart:convert';

import 'models.dart';

/// One sung line, and when it starts.
///
/// [at] is measured from the start of the audio. A blank line between stanzas
/// is kept: it is what lets a synced view breathe instead of turning a chorus
/// into a solid wall of text.
///
/// [pronunciation] and [translation] are the line's own readings, aligned by
/// its time when the server sent them as separate layers. They belong on the
/// line rather than in a parallel list so a view can never drift out of step
/// with the words it is annotating.
class LyricLine {
  final Duration at;
  final String text;
  final String? pronunciation;
  final String? translation;

  const LyricLine(
    this.at,
    this.text, {
    this.pronunciation,
    this.translation,
  });

  LyricLine withLayers({String? pronunciation, String? translation}) =>
      LyricLine(
        at,
        text,
        pronunciation: pronunciation ?? this.pronunciation,
        translation: translation ?? this.translation,
      );
}

/// The lyrics of one song, already ordered by [LyricLine.at].
class Lyrics {
  final List<LyricLine> lines;

  /// Whether [LyricLine.at] came from the file rather than being all zero.
  final bool synced;

  /// Language the server reported, when it did (`'und'`/`'xxx'` when unknown).
  final String? language;

  const Lyrics({required this.lines, required this.synced, this.language});

  static const empty = Lyrics(lines: [], synced: false);

  bool get isEmpty => lines.isEmpty;
}

/// Folds romanized and translated layers onto the words they annotate.
///
/// Layers are independent in the spec — a translation may carry fewer lines
/// than the original — so each line takes the entry whose start is closest to
/// its own within [tolerance]. Anything further away is not a reading of that
/// line and is dropped rather than shown beside the wrong words.
Lyrics mergeLyricLayers({
  required Lyrics main,
  Lyrics? pronunciation,
  Lyrics? translation,
  Duration tolerance = const Duration(milliseconds: 600),
}) {
  if (main.lines.isEmpty) return main;
  if (pronunciation == null && translation == null) return main;

  String? nearest(Lyrics? layer, Duration at) {
    if (layer == null || layer.lines.isEmpty) return null;
    final index = lyricIndexAt(layer.lines, at + tolerance);
    if (index < 0) return null;
    final line = layer.lines[index];
    final gap = (line.at - at).abs();
    if (gap > tolerance) return null;
    final text = line.text.trim();
    return text.isEmpty ? null : text;
  }

  return Lyrics(
    lines: [
      for (final line in main.lines)
        line.withLayers(
          pronunciation: nearest(pronunciation, line.at),
          translation: nearest(translation, line.at),
        ),
    ],
    synced: main.synced,
    language: main.language,
  );
}

/// What a lyrics request needs to identify its song, with value equality.
///
/// A family provider keys on its argument, and [LibrarySong] deliberately has
/// no value equality (the queue compares rows by identity when undoing a
/// shuffle), so the lookup key is this small class instead.
class LyricsRequest {
  final String sourceId;
  final String id;
  final String? artist;
  final String title;

  const LyricsRequest({
    required this.sourceId,
    required this.id,
    required this.title,
    this.artist,
  });

  factory LyricsRequest.of(LibrarySong song) => LyricsRequest(
    sourceId: song.sourceId,
    id: song.id,
    title: song.title,
    artist: song.artist,
  );

  /// The fields a server search needs; duration and album are irrelevant.
  LibrarySong get stub =>
      LibrarySong(sourceId: sourceId, id: id, title: title, artist: artist,
        duration: Duration.zero);

  @override
  bool operator ==(Object other) =>
      other is LyricsRequest &&
      other.sourceId == sourceId &&
      other.id == id &&
      other.artist == artist &&
      other.title == title;

  @override
  int get hashCode => Object.hash(sourceId, id, artist, title);
}

/// Index of the line playing at [position], or -1 before the first one.
///
/// Synced lyrics only; an unsynced block has no notion of "now". Binary search
/// rather than a scan: the dock asks on every position tick, and a karaoke
/// track can carry several hundred lines.
int lyricIndexAt(List<LyricLine> lines, Duration position) {
  if (lines.isEmpty) return -1;
  var low = 0;
  var high = lines.length - 1;
  var found = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (lines[mid].at <= position) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return found;
}

/// Parses LRC (`[mm:ss.xx] text`), including one line with several stamps and
/// the `[offset:+/-ms]` tag.
///
/// Libraries hand back LRC in a few places — a Subsonic `getLyrics` body, a
/// Jellyfin `.lrc` sidecar turned into text — so the timestamp grammar lives
/// here once rather than in each adapter.
Lyrics parseLrc(String raw) {
  final stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  final offsetTag = RegExp(r'^\[offset:\s*([+-]?\d+)\s*\]$', caseSensitive: false);
  var offsetMs = 0;
  final lines = <LyricLine>[];

  for (final rawLine in const LineSplitter().convert(raw)) {
    final line = rawLine.trimRight();
    if (line.isEmpty) continue;

    final offsetMatch = offsetTag.firstMatch(line.trim());
    if (offsetMatch != null) {
      // Same convention as OpenSubsonic: a positive offset makes the lyrics
      // appear sooner, so the model's absolute starts subtract it.
      offsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
      continue;
    }
    final stamps = stamp.allMatches(line).toList();
    if (stamps.isEmpty) {
      // An untagged line is a title, a credit, or a block of plain text.
      lines.add(LyricLine(Duration.zero, line.trim()));
      continue;
    }

    final text = line.substring(stamps.last.end).trim();
    for (final match in stamps) {
      final fraction = match.group(3) ?? '';
      final millis = switch (fraction.length) {
        0 => 0,
        1 => int.parse(fraction) * 100,
        2 => int.parse(fraction) * 10,
        _ => int.parse(fraction.substring(0, 3)),
      };
      final at = Duration(
        minutes: int.parse(match.group(1)!),
        seconds: int.parse(match.group(2)!),
        milliseconds: millis,
      ) - Duration(milliseconds: offsetMs);
      lines.add(LyricLine(at.isNegative ? Duration.zero : at, text));
    }
  }

  final synced = lines.any((line) => line.at != Duration.zero);
  lines.sort((a, b) => a.at.compareTo(b.at));
  return Lyrics(lines: lines, synced: synced);
}
