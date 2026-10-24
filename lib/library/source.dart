import 'jellyfin_adapter.dart';
import 'models.dart';
import 'subsonic_adapter.dart';

/// The kinds of library GroovyBox can talk to.
enum LibraryKind {
  subsonic('Subsonic', 'music.example.com'),
  jellyfin('Jellyfin', 'https://jellyfin.example.com:8096');

  const LibraryKind(this.label, this.addressHint);

  /// Shown in the setup picker and settings rows.
  final String label;

  /// Setup field placeholder.
  final String addressHint;
}

/// A persisted library connection.
///
/// [auth] keys are adapter-specific:
///   subsonic: username, token, salt
///   jellyfin: username, userId, accessToken
class SourceConfig {
  /// Stable instance id, e.g. `'jellyfin-m1k2j3'`.
  final String id;
  final LibraryKind kind;
  final String baseUrl;
  final String displayName;
  final Map<String, String> auth;

  const SourceConfig({
    required this.id,
    required this.kind,
    required this.baseUrl,
    required this.displayName,
    this.auth = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'baseUrl': baseUrl,
    'displayName': displayName,
    'auth': auth,
  };

  /// Returns null for a record that is not a map or names a kind this build
  /// does not know (e.g. a config written by a newer version).
  static SourceConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = LibraryKind.values
        .where((kind) => kind.name == raw['kind'])
        .firstOrNull;
    final id = raw['id'];
    final baseUrl = raw['baseUrl'];
    if (kind == null || id is! String || baseUrl is! String) return null;
    final auth = raw['auth'];
    return SourceConfig(
      id: id,
      kind: kind,
      baseUrl: baseUrl,
      displayName: raw['displayName'] is String
          ? raw['displayName'] as String
          : baseUrl,
      auth: auth is Map
          ? {
              for (final entry in auth.entries)
                '${entry.key}': '${entry.value}',
            }
          : const {},
    );
  }
}

/// One connected library: every read the app performs, in neutral models.
///
/// An abstract class rather than a pure interface so [id], [kind] and
/// [displayName] come from [config] instead of being repeated per adapter.
abstract class LibrarySource {
  SourceConfig get config;

  String get id => config.id;

  LibraryKind get kind => config.kind;

  String get displayName => config.displayName;

  Future<List<LibraryAlbum>> recentlyAdded({int limit});
  Future<List<LibraryAlbum>> albums({int limit, int offset});
  Future<LibraryAlbum?> album(String albumId);
  Future<List<LibrarySong>> albumSongs(String albumId);
  Future<List<LibraryArtist>> artists();
  Future<List<LibraryAlbum>> artistAlbums(String artistId);
  Future<List<LibraryPlaylist>> playlists();
  Future<List<LibrarySong>> playlistSongs(String playlistId);
  Future<List<LibrarySong>> search(String query, {int limit});
  Future<List<LibrarySong>> randomSongs({int size});

  Uri streamUri(LibrarySong song);
  Uri? artworkUri(String? artId, {int size});
}

/// The per-kind entry point: turns credentials into a stored config and turns
/// a stored config back into a [LibrarySource].
abstract interface class LibraryAdapter {
  LibraryKind get kind;

  /// Round-trips credentials against the server and returns a ready-to-store
  /// config. Throws [LibraryException] on bad address, bad credentials or an
  /// unreachable host. Used by both "Test connection" and "Connect".
  ///
  /// An empty [SourceConfig.displayName] means "use the server host".
  Future<SourceConfig> connect({
    required String baseUrl,
    required String username,
    required String password,
  });

  /// Cheap, offline: builds the source object from a stored config.
  LibrarySource sourceFor(SourceConfig config);
}

/// One adapter per kind.
final Map<LibraryKind, LibraryAdapter> libraryAdapters = {
  LibraryKind.subsonic: SubsonicAdapter(),
  LibraryKind.jellyfin: JellyfinAdapter(),
};

LibrarySource librarySourceFromConfig(SourceConfig config) =>
    libraryAdapters[config.kind]!.sourceFor(config);

/// `'<kind>-<base36 microseconds>'`; collision-free within a device.
String newSourceId(LibraryKind kind) =>
    '${kind.name}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
