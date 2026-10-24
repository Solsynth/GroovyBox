import 'package:dio/dio.dart';

import 'http.dart';
import 'models.dart';
import 'source.dart';

/// Jellyfin, over its plain HTTP API (no SDK, no extra dependency).
class JellyfinAdapter implements LibraryAdapter {
  @override
  LibraryKind get kind => LibraryKind.jellyfin;

  @override
  Future<SourceConfig> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final root = normalizeBaseUrl(baseUrl);
    final id = newSourceId(LibraryKind.jellyfin);
    final dio = Dio(
      BaseOptions(
        baseUrl: root,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 25),
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
        headers: {_authorizationHeader: _clientAuthorization(id)},
      ),
    );

    final Response<dynamic> auth;
    try {
      auth = await dio.post<dynamic>(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const LibraryException('Wrong username or password.', code: 401);
      }
      throw LibraryException(describeDioError(error));
    }

    final body = auth.data;
    final user = body is Map ? body['User'] : null;
    final token = body is Map ? body['AccessToken'] : null;
    final userId = user is Map ? user['Id'] : null;
    if (token is! String || userId is! String) {
      throw const LibraryException(
        'That address does not look like a Jellyfin server.',
      );
    }

    final config = SourceConfig(
      id: id,
      kind: LibraryKind.jellyfin,
      baseUrl: root,
      displayName: Uri.parse(root).host,
      auth: {'username': username, 'userId': userId, 'accessToken': token},
    );

    await JellyfinSource(config).verify();
    return config;
  }

  @override
  LibrarySource sourceFor(SourceConfig config) => JellyfinSource(config);

  /// Jellyfin identifies clients per device; [deviceId] is the stable part.
  static String _clientAuthorization(String deviceId) =>
      'MediaBrowser Client="GroovyBox", Device="GroovyBox", '
      'DeviceId="$deviceId", Version="0.1.0"';
}

const _authorizationHeader = 'X-Emby-Authorization';
const _tokenHeader = 'X-Emby-Token';

/// One connected Jellyfin server.
///
/// Jellyfin's item model is one flat `BaseItemDto` for albums, songs, artists
/// and playlists, so mapping is a single pair of helpers over `/Items`.
class JellyfinSource extends LibrarySource {
  @override
  final SourceConfig config;
  final Dio _dio;

  JellyfinSource(this.config)
    : _dio = Dio(
        BaseOptions(
          baseUrl: normalizeBaseUrl(config.baseUrl),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          responseType: ResponseType.json,
          contentType: Headers.jsonContentType,
          headers: {
            _tokenHeader: config.auth['accessToken'] ?? '',
            _authorizationHeader: JellyfinAdapter._clientAuthorization(
              config.id,
            ),
          },
        ),
      );

  String get _root => normalizeBaseUrl(config.baseUrl);

  String get _userId {
    final userId = config.auth['userId'];
    if (userId == null) throw _signedOut;
    return userId;
  }

  String get _accessToken {
    final token = config.auth['accessToken'];
    if (token == null) throw _signedOut;
    return token;
  }

  static const _signedOut = LibraryException(
    'This library is not signed in. Connect it again from Settings.',
  );

  /// Confirms the stored token still works.
  Future<void> verify() => _request('/Users/Me');

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(path, queryParameters: query);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (error.type == DioExceptionType.badResponse) {
        final data = error.response?.data;
        final message = data is Map ? data['Message'] : null;
        throw LibraryException(
          message is String ? message : 'Jellyfin returned HTTP $status.',
          code: status,
        );
      }
      throw LibraryException(describeDioError(error));
    }

    final data = response.data;
    if (data is! Map) throw const LibraryException('Malformed server response.');
    return Map<String, dynamic>.from(data);
  }

  /// Every list endpoint returns `{Items: [...], TotalRecordCount: n}`.
  Future<List<Map<String, dynamic>>> _items(
    Map<String, dynamic> query,
  ) async {
    final body = await _request('/Items', query: {...query, 'userId': _userId});
    final items = body['Items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) async {
    final items = await _items({
      'IncludeItemTypes': 'MusicAlbum',
      'Recursive': true,
      'SortBy': 'DateCreated',
      'SortOrder': 'Descending',
      'Limit': limit,
      'Fields': 'Genres',
    });
    return [for (final item in items) _album(item)];
  }

  @override
  Future<List<LibraryAlbum>> albums({int limit = 60, int offset = 0}) async {
    final items = await _items({
      'IncludeItemTypes': 'MusicAlbum',
      'Recursive': true,
      'SortBy': 'SortName',
      'StartIndex': offset,
      'Limit': limit,
      'Fields': 'Genres',
    });
    return [for (final item in items) _album(item)];
  }

  @override
  Future<LibraryAlbum?> album(String albumId) async {
    final items = await _items({'Ids': albumId, 'userId': _userId});
    return items.isEmpty ? null : _album(items.first);
  }

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async {
    final items = await _items({
      'ParentId': albumId,
      'IncludeItemTypes': 'Audio',
      'Recursive': true,
      'SortBy': 'ParentIndexNumber,IndexNumber',
      'Fields': 'Genres',
    });
    return [for (final item in items) _song(item)];
  }

  @override
  Future<List<LibraryArtist>> artists() async {
    final items = await _items({
      'IncludeItemTypes': 'MusicArtist',
      'Recursive': true,
      'SortBy': 'SortName',
    });
    return [
      for (final item in items)
        LibraryArtist(
          sourceId: config.id,
          id: '${item['Id']}',
          name: item['Name'] as String? ?? 'Unknown artist',
          artId: _primaryImage(item),
        ),
    ];
  }

  @override
  Future<List<LibraryAlbum>> artistAlbums(String artistId) async {
    final items = await _items({
      'AlbumArtistIds': artistId,
      'IncludeItemTypes': 'MusicAlbum',
      'Recursive': true,
      'SortBy': 'ProductionYear',
      'Fields': 'Genres',
    });
    return [for (final item in items) _album(item)];
  }

  @override
  Future<List<LibraryPlaylist>> playlists() async {
    final items = await _items({
      'IncludeItemTypes': 'Playlist',
      'Recursive': true,
    });
    return [
      for (final item in items)
        LibraryPlaylist(
          sourceId: config.id,
          id: '${item['Id']}',
          name: item['Name'] as String? ?? 'Untitled playlist',
          owner: item['OwnerName'] as String?,
          songCount: (item['ChildCount'] as num?)?.toInt(),
          duration: _duration(item),
          artId: _primaryImage(item),
        ),
    ];
  }

  @override
  Future<List<LibrarySong>> playlistSongs(String playlistId) async {
    final body = await _request(
      '/Playlists/$playlistId/Items',
      query: {'userId': _userId, 'Fields': 'Genres'},
    );
    final items = body['Items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map) _song(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    final items = await _items({
      'searchTerm': query,
      'IncludeItemTypes': 'Audio',
      'Recursive': true,
      'Limit': limit,
      'Fields': 'Genres',
    });
    return [for (final item in items) _song(item)];
  }

  @override
  Future<List<LibrarySong>> randomSongs({int size = 40}) async {
    final items = await _items({
      'IncludeItemTypes': 'Audio',
      'Recursive': true,
      'SortBy': 'Random',
      'Limit': size,
    });
    return [for (final item in items) _song(item)];
  }

  @override
  Uri streamUri(LibrarySong song) => Uri.parse(
    '$_root/Audio/${Uri.encodeComponent(song.id)}/stream'
    '?static=true&api_key=$_accessToken',
  );

  @override
  Uri? artworkUri(String? artId, {int size = 600}) {
    if (artId == null || artId.isEmpty) return null;
    return Uri.parse(
      '$_root/Items/${Uri.encodeComponent(artId)}/Images/Primary'
      '?maxHeight=$size&api_key=$_accessToken',
    );
  }

  LibrarySong _song(Map<String, dynamic> json) => LibrarySong(
    sourceId: config.id,
    id: '${json['Id']}',
    title: json['Name'] as String? ?? 'Untitled',
    artist: _artist(json),
    album: json['Album'] as String?,
    albumId: json['AlbumId'] as String?,
    artId: json['AlbumId'] as String? ?? '${json['Id']}',
    duration: _duration(json),
    track: (json['IndexNumber'] as num?)?.toInt(),
    discNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
    year: (json['ProductionYear'] as num?)?.toInt(),
    genre: (json['Genres'] as List?)?.firstOrNull as String?,
  );

  LibraryAlbum _album(Map<String, dynamic> json) => LibraryAlbum(
    sourceId: config.id,
    id: '${json['Id']}',
    name: json['Name'] as String? ?? 'Untitled',
    artist: _artist(json),
    artId: _primaryImage(json),
    songCount: (json['ChildCount'] as num?)?.toInt(),
    duration: _duration(json),
    year: (json['ProductionYear'] as num?)?.toInt(),
    genre: (json['Genres'] as List?)?.firstOrNull as String?,
  );

  static String? _artist(Map<String, dynamic> json) {
    final albumArtist = json['AlbumArtist'];
    if (albumArtist is String && albumArtist.isNotEmpty) return albumArtist;
    final artists = json['Artists'];
    if (artists is List && artists.isNotEmpty) return '${artists.first}';
    return null;
  }

  /// Jellyfin reports a primary image only by tagging the item; the art id is
  /// the item's own id.
  static String? _primaryImage(Map<String, dynamic> json) {
    final tags = json['ImageTags'];
    return tags is Map && tags['Primary'] != null ? '${json['Id']}' : null;
  }

  /// Jellyfin ticks are 100 ns each.
  static Duration _duration(Map<String, dynamic> json) => Duration(
    microseconds: ((json['RunTimeTicks'] as num?)?.toInt() ?? 0) ~/ 10,
  );
}
