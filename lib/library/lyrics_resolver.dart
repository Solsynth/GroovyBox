/// Where a song's lyrics come from, and in what order.
///
/// The library is asked first — it is the server the user already pays for and
/// its lyrics are usually the ones that line up with the master it streams —
/// but only the cache and LRCLIB can turn a timed lyric into a *better* timed
/// lyric, so the preferences are:
///
///   1. a stored answer, whatever its origin;
///   2. the library's own lyrics, if it produced timed lines;
///   3. LRCLIB, whose records are vetted and usually timed;
///   4. the library's plain block, when LRCLIB had nothing.
///
/// Every answer is written to the local library, including "nobody has it", so
/// a replay never walks the network again. Nothing here throws: a lyrics pane
/// with no words is a normal state, and a dead server must not turn it into an
/// error card.
library;

import 'catalog.dart';
import 'lrclib.dart';
import 'lyrics.dart';
import 'lyrics_enricher.dart';
import 'lyrics_store.dart';
import 'source.dart';

/// Resolves one song's lyrics through the local library and then the network.
///
/// Storage is keyed by the canonical track, not by the `(source, id)` pair a
/// request carries: a second server with the same song, or the same server
/// after a re-tag, finds the words that were already fetched.
class LyricsResolver {
  LyricsResolver({
    required this.catalog,
    required this.store,
    required this.lrclib,
    this.sourceFor,
    LyricsEnricher? enricher,
  }) : enricher = enricher ?? LyricsEnricher();

  /// Null when the local database could not be opened. Lyrics still resolve;
  /// they are simply fetched again on every play.
  final LibraryCatalog? catalog;
  final LyricsStore? store;
  final Lrclib lrclib;
  final LibrarySource? Function(String sourceId)? sourceFor;
  final LyricsEnricher enricher;

  /// The library's answer, or null when it has none or cannot be reached.
  Future<Lyrics?> _fromLibrary(LyricsRequest song) async {
    final source = sourceFor?.call(song.sourceId);
    if (source == null) return null;
    try {
      final lyrics = await source.lyrics(song.stub);
      return lyrics.isEmpty ? null : lyrics;
    } catch (_) {
      return null;
    }
  }

  /// The track the request is about, or null when nothing can be stored.
  Future<int?> _trackId(LyricsRequest song) async {
    final database = catalog;
    if (database == null) return null;
    try {
      return await database.requestTrackId(song);
    } catch (_) {
      // A database that refuses a write must not cost the user their lyrics.
      return null;
    }
  }

  /// The song's lyrics, never failing and never returning null.
  ///
  /// [refresh] skips the stored answer for this call: the user asked for the
  /// lyrics again because the ones on screen are wrong.
  Future<Lyrics> resolve(
    LyricsRequest song, {
    bool refresh = false,
    String? languageCode,
  }) async {
    final trackId = await _trackId(song);
    // One target for the whole call, so the cache key it reads with is the
    // same one it writes with.
    final targetLang = languageCode == null
        ? null
        : LyricsEnricher.targetLanguageFor(languageCode);

    if (!refresh && trackId != null) {
      final stored = await store?.read(
        trackId,
        translationLanguage: targetLang,
      );
      if (stored != null) {
        if (enricher.needsEnrichment(stored.lyrics)) {
          final enriched = await enricher.enrich(
            stored.lyrics,
            targetLanguage: targetLang,
          );
          await store?.write(
            trackId,
            enriched,
            origin: stored.origin,
            remoteId: stored.remoteId,
          );
          return enriched;
        }
        return stored.lyrics;
      }
    }

    Future<void> remember(Lyrics lyrics, LyricsOrigin origin, {int? remoteId}) async {
      if (trackId == null) return;
      await store?.write(
        trackId,
        lyrics,
        origin: origin,
        remoteId: remoteId,
      );
    }

    final library = await _fromLibrary(song);
    if (library != null && library.synced) {
      final enriched = await enricher.enrich(
        library,
        targetLanguage: targetLang,
      );
      await remember(enriched, LyricsOrigin.library);
      return enriched;
    }

    final found = await lrclib.find(song);
    final remote = found.result?.lyrics;
    if (remote != null) {
      // A plain block from the library is still a lyric worth keeping; LRCLIB
      // only wins because its version is timed.
      final useRemote = remote.synced || library == null;
      final lyrics = useRemote ? remote : library;
      final enriched = await enricher.enrich(
        lyrics,
        targetLanguage: targetLang,
      );
      await remember(
        enriched,
        useRemote ? LyricsOrigin.lrclib : LyricsOrigin.library,
        remoteId: useRemote ? found.result?.id : null,
      );
      return enriched;
    }

    if (library != null) {
      final enriched = await enricher.enrich(
        library,
        targetLanguage: targetLang,
      );
      await remember(enriched, LyricsOrigin.library);
      return enriched;
    }

    // Only a miss the service confirmed is worth remembering; an offline
    // answer must be asked again on the next play.
    if (found.settled) await remember(Lyrics.empty, LyricsOrigin.none);
    return Lyrics.empty;
  }

  /// Forgets one song so the next play asks the network again.
  Future<void> forget(LyricsRequest song) async {
    final trackId = await _trackId(song);
    if (trackId != null) await store?.remove(trackId);
  }

  /// Stores the lyrics the user chose by hand for [song], displacing whatever
  /// was there: an automatic fetch must never overwrite a deliberate choice.
  ///
  /// [languageCode] feeds the translation pass, so picking a lyric writes the
  /// same enriched rows a play-time fetch would have.
  Future<Lyrics> adopt(
    LyricsRequest song,
    Lyrics lyrics, {
    String? languageCode,
  }) async {
    final trackId = await _trackId(song);
    final targetLang = languageCode == null
        ? null
        : LyricsEnricher.targetLanguageFor(languageCode);
    final enriched = await enricher.enrich(
      lyrics,
      targetLanguage: targetLang,
    );
    if (trackId != null) {
      await store?.write(trackId, enriched, origin: LyricsOrigin.manual);
    }
    return enriched;
  }

}
