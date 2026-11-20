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
import 'lyrics.dart';
import 'lyrics_enricher.dart';
import 'lyrics_query.dart';
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
    required this.queries,
    this.sourceFor,
    LyricsEnricher? enricher,
    this.enricherFor,
  }) : _enricher = enricher;  // ignore: prefer_initializing_formals

  /// A fixed enricher, for tests and for the guest engine. Null in the app,
  /// where [enricherFor] builds one per lookup.
  final LyricsEnricher? _enricher;

  /// Builds the enricher for one lookup — normally one that carries the
  /// opt-in translator when the account has one. Read per call rather than
  /// captured, so picking a model mid-session joins the next lookup without
  /// the long-lived resolver being rebuilt.
  final Future<LyricsEnricher> Function()? enricherFor;

  /// The enricher this lookup uses.
  Future<LyricsEnricher> resolveEnricher() async =>
      _enricher ?? await enricherFor?.call() ?? LyricsEnricher();

  /// Null when the local database could not be opened. Lyrics still resolve;
  /// they are simply fetched again on every play.
  final LibraryCatalog? catalog;
  final LyricsStore? store;

  /// Services that can find words for a song they do not hold, asked in order
  /// after the library. LRCLIB is always first; a connected account that can
  /// answer the same question follows it, so a NetEase-only listener still
  /// gets lyrics for a local file.
  ///
  /// Called per lookup rather than captured: an account connected mid-session
  /// must join the chain without the long-lived resolver being rebuilt.
  final List<LyricsQuerySource> Function() queries;
  final LibrarySource? Function(String sourceId)? sourceFor;

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
    final enricher = await resolveEnricher();
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
        // A layer from the other engine is not a miss: the words and readings
        // are right, only their translation is in the wrong voice. One
        // translation pass replaces it, where a full lookup would walk the
        // network for lyrics it already has.
        final staleEngine =
            stored.lyrics.translationEngine != null &&
            stored.lyrics.translationEngine != enricher.engine &&
            stored.lyrics.translationLanguage == targetLang;
        if (staleEngine || enricher.needsEnrichment(stored.lyrics)) {
          final enriched = staleEngine
              ? await enricher.retranslate(
                  stored.lyrics,
                  targetLanguage: targetLang,
                )
              : await enricher.enrich(
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

    // Each service is asked in turn and the first timed answer wins: a lookup
    // is a network round trip, and a later service having the same words adds
    // nothing. A plain block is kept as a fallback, so a service that only has
    // unsynced text still beats having nothing.
    LyricsHit? timedHit;
    LyricsHit? plainHit;
    var allSettled = true;
    final sources = queries();
    for (final query in sources) {
      final found = await query.findLyrics(song);
      if (!found.settled) allSettled = false;
      final hit = found.result;
      if (hit == null) continue;
      if (hit.lyrics.synced) {
        timedHit = hit;
        break;
      }
      plainHit ??= hit;
    }

    final remote = timedHit ?? plainHit;
    if (remote != null) {
      // A plain block from the library is still a lyric worth keeping; a timed
      // answer from a service only wins because its version follows the audio.
      final useRemote = remote.lyrics.synced || library == null;
      final lyrics = useRemote ? remote.lyrics : library;
      final enriched = await enricher.enrich(
        lyrics,
        targetLanguage: targetLang,
      );
      await remember(
        enriched,
        useRemote ? remote.origin : LyricsOrigin.library,
        remoteId: useRemote ? remote.id : null,
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

    // Only a miss every service confirmed is worth remembering; one that could
    // not be reached must be asked again on the next play.
    if (allSettled && sources.isNotEmpty) {
      await remember(Lyrics.empty, LyricsOrigin.none);
    }
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
    final enricher = await resolveEnricher();
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
