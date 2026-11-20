/// Lyrics, normalized across libraries.
///
/// Two shapes have to fit in one model: timestamped lines that follow the
/// transport, and plain blocks that only scroll by hand. A synced lyric is
/// still just an ordered list where [LyricLine.at] is meaningful; unsynced
/// text is stored with [Lyrics.synced] false and every line at zero, so a view
/// never has to branch on the type.
library;

import 'dart:convert';
import 'dart:isolate';

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
  /// Language the translation layer was generated into, when the app added
  /// one (e.g. `'zh-CN'`). Null when the lines carry no generated
  /// translation, or when a server supplied one in a language it did not name.
  final String? translationLanguage;

  /// Which engine wrote the translation layer: `'google'`, `'llm'`, or null
  /// for a layer the app did not generate (a server's own translation).
  ///
  /// Cached with the layer so switching engines re-translates from the stored
  /// words instead of serving the old engine's voice until the row expires.
  final String? translationEngine;

  const Lyrics({
    required this.lines,
    required this.synced,
    this.language,
    this.translationLanguage,
    this.translationEngine,
  });

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
    translationLanguage: main.translationLanguage,
    translationEngine: main.translationEngine,
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

  /// The library's reported length and album, used to disambiguate a match
  /// when a cache or a lyrics service is asked by title and artist.
  final Duration duration;
  final String? album;

  const LyricsRequest({
    required this.sourceId,
    required this.id,
    required this.title,
    this.artist,
    this.duration = Duration.zero,
    this.album,
  });

  factory LyricsRequest.of(LibrarySong song) => LyricsRequest(
    sourceId: song.sourceId,
    id: song.id,
    title: song.title,
    artist: song.artist,
    duration: song.duration,
    album: song.album,
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
      other.title == title &&
      other.duration == duration &&
      other.album == album;

  @override
  int get hashCode =>
      Object.hash(sourceId, id, artist, title, duration, album);
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

/// Past this much raw LRC text the parse moves to a background isolate.
///
/// The grammar is a regex over every line, and a karaoke file can carry
/// several hundred of them: parsing one on the UI isolate costs frames while
/// the lyric pane is animating. Below the threshold the copy out to the
/// isolate and the spawn would cost more than the parse itself.
const int _kParseIsolateThreshold = 8 * 1024;

/// [parseLrc], off the UI isolate when [raw] is big enough to be worth it.
Future<Lyrics> parseLrcAsync(String raw) =>
    raw.length > _kParseIsolateThreshold
    ? Isolate.run(() => parseLrc(raw))
    : Future.value(parseLrc(raw));

/// One timed slot in a prepared lyric timeline: either a sung line or an
/// instrumental interlude between vocal sections.
sealed class LyricTimelineItem {
  final Duration startTime;
  final Duration endTime;

  const LyricTimelineItem({
    required this.startTime,
    required this.endTime,
  });

  /// Normalized progress (`0.0` to `1.0`) across `[startTime, endTime]` at
  /// [position].
  double progressAt(Duration position) {
    final spanUs = (endTime - startTime).inMicroseconds;
    if (spanUs <= 0) return position >= startTime ? 1.0 : 0.0;
    final elapsedUs = (position - startTime).inMicroseconds;
    return (elapsedUs / spanUs).clamp(0.0, 1.0);
  }
}

/// A sung lyric line with its resolved `[startTime, endTime]` window.
class LyricLineEntry extends LyricTimelineItem {
  final LyricLine line;

  const LyricLineEntry({
    required this.line,
    required super.startTime,
    required super.endTime,
  });
}

/// An instrumental gap rendered as three sequential breathing dots.
class LyricInterludeEntry extends LyricTimelineItem {
  const LyricInterludeEntry({
    required super.startTime,
    required super.endTime,
  });
}

/// Minimum leading instrumental gap before the first vocal line that receives
/// an interlude indicator.
const Duration kLeadingInterludeThreshold = Duration(seconds: 3);

/// Minimum instrumental gap between two vocal lines that receives an interlude
/// indicator.
const Duration kInterludeGapThreshold = Duration(seconds: 4);

/// Converts parsed [lyrics] into a display timeline with explicit line end
/// times and injected [LyricInterludeEntry] items for instrumental breaks.
///
/// Unsynced lyrics are returned as plain [LyricLineEntry] items without
/// interludes.
List<LyricTimelineItem> buildLyricTimeline(
  Lyrics lyrics, {
  Duration? trackDuration,
}) {
  if (lyrics.lines.isEmpty) return const [];
  if (!lyrics.synced) {
    return [
      for (final line in lyrics.lines)
        LyricLineEntry(
          line: line,
          startTime: Duration.zero,
          endTime: Duration.zero,
        ),
    ];
  }

  final raw = lyrics.lines;
  final sungEntries = <LyricLineEntry>[];

  for (var i = 0; i < raw.length; i++) {
    final line = raw[i];
    if (line.text.trim().isEmpty) continue;

    // Look ahead for the next non-empty vocal line and any explicit blank
    // timestamped end marker between them.
    Duration? explicitEnd;
    LyricLine? nextSung;
    for (var j = i + 1; j < raw.length; j++) {
      final candidate = raw[j];
      if (candidate.text.trim().isEmpty) {
        if (explicitEnd == null && candidate.at > line.at) {
          explicitEnd = candidate.at;
        }
        continue;
      }
      nextSung = candidate;
      break;
    }

    Duration endTime;
    if (explicitEnd != null) {
      endTime = explicitEnd;
    } else if (nextSung != null) {
      final gap = nextSung.at - line.at;
      final estimatedVocal = Duration(
        milliseconds: (2600 + line.text.trim().length * 110).clamp(4000, 6500),
      );
      if (gap >= estimatedVocal + kInterludeGapThreshold) {
        endTime = line.at + estimatedVocal;
      } else {
        endTime = nextSung.at;
      }
    } else {
      if (trackDuration != null && trackDuration > line.at) {
        final remaining = trackDuration - line.at;
        endTime = remaining <= const Duration(seconds: 10)
            ? trackDuration
            : line.at + const Duration(seconds: 6);
      } else {
        endTime = line.at + const Duration(seconds: 5);
      }
    }

    if (endTime < line.at) endTime = line.at;

    sungEntries.add(
      LyricLineEntry(
        line: line,
        startTime: line.at,
        endTime: endTime,
      ),
    );
  }

  if (sungEntries.isEmpty) return const [];

  final timeline = <LyricTimelineItem>[];
  if (sungEntries.first.startTime >= kLeadingInterludeThreshold) {
    timeline.add(
      LyricInterludeEntry(
        startTime: Duration.zero,
        endTime: sungEntries.first.startTime,
      ),
    );
  }

  for (var i = 0; i < sungEntries.length; i++) {
    final entry = sungEntries[i];
    timeline.add(entry);
    if (i + 1 < sungEntries.length) {
      final next = sungEntries[i + 1];
      final gap = next.startTime - entry.endTime;
      if (gap >= kInterludeGapThreshold) {
        timeline.add(
          LyricInterludeEntry(
            startTime: entry.endTime,
            endTime: next.startTime,
          ),
        );
      }
    }
  }

  return timeline;
}

/// Binary-searches [items] for the active timeline item at [position], or `-1`
/// when [position] precedes the first item.
int timelineIndexAt(List<LyricTimelineItem> items, Duration position) {
  if (items.isEmpty) return -1;
  var low = 0;
  var high = items.length - 1;
  var found = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (items[mid].startTime <= position) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return found;
}
