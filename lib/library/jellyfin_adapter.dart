import 'dart:io' show HttpHeaders;

import 'package:dio/dio.dart';

import '../core/identity.dart';
import 'http.dart';
import 'lyrics.dart';
import 'models.dart';
import 'source.dart';

/// Jellyfin, over its plain HTTP API (no SDK, no extra dependency).
class JellyfinAdapter implements LibraryAdapter {
  @override
  LibraryKind get kind => LibraryKind.jellyfin;

  /// Runs anywhere with a network.
  @override
  bool get isAvailable => true;

  /// Address, username and password are exactly what a Jellyfin server needs.
  @override
  bool get needsCredentials => true;

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
        headers: {HttpHeaders.authorizationHeader: _authorization(id)},
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
        throw const LibraryException(
          'Wrong username or password.',
          code: 401,
          messageKey: 'libraryWrongCredentials',
        );
      }
      throw _describeAuthError(error);
    }

    final body = auth.data;
    final user = body is Map ? body['User'] : null;
    final token = body is Map ? body['AccessToken'] : null;
    final userId = user is Map ? user['Id'] : null;
    if (token is! String || userId is! String) {
      throw const LibraryException(
        'That address does not look like a Jellyfin server.',
        messageKey: 'libraryNotJellyfin',
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

  /// The one header Jellyfin authenticates every request with.
  ///
  /// Jellyfin 10.11 stopped accepting the legacy `X-Emby-Authorization` /
  /// `X-Emby-Token` pair: it parses `Authorization: MediaBrowser ...` only, and
  /// derives the client's `App` from this header. Without it the auth call
  /// fails with a 400 *before* the credentials are looked at — which is why a
  /// correct password still reported "HTTP 400". The access token rides in the
  /// same header once signed in; [deviceId] is the part that identifies this
  /// install.
  static String authorization(String deviceId, {String? token}) =>
      _authorization(deviceId, token: token);

  static String _authorization(String deviceId, {String? token}) {
    final fields = [
      'Client="$kAppName"',
      'Device="$kAppName"',
      'DeviceId="$deviceId"',
      'Version="$kAppVersion"',
      if (token != null && token.isNotEmpty) 'Token="$token"',
    ];
    return 'MediaBrowser ${fields.join(', ')}';
  }

  /// A 400 from the auth endpoint is never about the password: the server
  /// rejected the client identity, which means it is not a Jellyfin server, or
  /// a proxy in front of it strips the `Authorization` header.
  static LibraryException _describeAuthError(DioException error) {
    if (error.type == DioExceptionType.badResponse &&
        error.response?.statusCode == 400) {
      return const LibraryException(
        'The server rejected the client identity. Check that this is a '
        'Jellyfin address, and that no proxy strips the Authorization '
        'header.',
        messageKey: 'libraryRejectedIdentity',
      );
    }
    return describeDioError(error);
  }
}

/// One connected Jellyfin server.
///
/// Jellyfin's item model is one flat `BaseItemDto` for albums, songs, artists
/// and playlists, so mapping is a single pair of helpers over `/Items`.
class JellyfinSource extends LibrarySource implements RatedSource {
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
            HttpHeaders.authorizationHeader: JellyfinAdapter.authorization(
              config.id,
              token: config.auth['accessToken'],
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
    messageKey: 'librarySignedOut',
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
        // A server's own words are shown as sent; ours are not translated
        // here, and carry the key the UI resolves.
        throw message is String
            ? LibraryException(message, code: status)
            : LibraryException(
                'Jellyfin returned HTTP $status.',
                code: status,
                messageKey: 'libraryHttpError',
                messageArgs: [status.toString()],
              );
      }
      throw describeDioError(error);
    }

    final data = response.data;
    if (data is! Map) {
      throw const LibraryException(
        'Malformed server response.',
        messageKey: 'libraryMalformedResponse',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  /// Every list endpoint returns `{Items: [...], TotalRecordCount: n}`.
  Future<List<Map<String, dynamic>>> _items(Map<String, dynamic> query) async {
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
      'Fields': 'Genres,AlbumArtists,ArtistItems',
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
      'Fields': 'Genres,AlbumArtists,ArtistItems',
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
      'Fields': 'Genres,AlbumArtists,ArtistItems',
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
      'Fields': 'Genres,AlbumArtists,ArtistItems',
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
      query: {'userId': _userId, 'Fields': 'Genres,AlbumArtists,ArtistItems'},
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
      'Fields': 'Genres,AlbumArtists,ArtistItems',
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

  /// `/Users/{userId}/FavoriteItems/{itemId}`: PUT is a favourite, DELETE
  /// clears it. Jellyfin's own API has no partial-update for the flag.
  @override
  Future<void> setFavourite(LibrarySong song, {required bool value}) async {
    final path =
        '/Users/${Uri.encodeComponent(_userId)}/FavoriteItems/'
        '${Uri.encodeComponent(song.id)}';
    try {
      if (value) {
        await _dio.post<void>(path);
      } else {
        await _dio.delete<void>(path);
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw LibraryException(
        'Jellyfin returned HTTP $status.',
        code: status,
        messageKey: 'libraryHttpError',
        messageArgs: [status?.toString() ?? ''],
      );
    }
  }

  /// Whether the server reports the item as a favourite.
  ///
  /// One `Items` read with the `UserData` field: the flag lives there, and
  /// the list endpoints only include it when asked.
  @override
  Future<bool> isFavourite(LibrarySong song) async {
    try {
      final items = await _items({
        'Ids': song.id,
        'Fields': 'UserData',
        'Recursive': true,
      });
      if (items.isEmpty) return false;
      final userData = items.first['UserData'];
      return userData is Map && userData['IsFavorite'] == true;
    } on LibraryException {
      return false;
    }
  }

  /// `/Audio/{id}/Lyrics`; 404 means the item has no lyrics at all.
  ///
  /// Jellyfin stores every line's start in ticks (100 ns), and reports 0 for
  /// lines it could not time, which a view must not treat as "sung at 0:00".
  @override
  Future<Lyrics> lyrics(LibrarySong song) async {
    final Map<String, dynamic> body;
    try {
      body = await _request('/Audio/${Uri.encodeComponent(song.id)}/Lyrics');
    } on LibraryException catch (error) {
      if (error.code == 404) return Lyrics.empty;
      rethrow;
    }

    final raw = body['Lyrics'];
    if (raw is! List) return Lyrics.empty;
    final lines = <LyricLine>[];
    for (final line in raw) {
      if (line is! Map) continue;
      final text = line['Text'] as String? ?? '';
      final ticks = (line['Start'] as num?)?.toInt() ?? 0;
      lines.add(LyricLine(_fromTicks(ticks), text));
    }
    if (lines.isEmpty) return Lyrics.empty;
    lines.sort((a, b) => a.at.compareTo(b.at));

    final metadata = body['Metadata'];
    final language = metadata is Map ? metadata['ThreeLetterISOLanguageName'] : null;
    return Lyrics(
      lines: lines,
      synced: lines.any((line) => line.at > Duration.zero),
      language: language is String && language != 'und' ? language : null,
    );
  }

  /// Jellyfin ticks are 100 ns each.
  static Duration _fromTicks(int ticks) => Duration(microseconds: ticks ~/ 10);

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
    artistId: _artistId(json),
    album: json['Album'] as String?,
    albumId: json['AlbumId'] as String?,
    artId: json['AlbumId'] as String? ?? '${json['Id']}',
    duration: _duration(json),
    track: (json['IndexNumber'] as num?)?.toInt(),
    discNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
    year: (json['ProductionYear'] as num?)?.toInt(),
    genre: (json['Genres'] as List?)?.firstOrNull as String?,
    mbid: _mbid(json),
  );

  LibraryAlbum _album(Map<String, dynamic> json) => LibraryAlbum(
    sourceId: config.id,
    id: '${json['Id']}',
    name: json['Name'] as String? ?? 'Untitled',
    artist: _artist(json),
    artistId: _artistId(json),
    artId: _primaryImage(json),
    songCount: (json['ChildCount'] as num?)?.toInt(),
    duration: _duration(json),
    year: (json['ProductionYear'] as num?)?.toInt(),
    genre: (json['Genres'] as List?)?.firstOrNull as String?,
  );

  static String? _mbid(Map<String, dynamic> json) {
    final providerIds = json['ProviderIds'];
    if (providerIds is Map) {
      return providerIds['MusicBrainzTrack'] as String? ??
          providerIds['MusicBrainzRecording'] as String? ??
          providerIds['MusicBrainzId'] as String?;
    }
    return null;
  }

  static String? _artist(Map<String, dynamic> json) {
    final albumArtist = json['AlbumArtist'];
    if (albumArtist is String && albumArtist.isNotEmpty) return albumArtist;
    final artists = json['Artists'];
    if (artists is List && artists.isNotEmpty) return '${artists.first}';
    return null;
  }

  /// The artist item's id, from the same field the display name comes from.
  /// The song queries do not ask for `AlbumArtists` unless a song carries it
  /// inline, so null is common and the credit line stays plain text then.
  static String? _artistId(Map<String, dynamic> json) {
    final albumArtists = json['AlbumArtists'];
    if (albumArtists is List && albumArtists.isNotEmpty) {
      final first = albumArtists.first;
      if (first is Map && first['Id'] != null) return '${first['Id']}';
    }
    final artistItems = json['ArtistItems'];
    if (artistItems is List && artistItems.isNotEmpty) {
      final first = artistItems.first;
      if (first is Map && first['Id'] != null) return '${first['Id']}';
    }
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
