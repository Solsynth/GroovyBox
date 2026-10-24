import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';

import 'models.dart';

/// A configured Subsonic-compatible server (Navidrome, Jellyfin, Gonic, …).
class ServerConfig {
  final String baseUrl;

  /// Account used for every request. Stored, but never shown in logs.
  final String username;
  final String? token;
  final String? salt;

  /// Client identity sent as `c` / `v`; the server uses these for its own
  /// bookkeeping and some deployments reject requests without them.
  static const appName = 'GroovyBox';
  static const apiVersion = '1.16.1';

  const ServerConfig({
    required this.baseUrl,
    required this.username,
    this.token,
    this.salt,
  });

  bool get isAuthenticated => token != null && salt != null;

  ServerConfig withPassword(String password) {
    final salt = _randomSalt();
    return ServerConfig(
      baseUrl: baseUrl,
      username: username,
      token: crypto.md5.convert(utf8.encode('$password$salt')).toString(),
      salt: salt,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'token': token,
    'salt': salt,
  };

  static ServerConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final baseUrl = raw['baseUrl'];
    final username = raw['username'];
    if (baseUrl is! String || username is! String) return null;
    return ServerConfig(
      baseUrl: baseUrl,
      username: username,
      token: raw['token'] as String?,
      salt: raw['salt'] as String?,
    );
  }

  /// Subsonic's token auth: `t = md5(password + salt)`. The salt only has to
  /// make the hash unusable for replay on its own, not to be secret.
  static String _randomSalt() {
    final random = Random.secure();
    final values = List<int>.generate(8, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }
}

/// Minimal client for the OpenSubsonic API surface GroovyBox needs.
///
/// Every call goes through [_request], which unwraps the standard
/// `subsonic-response` envelope, converts `status: failed` into a
/// [SubsonicException] and returns the inner map. That keeps the individual
/// endpoints readable and means no caller ever sees the envelope.
class SubsonicClient {
  final ServerConfig config;
  final Dio _dio;

  SubsonicClient(this.config)
    : _dio = Dio(
        BaseOptions(
          baseUrl: _normalizeBaseUrl(config.baseUrl),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          responseType: ResponseType.json,
          // The API is queried with query parameters only; no JSON bodies.
          contentType: Headers.jsonContentType,
        ),
      );

  /// Some servers expose `/rest` at the root, others under a path. Accept a
  /// bare host, a host with a trailing slash, or a full `/rest` URL.
  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/rest')) url = '$url/rest';
    return url;
  }

  String get serverRoot {
    final url = _normalizeBaseUrl(config.baseUrl);
    return url.substring(0, url.length - '/rest'.length);
  }

  Map<String, dynamic> _authParams() {
    final params = <String, dynamic>{
      'u': config.username,
      'c': ServerConfig.appName,
      'v': ServerConfig.apiVersion,
      'f': 'json',
    };
    if (config.token != null) params['t'] = config.token;
    if (config.salt != null) params['s'] = config.salt;
    return params;
  }

  /// Unwraps the envelope and returns the body of a successful response.
  Future<Map<String, dynamic>> _request(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/$endpoint',
        queryParameters: {..._authParams(), ...?query},
      );
    } on DioException catch (error) {
      throw SubsonicException(_describeDioError(error));
    }

    final data = response.data;
    if (data is! Map) {
      throw const SubsonicException(
        'The server did not return a Subsonic response. '
        'Check that the URL points at a Subsonic-compatible API.',
      );
    }

    final envelope = data['subsonic-response'] ?? data['openSubsonic-response'];
    if (envelope is! Map) {
      throw const SubsonicException('Malformed server response.');
    }

    if (envelope['status'] == 'failed') {
      final error = envelope['error'];
      throw SubsonicException(
        error is Map ? (error['message'] as String? ?? 'Request failed') : 'Request failed',
        code: error is Map ? (error['code'] as num?)?.toInt() : null,
      );
    }

    // OpenSubsonic servers nest everything under the same envelope; flatten
    // the metadata fields so callers can read `artists` or `song` directly.
    return Map<String, dynamic>.from(envelope)
      ..remove('status')
      ..remove('version')
      ..remove('type')
      ..remove('serverVersion')
      ..remove('openSubsonic');
  }

  static String _describeDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return 'The server took too long to respond.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check the address and your network.';
      case DioExceptionType.badCertificate:
        return "The server's certificate is not valid.";
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        return 'Server returned HTTP ${status ?? 'error'}.';
      case DioExceptionType.unknown:
        return error.message ?? 'Unknown network error.';
    }
  }

  Future<bool> ping() async {
    await _request('ping');
    return true;
  }

  /// Artists, paged. OpenSubsonic `getArtists` gives indexed entries; the
  /// flattened `artists` list is the union of every index bucket.
  Future<List<SubsonicArtist>> getArtists() async {
    final body = await _request('getArtists');
    final index = body['artists'];
    if (index is! Map) return const [];
    final entries = index['index'];
    if (entries is! List) return const [];
    return [
      for (final bucket in entries)
        if (bucket is Map && bucket['artist'] is List)
          for (final artist in bucket['artist'] as List)
            if (artist is Map) SubsonicArtist.fromJson(_stringKeyed(artist)),
    ];
  }

  Future<List<SubsonicAlbum>> getArtistAlbums(String artistId) async {
    final body = await _request('getArtist', query: {'id': artistId});
    final albums = body['artist'] is Map ? (body['artist'] as Map)['album'] : null;
    if (albums is! List) return const [];
    return [
      for (final album in albums)
        if (album is Map) SubsonicAlbum.fromJson(_stringKeyed(album)),
    ];
  }

  Future<List<SubsonicAlbum>> getAlbums({
    String type = 'newest',
    int size = 60,
    int offset = 0,
  }) async {
    final body = await _request(
      'getAlbumList2',
      query: {'type': type, 'size': size, 'offset': offset},
    );
    final albums = body['albumList2'];
    if (albums is! Map || albums['album'] is! List) return const [];
    return [
      for (final album in albums['album'] as List)
        if (album is Map) SubsonicAlbum.fromJson(_stringKeyed(album)),
    ];
  }

  Future<List<SubsonicSong>> getAlbumSongs(String albumId) async {
    final body = await _request('getAlbum', query: {'id': albumId});
    final album = body['album'];
    if (album is! Map || album['song'] is! List) return const [];
    return [
      for (final song in album['song'] as List)
        if (song is Map) SubsonicSong.fromJson(_stringKeyed(song)),
    ];
  }

  Future<List<SubsonicPlaylist>> getPlaylists() async {
    final body = await _request('getPlaylists');
    final playlists = body['playlists'];
    if (playlists is! Map || playlists['playlist'] is! List) return const [];
    return [
      for (final playlist in playlists['playlist'] as List)
        if (playlist is Map) SubsonicPlaylist.fromJson(_stringKeyed(playlist)),
    ];
  }

  Future<List<SubsonicSong>> getPlaylistSongs(String playlistId) async {
    final body = await _request('getPlaylist', query: {'id': playlistId});
    final playlist = body['playlist'];
    if (playlist is! Map || playlist['entry'] is! List) return const [];
    return [
      for (final song in playlist['entry'] as List)
        if (song is Map) SubsonicSong.fromJson(_stringKeyed(song)),
    ];
  }

  Future<List<SubsonicSong>> search(String query, {int count = 40}) async {
    final body = await _request(
      'search3',
      query: {
        'query': query,
        'songCount': count,
        'albumCount': 0,
        'artistCount': 0,
      },
    );
    final result = body['searchResult3'];
    if (result is! Map || result['song'] is! List) return const [];
    return [
      for (final song in result['song'] as List)
        if (song is Map) SubsonicSong.fromJson(_stringKeyed(song)),
    ];
  }

  Future<List<SubsonicSong>> getRandomSongs({int size = 40}) async {
    final body = await _request('getRandomSongs', query: {'size': size});
    final random = body['randomSongs'];
    if (random is! Map || random['song'] is! List) return const [];
    return [
      for (final song in random['song'] as List)
        if (song is Map) SubsonicSong.fromJson(_stringKeyed(song)),
    ];
  }

  /// A directly playable URL. media_kit can stream this as-is; the signed
  /// token travels in the query string, exactly like the API calls.
  String streamUrl(String songId, {int? maxBitRate}) {
    final params = {
      ..._authParams(),
      'id': songId,
      if (maxBitRate != null) 'maxBitRate': '$maxBitRate',
    };
    final uri = Uri.parse('$serverRoot/rest/stream').replace(
      queryParameters: params.map((key, value) => MapEntry(key, '$value')),
    );
    return uri.toString();
  }

  /// Cover art URL, or null when the track has no cover.
  String? coverArtUrl(String? coverArtId, {int size = 600}) {
    if (coverArtId == null || coverArtId.isEmpty) return null;
    final params = {..._authParams(), 'id': coverArtId, 'size': '$size'};
    return Uri.parse('$serverRoot/rest/getCoverArt')
        .replace(
          queryParameters: params.map((key, value) => MapEntry(key, '$value')),
        )
        .toString();
  }

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
}
