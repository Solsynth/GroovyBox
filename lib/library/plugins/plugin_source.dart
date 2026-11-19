import 'dart:async';

import '../http_cache.dart';
import '../lyrics.dart';
import '../models.dart';
import '../source.dart';
import 'plugin_host.dart';
import 'plugin_schema.dart';

/// A library implemented by an installed JS plugin.
///
/// Everything a provider knows arrives as JSON from [PluginHost.call] and is
/// mapped onto the neutral models here, so no screen ever learns a plugin's
/// vocabulary. The three capabilities it advertises are the three the app asks
/// of a streaming provider: it resolves playback URLs per request
/// ([ResolvedStreamSource]), it may carry per-stream headers (Bilibili's CDN
/// wants a `Referer`), and it can say something about the account it serves
/// ([CuratedSource]).
///
/// A read whose function the provider does not declare answers empty instead
/// of throwing: merged reads call every method, and a plugin that only streams
/// must not litter the landing page with failures. Only a declared function
/// that fails surfaces an error.
class PluginSource extends LibrarySource
    implements ResolvedStreamSource, CuratedSource {
  PluginSource(
    this.config, {
    required this.host,
    this.missing = false,
  });

  @override
  final SourceConfig config;

  /// Null on a platform without a plugin runtime; every read then reports the
  /// plugin as missing rather than crashing at resolve time.
  final PluginHost? host;

  /// The plugin this config names is not installed (a settings row that
  /// outlived it, or a backup restored onto a machine without it).
  final bool missing;

  /// Extra headers per song id, kept from [resolveStreamUri] until the stream
  /// is opened. Bounded: a queue position is resolved once and rarely again,
  /// so unbounded growth is the only real hazard.
  final Map<String, Map<String, String>> _streamHeaders = {};

  static const _kMaxHeaderEntries = 64;

  String get _providerId => config.auth['providerId'] ?? '';

  /// Overrides the stored `baseUrl`: that is the plugin's manifest id, which
  /// is not an address and must not be printed as one.
  @override
  String get addressLabel => '';

  /// The provider this config was connected to, when its plugin still declares
  /// it. Null means the manifest changed under a stored config.
  PluginProvider? get _provider => host?.providers
      .where(
        (provider) =>
            provider.pluginId == config.baseUrl &&
            provider.providerId == _providerId,
      )
      .firstOrNull;

  /// Whether [fn] may be called. An unknown provider is asked anyway: the
  /// plugin's own answer is a better error than a silent empty one.
  bool _declares(String fn) => _provider?.declares(fn) ?? true;

  void _requireInstalled() {
    if (missing || host == null) {
      throw LibraryException(
        'This plugin is not installed.',
        messageKey: 'libraryPluginMissing',
      );
    }
  }

  /// Calls [fn] on this connection's provider.
  Future<Map<String, dynamic>> _call(
    String fn, [
    Map<String, dynamic> args = const {},
  ]) {
    _requireInstalled();
    return host!.call(
      pluginId: config.baseUrl,
      providerId: _providerId,
      fn: fn,
      args: args,
      auth: config.auth,
      baseUrl: config.baseUrl,
      // A provider's reads are listings; a random draw is the one function
      // whose answer is meant to differ on every call.
      cachePolicy: fn == 'randomSongs'
          ? CachePolicy.none
          : CachePolicy.medium,
    );
  }

  /// An answer of `{ok: true, songs: [...]}`.
  Future<List<LibrarySong>> _songs(
    String fn,
    Map<String, dynamic> args,
  ) async {
    if (!_declares(fn)) return const [];
    final answer = await _call(fn, args);
    return _list(answer['songs']).map(_song).toList();
  }

  Future<List<LibraryAlbum>> _albums(
    String fn,
    Map<String, dynamic> args,
  ) async {
    if (!_declares(fn)) return const [];
    final answer = await _call(fn, args);
    return _list(answer['albums']).map(_album).toList();
  }

  // ---- reads ----------------------------------------------------------------

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) =>
      _albums('recentlyAdded', {'limit': limit});

  @override
  Future<List<LibraryAlbum>> albums({int limit = 60, int offset = 0}) =>
      _albums('albums', {'limit': limit, 'offset': offset});

  @override
  Future<LibraryAlbum?> album(String albumId) async {
    if (!_declares('album')) return null;
    final answer = await _call('album', {'albumId': albumId});
    final album = answer['album'];
    if (album is! Map) return null;
    return _album(album);
  }

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) =>
      _songs('albumSongs', {'albumId': albumId});

  @override
  Future<List<LibraryArtist>> artists() async {
    if (!_declares('artists')) return const [];
    final answer = await _call('artists');
    return [
      for (final json in _list(answer['artists']))
        LibraryArtist(
          sourceId: id,
          id: _text(json['id']) ?? '',
          name: _text(json['name']) ?? '',
          artId: _text(json['artId']),
          albumCount: _int(json['albumCount']),
        ),
    ];
  }

  @override
  Future<List<LibraryAlbum>> artistAlbums(String artistId) =>
      _albums('artistAlbums', {'artistId': artistId});

  @override
  Future<List<LibraryPlaylist>> playlists() async {
    if (!_declares('playlists')) return const [];
    final answer = await _call('playlists');
    return [
      for (final json in _list(answer['playlists']))
        LibraryPlaylist(
          sourceId: id,
          id: _text(json['id']) ?? '',
          name: _text(json['name']) ?? '',
          owner: _text(json['owner']),
          songCount: _int(json['songCount']),
          duration: _duration(json['durationMs']),
          artId: _text(json['artId']),
        ),
    ];
  }

  @override
  Future<List<LibrarySong>> playlistSongs(String playlistId) =>
      _songs('playlistSongs', {'playlistId': playlistId});

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) =>
      _songs('search', {'query': query, 'limit': limit});

  @override
  Future<List<LibrarySong>> randomSongs({int size = 40}) =>
      _songs('randomSongs', {'size': size});

  @override
  Future<Lyrics> lyrics(LibrarySong song) async {
    if (!_declares('lyrics')) return Lyrics.empty;
    final answer = await _call('lyrics', {'song': song.toJson()});
    final lrc = _text(answer['lrc']);
    if (lrc == null || lrc.trim().isEmpty) return Lyrics.empty;
    return parseLrcAsync(lrc);
  }

  // ---- playback -------------------------------------------------------------

  /// Never called: a plugin mints its URLs, so [`resolveStreamUri`] answers
  /// instead. Kept as a refusal rather than a guess, as NetEase's is.
  @override
  Uri streamUri(LibrarySong song) => throw const LibraryException(
    'Plugin tracks are streamed through a resolved URL.',
    messageKey: 'libraryPluginFailed',
  );

  @override
  Future<Uri> resolveStreamUri(LibrarySong song) async {
    if (!_declares('streamUri')) {
      throw const LibraryException(
        'This plugin does not stream tracks.',
        messageKey: 'libraryPluginFailed',
      );
    }
    final answer = await _call('streamUri', {'song': song.toJson()});

    // A provider that holds the track but will not licence it: the excerpt is
    // the answer, and the caller falls back through `findCopies` exactly as it
    // does for NetEase.
    final preview = _text(answer['previewUrl']);
    if (preview != null && preview.isNotEmpty) {
      throw PreviewOnlyException(
        Uri.parse(preview),
        'Only a preview is available.',
        messageKey: 'libraryPluginPreviewOnly',
      );
    }

    final url = _text(answer['url']);
    if (url == null || url.isEmpty) {
      throw const LibraryException(
        'The plugin did not return a stream.',
        messageKey: 'libraryPluginFailed',
      );
    }
    _rememberHeaders(song, answer['headers']);
    return Uri.parse(url);
  }

  void _rememberHeaders(LibrarySong song, Object? raw) {
    if (raw is! Map || raw.isEmpty) {
      _streamHeaders.remove(song.id);
      return;
    }
    if (_streamHeaders.length >= _kMaxHeaderEntries) _streamHeaders.clear();
    _streamHeaders[song.id] = {
      for (final entry in raw.entries)
        if (entry.value != null) '${entry.key}': '${entry.value}',
    };
  }

  @override
  Map<String, String> streamHeaders(LibrarySong song) =>
      _streamHeaders[song.id] ?? const {};

  @override
  Uri? artworkUri(String? artId, {int size = 600}) {
    if (artId == null || artId.isEmpty) return null;
    // The provider carries the cover URL it already knows, with an optional
    // `{size}` token: artwork has to answer synchronously, so it is data, never
    // a request.
    return Uri.tryParse(artId.replaceAll('{size}', '$size'));
  }

  // ---- curated --------------------------------------------------------------

  /// A plugin has no shelves of its own: its landing contribution is the
  /// ordinary merged reads, which it already answers.
  @override
  Future<List<LandingShelf>> landingShelves() async => const [];

  @override
  Future<LibraryDigest?> digest() async {
    if (!_declares('digest')) return null;
    try {
      final answer = await _call('digest');
      final tracks = _int(answer['tracks']);
      if (tracks == null) return null;
      return LibraryDigest(sourceId: id, libraryTracks: tracks);
    } catch (error) {
      // The row's failure banner is the place for a broken plugin; a digest is
      // optional garnish and must not add a second complaint.
      return null;
    }
  }

  // ---- mapping --------------------------------------------------------------

  LibrarySong _song(Map<dynamic, dynamic> json) => LibrarySong(
    sourceId: id,
    id: _text(json['id']) ?? '',
    title: _text(json['title']) ?? '',
    artist: _text(json['artist']),
    artistId: _text(json['artistId']),
    album: _text(json['album']),
    albumId: _text(json['albumId']),
    artId: _text(json['artId']),
    duration: _duration(json['durationMs']),
    track: _int(json['track']),
    discNumber: _int(json['discNumber']),
    year: _int(json['year']),
    genre: _text(json['genre']),
  );

  LibraryAlbum _album(Map<dynamic, dynamic> json) => LibraryAlbum(
    sourceId: id,
    id: _text(json['id']) ?? '',
    name: _text(json['name']) ?? '',
    artist: _text(json['artist']),
    artistId: _text(json['artistId']),
    artId: _text(json['artId']),
    songCount: _int(json['songCount']),
    duration: _duration(json['durationMs']),
    year: _int(json['year']),
    genre: _text(json['genre']),
  );
}

List<Map<dynamic, dynamic>> _list(Object? raw) => [
  for (final entry in raw is List ? raw : const [])
    if (entry is Map) entry,
];

String? _text(Object? raw) => switch (raw) {
  final String value => value,
  final num value => '$value',
  _ => null,
};

int? _int(Object? raw) => switch (raw) {
  final int value => value,
  final num value => value.round(),
  final String value => int.tryParse(value) ?? double.tryParse(value)?.round(),
  _ => null,
};

/// A missing length stays zero rather than null: [LibrarySong.duration] is not
/// optional, and a provider that does not know is better served by "unknown"
/// than by a number it made up.
Duration _duration(Object? raw) =>
    Duration(milliseconds: _int(raw) ?? 0);
