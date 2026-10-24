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
