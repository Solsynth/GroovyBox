import 'package:easy_localization/easy_localization.dart';

import 'package:dio/dio.dart';

import 'http.dart';
import 'lyrics.dart';
import 'lyrics_query.dart';
import 'lyrics_store.dart';
import 'models.dart';
import 'source.dart';
import 'track_identity.dart';

/// NetEase Cloud Music, read through a self-hosted NeteaseCloudMusicApi server.
///
/// The server is the user's own deployment of the open-source API bridge
/// (typically one `docker run` of NeteaseCloudMusicApi); GroovyBox ships no
/// address and no bundled service. The bridge speaks plain JSON over HTTP and
/// carries the login state as a cookie, which the app stores in
/// [SourceConfig.auth] like any other session token.
///
/// Capabilities, chosen by what the service can do rather than by kind:
/// [RatedSource] (the red-heart list), [CuratedSource] (daily recommendations
/// and personalised playlists) and [ResolvedStreamSource], because the
/// playback URL is minted per request by `song/url/v1` instead of being
/// derivable from the item.
class NeteaseAdapter implements InteractiveLoginAdapter {
  @override
  LibraryKind get kind => LibraryKind.netease;

  /// Runs anywhere with a network.
  @override
  bool get isAvailable => true;

  /// The address is the only thing typed; the account signs in by scanning
  /// the QR the bridge mints, because NetEase's risk control rejects plain
  /// password logins from API bridges.
  @override
  bool get needsCredentials => false;

  /// Never called: the setup screen drives [loginSteps] and
  /// [completeLogin] for an [InteractiveLoginAdapter].
  @override
  Future<SourceConfig> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) => completeLogin(baseUrl, const []);

  @override
  LibrarySource sourceFor(SourceConfig config) => NeteaseSource(config);

  // ---- interactive login ---------------------------------------------------

  /// QR sign-in: the bridge mints a unikey, renders it as a base64 QR, and
  /// the poll stream reports the scan state (801 waiting, 802 scanned,
  /// 803 authorized, 800 expired). The cookie arrives with the 803.
  @override
  List<LoginStep> loginSteps(String baseUrl) {
    final normalized = normalizeBaseUrl(baseUrl);
    final http = _NeteaseHttp(normalized, cookie: null);
    String? key;
    return [
      QrLoginStep(
        id: 'qr',
        prompt: 'setupNeteaseScanQr'.tr(),
        prepare: () async {
          final keyBody = await http.get(
            '/login/qr/key',
            query: {'timestamp': DateTime.now().millisecondsSinceEpoch},
          );
          final keyData = keyBody['data'];
          final unikey = keyData is Map ? keyData['unikey'] : null;
          if (unikey is! String || unikey.isEmpty) {
            throw http.errorOf(keyBody);
          }
          key = unikey;
          final qrBody = await http.get(
            '/login/qr/create',
            query: {
              'key': unikey,
              'qrimg': true,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );
          final qrData = qrBody['data'];
          final qrimg = qrData is Map ? qrData['qrimg'] : null;
          if (qrimg is! String || qrimg.isEmpty) {
            throw http.errorOf(qrBody);
          }
          return qrimg;
        },
        poll: () async* {
          final pollingKey = key;
          if (pollingKey == null) {
            throw const LibraryException(
              'The QR code was not prepared. Start again.',
              messageKey: 'libraryNeteaseNoCookie',
            );
          }
          // 800 ends the stream rather than retrying: an expired code needs a
          // fresh key, which is a new login, not another poll.
          while (true) {
            await Future<void>.delayed(const Duration(seconds: 2));
            final check = await http.get(
              '/login/qr/check',
              query: {
                'key': pollingKey,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              },
            );
            final code = (check['code'] as num?)?.toInt();
            if (code == null) continue;
            // 803 is the answer that *carries* the session, so the cookie is
            // stored before the state is emitted: the screen reacts to 803 by
            // completing the login, and an event that arrived before the
            // cookie would complete it with nothing to store.
            if (code == 803) {
              _cookie = _cookieFrom(check, http.lastSetCookie);
              yield code;
              return;
            }
            yield code;
            if (code == 800) {
              throw LibraryException(
                'The QR code expired. Start again.',
                messageKey: 'libraryNeteaseQrExpired',
              );
            }
          }
        },
      ),
    ];
  }

  /// The session the 803 handed back.
  ///
  /// The bridge states it twice — `cookie` in the body, and as `Set-Cookie`
  /// headers — and different builds populate one, the other, or both. The body
  /// wins (it is the one the bridge documents); the headers are the fallback.
  static String? _cookieFrom(Map<String, dynamic> body, String? setCookie) {
    final bodyCookie = body['cookie'];
    if (bodyCookie is String && bodyCookie.trim().isNotEmpty) {
      return bodyCookie.trim();
    }
    final header = setCookie?.trim();
    return header == null || header.isEmpty ? null : header;
  }

  String? _cookie;

  @override
  Future<SourceConfig> completeLogin(
    String baseUrl,
    List<LoginStep> steps,
  ) async {
    final cookie = _cookie;
    if (cookie == null || cookie.isEmpty) {
      throw const LibraryException(
        'The sign-in did not complete. Try again.',
        messageKey: 'libraryNeteaseNoCookie',
      );
    }
    final normalized = normalizeBaseUrl(baseUrl);
    final source = NeteaseSource(
      SourceConfig(
        id: newSourceId(LibraryKind.netease),
        kind: LibraryKind.netease,
        baseUrl: normalized,
        displayName: '',
        auth: {'cookie': cookie},
      ),
    );
    // One read proves the session works and learns the account's name for
    // the settings row, in the same call.
    final account = await source.accountName();
    return SourceConfig(
      id: source.config.id,
      kind: LibraryKind.netease,
      baseUrl: normalized,
      displayName: account ?? 'NetEase Cloud Music',
      auth: {'cookie': cookie},
    );
  }
}

/// The HTTP half of the bridge: every endpoint is a GET with query
/// parameters, the login cookie rides along as the `cookie` query parameter
/// the bridge documents, and errors come back as `{code, msg}` with HTTP 200
/// more often than not.
class _NeteaseHttp {
  _NeteaseHttp(this.baseUrl, {required this.cookie});

  final String baseUrl;
  final String? cookie;

  /// The `Set-Cookie` pairs the last answer carried, as one `Cookie` header
  /// value. Login hands the session back this way on builds whose module
  /// returns cookies as headers instead of a body field; every other call
  /// ignores it.
  String? lastSetCookie;
  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.json,
    ),
  );

  void close() => _dio.close();

  /// One call to the bridge. Returns the body map, or throws
  /// [LibraryException] with the bridge's own words when it refuses.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(path, query: query);

  /// The login endpoints are POSTs in the bridge's own examples, but the
  /// server accepts both; POST keeps passwords out of server access logs.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(path, query: query, method: 'post');

  Future<Map<String, dynamic>> _send(
    String path, {
    Map<String, dynamic>? query,
    String method = 'get',
  }) async {
    final fullQuery = <String, dynamic>{...?query};
    // The bridge takes the session as a `cookie` parameter (URL-encoded) —
    // sending it on every call is what keeps a stateless client signed in.
    if (cookie != null) fullQuery['cookie'] = cookie;
    final Response<dynamic> response;
    try {
      response = method == 'post'
          ? await _dio.post<dynamic>(
              '$baseUrl$path',
              queryParameters: fullQuery,
            )
          : await _dio.get<dynamic>(
              '$baseUrl$path',
              queryParameters: fullQuery,
            );
    } on DioException catch (error) {
      // A 404 means the request reached *something* but not the bridge's
      // route: the address carries a path prefix the bridge does not mount
      // under, or points at a host that is not an API at all. Saying "HTTP
      // 404" leaves the user with nowhere to go, so name the likely cause.
      if (error.response?.statusCode == 404) {
        throw const LibraryException(
          'The address answered 404. It must be the API server itself: no '
          'path after the host, and not its documentation page.',
          code: 404,
          messageKey: 'libraryNeteaseNotFound',
        );
      }
      throw describeDioError(error);
    }
    // A bridge answers JSON on every route. HTML means the address is a web
    // page — typically the project's docs site, which answers 200 to any
    // path — so the failure is the address, not a broken response.
    final contentType = response.headers.value('content-type') ?? '';
    if (contentType.contains('text/html')) {
      throw const LibraryException(
        'That address serves a web page, not the API. Use the address the '
        'API server itself listens on.',
        messageKey: 'libraryNeteaseNotApi',
      );
    }
    lastSetCookie = _cookieHeader(response.headers);
    final data = response.data;
    if (data is! Map) {
      throw const LibraryException(
        'Malformed NetEase response.',
        messageKey: 'libraryMalformedResponse',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  /// The `Set-Cookie` headers of one answer, as the `Cookie` header a later
  /// request would send: name=value pairs, attributes dropped.
  static String? _cookieHeader(Headers headers) {
    final raw = headers.map['set-cookie'];
    if (raw == null || raw.isEmpty) return null;
    final pairs = <String>[];
    for (final entry in raw) {
      for (final cookie in entry.split(',')) {
        // Everything after the first `;` is an attribute (`Path`, `HttpOnly`,
        // `Expires`) and is not part of what a later request sends.
        final pair = cookie.split(';').first.trim();
        final eq = pair.indexOf('=');
        if (eq <= 0 || eq == pair.length - 1) continue;
        pairs.add(pair);
      }
    }
    return pairs.isEmpty ? null : pairs.join('; ');
  }

  /// The bridge answers `code: 200` for success and carries a `body` that is
  /// itself the payload; anything else is the failure the UI should show.
  LibraryException errorOf(Map<String, dynamic> body) => LibraryException(
    '${body['msg'] ?? body['message'] ?? 'NetEase refused the request.'}',
    code: (body['code'] as num?)?.toInt(),
    messageKey: 'libraryNeteaseRequestFailed',
  );
}

/// One signed-in NetEase Cloud Music account, via the user's own bridge.
///
/// Every read the merged library performs is answered in the app's neutral
/// models; nothing in the app knows this source came from NetEase except the
/// setup row that names it.
class NeteaseSource extends LibrarySource
    implements
        RatedSource,
        CuratedSource,
        ResolvedStreamSource,
        LyricsQuerySource {
  NeteaseSource(this.config)
    : _http = _NeteaseHttp(config.baseUrl, cookie: config.auth['cookie']);

  @override
  final SourceConfig config;

  final _NeteaseHttp _http;

  /// The user id the session belongs to. Most reads take `uid`; the account
  /// endpoint states it once and the source keeps it.
  int? _userId;

  static const _malformed = LibraryException(
    'Malformed NetEase response.',
    messageKey: 'libraryMalformedResponse',
  );

  /// Guards every read: a session the bridge no longer recognises must not
  /// surface as a generic HTTP failure, but as "sign in again".
  Future<Map<String, dynamic>> _call(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final body = await _http.get(path, query: query);
    final code = (body['code'] as num?)?.toInt();
    if (code == 301) {
      throw const LibraryException(
        'This NetEase account is not signed in. Connect it again from Settings.',
        messageKey: 'libraryNeteaseSignedOut',
      );
    }
    return body;
  }

  Future<int> _uid() async {
    final known = _userId;
    if (known != null) return known;
    final body = await _call('/user/account');
    final account = body['profile'] ?? body['account'];
    if (account is! Map) throw _malformed;
    final id = (account['userId'] as num?)?.toInt();
    if (id == null) throw _malformed;
    return _userId = id;
  }

  /// The signed-in account's nickname, or null when the bridge does not say.
  /// Used by [NeteaseAdapter.completeLogin] to name the settings row.
  Future<String?> accountName() async {
    final body = await _call('/user/account');
    final profile = body['profile'];
    final nickname = profile is Map ? profile['nickname'] : null;
    return nickname is String && nickname.isNotEmpty ? nickname : null;
  }

  // ---- library reads -------------------------------------------------------

  /// The account's playlists, the ones it owns first.
  ///
  /// `/user/playlist` lists every playlist the account can see, created and
  /// collected alike; the own ones are the rows whose creator is this user,
  /// and they come first in the answer.
  @override
  Future<List<LibraryPlaylist>> playlists() async {
    final uid = await _uid();
    final body = await _call('/user/playlist', query: {'uid': uid});
    final list = body['playlist'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) _playlist(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<List<LibrarySong>> playlistSongs(String playlistId) async {
    final body = await _call(
      '/playlist/track/all',
      query: {'id': playlistId, 'limit': 1000},
    );
    return _songs(body['songs']);
  }

  /// The album list is the collected-album endpoint: NetEase has no "my
  /// albums" other than the ones the account subscribed to, and that is what
  /// a library page shows.
  @override
  Future<List<LibraryAlbum>> albums({int limit = 60, int offset = 0}) async {
    final body = await _call(
      '/album/sublist',
      query: {'limit': limit, 'offset': offset},
    );
    return _albums(body['data']);
  }

  @override
  Future<LibraryAlbum?> album(String albumId) async {
    final body = await _call('/album', query: {'id': albumId});
    final album = body['album'];
    return album is Map ? _album(Map<String, dynamic>.from(album)) : null;
  }

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async {
    final body = await _call('/album', query: {'id': albumId});
    final album = body['album'];
    final songs = album is Map ? album['songs'] : null;
    return _songs(songs);
  }

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) async {
    // The subscription list has no "added at"; the newest row the service
    // offers is what the merged library's newest shelf wants, in its order.
    return albums(limit: limit);
  }

  /// The artists the account follows. NetEase does not keep a "my artists"
  /// beyond follows, so this is the honest answer.
  @override
  Future<List<LibraryArtist>> artists() async {
    final body = await _call('/artist/sublist', query: {'limit': 200});
    return _artists(body['data']);
  }

  @override
  Future<List<LibraryAlbum>> artistAlbums(String artistId) async {
    final body = await _call(
      '/artist/album',
      query: {'id': artistId, 'limit': 100},
    );
    return _albums(body['hotAlbums']);
  }

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final body = await _call(
      '/cloudsearch',
      query: {'keywords': term, 'type': 1, 'limit': limit},
    );
    final result = body['result'];
    return _songs(result is Map ? result['songs'] : null);
  }

  @override
  Future<List<LibrarySong>> randomSongs({int size = 40}) async {
    // No random endpoint; the personalised new-song feed is the closest
    // thing the service curates itself.
    final body = await _call('/personalized/newsong', query: {'limit': size});
    final result = body['result'];
    return _songs(result is Map ? result['songs'] : null)..shuffle();
  }

  /// The daily mix, as the landing page's own shelf.
  @override
  Future<List<LandingShelf>> landingShelves() async {
    final shelves = <LandingShelf>[];
    try {
      final daily = await _call('/recommend/songs');
      final data = daily['data'];
      final songs = _songs(data is Map ? data['dailySongs'] : null);
      if (songs.isNotEmpty) {
        shelves.add(
          LandingShelf(
            title: 'shelfNeteaseDaily'.tr(),
            sourceId: id,
            songs: songs,
          ),
        );
      }
    } on LibraryException {
      // A signed-out recommendation must not blank the whole page; the other
      // shelves still count.
    }
    return shelves;
  }

  /// What the account has, for the row that manages this connection.
  @override
  Future<LibraryDigest?> digest() async {
    try {
      final uid = await _uid();
      final body = await _call('/user/playlist', query: {'uid': uid});
      final list = body['playlist'];
      final own = list is List
          ? list
                .whereType<Map>()
                .where((item) => item['userId'] == uid)
                .toList()
          : const <Map>[];
      return LibraryDigest(
        sourceId: id,
        libraryTracks: own.isEmpty
            ? null
            : own.fold<int>(
                0,
                (total, item) =>
                    total + ((item['trackCount'] as num?)?.toInt() ?? 0),
              ),
      );
    } on LibraryException {
      return null;
    }
  }

  // ---- favourites ----------------------------------------------------------

  /// The red-heart list, answered as a set of ids.
  ///
  /// `/likelist` returns ids only, so whether one song is in it costs one
  /// read of the whole list. It is cached for a short window: the heart on
  /// one row does not need the service asked again for each redraw.
  Set<String>? _likedIds;
  DateTime _likedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Set<String>> _likes() async {
    final cached = _likedIds;
    if (cached != null &&
        DateTime.now().difference(_likedAt) < const Duration(seconds: 30)) {
      return cached;
    }
    final uid = await _uid();
    final body = await _call('/likelist', query: {'uid': uid});
    final ids = body['ids'];
    final liked = ids is List
        ? {for (final id in ids) '$id'}
        : const <String>{};
    _likedIds = liked;
    _likedAt = DateTime.now();
    return liked;
  }

  @override
  Future<bool> isFavourite(LibrarySong song) async {
    try {
      return (await _likes()).contains(song.id);
    } on LibraryException {
      return false;
    }
  }

  @override
  Future<void> setFavourite(LibrarySong song, {required bool value}) async {
    final body = await _call('/like', query: {'id': song.id, 'like': value});
    final code = (body['code'] as num?)?.toInt();
    if (code != 200) {
      throw _http.errorOf(body);
    }
    // The cached list is now wrong by one entry; the next read within the
    // window must not answer the old state.
    _likedIds = null;
  }

  /// The red-heart list, resolved to songs in one `/song/detail` read.
  ///
  /// `/likelist` answers ids only, so the ids are handed to the detail
  /// endpoint in batches: a per-id read would be one request per heart.
  @override
  Future<List<LibrarySong>> favouriteSongs() async {
    final ids = (await _likes()).toList();
    if (ids.isEmpty) return const [];
    final songs = <LibrarySong>[];
    for (var start = 0; start < ids.length; start += 100) {
      final batch = ids.sublist(
        start,
        start + 100 > ids.length ? ids.length : start + 100,
      );
      final body = await _call('/song/detail', query: {'ids': batch.join(',')});
      songs.addAll(_songs(body['songs']));
    }
    return songs;
  }

  // ---- playback ------------------------------------------------------------

  /// The playback URL, minted per request by the bridge.
  ///
  /// `/song/url/v1` answers `{data: [{url, ...}]}`; a `null` url means the
  /// account cannot hear the track (no entitlement, or no licence in the
  /// region), which is a refusal the UI can explain, not a network failure.
  final Map<String, (Uri, DateTime)> _streamCache = {};

  @override
  Future<Uri> resolveStreamUri(LibrarySong song) async {
    final cached = _streamCache[song.id];
    if (cached != null && DateTime.now().isBefore(cached.$2)) {
      return cached.$1;
    }
    final body = await _call(
      '/song/url/v1',
      query: {'id': song.id, 'level': 'exhigh'},
    );
    final data = body['data'];
    final first = data is List && data.isNotEmpty ? data.first : null;
    final url = first is Map ? first['url'] : null;
    if (url is! String || url.isEmpty) {
      throw const LibraryException(
        'This track cannot be played with the current account.',
        messageKey: 'libraryNeteaseUnavailable',
      );
    }
    final uri = Uri.parse(url);
    // The minted URL is short-lived; ten minutes keeps one queue position
    // from re-asking during a long listen without outliving the token.
    _streamCache[song.id] = (
      uri,
      DateTime.now().add(const Duration(minutes: 10)),
    );
    return uri;
  }

  /// Never called on this source: [Playback] asks [resolveStreamUri] first
  /// because the source has the capability.
  @override
  Uri streamUri(LibrarySong song) => throw const LibraryException(
    'NetEase tracks are streamed through a resolved URL.',
    messageKey: 'libraryNeteaseNoStream',
  );

  // ---- lyrics --------------------------------------------------------------

  /// The service's own lyrics, plain or synced.
  ///
  /// `/lyric` answers `lrc` (synced) and `tlyric` (translation) as LRC text;
  /// an empty answer means the song has none, which is not an error.
  @override
  Future<Lyrics> lyrics(LibrarySong song) async {
    final body = await _call('/lyric', query: {'id': song.id});
    final lrc = body['lrc'];
    final raw = lrc is Map ? lrc['lyric'] : null;
    if (raw is! String || raw.isEmpty) return Lyrics.empty;
    final main = await parseLrcAsync(raw);
    final tlyric = body['tlyric'];
    final translationRaw = tlyric is Map ? tlyric['lyric'] : null;
    if (translationRaw is! String || translationRaw.isEmpty) return main;
    final translation = await parseLrcAsync(translationRaw);
    return mergeLyricLayers(main: main, translation: translation);
  }

  // ---- lyrics lookup -------------------------------------------------------

  /// Whether this source can answer lyrics questions at all.
  ///
  /// A signed-out bridge still answers `/lyric` for any id, but searching a
  /// catalogue without a session is what NetEase rate-limits and eventually
  /// refuses, so an account that is not signed in does not offer the
  /// capability: the resolver falls through to the services that still can.
  bool get canQueryLyrics => (config.auth['cookie'] ?? '').isNotEmpty;

  /// Finds words for a song this account does not necessarily hold.
  ///
  /// The catalogue is searched by title and artist (the bridge's
  /// `/cloudsearch`), the best-matching row is chosen with the same identity
  /// rules the rest of the app uses, and its `/lyric` is read. A miss the
  /// service confirmed is [LyricsLookup.missing]; a session that has expired
  /// is *not* settled, because the same song would be found next time.
  @override
  Future<LyricsLookup> findLyrics(LyricsRequest song) async {
    if (!canQueryLyrics) return LyricsLookup.unknown;
    final query = [song.artist, song.title]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (query.isEmpty) return LyricsLookup.missing;

    final List<LibrarySong> candidates;
    try {
      candidates = await search(query, limit: 10);
    } on LibraryException {
      // An expired session or a refusal is "could not ask", not "no such
      // lyric": caching it would blank every matching track.
      return LyricsLookup.unknown;
    }
    final identity = TrackIdentity.ofRequest(
      title: song.title,
      artist: song.artist,
      duration: song.duration,
    );
    LibrarySong? best;
    for (final candidate in candidates) {
      if (!identity.matches(TrackIdentity.of(candidate))) continue;
      // A timed lyric is not knowable before the fetch, so the first row that
      // is the same recording wins: the service already ranked by relevance.
      best = candidate;
      break;
    }
    best ??= candidates.length == 1 ? candidates.single : null;
    if (best == null) return LyricsLookup.missing;

    try {
      final found = await lyrics(best);
      return found.isEmpty
          ? LyricsLookup.missing
          : LyricsLookup(
              result: LyricsHit(
                lyrics: found,
                origin: LyricsOrigin.netease,
                id: int.tryParse(best.id),
              ),
              settled: true,
            );
    } on LibraryException {
      return LyricsLookup.unknown;
    }
  }

  /// Free-text search over the catalogue, for the manual picker.
  ///
  /// The bridge has no lyric-full-text endpoint, so the search is over songs
  /// and each hit's words are fetched: a picker row is a song whose lyrics
  /// the user is about to adopt, and offering one that cannot be fetched would
  /// be a dead row.
  @override
  Future<List<LyricsCandidate>?> searchLyrics(String query) async {
    if (!canQueryLyrics) return null;
    final term = query.trim();
    if (term.isEmpty) return const [];
    final List<LibrarySong> songs;
    try {
      songs = await search(term, limit: 12);
    } on LibraryException {
      return null;
    }
    final candidates = <LyricsCandidate>[];
    for (final song in songs) {
      try {
        final found = await lyrics(song);
        if (found.isEmpty) continue;
        candidates.add(
          LyricsCandidate(
            id: int.tryParse(song.id),
            title: song.title,
            artistName: song.artist,
            albumName: song.album,
            origin: LyricsOrigin.netease,
            duration: song.duration == Duration.zero ? null : song.duration,
            lyrics: found,
          ),
        );
      } on LibraryException {
        // One unreadable row must not sink the whole search.
        continue;
      }
    }
    return candidates;
  }

  // ---- artwork ---------------------------------------------------------------

  @override
  Uri? artworkUri(String? artId, {int size = 600}) {
    if (artId == null || artId.isEmpty) return null;
    if (!artId.startsWith('http')) return null;
    // NetEase covers are served at a fixed size; `?param=WxH` asks the CDN
    // for a resize instead of downloading the original every time.
    return Uri.parse('$artId?param=${size}y$size');
  }

  // ---- mapping -------------------------------------------------------------

  LibrarySong _song(Map<String, dynamic> json) {
    final artists = json['ar'] ?? json['artists'];
    final first = artists is List && artists.isNotEmpty
        ? Map<String, dynamic>.from(artists.first as Map)
        : null;
    final album = json['al'] ?? json['album'];
    final albumMap = album is Map ? Map<String, dynamic>.from(album) : null;
    return LibrarySong(
      sourceId: id,
      id: '${json['id']}',
      title: json['name'] as String? ?? 'Untitled',
      artist: first?['name'] as String?,
      artistId: first?['id']?.toString(),
      album: albumMap?['name'] as String?,
      albumId: albumMap?['id']?.toString(),
      artId: albumMap != null ? _picUrl(albumMap) : null,
      duration: Duration(
        milliseconds: (json['dt'] ?? json['duration'] as num?)?.toInt() ?? 0,
      ),
      track: (json['no'] as num?)?.toInt(),
      discNumber: (json['cd'] is num) ? (json['cd'] as num).toInt() : null,
      year: _year(json),
      // Fee 1 is VIP-only, 4 is a paid album, 8 is a low-quality free trial;
      // none of these change what the row shows, so they are not kept.
    );
  }

  List<LibrarySong> _songs(Object? raw) => raw is List
      ? [
          for (final item in raw)
            if (item is Map) _song(Map<String, dynamic>.from(item)),
        ]
      : const [];

  LibraryAlbum _album(Map<String, dynamic> json) {
    final artist = json['artist'] ?? json['ar'];
    final artistMap = artist is Map ? Map<String, dynamic>.from(artist) : null;
    return LibraryAlbum(
      sourceId: id,
      id: '${json['id']}',
      name: json['name'] as String? ?? 'Untitled',
      artist: artistMap?['name'] as String?,
      artistId: artistMap?['id']?.toString(),
      artId: _picUrl(json),
      songCount: (json['size'] as num?)?.toInt(),
      duration: Duration.zero,
      year: _publishTime(json),
      genre: null,
    );
  }

  List<LibraryAlbum> _albums(Object? raw) => raw is List
      ? [
          for (final item in raw)
            if (item is Map) _album(Map<String, dynamic>.from(item)),
        ]
      : const [];

  LibraryArtist _artist(Map<String, dynamic> json) => LibraryArtist(
    sourceId: id,
    id: '${json['id']}',
    name: json['name'] as String? ?? 'Unknown artist',
    artId: _picUrl(json),
  );

  List<LibraryArtist> _artists(Object? raw) => raw is List
      ? [
          for (final item in raw)
            if (item is Map) _artist(Map<String, dynamic>.from(item)),
        ]
      : const [];

  LibraryPlaylist _playlist(Map<String, dynamic> json) => LibraryPlaylist(
    sourceId: id,
    id: '${json['id']}',
    name: json['name'] as String? ?? 'Untitled playlist',
    owner: json['creator'] is Map
        ? ((json['creator'] as Map)['nickname'] as String?)
        : null,
    songCount: (json['trackCount'] as num?)?.toInt(),
    duration: Duration.zero,
    artId: _picUrl(json),
  );

  /// The cover URL, whichever of the shapes the endpoints answer with.
  static String? _picUrl(Map<String, dynamic> json) {
    final url =
        json['picUrl'] ??
        json['coverImgUrl'] ??
        json['pic_str'] ??
        json['picUrl_str'];
    return url is String && url.isNotEmpty ? url : null;
  }

  static int? _year(Map<String, dynamic> json) {
    final publish = json['publishTime'];
    if (publish is num && publish > 0) {
      return DateTime.fromMillisecondsSinceEpoch(publish.toInt()).year;
    }
    return null;
  }

  static int? _publishTime(Map<String, dynamic> json) => _year(json);
}
