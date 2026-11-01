import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Format a duration the way a player does: `m:ss`, or `h:mm:ss` past an hour.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  }
  return '$minutes:$paddedSeconds';
}

/// Total time listened, in the units a person would say it in.
///
/// Play history adds up to hours fast, so seconds are dropped past a minute
/// and minutes past an hour: "3 h 12 min" is the useful part of 3:12:47.
String formatListeningTime(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return duration.inSeconds < 1 ? 'Nothing yet' : 'Under a minute';
  if (minutes < 60) return '$minutes min';
  final hours = duration.inHours;
  final rest = minutes.remainder(60);
  if (hours < 24) return rest == 0 ? '$hours h' : '$hours h $rest min';
  final days = duration.inDays;
  final dayHours = hours.remainder(24);
  return dayHours == 0 ? '$days d' : '$days d $dayHours h';
}

/// `1 play` / `12 plays`.
String formatPlayCount(int plays) => '$plays ${plays == 1 ? 'play' : 'plays'}';

/// When something happened, as a person would say it.
///
/// Days rather than hours past yesterday: a play history is read at the scale
/// of a week, and "17 hours ago" makes the reader do the arithmetic.
String formatRelativeTime(DateTime at, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final elapsed = reference.difference(at);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';

  // Calendar days, not 24-hour spans: a play at 23:00 and a look at 01:00 are
  // "yesterday", even though barely two hours passed.
  final days = DateTime(
    reference.year,
    reference.month,
    reference.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 30) {
    final weeks = days ~/ 7;
    return weeks == 1 ? 'Last week' : '$weeks weeks ago';
  }
  if (days < 365) {
    final months = days ~/ 30;
    return months == 1 ? 'Last month' : '$months months ago';
  }
  final years = days ~/ 365;
  return years == 1 ? 'Last year' : '$years years ago';
}

/// A song row's second line: the usual subtitle, plus the library name when
/// the track carries no album and several libraries are connected.
///
/// With one library the name is noise; with several it is the only way to tell
/// two identically-titled tracks apart.
String songRowSubtitle(WidgetRef ref, LibrarySong song) =>
    song.album == null
    ? '${song.subtitle}${sourceSuffix(ref, song.sourceId) ?? ''}'
    : song.subtitle;

/// `' · <library name>'`, or null when only one library is connected.
///
/// With a single server the name is noise on every row; with several it is the
/// only way to tell two identically-titled tracks apart.
String? sourceSuffix(WidgetRef ref, String sourceId) {
  final sources = ref.watch(librarySourcesProvider);
  if (sources.length < 2) return null;
  final source = ref.watch(librarySourceByIdProvider)[sourceId];
  if (source == null) return null;
  return '  ·  ${source.displayName}';
}
