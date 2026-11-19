/// Every JSON answer the libraries return, kept on this device.
///
/// The app is useful without a network because it already remembers what it
/// last saw: the canonical library (songs, lyrics, plays) is the device's own,
/// and this layer adds the *server's* answers on top — the album lists, the
/// playlist pages, the searches, the account digests. A read walks three
/// states, in order:
///
///   1. a fresh entry answers without touching the network;
///   2. the network answers, and its answer replaces the entry;
///   3. the network could not be reached, and the entry that expired is served
///      anyway — the screen shows what it last showed, and the source is
///      reported as offline so the failure is not hidden.
///
/// Only GET is cached. Any write (a star, a like, a playlist edit) drops the
/// whole scope's entries first, so a read after a write can never be answered
/// with the state the write was meant to change.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/local/library_database.dart';
import 'models.dart';

/// How long one answer may be served from disk before the network is asked.
///
/// A duration rather than a name, because the number is the whole policy: a
/// caller says "this is good for an hour" and this layer never guesses what a
/// path means.
enum CachePolicy {
  /// Never stored: a minted playback URL, a random draw, a login poll.
  none(Duration.zero),

  /// Frequently changing reads — recommendations, random draws.
  short(Duration(minutes: 2)),

  /// Library listings: albums, playlists, searches.
  medium(Duration(minutes: 15)),

  /// Answers that do not change while the account does not: lyrics, digests,
  /// the store's own catalogue.
  long(Duration(days: 7));

  const CachePolicy(this.ttl);

  final Duration ttl;
}

/// Where a caller states a policy for one request.
///
/// A key in `RequestOptions.extra`, so an adapter opts one call out without
/// the cache having to learn its URL vocabulary.
const kCachePolicyExtra = 'groovybox.cache.policy';

/// The policy [options] asks for, or [fallback] when it asks for none.
CachePolicy policyOf(RequestOptions options, CachePolicy fallback) {
  final raw = options.extra[kCachePolicyExtra];
  return raw is CachePolicy ? raw : fallback;
}
/// The parameters a request carries for authentication rather than meaning.
///
/// They are stripped from the key so the same answer is one entry after a
/// reconnect (a new salt), and so no credential is written into a key column.
const _credentialParams = {'t', 's', 'u', 'p', 'api_key', 'cookie'};

/// Marks a request that changes the account, even when it is a GET.
///
/// Subsonic stars a song with `/rest/star`, which is a GET like every other
/// Subsonic call, so the verb alone cannot tell a write from a read. An
/// adapter that sends such a write sets this key and the cache drops the
/// library's stored answers before the request goes out.
const kCacheMutationExtra = 'groovybox.cache.mutation';

/// The cache key of one request: scope, method, host and path, and the
/// meaningful query parameters, sorted so two spellings of one query meet.
String cacheKeyFor(String scope, RequestOptions options) =>
    cacheKeyForUri(scope, options.method, options.uri);

/// The same key, for a caller that has a URL rather than a [RequestOptions]
/// (the plugin host performs its own requests).
String cacheKeyForUri(String scope, String method, Uri uri) {
  final params = <String>[
    for (final entry in uri.queryParametersAll.entries)
      if (!_credentialParams.contains(entry.key.toLowerCase()))
        for (final value in entry.value) '${entry.key}=$value',
  ]..sort();
  return '$scope ${method.toUpperCase()} ${uri.host}${uri.path}?'
      '${params.join('&')}';
}

/// Reads and writes the cache table, and serves [Dio] from it.
class ResponseCache {
  ResponseCache(this._db, {this.onServedStale}) {
    // Entries serve as the offline answer long after they expire, but not
    // forever: a two-week-old album list is history, not a library.
    unawaited(
      _db
          .pruneCache(DateTime.now().subtract(const Duration(days: 14)))
          .catchError((Object error) {
            debugPrint('[Cache] Could not prune: $error');
            return 0;
          }),
    );
  }

  final LibraryDatabase _db;
  /// Called once per source that had to answer from disk because it could
  /// not be reached, so Settings can say why the library looks the way it
  /// does.
  final void Function(String scope)? onServedStale;

  /// A [Dio] interceptor for one scope — a connected library's id.
  ///
  /// [fallback] is the policy of every call the adapter did not label, which
  /// is the common case: a source's reads change at one rate, and the few
  /// calls that differ say so at the call site.
  Interceptor interceptorFor(
    String scope, {
    CachePolicy fallback = CachePolicy.medium,
  }) => CachingInterceptor(cache: this, scope: scope, fallback: fallback);

  Future<HttpCacheRow?> read(String key) => _db.cachedResponse(key);

  Future<void> write({
    required String key,
    required Object? body,
    required CachePolicy policy,
  }) async {
    if (policy == CachePolicy.none) return;
    final String encoded;
    try {
      encoded = jsonEncode(body);
    } catch (error) {
      // An answer json cannot carry is not one the app can replay either.
      debugPrint('[Cache] Not stored ($key): $error');
      return;
    }
    final now = DateTime.now();
    await _db.putCachedResponse(
      HttpCacheRow(
        key: key,
        body: encoded,
        storedAt: now,
        expiresAt: now.add(policy.ttl),
        stale: false,
      ),
    );
  }

  /// The answer a [Dio] response would have carried, rebuilt from [row].
  ///
  /// A cache hit has no headers: nothing in the app reads a header off a read
  /// it did not just make, and the ones that mattered (`Set-Cookie`, a login
  /// poll) are calls that are never cached.
  Response<dynamic>? responseOf(HttpCacheRow row, RequestOptions options) {
    try {
      return Response<dynamic>(
        requestOptions: options,
        data: jsonDecode(row.body),
        statusCode: 200,
      );
    } catch (error) {
      debugPrint('[Cache] Unreadable entry ${row.key}: $error');
      return null;
    }
  }

  /// Marks a served-from-disk answer as having been used while the source was
  /// unreachable, so Settings can tell a warm cache from a working server.
  Future<void> markServedStale(String key) =>
      _db.touchCachedResponse(key).catchError((Object error) {
        debugPrint('[Cache] Could not mark stale: $error');
      });

  /// Drops every entry of one library.
  ///
  /// Called before a write is sent: a heart tapped offline must not leave the
  /// list it was in answering with the old state once it is tapped again.
  Future<void> invalidateScope(String scope) =>
      _db.clearScope(scope).catchError((Object error) {
        debugPrint('[Cache] Could not drop $scope: $error');
        return 0;
      });

  /// Forgets everything, for Settings.
  Future<void> clear() => _db.clearCache();

  /// How many answers are held, and how many bytes they take.
  Future<({int count, int bytes})> totals() => _db.cacheTotals();

  /// A cached body for a request the plugin host made itself.
  ///
  /// Plugins ask the host for `{status, headers, body}` rather than going
  /// through a source's client, so they are served by these two calls instead
  /// of an interceptor. A miss, or an expired entry with no fallback asked
  /// for, is null and the request goes out.
  Future<Map<String, dynamic>?> readPerformed(
    String key, {
    required bool allowStale,
  }) async {
    final row = await read(key);
    if (row == null) return null;
    final fresh = !row.expiresAt.isBefore(DateTime.now());
    if (!fresh && !allowStale) return null;
    if (!fresh) unawaited(markServedStale(key));
    try {
      final body = jsonDecode(row.body);
      return body is Map<String, dynamic> ? body : null;
    } catch (error) {
      debugPrint('[Cache] Unreadable entry ${row.key}: $error');
      return null;
    }
  }

  /// Stores an answer the plugin host performed, under the same policy a
  /// source's own calls use.
  Future<void> writePerformed(
    String key,
    Object? body,
    CachePolicy policy,
  ) => write(key: key, body: body, policy: policy);

  /// Tells the listener a source answered from disk because it could not be
  /// reached.
  void _stale(String scope) => onServedStale?.call(scope);
}

/// The [Interceptor] a source installs on its own client.
class CachingInterceptor extends Interceptor {
  CachingInterceptor({
    required this.cache,
    required this.scope,
    required this.fallback,
  });

  final ResponseCache cache;
  final String scope;
  final CachePolicy fallback;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final mutating =
        options.method.toUpperCase() != 'GET' ||
        options.extra[kCacheMutationExtra] == true;
    if (mutating) {
      // A write makes every answer of this library suspect; dropping them is
      // cheaper than tracking which lists a heart touched.
      unawaited(cache.invalidateScope(scope));
      handler.next(options);
      return;
    }
    final policy = policyOf(options, fallback);
    if (policy == CachePolicy.none) {
      handler.next(options);
      return;
    }

    final key = cacheKeyFor(scope, options);
    options.extra['groovybox.cache.key'] = key;
    final row = await cache.read(key);
    if (row == null) {
      handler.next(options);
      return;
    }
    if (!row.expiresAt.isBefore(DateTime.now())) {
      handler.resolve(cache.responseOf(row, options)!);
      return;
    }
    // Expired: the network is asked. `onError` falls back to this row.
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final key = response.requestOptions.extra['groovybox.cache.key'];
    final policy = policyOf(response.requestOptions, fallback);
    final status = response.statusCode ?? 0;
    if (key is String && policy != CachePolicy.none && status ~/ 100 == 2) {
      await cache.write(key: key, body: response.data, policy: policy);
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isUnreachable(err)) {
      handler.next(err);
      return;
    }
    final key = err.requestOptions.extra['groovybox.cache.key'];
    final policy = policyOf(err.requestOptions, fallback);
    if (key is! String || policy == CachePolicy.none) {
      handler.next(err);
      return;
    }
    final row = await cache.read(key);
    final response = row == null
        ? null
        : cache.responseOf(row, err.requestOptions);
    if (response == null) {
      handler.next(err);
      return;
    }
    unawaited(cache.markServedStale(key));
    cache._stale(scope);
    handler.resolve(response);
  }

  /// Whether the failure means "the server could not be reached", as opposed
  /// to "the server answered no".
  ///
  /// A refusal is the server's own word and must surface; a DNS failure, a
  /// timeout or a gateway that has no upstream is the network being gone, and
  /// that is what the cache exists for.
  static bool _isUnreachable(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.unknown => true,
    DioExceptionType.badResponse =>
      const {502, 503, 504}.contains(error.response?.statusCode),
    _ => false,
  };
}

/// The failure a source reports when its answer came from disk.
///
/// Reuses the shape every screen already renders, so the offline state is a
/// banner with an explanation rather than a silent difference.
const offlineCachedFailure = LibraryException(
  'This library could not be reached; showing what was saved.',
  messageKey: 'libraryOfflineCached',
);
