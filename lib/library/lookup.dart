/// Finding one song's copies across every connected library.
library;

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'models.dart';
import 'source.dart';
import 'track_identity.dart';

/// Every connected library's copy of [song], the song's own source first.
///
/// Two sources of truth, merged. The catalog knows the copies the app has
/// already seen — instant, offline, and the only way to find a local file. The
/// other libraries are *asked*, because a song this library has but another
/// does not yet show in a browse is exactly the case a lookup is for: a
/// provider that only sells a trial excerpt of a track may well have a
/// neighbour that streams the whole thing.
///
/// A library that cannot be reached contributes nothing instead of failing the
/// answer, and a copy is only adopted when its identity matches
/// ([TrackIdentity.matches]), so a search result of a different recording is
/// never offered as "the same song".
Future<List<TrackCopy>> findCopies(
  LibrarySong song, {
  required Map<String, LibrarySource> sources,
  LibraryCatalog? catalog,
}) async {
  final known = catalog == null
      ? const <TrackCopy>[]
      : await catalog.copiesOfSong(
          song,
          connectedSourceIds: sources.keys.toSet(),
        );
  // The track the user is looking at is always one of the answers, even when
  // the catalog has never seen it: it is the copy they currently have.
  final bySource = {
    song.sourceId: TrackCopy(
      sourceId: song.sourceId,
      externalId: song.id,
      song: song,
      playable: sources.containsKey(song.sourceId),
    ),
    for (final copy in known)
      if (copy.playable) copy.sourceId: copy,
  };

  final others = [
    for (final source in sources.values)
      if (source.id != song.sourceId) source,
  ];
  if (others.isEmpty) return bySource.values.toList();

  // Title and artist, not the album: a copy in another library is usually
  // tagged with that library's own album, and an album match would miss it.
  final query = [song.artist, song.title].whereType<String>().join(' ');
  final identity = TrackIdentity.of(song);
  final results = await Future.wait([
    for (final source in others) _searchQuietly(source, query),
  ]);

  for (var index = 0; index < others.length; index++) {
    final source = others[index];
    if (bySource.containsKey(source.id)) continue;
    final match = results[index]
        .where((candidate) => identity.matches(TrackIdentity.of(candidate)))
        .firstOrNull;
    if (match == null) continue;
    bySource[source.id] = TrackCopy(
      sourceId: source.id,
      externalId: match.id,
      song: match,
    );
  }

  // The source the track was opened from comes first; the rest keep the
  // order the user connected them in.
  final ordered = bySource.values.toList()
    ..sort((a, b) {
      if (a.sourceId == song.sourceId) return -1;
      if (b.sourceId == song.sourceId) return 1;
      return 0;
    });
  return ordered;
}

/// A library's search, with a failure (thrown now or later) answered as
/// nothing found.
///
/// Playback reaches this when a track has to be found elsewhere, so one
/// library that is down must not cost the answer for the others.
Future<List<LibrarySong>> _searchQuietly(
  LibrarySource source,
  String query,
) async {
  try {
    return await source.search(query, limit: 20);
  } catch (error) {
    debugPrint('[Library] lookup on ${source.id}: $error');
    return const [];
  }
}
