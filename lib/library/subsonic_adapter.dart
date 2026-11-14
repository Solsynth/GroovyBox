import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';

import 'http.dart';
import 'lyrics.dart';
import 'models.dart';
import 'source.dart';

/// Subsonic / OpenSubsonic / Navidrome / Gonic and friends.
class SubsonicAdapter implements LibraryAdapter {
  @override
  LibraryKind get kind => LibraryKind.subsonic;

  /// Runs anywhere with a network.
  @override
  bool get isAvailable => true;

  /// Address, username and password are exactly what a Subsonic server needs.
  @override
  bool get needsCredentials => true;

  @override
  Future<SourceConfig> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final root = normalizeBaseUrl(baseUrl, suffix: '/rest');
    final salt = _randomSalt();
    final config = SourceConfig(
      id: newSourceId(LibraryKind.subsonic),
      kind: LibraryKind.subsonic,
      baseUrl: root,
      displayName: _displayNameFor(root),
      auth: {
        'username': username,
        'token': crypto.md5.convert(utf8.encode('$password$salt')).toString(),
        'salt': salt,
      },
    );
    await SubsonicSource(config).ping();
    return config;
  }

  @override
  LibrarySource sourceFor(SourceConfig config) => SubsonicSource(config);

  /// The server host, used when the caller passes no display name.
  static String _displayNameFor(String normalizedUrl) =>
      Uri.parse(normalizedUrl).host;

  /// Subsonic's token auth: `t = md5(password + salt)`. The salt only has to
  /// make the hash unusable for replay on its own, not to be secret.
  static String _randomSalt() {
    final random = Random.secure();
    final values = List<int>.generate(8, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }
}

/// Client identity sent as `c` / `v`; the server uses these for its own
/// bookkeeping and some deployments reject requests without them.
const _appName = 'GroovyBox';
const _apiVersion = '1.16.1';

/// One connected Subsonic server.
///
/// Every call goes through [_request], which unwraps the standard
/// `subsonic-response` envelope, converts `status: failed` into a
/// [LibraryException] and returns the inner map. That keeps the individual
/// endpoints readable and means no caller ever sees the envelope.
class SubsonicSource extends LibrarySource implements RatedSource {
  @override
  final SourceConfig config;
  final Dio _dio;

  SubsonicSource(this.config)
    : _dio = Dio(
        BaseOptions(
          baseUrl: normalizeBaseUrl(config.baseUrl, suffix: '/rest'),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          responseType: ResponseType.json,
          // The API is queried with query parameters only; no JSON bodies.
          contentType: Headers.jsonContentType,
        ),
      );

  String get _username {
    final username = config.auth['username'];
    if (username == null) throw _signedOut;
    return username;
  }

  String get _token {
    final token = config.auth['token'];
    if (token == null) throw _signedOut;
    return token;
  }

  String get _salt {
    final salt = config.auth['salt'];
    if (salt == null) throw _signedOut;
    return salt;
  }

  static const _signedOut = LibraryException(
    'This library is not signed in. Connect it again from Settings.',
    messageKey: 'librarySignedOut',
  );

  String get _serverRoot {
    final url = normalizeBaseUrl(config.baseUrl, suffix: '/rest');
    return url.substring(0, url.length - '/rest'.length);
  }

  Map<String, dynamic> _authParams() => {
    'u': _username,
    'c': _appName,
    'v': _apiVersion,
    'f': 'json',
    't': _token,
    's': _salt,
  };

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
      throw describeDioError(error);
    }

    final data = response.data;
    if (data is! Map) {
      throw const LibraryException(
        'The server did not return a Subsonic response. '
        'Check that the URL points at a Subsonic-compatible API.',
        messageKey: 'libraryNotSubsonic',
      );
    }

    final envelope = data['subsonic-response'] ?? data['openSubsonic-response'];
    if (envelope is! Map) {
      throw const LibraryException(
        'Malformed server response.',
        messageKey: 'libraryMalformedResponse',
      );
    }

    if (envelope['status'] == 'failed') {
      final error = envelope['error'];
      final message = error is Map ? error['message'] as String? : null;
      throw LibraryException(
        // A Subsonic server names its own failure; show it untranslated.
        message ?? 'Request failed',
        code: error is Map ? (error['code'] as num?)?.toInt() : null,
        messageKey: message == null ? 'libraryRequestFailed' : null,
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

  Future<bool> ping() async {
    await _request('ping');
    return true;
  }

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) =>
      _albums(limit: limit, offset: 0, type: 'newest');

  @override
  Future<List<LibraryAlbum>> albums({int limit = 60, int offset = 0}) =>
      _albums(limit: limit, offset: offset, type: 'alphabeticalByName');

  Future<List<LibraryAlbum>> _albums({
    required int limit,
    required int offset,
    required String type,
  }) async {
    final body = await _request(
      'getAlbumList2',
      query: {'type': type, 'size': limit, 'offset': offset},
    );
    final albums = body['albumList2'];
    if (albums is! Map || albums['album'] is! List) return const [];
    return [
      for (final album in albums['album'] as List)
        if (album is Map) _albumFromJson(_stringKeyed(album)),
    ];
  }

  @override
  Future<LibraryAlbum?> album(String albumId) async {
    final body = await _request('getAlbum', query: {'id': albumId});
    final album = body['album'];
    return album is Map ? _albumFromJson(_stringKeyed(album)) : null;
  }

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async {
    final body = await _request('getAlbum', query: {'id': albumId});
    final album = body['album'];
    if (album is! Map || album['song'] is! List) return const [];
    return [
      for (final song in album['song'] as List)
        if (song is Map) _songFromJson(_stringKeyed(song)),
    ];
  }

  /// OpenSubsonic `getArtists` gives indexed entries; the flattened list is the
  /// union of every index bucket.
  @override
  Future<List<LibraryArtist>> artists() async {
    final body = await _request('getArtists');
    final index = body['artists'];
    if (index is! Map) return const [];
    final entries = index['index'];
    if (entries is! List) return const [];
    return [
      for (final bucket in entries)
        if (bucket is Map && bucket['artist'] is List)
          for (final artist in bucket['artist'] as List)
            if (artist is Map) _artistFromJson(_stringKeyed(artist)),
    ];
  }

  @override
  Future<List<LibraryAlbum>> artistAlbums(String artistId) async {
    final body = await _request('getArtist', query: {'id': artistId});
    final albums = body['artist'] is Map
        ? (body['artist'] as Map)['album']
        : null;
    if (albums is! List) return const [];
    return [
      for (final album in albums)
        if (album is Map) _albumFromJson(_stringKeyed(album)),
    ];
  }

  @override
  Future<List<LibraryPlaylist>> playlists() async {
    final body = await _request('getPlaylists');
    final playlists = body['playlists'];
    if (playlists is! Map || playlists['playlist'] is! List) return const [];
    return [
      for (final playlist in playlists['playlist'] as List)
        if (playlist is Map) _playlistFromJson(_stringKeyed(playlist)),
    ];
  }

  @override
  Future<List<LibrarySong>> playlistSongs(String playlistId) async {
    final body = await _request('getPlaylist', query: {'id': playlistId});
    final playlist = body['playlist'];
    if (playlist is! Map || playlist['entry'] is! List) return const [];
    return [
      for (final song in playlist['entry'] as List)
        if (song is Map) _songFromJson(_stringKeyed(song)),
    ];
  }

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    final body = await _request(
      'search3',
      query: {
        'query': query,
        'songCount': limit,
        'albumCount': 0,
        'artistCount': 0,
      },
    );
    final result = body['searchResult3'];
    if (result is! Map || result['song'] is! List) return const [];
    return [
      for (final song in result['song'] as List)
        if (song is Map) _songFromJson(_stringKeyed(song)),
    ];
  }

  @override
  Future<List<LibrarySong>> randomSongs({int size = 40}) async {
    final body = await _request('getRandomSongs', query: {'size': size});
    final random = body['randomSongs'];
    if (random is! Map || random['song'] is! List) return const [];
    return [
      for (final song in random['song'] as List)
        if (song is Map) _songFromJson(_stringKeyed(song)),
    ];
  }

  /// `/star` and `/unstar`, or the OpenSubsonic extension's identical pair.
  ///
  /// The star is the server's own favourite: Navidrome and Gonic surface it as
  /// a heart, and `getStarred` is the list it builds. A server that refuses the
  /// write throws, so the button can put the heart back where the server says.
  @override
  Future<void> setFavourite(LibrarySong song, {required bool value}) async {
    await _request(value ? 'star' : 'unstar', query: {'id': song.id});
  }

  /// Whether the server's `starred` field is set on [song].
  ///
  /// One `getSong` read rather than a starred-list scan: the song id is what
  /// the page already has, and a list of every star in a large library is not
  /// something to fetch to answer one boolean.
  @override
  Future<bool> isFavourite(LibrarySong song) async {
    try {
      final body = await _request('getSong', query: {'id': song.id});
      final songJson = body['song'];
      return songJson is Map && songJson['starred'] != null;
    } on LibraryException {
      // A server that cannot answer is drawn as "not set"; the tap reports.
      return false;
    }
  }

  /// OpenSubsonic's timed endpoint first, then the older plain-text one.
  ///
  /// A server that predates `songLyrics` answers the first call with an error
  /// code, which is not a playback failure: the second call is the honest
  /// fallback, and no lyrics at all is a normal answer for a lot of tracks.
  @override
  Future<Lyrics> lyrics(LibrarySong song) async {
    try {
      final body = await _request(
        'getLyricsBySongId',
        // `enhanced` only adds data on servers that know the songLyrics v2
        // extension; older ones ignore the parameter, and a server that
        // rejects it at all falls through to the classic endpoint below.
        query: {'id': song.id, 'enhanced': 'true'},
      );
      final structured = _structuredLyrics(body['lyricsList']);
      if (!structured.isEmpty) return structured;
    } on LibraryException {
      // Extension missing or the request failed; try the classic endpoint.
    }

    try {
      final body = await _request(
        'getLyrics',
        query: {'artist': ?song.artist, 'title': song.title},
      );
      final lyrics = body['lyrics'];
      final value = lyrics is Map ? lyrics['value'] : null;
      if (value is String && value.trim().isNotEmpty) {
        // Some servers store LRC in `value` even on the classic endpoint.
        return parseLrc(value);
      }
    } on LibraryException {
      // Unsupported endpoint or no lyrics; both read as "none" here.
    }
    return Lyrics.empty;
  }

  /// Splits the response into its layers and folds the readings onto the words.
  ///
  /// `kind` only appears on enhanced responses; when it is absent the entry is
  /// the song's own words. A translation or romanization is never shown in the
  /// main column — it annotates a line instead, aligned by its own stamps.
  static Lyrics _structuredLyrics(Object? list) {
    if (list is! Map) return Lyrics.empty;
    final entries = list['structuredLyrics'];
    if (entries is! List) return Lyrics.empty;

    Lyrics? main;
    Lyrics? unsyncedMain;
    Lyrics? pronunciation;
    Lyrics? translation;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final parsed = _layer(entry);
      if (parsed == null) continue;
      final kind = entry['kind'];
      switch (kind) {
        case 'pronunciation':
          pronunciation ??= parsed;
        case 'translation':
          translation ??= parsed;
        case _:
          // An unmarked entry is the main track; a synced one beats a plain.
          if (parsed.synced) {
            main ??= parsed;
          } else {
            unsyncedMain ??= parsed;
          }
      }
    }

    final words = main ?? unsyncedMain;
    if (words == null) return Lyrics.empty;
    return mergeLyricLayers(
      main: words,
      pronunciation: pronunciation,
      translation: translation,
    );
  }

  /// One `structuredLyrics` entry, or null when it carries no text.
  static Lyrics? _layer(Map entry) {
    final raw = entry['line'];
    if (raw is! List) return null;

    // The spec's offset is positive-when-earlier, so it subtracts.
    final offset = Duration(
      milliseconds: (entry['offset'] as num?)?.round() ?? 0,
    );
    final lines = <LyricLine>[];
    for (final line in raw) {
      if (line is! Map) continue;
      final start = Duration(
        milliseconds: (line['start'] as num?)?.round() ?? 0,
      );
      final at = start - offset;
      lines.add(
        LyricLine(
          at.isNegative ? Duration.zero : at,
          line['value'] as String? ?? '',
        ),
      );
    }
    if (lines.isEmpty) return null;

    final language = entry['lang'] as String?;
    return Lyrics(
      lines: lines,
      synced:
          entry['synced'] == true &&
          lines.any((line) => line.at > Duration.zero),
      language: language == 'xxx' ? null : language,
    );
  }

  /// A directly playable URL. media_kit can stream this as-is; the signed
  /// token travels in the query string, exactly like the API calls.
  @override
  Uri streamUri(LibrarySong song) {
    final params = {..._authParams(), 'id': song.id};
    return Uri.parse('$_serverRoot/rest/stream').replace(
      queryParameters: params.map((key, value) => MapEntry(key, '$value')),
    );
  }

  @override
  Uri? artworkUri(String? artId, {int size = 600}) {
    if (artId == null || artId.isEmpty) return null;
    final params = {..._authParams(), 'id': artId, 'size': '$size'};
    return Uri.parse('$_serverRoot/rest/getCoverArt').replace(
      queryParameters: params.map((key, value) => MapEntry(key, '$value')),
    );
  }

  LibrarySong _songFromJson(Map<String, dynamic> json) => LibrarySong(
    sourceId: config.id,
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled',
    artist: json['artist'] as String?,
    artistId: json['artistId'] as String?,
    album: json['album'] as String?,
    albumId: json['albumId'] as String?,
    artId: json['coverArt'] as String?,
    duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
    track: (json['track'] as num?)?.toInt(),
    discNumber: (json['discNumber'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
    mbid: json['musicBrainzId'] as String? ?? json['musicbrainzId'] as String?,
  );

  LibraryAlbum _albumFromJson(Map<String, dynamic> json) => LibraryAlbum(
    sourceId: config.id,
    id: json['id'] as String,
    name: json['name'] as String? ?? json['title'] as String? ?? 'Untitled',
    artist: json['artist'] as String?,
    artistId: json['artistId'] as String?,
    artId: json['coverArt'] as String?,
    songCount: (json['songCount'] as num?)?.toInt(),
    duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
  );

  LibraryArtist _artistFromJson(Map<String, dynamic> json) => LibraryArtist(
    sourceId: config.id,
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Unknown artist',
    artId: json['coverArt'] as String?,
    albumCount: (json['albumCount'] as num?)?.toInt(),
  );

  LibraryPlaylist _playlistFromJson(Map<String, dynamic> json) =>
      LibraryPlaylist(
        sourceId: config.id,
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled playlist',
        owner: json['owner'] as String?,
        songCount: (json['songCount'] as num?)?.toInt(),
        duration: Duration(seconds: (json['duration'] as num?)?.round() ?? 0),
        artId: json['coverArt'] as String?,
      );

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
}
