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
/// answer, and a copy is only adopted when it could be the same recording
/// ([TrackIdentity.couldBeSameRecording]), so a search result of a different
/// recording is never offered as "the same song" — while the same one tagged
/// differently by two services still is.
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
  final credit = [song.artist, song.title].whereType<String>().join(' ');
  final titleOnly = song.title;
  final queries = <String>[
    if (credit.trim().isNotEmpty) credit,
    if (titleOnly.trim().isNotEmpty &&
        titleOnly.trim().toLowerCase() != credit.trim().toLowerCase())
      titleOnly,
  ];
  final identity = TrackIdentity.of(song);
  final results = await Future.wait([
    for (final source in others)
      _findForSource(source, identity, queries),
  ]);

  for (var index = 0; index < others.length; index++) {
    final match = results[index];
    if (match == null) continue;
    bySource[others[index].id] = TrackCopy(
      sourceId: others[index].id,
      externalId: match.id,
      song: match,
    );
  }

  // The source the track was opened from comes first, then the copies whose
  // credit names the same act — a cover of the same length is still a cover —
  // and the rest keep the order the user connected them in. Playback walks
  // this list, so the ranking is what keeps it from opening the stranger.
  final ordered = bySource.values.toList()
    ..sort((a, b) {
      if (a.sourceId == song.sourceId) return -1;
      if (b.sourceId == song.sourceId) return 1;
      final aAgrees = identity.couldBeSameAct(TrackIdentity.of(a.song));
      final bAgrees = identity.couldBeSameAct(TrackIdentity.of(b.song));
      if (aAgrees != bAgrees) return aAgrees ? -1 : 1;
      return 0;
    });
  return ordered;
}

/// One library's search for [wanted], tried query by query.
///
/// The credit-and-title query is asked first because it is precise; the title
/// alone follows only when the first pass found nothing, because a service
/// whose row credits a featured artist the playing row does not name buries
/// the recording under that first query's answers. Stopping on a hit keeps
/// the usual lookup to one request per library.
Future<LibrarySong?> _findForSource(
  LibrarySource source,
  TrackIdentity wanted,
  List<String> queries,
) async {
  for (final query in queries) {
    final match = _bestCopy(wanted, await _searchQuietly(source, query));
    if (match != null) return match;
  }
  return null;
}

/// The row among [candidates] most likely to be [wanted], or null.
///
/// [TrackIdentity.couldBeSameRecording] decides whether a row is the same
/// recording at all; among those a row whose credit names the same act wins
/// over one that is only the same length — a cover credited to somebody else
/// times the record too — and among equals the closest length wins, because
/// that is what tells a studio take from the live one that a search also
/// returns. A row without a length is kept as a last resort rather than
/// dropped: a library that cannot say how long a track is has not thereby said
/// it is a different one.
LibrarySong? _bestCopy(TrackIdentity wanted, List<LibrarySong> candidates) {
  LibrarySong? best;
  var bestActAgrees = false;
  // Null while the best row so far has no length of its own.
  Duration? bestDelta;
  for (final candidate in candidates) {
    final identity = TrackIdentity.of(candidate);
    if (!wanted.couldBeSameRecording(identity)) continue;
    final actAgrees = wanted.couldBeSameAct(identity);
    // Two unknown lengths are no evidence: keep the first row the search
    // ranked, rather than the shortest of them.
    final delta =
        wanted.duration > Duration.zero && identity.duration > Duration.zero
        ? (wanted.duration - identity.duration).abs()
        : null;
    // The same act always beats a stranger; between two of a kind the closer
    // length is the better guess, and a known length beats an unknown one.
    if (best == null ||
        (actAgrees && !bestActAgrees) ||
        (actAgrees == bestActAgrees &&
            delta != null &&
            (bestDelta == null || delta < bestDelta))) {
      best = candidate;
      bestActAgrees = actAgrees;
      bestDelta = delta;
    }
  }
  return best;
}

/// [source]'s copy of [song], if it has one.
///
/// The one-library half of [findCopies], for a caller that already knows where
/// it wants to play the track from: a preferred library being checked before
/// the track opens. The catalog's link to that library answers first — the
/// same row the "other versions" sheet shows — so a preference does not cost a
/// network search on every track; the library is asked only when it has never
/// been seen holding this song. Both answers use the same query and the same
/// [TrackIdentity] rules as [findCopies], so the two can never disagree about
/// whether this library has the track, and a failure is answered as nothing
/// found rather than failing the caller, exactly as the fan-out answers one.
Future<LibrarySong?> findCopyIn(
  LibrarySong song, {
  required LibrarySource source,
  LibraryCatalog? catalog,
}) async {
  if (source.id == song.sourceId) return song;
  if (source is PlatformPlayedSource) return null;
  if (catalog != null) {
    final known = await catalog.copiesOfSong(
      song,
      connectedSourceIds: {source.id},
    );
    for (final copy in known) {
      if (copy.sourceId == source.id) return copy.playable ? copy.song : null;
    }
  }
  // Title and artist, not the album: the copy is usually filed under that
  // library's own release. The credit and title query is precise; the title
  // alone follows only when it found nothing.
  final credit = [song.artist, song.title].whereType<String>().join(' ');
  final queries = <String>[
    if (credit.trim().isNotEmpty) credit,
    if (song.title.trim().isNotEmpty &&
        song.title.trim().toLowerCase() != credit.trim().toLowerCase())
      song.title,
  ];
  return _findForSource(source, TrackIdentity.of(song), queries);
}

/// A library's search for **this recording**, with a failure (thrown now or
/// later) answered as nothing found.
///
/// The wide question, not the holdings one: a copy a library can stream is a
/// candidate whether or not the account ever added it, and a source whose
/// search stops at its own holdings (a server) simply answers the same set
/// either way.
///
/// Playback reaches this when a track has to be found elsewhere, so one
/// library that is down must not cost the answer for the others.
Future<List<LibrarySong>> _searchQuietly(
  LibrarySource source,
  String query,
) async {
  try {
    return await (source is CatalogueSource
        ? source.searchCatalogue(query, limit: 20)
        : source.search(query, limit: 20));
  } catch (error) {
    debugPrint('[Library] lookup on ${source.id}: $error');
    return const [];
  }
}
