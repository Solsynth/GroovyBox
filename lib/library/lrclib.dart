/// LRCLIB: a community lyrics database with a plain HTTP API.
///
/// Used when the library has nothing for a track, and preferred over the
/// library when the library only has an unsynced block and LRCLIB has a timed
/// one. The API needs no key; the client identifies itself and keeps to one
/// request at a time with a short gap, because LRCLIB is a free service shared
/// by everyone.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'lyrics.dart';

/// A resolved lyric from LRCLIB.
class LrclibResult {
  final Lyrics lyrics;

  /// LRCLIB's record id, for naming the row a lyric came from.
  final int id;

  const LrclibResult({required this.lyrics, required this.id});
}

/// One lookup's outcome.
///
/// [settled] separates "there is no such lyric" from "we could not find out":
/// a timeout or a rate limit must not be cached as an answer, or a track that
/// LRCLIB does have would stay blank until the entry expired.
class LrclibLookup {
  final LrclibResult? result;
  final bool settled;

  const LrclibLookup({required this.result, required this.settled});

  static const unknown = LrclibLookup(result: null, settled: false);
  static const missing = LrclibLookup(result: null, settled: true);
}

/// Client for `https://lrclib.net`.
class Lrclib {
  Lrclib({Dio? dio, this.identity = defaultIdentity})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://lrclib.net',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              responseType: ResponseType.json,
              headers: {
                'User-Agent': identity,
                'Accept': 'application/json',
              },
              // A 404 is the API's "no such track"; it is read from the
              // response rather than thrown. Only 5xx is a transport failure.
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  /// LRCLIB asks every client to name itself and to leave a way to be reached.
  static const defaultIdentity =
      'GroovyBox/0.1.0 (+https://github.com/littlesheep/GroovyBox)';

  /// Records further apart than this are a different recording even when the
  /// title and artist match: live takes, remasters and edits all collide.
  static const durationTolerance = Duration(seconds: 3);

  /// Gap between requests, as the API docs ask for.
  static const requestGap = Duration(milliseconds: 250);

  final Dio _dio;
  final String identity;

  /// Requests are chained so the next one starts only after the last answer
  /// plus [requestGap]; two lyrics requests in flight at once would double the
  /// rate-limit cost for no benefit.
  Future<void> _queue = Future.value();
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// Set from `Retry-After` on a 429; nothing is sent until it passes.
  DateTime? _blockedUntil;

  /// Looks up one song.
  Future<LrclibLookup> find(LyricsRequest song) {
    final title = song.title.trim();
    final artist = song.artist?.trim();
    if (title.isEmpty || artist == null || artist.isEmpty) {
      return Future.value(LrclibLookup.missing);
    }

    return _serialized(LrclibLookup.unknown, () async {
      final exact = await _get(song);
      if (exact.result != null) return exact;

      // `/api/get` only answers when the duration is within ±2s of its row,
      // and a library's reported length can be off by more than that. Search
      // is also the only path when the duration is unknown.
      final search = await _search(title, artist);
      final best = _best(search.rows, song.duration);
      if (best == null) {
        return LrclibLookup(result: null, settled: exact.settled && search.settled);
      }
      return LrclibLookup(result: _toResult(best), settled: true);
    });
  }

  /// Runs [task] after the previous request and the gap, or returns [fallback]
  /// while a rate limit is in force.
  Future<T> _serialized<T>(T fallback, Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      if (_isBlocked) {
        completer.complete(fallback);
        return;
      }
      final wait = _lastRequest.add(requestGap).difference(DateTime.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      try {
        completer.complete(await task());
      } catch (_) {
        // Covered by [_send] for HTTP; this catches a malformed response.
        completer.complete(fallback);
      } finally {
        _lastRequest = DateTime.now();
      }
    });
    return completer.future;
  }

  /// `/api/get` — the exact-signature lookup.
  Future<LrclibLookup> _get(LyricsRequest song) async {
    final seconds = _seconds(song.duration);
    final album = song.album?.trim();
    final response = await _send('/api/get', {
      'track_name': song.title.trim(),
      'artist_name': song.artist!.trim(),
      if (album != null && album.isNotEmpty) 'album_name': album,
      'duration': ?seconds,
    });
    // A rate limit is not an answer: LRCLIB may well have this lyric, it just
    // would not tell us now, so the caller must not cache a miss.
    if (response == null || response.statusCode == 429) {
      return LrclibLookup.unknown;
    }
    if (response.statusCode != 200) return LrclibLookup.missing;
    final body = response.data;
    if (body is! Map) return LrclibLookup.unknown;
    final result = _toResult(body);
    // An instrumental is a real answer: LRCLIB knows the track has no words.
    return result == null
        ? LrclibLookup.missing
        : LrclibLookup(result: result, settled: true);
  }

  /// `/api/search` — keywords, then a local pick. At most 20 rows, no paging.
  Future<_SearchOutcome> _search(String title, String artist) async {
    final response = await _send('/api/search', {
      'track_name': title,
      'artist_name': artist,
    });
    if (response == null || response.statusCode == 429) {
      return const _SearchOutcome(rows: [], settled: false);
    }
    if (response.statusCode != 200) {
      return const _SearchOutcome(rows: [], settled: true);
    }
    final body = response.data;
    if (body is! List) return const _SearchOutcome(rows: [], settled: false);
    return _SearchOutcome(
      rows: [
        for (final entry in body)
          if (entry is Map) entry,
      ],
      settled: true,
    );
  }

  /// The row a search should hand back, or null when none is close enough.
  ///
  /// A timed lyric beats a plain one; among equals the closest runtime wins.
  /// When the runtime is unknown a lone candidate is accepted and a tie is
  /// not: the wrong song's words are worse than none.
  Map? _best(List<Map> results, Duration duration) {
    final known = duration > Duration.zero;
    Map? best;
    var bestScore = -1.0;
    for (final row in results) {
      final synced = _text(row['syncedLyrics']);
      final plain = _text(row['plainLyrics']);
      if (row['instrumental'] == true || (synced == null && plain == null)) {
        continue;
      }

      var score = synced != null ? 2.0 : 1.0;
      if (known) {
        final rowSeconds = (row['duration'] as num?)?.toDouble();
        if (rowSeconds == null) continue;
        final gapMs =
            ((rowSeconds * 1000).round() - duration.inMilliseconds).abs();
        if (gapMs > durationTolerance.inMilliseconds) continue;
        score += 1 - gapMs / durationTolerance.inMilliseconds;
      }
      if (score > bestScore) {
        bestScore = score;
        best = row;
      }
    }
    if (best != null || known) return best;
    return results.length == 1 ? _firstWithWords(results) : null;
  }

  static Map? _firstWithWords(List<Map> rows) {
    for (final row in rows) {
      if (row['instrumental'] == true) continue;
      if (_text(row['syncedLyrics']) != null ||
          _text(row['plainLyrics']) != null) {
        return row;
      }
    }
    return null;
  }

  /// Maps one record onto [Lyrics]; timed text wins over plain.
  LrclibResult? _toResult(Map row) {
    if (row['instrumental'] == true) return null;
    final id = (row['id'] as num?)?.toInt() ?? 0;

    final timed = _text(row['syncedLyrics']);
    if (timed != null) {
      final lyrics = parseLrc(timed);
      if (!lyrics.isEmpty) return LrclibResult(lyrics: lyrics, id: id);
    }
    final plain = _text(row['plainLyrics']);
    if (plain != null) {
      final lyrics = _plain(plain);
      if (!lyrics.isEmpty) return LrclibResult(lyrics: lyrics, id: id);
    }
    return null;
  }

  /// A plain block, with blank lines kept as the stanza breaks they are.
  static Lyrics _plain(String raw) {
    final lines = [
      for (final line in raw.split('\n')) LyricLine(Duration.zero, line.trim()),
    ];
    while (lines.isNotEmpty && lines.last.text.isEmpty) {
      lines.removeLast();
    }
    return Lyrics(lines: lines, synced: false);
  }

  /// Sends one request, recording a rate limit instead of retrying into it.
  Future<Response<dynamic>?> _send(
    String path,
    Map<String, Object> query,
  ) async {
    // A 429 on the first half of a lookup must not be followed by the second:
    // that is exactly the behaviour the retry-after header exists to stop.
    if (_isBlocked) return null;
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      if (response.statusCode == 429) {
        _blockedUntil = DateTime.now().add(_retryAfter(response.headers));
      }
      return response;
    } on DioException catch (error) {
      final response = error.response;
      if (response?.statusCode == 429) {
        _blockedUntil = DateTime.now().add(_retryAfter(response!.headers));
      }
      return null;
    }
  }

  bool get _isBlocked {
    final blocked = _blockedUntil;
    return blocked != null && blocked.isAfter(DateTime.now());
  }

  /// `Retry-After` seconds plus up to 30% jitter, as the docs prescribe.
  static Duration _retryAfter(Headers headers) {
    final raw = headers.value('retry-after');
    final seconds = int.tryParse(raw?.trim() ?? '') ?? 30;
    final jitter = math.Random().nextDouble() * seconds * 0.3;
    return Duration(
      milliseconds: (seconds * 1000 + jitter * 1000).round(),
    );
  }

  /// LRCLIB accepts 1–3600 whole seconds; anything else is left out.
  static int? _seconds(Duration duration) {
    final seconds = duration.inSeconds;
    return seconds >= 1 && seconds <= 3600 ? seconds : null;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _SearchOutcome {
  final List<Map> rows;
  final bool settled;

  const _SearchOutcome({required this.rows, required this.settled});
}
