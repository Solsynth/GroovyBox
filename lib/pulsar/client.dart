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
import 'models.dart';

/// The stable identity GroovyBox sends for one track, scoped to its source.
///
/// A [LibrarySong.id] is only unique inside the library it came from; two
/// servers can hand out the same number. Every catalog write the fleet sees
/// — share links, playlist items, scrobbles — uses this as `provider_key`,
/// so the same recording dedupes to one entry and two different ones never
/// merge.
String pulsarTrackKey(LibrarySong song) => '${song.sourceId}:${song.id}';

/// Pushes playlists, friends' listening and share targets over the fleet.
class PulsarClient {
  PulsarClient({required this.dio, required String baseUrl})
    : _basePath = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/pulsar',
      _siteBase = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final Dio dio;
  final String _basePath;

  /// Public share pages live at the site root, not under `/pulsar`: Blade
  /// routes `/m/:id` straight through to Pulsar with no auth.
  final String _siteBase;

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
        },
        options: Options(headers: _headers(session)),
      ),
    );
    // The catalog record's id is the public page's id: GET /m/:id resolves
    // UUID, URN and slug alike.
    final item = CatalogItem.fromJson(data ?? const {});
    return MusicShare(item: item, shareUrl: '$_siteBase/m/${item.id}');
  }

  // ── Transport ──────────────────────────────────────────────────────────

  /// Runs one request and maps a fleet ApiError onto a typed exception.
  Future<T?> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data;
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
