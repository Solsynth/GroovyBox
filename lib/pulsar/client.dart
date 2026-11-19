/// The Pulsar HTTP client, over the same Dio conventions as
/// [SolarpassClient] and the library sync client.
///
/// Blade maps `/pulsar/*` to Pulsar's `/api/*`, so every path here names the
/// gateway prefix and never the service's own. Lists come back as bare
/// arrays with the total in the `X-Total` header.
library;

import 'package:dio/dio.dart';

import '../core/identity.dart';
import '../library/models.dart';
import '../solarpass/models.dart';
import 'metadata.dart';
import 'models.dart';

/// The stable identity GroovyBox sends for one track, scoped to its source.
///
/// A [LibrarySong.id] is only unique inside the library it came from; two
/// servers can hand out the same number. Every catalog write the fleet sees
/// — share links, playlist items, scrobbles — uses this as `provider_key`,
/// so the same recording dedupes to one entry and two different ones never
/// merge.
String pulsarTrackKey(LibrarySong song) => '${song.sourceId}:${song.id}';

class PulsarClient {
  PulsarClient({required this.dio, required String baseUrl})
    : _basePath = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/pulsar',
      _siteBase = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _shareBase = _shareBaseOf(baseUrl);

  final Dio dio;
  final String _basePath;

  /// The API root everything but the share page hangs off — Pulsar's routes
  /// and the Stargate endpoints this client reads.
  final String _siteBase;

  /// The public site the share page lives on, derived by [_shareBaseOf]:
  /// `mu.solian.app` where the API says `api.solian.app`. Blade routes
  /// `/m/:id` straight through to Pulsar with no auth.
  final String _shareBase;

  /// Rewrites an `api.`-prefixed API host into the public share host; any
  /// other base passes through unchanged.
  static String _shareBaseOf(String apiBase) {
    final base = apiBase.replaceAll(RegExp(r'/+$'), '');
    final match = RegExp(r'^(https?://)api\.(.+)').firstMatch(base);
    return match == null ? base : '${match.group(1)}mu.${match.group(2)}';
  }

  Map<String, String> _headers(OAuthSession session) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': appUserAgent,
    'Authorization': '${session.tokenType} ${session.accessToken}',
  };

  // ── Playlists (Pulsar collections, kind playlist) ──────────────────────

  /// The signed-in account's playlists. The response is a bare array; the
  /// count travels in `X-Total` and is not needed, the array is the truth.
  Future<List<PulsarPlaylist>> listPlaylists(OAuthSession session) async {
    final data = await _send<List<dynamic>>(
      () => dio.get<List<dynamic>>(
        '$_basePath/collections',
        queryParameters: {'domain': 'music', 'kind': 'playlist'},
        options: Options(headers: _headers(session)),
      ),
    );
    return [
      for (final entry in data ?? const [])
        if (entry is Map<String, dynamic>) PulsarPlaylist.fromJson(entry),
    ];
  }

  /// One playlist with its items, position order. Private playlists are
  /// gated to the owner, so the session must be the owner's for those.
  Future<PulsarPlaylist> getPlaylist(OAuthSession session, String id) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/collections/$id',
        options: Options(headers: _headers(session)),
      ),
    );
    return PulsarPlaylist.fromJson(data ?? const {});
  }

  /// Creates a playlist and returns it with its server id.
  Future<PulsarPlaylist> createPlaylist(
    OAuthSession session, {
    required String name,
    bool isPublic = true,
    String? description,
  }) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.post<Map<String, dynamic>>(
        '$_basePath/collections',
        data: {
          'domain': 'music',
          'kind': 'playlist',
          'name': name,
          'description': ?description,
          'is_public': isPublic,
        },
        options: Options(headers: _headers(session)),
      ),
    );
    return PulsarPlaylist.fromJson(data ?? const {});
  }

  /// Renames a playlist. The server answers with the updated collection.
  Future<PulsarPlaylist> renamePlaylist(
    OAuthSession session,
    String id, {
    required String name,
  }) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.put<Map<String, dynamic>>(
        '$_basePath/collections/$id',
        data: {'name': name},
        options: Options(headers: _headers(session)),
      ),
    );
    return PulsarPlaylist.fromJson(data ?? const {});
  }

  /// Deletes a playlist. The server answers 204.
  Future<void> deletePlaylist(OAuthSession session, String id) async {
    await _send<Object?>(
      () => dio.delete<Object?>(
        '$_basePath/collections/$id',
        options: Options(headers: _headers(session)),
      ),
    );
  }

  /// Adds one track to a playlist. The inline title/subtitle/artwork payload
  /// makes the server find-or-create the catalog item, deduped on
  /// provider + provider_key, so the same track never duplicates.
  Future<void> addTrack(
    OAuthSession session, {
    required String playlistId,
    required String title,
    String? artist,
    String? artworkUrl,
    int? durationSeconds,
    String? trackKey,
  }) async {
    await _send<Map<String, dynamic>>(
      () => dio.post<Map<String, dynamic>>(
        '$_basePath/collections/$playlistId/items',
        data: {
          'domain': 'music',
          'provider': 'groovybox',
          'provider_key': ?trackKey,
          'title': title,
          if (artist != null && artist.isNotEmpty) 'subtitle': artist,
          if (artworkUrl != null && artworkUrl.isNotEmpty)
            'artwork_url': artworkUrl,
          'duration_seconds': ?durationSeconds,
        },
        options: Options(headers: _headers(session)),
      ),
    );
  }

  /// Removes one item from a playlist.
  Future<void> removeTrack(
    OAuthSession session, {
    required String playlistId,
    required String itemId,
  }) async {
    await _send<Object?>(
      () => dio.delete<Object?>(
        '$_basePath/collections/$playlistId/items/$itemId',
        options: Options(headers: _headers(session)),
      ),
    );
  }

  /// Makes the playlist hold exactly [tracks], in order: the upload a user
  /// runs to push a device or server playlist into Pulsar, and the re-sync
  /// that runs again later. Tracks the playlist no longer names are removed
  /// server-side, so this is safe to repeat with the same list.
  Future<int> replacePlaylistTracks(
    OAuthSession session, {
    required String playlistId,
    required List<PulsarTrackPayload> tracks,
  }) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.put<Map<String, dynamic>>(
        '$_basePath/collections/$playlistId/items',
        data: {
          'items': [for (final track in tracks) track.toJson()],
        },
        options: Options(headers: _headers(session)),
      ),
    );
    return (data?['count'] as num?)?.toInt() ?? tracks.length;
  }

  /// The account's favourite tracks, newest first. One entry per recording.
  Future<List<PlaylistItem>> favourites(OAuthSession session) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/collections/favourites',
        queryParameters: {'domain': 'music'},
        options: Options(headers: _headers(session)),
      ),
    );
    return [
      for (final entry in (data?['items'] as List?) ?? const [])
        if (entry is Map<String, dynamic>) PlaylistItem.fromJson(entry),
    ];
  }

  /// Marks one track a favourite. Idempotent, so a sync can re-send it.
  Future<void> addFavourite(
    OAuthSession session,
    PulsarTrackPayload track,
  ) async {
    await _send<Map<String, dynamic>>(
      () => dio.put<Map<String, dynamic>>(
        '$_basePath/collections/favourites',
        data: track.toJson(),
        options: Options(headers: _headers(session)),
      ),
    );
  }

  /// Clears one track's favourite.
  Future<void> removeFavourite(OAuthSession session, String catalogId) async {
    await _send<Object?>(
      () => dio.delete<Object?>(
        '$_basePath/collections/favourites/$catalogId',
        options: Options(headers: _headers(session)),
      ),
    );
  }

  // ── Friends' listening ─────────────────────────────────────────────────

  /// What the account's friends are listening to, straight from Stargate's
  /// friends overview, which already merges each friend's live Pulsar
  /// presence. Returns a bare array; empty when nobody is listening.
  Future<List<FriendListening>> friendsListening(OAuthSession session) async {
    final data = await _send<List<dynamic>>(
      () => dio.get<List<dynamic>>(
        '$_siteBase/api/friends/overview',
        options: Options(headers: _headers(session)),
      ),
    );
    return [
      for (final entry in data ?? const [])
        if (entry is Map<String, dynamic>) FriendListening.fromJson(entry),
    ];
  }

  // ── Taste (Pulsar rewind stats) ────────────────────────────────────────

  /// The account's aggregated listening stats. The window is optional:
  /// omitted it covers everything the account has ever scrobbled.
  Future<PulsarMediaStats> getStats(
    OAuthSession session, {
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/stats',
        queryParameters: {
          'domain': 'music',
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
        options: Options(headers: _headers(session)),
      ),
    );
    return PulsarMediaStats.fromJson(data ?? const {});
  }

  // ── Sharing ────────────────────────────────────────────────────────────

  /// Shares one track: registers it as a catalog item (find-or-create, so
  /// repeat shares return the same id) and returns the public share URL.
  ///
  /// [trackKey] is the source-scoped identity from [pulsarTrackKey]: the
  /// song's own id is only unique inside its [LibrarySong.sourceId], and two
  /// servers reusing one id would otherwise share a page.
  Future<MusicShare> shareTrack(
    OAuthSession session, {
    required String title,
    String? artist,
    String? album,
    String? artworkUrl,
    int? durationSeconds,
    String? trackKey,
    List<PulsarCreatorCredit>? creators,
  }) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.post<Map<String, dynamic>>(
        '$_basePath/catalog',
        data: {
          'domain': 'music',
          'provider': 'groovybox',
          'provider_key': ?trackKey,
          'title': title,
          if (artist != null && artist.isNotEmpty) 'subtitle': artist,
          if (album != null && album.isNotEmpty) 'caption': album,
          if (artworkUrl != null && artworkUrl.isNotEmpty)
            'artwork_url': artworkUrl,
          'duration_seconds': durationSeconds,
          if (creators != null && creators.isNotEmpty)
            'creators': [
              for (final credit in creators)
                {'name': credit.name, 'role': credit.role},
            ],
        },
        options: Options(headers: _headers(session)),
      ),
    );
    // The catalog record's id is the public page's id: GET /m/:id resolves
    // UUID, URN and slug alike.
    final item = CatalogItem.fromJson(data ?? const {});
    return MusicShare(item: item, shareUrl: '$_shareBase/m/${item.id}');
  }

  // ── Reviews ────────────────────────────────────────────────────────────

  /// Headers for the endpoints Pulsar serves without an account. When a
  /// session exists it is spread over these, adding `Authorization`.
  Map<String, String> get _publicHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': appUserAgent,
  };

  /// The reviews on one catalog item, newest first. Public: no session
  /// needed. The response is a bare array with the total in `X-Total`.
  Future<List<PulsarReview>> reviews(
    String catalogId, {
    OAuthSession? session,
  }) async {
    final data = await _send<List<dynamic>>(
      () => dio.get<List<dynamic>>(
        '$_basePath/reviews',
        queryParameters: {'catalog_id': catalogId},
        options: Options(
          headers: {
            ..._publicHeaders,
            if (session != null) ..._headers(session),
          },
        ),
      ),
    );
    return [
      for (final entry in data ?? const [])
        if (entry is Map<String, dynamic>) PulsarReview.fromJson(entry),
    ];
  }

  /// The rating average and count for one item. Public. Comment-only
  /// reviews are not counted — they have nothing to average.
  Future<PulsarReviewStats> reviewStats(String catalogId) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/reviews/stats',
        queryParameters: {'catalog_id': catalogId},
        options: Options(headers: _publicHeaders),
      ),
    );
    return PulsarReviewStats.fromJson(data ?? const {});
  }

  /// The signed-in account's own review on one item, or null when the
  /// account has not reviewed it (the server answers 404).
  Future<PulsarReview?> myReview(
    OAuthSession session,
    String catalogId,
  ) async {
    try {
      final data = await _send<Map<String, dynamic>>(
        () => dio.get<Map<String, dynamic>>(
          '$_basePath/reviews/me',
          queryParameters: {'catalog_id': catalogId},
          options: Options(headers: _headers(session)),
        ),
      );
      return data == null ? null : PulsarReview.fromJson(data);
    } on PulsarException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Writes the account's review on one item. 201 the first time, 200 on
  /// update — one review per account per item, so re-sending edits in place.
  /// Returns true when the review was created, false when it was updated.
  Future<bool> putReview(OAuthSession session, PulsarReviewPayload payload) {
    assert(payload.isValid, 'A review needs a 1-10 rating, a body, or both.');
    return _sendWithStatus<Map<String, dynamic>>(
      () => dio.put<Map<String, dynamic>>(
        '$_basePath/reviews',
        data: payload.toJson(),
        options: Options(headers: _headers(session)),
      ),
    ).then((response) => response.statusCode == 201);
  }

  /// Deletes the account's review. Owner only; the server answers 204.
  Future<void> deleteReview(OAuthSession session, String reviewId) async {
    await _send<Object?>(
      () => dio.delete<Object?>(
        '$_basePath/reviews/$reviewId',
        options: Options(headers: _headers(session)),
      ),
    );
  }

  // ── Status marking ─────────────────────────────────────────────────────

  /// Moves one collection item's status, rating or note in place. Only the
  /// fields [patch] names change; the rest keep their server values, so no
  /// whole-list `PUT` is needed.
  Future<void> patchCollectionItem(
    OAuthSession session, {
    required String collectionId,
    required String itemId,
    required PulsarItemPatch patch,
  }) async {
    assert(patch.validStatus, 'Unknown status: ${patch.status}');
    assert(!patch.isEmpty, 'A patch must name at least one field.');
    await _send<Map<String, dynamic>>(
      () => dio.patch<Map<String, dynamic>>(
        '$_basePath/collections/$collectionId/items/$itemId',
        data: patch.toJson(),
        options: Options(headers: _headers(session)),
      ),
    );
  }

  // ── Entity metadata ────────────────────────────────────────────────────

  /// The fleet's record for one artist, resolved from MusicBrainz and cached
  /// server-side. A name is the only handle the app's libraries share, so
  /// the query is the name; [language] asks for the biography in the reader's
  /// language when Wikipedia has it.
  ///
  /// Public: a page shows what the act is whether or not anyone is signed in,
  /// and the record is a shared artefact rather than an account's data.
  Future<PulsarEntityMetadata> artistMetadata(
    String name, {
    String? language,
    OAuthSession? session,
  }) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/metadata/artist',
        queryParameters: {
          'name': name,
          if (language != null && language.isNotEmpty) 'lang': language,
        },
        options: Options(
          headers: {
            ..._publicHeaders,
            if (session != null) ..._headers(session),
          },
        ),
      ),
    );
    return PulsarEntityMetadata.fromJson(data ?? const {});
  }

  /// The fleet's record for one album, identified the way every library
  /// spells it: a title and the artist credited on it.
  Future<PulsarEntityMetadata> albumMetadata({
    required String title,
    String? artist,
    String? language,
    OAuthSession? session,
  }) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/metadata/album',
        queryParameters: {
          'title': title,
          if (artist != null && artist.isNotEmpty) 'artist': artist,
          if (language != null && language.isNotEmpty) 'lang': language,
        },
        options: Options(
          headers: {
            ..._publicHeaders,
            if (session != null) ..._headers(session),
          },
        ),
      ),
    );
    return PulsarEntityMetadata.fromJson(data ?? const {});
  }

  // ── Creators ───────────────────────────────────────────────────────────

  /// The creators matching an optional name filter and domain, alphabetical.
  /// The same name in two domains is two creators; [domain] narrows to one.
  Future<List<PulsarCreator>> creators({
    String? query,
    String? domain,
    OAuthSession? session,
  }) async {
    final data = await _send<List<dynamic>>(
      () => dio.get<List<dynamic>>(
        '$_basePath/creators',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (domain != null && domain.isNotEmpty) 'domain': domain,
        },
        options: Options(
          headers: {
            ..._publicHeaders,
            if (session != null) ..._headers(session),
          },
        ),
      ),
    );
    return [
      for (final entry in data ?? const [])
        if (entry is Map<String, dynamic>) PulsarCreator.fromJson(entry),
    ];
  }

  /// One creator with its item count. Throws [PulsarException] 404 when the
  /// id is unknown.
  Future<PulsarCreator> creator(String id, {OAuthSession? session}) async {
    final data = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/creators/$id',
        options: Options(
          headers: {
            ..._publicHeaders,
            if (session != null) ..._headers(session),
          },
        ),
      ),
    );
    return PulsarCreator.fromJson(data ?? const {});
  }

  /// The catalog items one creator is credited on — "everything by X".
  /// Bare array, newest-not-guaranteed; [domain] narrows the filter.
  Future<List<CatalogItem>> creatorCatalog(
    String creatorId, {
    String? domain,
    OAuthSession? session,
  }) async {
    final data = await _send<List<dynamic>>(
      () => dio.get<List<dynamic>>(
        '$_basePath/catalog',
        queryParameters: {
          'creator_id': creatorId,
          if (domain != null && domain.isNotEmpty) 'domain': domain,
        },
        options: Options(
          headers: {
            ..._publicHeaders,
            if (session != null) ..._headers(session),
          },
        ),
      ),
    );
    return [
      for (final entry in data ?? const [])
        if (entry is Map<String, dynamic>) CatalogItem.fromJson(entry),
    ];
  }

  /// Runs one request and maps a fleet ApiError onto a typed exception.
  Future<T?> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (error) {
      throw _exceptionOf(error);
    }
  }

  /// [_send] plus the status code, for the one endpoint where 201 vs 200 is
  /// the answer: `PUT /reviews` creates the first time and updates after.
  Future<Response<T>> _sendWithStatus<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _exceptionOf(error);
    }
  }

  PulsarException _exceptionOf(DioException error) {
    final status = error.response?.statusCode ?? 0;
    final body = error.response?.data;
    var code = 'PULSAR_REQUEST_FAILED';
    var message = error.message ?? 'The request failed.';
    String? detail;
    String? traceId;
    if (body is Map) {
      code = body['code'] as String? ?? code;
      message = body['message'] as String? ?? message;
      detail = body['detail'] as String?;
      traceId = body['traceId'] as String?;
    }
    if (status == 401) {
      return PulsarUnauthorized(
        code: code,
        message: message,
        detail: detail,
        traceId: traceId,
      );
    }
    return PulsarException(
      statusCode: status,
      code: code,
      message: message,
      detail: detail,
      traceId: traceId,
    );
  }
}
