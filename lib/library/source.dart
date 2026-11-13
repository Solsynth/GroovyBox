import 'package:easy_localization/easy_localization.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'apple_adapter.dart';
import 'jellyfin_adapter.dart';
import 'lyrics.dart';
import 'models.dart';
import 'subsonic_adapter.dart';

/// The kinds of library GroovyBox can talk to.
enum LibraryKind {
  subsonic('libraryKindSubsonic', 'libraryAddressSubsonic'),
  jellyfin('libraryKindJellyfin', 'libraryAddressJellyfin'),

  /// Apple Music: the account comes from the system, so there is no address
  /// or password to ask for and the setup form shows one button.
  appleMusic('libraryKindAppleMusic', ''),

  /// Files this device owns. There is nothing to sign in to, so this kind has
  /// no adapter: [LocalLibrarySource] is constructed directly.
  local('libraryKindLocal', '');

  const LibraryKind(this.labelKey, this.addressHintKey);

  /// Translation keys, resolved on read: the enum is `const`, so the name and
  /// placeholder cannot be translated at definition time.
  final String labelKey;
  final String addressHintKey;

  /// Shown in the setup picker and settings rows.
  String get label => labelKey.tr();

  /// A small mark for this kind, where the name would be too long: the
  /// now-playing line names a track, and a whole library name beside it costs
  /// space the title needs.
  ///
  /// Null for a kind with no mark of its own: a self-hosted server is named,
  /// because two servers called "music" are told apart by their name and not
  /// by a glyph.
  IconData? get mark => switch (this) {
    // The icon set has no Apple mark; the music note is the app's
    // own mark for an account-backed library.
    LibraryKind.appleMusic => Symbols.cloud_rounded,
    LibraryKind.local => Symbols.smartphone_rounded,
    LibraryKind.subsonic || LibraryKind.jellyfin => null,
  };

  /// Setup field placeholder.
  String get addressHint => addressHintKey.tr();
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
          ? {for (final entry in auth.entries) '${entry.key}': '${entry.value}'}
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

  /// The address shown next to a source in Settings. Empty when there is
  /// nothing to show: an Apple Music account has no server address.
  String get addressLabel => config.baseUrl;

  /// Everything that identifies this library, in one line, for a tooltip:
  /// the kind, and the host it lives at when it has one.
  ///
  /// Two Jellyfin installs are told apart by their address, so the name alone
  /// is not the identity; a hover is where that fits without costing the row
  /// its width.
  String get identityLabel {
    final address = addressLabel;
    if (address.isEmpty) return displayName;
    final host = Uri.tryParse(address)?.host ?? address;
    return host.isEmpty ? displayName : '${kind.label} · $host';
  }

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

  /// Lyrics for [song], synced when the server has a timed version.
  ///
  /// Never throws for "this song has none": an empty [Lyrics] is the answer.
  /// A network failure does throw, so a caller can tell "no lyrics" from
  /// "could not ask".
  Future<Lyrics> lyrics(LibrarySong song);
  Uri streamUri(LibrarySong song);
  Uri? artworkUri(String? artId, {int size});
}

/// A library whose items cannot be streamed: the platform's own player takes
/// the item instead.
///
/// Apple Music is the case this exists for. Reading it and playing it are
/// different questions — the API answers with plain HTTP, while the sound
/// comes from `ApplicationMusicPlayer` — so the split is below [LibrarySource]
/// and every caller asks the capability, never the kind.
abstract interface class PlatformPlayedSource implements LibrarySource {
  /// The resource the platform player starts this item from.
  ///
  /// The player needs the item in its own shape, which is not the neutral
  /// model: a library song and a radio station are resolved differently.
  Map<String, dynamic> platformResource(LibrarySong song);

  /// A usable artwork template for [song], when the platform player only
  /// reported a handle the app cannot load.
  ///
  /// A station's generated tracks report `musicKit://artwork/...`, which the
  /// system player reads from its own cache and nothing else can. This asks
  /// the source to turn what it knows about the item into a real image URL;
  /// null means the app has no way to draw it.
  Future<String?> artworkTemplate(LibrarySong song);

  /// The kind the platform player resolves [song] as (`'songs'`,
  /// `'stations'`). A queue is all of one kind, so this is asked of its first
  /// item.
  ///
  /// Part of the contract rather than defaulted: a source that hands the
  /// platform player items of a new kind must say so, and a silent default
  /// would make it play the wrong collection instead of failing.
  String platformItemType(LibrarySong song);
}

/// A library backed by a store the user can browse and add from.
///
/// Apple Music's account library is a subset of a much larger catalog: the
/// app could only show what was already added. This capability is the other
/// half — search what the store has, and put a result into the account's
/// library so it becomes playable like everything else.
///
/// Adding is a *write*: it changes the user's account, so it is never done
/// implicitly by a read or a play.
abstract interface class ExtendableSource implements LibrarySource {
  /// Search the store, not just the account. [limit] is per kind.
  Future<CatalogSearch> searchCatalog(String query, {int limit});

  /// Adds the catalog items [ids] to the account's library.
  ///
  /// Returns how many the store accepted. Throws [LibraryException] when the
  /// account cannot add (no subscription, or a token that lost its write
  /// scope).
  Future<int> addToLibrary(CatalogKind kind, List<String> ids);
}

/// What a store search found, in the app's own models.
///
/// Songs and albums come back as the same shapes the library reads return, so
/// a result row is the row the rest of the app already knows how to draw.
class CatalogSearch {
  final List<LibrarySong> songs;
  final List<LibraryAlbum> albums;
  final List<LibraryPlaylist> playlists;

  const CatalogSearch({
    this.songs = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  bool get isEmpty => songs.isEmpty && albums.isEmpty && playlists.isEmpty;

  CatalogSearch merge(CatalogSearch other) => CatalogSearch(
    songs: [...songs, ...other.songs],
    albums: [...albums, ...other.albums],
    playlists: [...playlists, ...other.playlists],
  );
}

/// The kinds a library can hold, as a store search names them.
enum CatalogKind { songs, albums, playlists }

/// A library that curates its landing page itself.
///
/// Only an account-backed service has anything to say here: a server's
/// landing shelves are the app's merged reads, while Apple Music has personal
/// mixes and station suggestions no other provider has a word for.
abstract interface class CuratedSource implements LibrarySource {
  /// The shelves this source wants on the landing page, in display order.
  Future<List<LandingShelf>> landingShelves();

  /// What the source wants to say about itself on the landing page: a line
  /// and a few numbers. Null when there is nothing to say.
  Future<LibraryDigest?> digest();
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

  /// Whether this platform can run the adapter at all.
  ///
  /// Apple Music is iOS/macOS only, so the setup picker hides it elsewhere
  /// rather than offering a connection that can only fail.
  bool get isAvailable => true;

  /// Whether this adapter's form takes an address, a username and a password.
  ///
  /// Apple Music signs in through the system, so the setup screen hides the
  /// three fields instead of showing inputs it would ignore.
  bool get needsCredentials => true;
}

/// One adapter per kind.
final Map<LibraryKind, LibraryAdapter> libraryAdapters = {
  LibraryKind.subsonic: SubsonicAdapter(),
  LibraryKind.jellyfin: JellyfinAdapter(),
  LibraryKind.appleMusic: AppleMusicAdapter(),
};

LibrarySource librarySourceFromConfig(SourceConfig config) =>
    libraryAdapters[config.kind]!.sourceFor(config);

/// `'<kind>-<base36 microseconds>'`; collision-free within a device.
String newSourceId(LibraryKind kind) =>
    '${kind.name}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
