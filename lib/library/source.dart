import 'package:easy_localization/easy_localization.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'apple_adapter.dart';
import 'http_cache.dart';
import 'jellyfin_adapter.dart';
import 'lyrics.dart';
import 'models.dart';
import 'subsonic_adapter.dart';
import 'netease_adapter.dart';
import 'plugins/plugin_host.dart';
import 'plugins/plugin_source.dart';
import 'plugins/plugin_schema.dart';

/// The kinds of library GroovyBox can talk to.
enum LibraryKind {
  netease('libraryKindNetease', 'libraryAddressNetease'),
  subsonic('libraryKindSubsonic', 'libraryAddressSubsonic'),
  jellyfin('libraryKindJellyfin', 'libraryAddressJellyfin'),

  /// Apple Music: the account comes from the system, so there is no address
  /// or password to ask for and the setup form shows one button.
  appleMusic('libraryKindAppleMusic', ''),

  /// Files this device owns. There is nothing to sign in to, so this kind has
  /// no adapter: [LocalLibrarySource] is constructed directly.
  local('libraryKindLocal', ''),

  /// A source implemented by an installed JS plugin. [SourceConfig.baseUrl] is
  /// the plugin's manifest id and [SourceConfig.auth]'s `providerId` names
  /// which provider of that plugin this connection is — which is why this kind
  /// has no entry in [libraryAdapters]: the plugin is a per-config fact, not a
  /// per-kind one.
  plugin('libraryKindPlugin', 'libraryAddressPlugin');

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
    LibraryKind.plugin => Symbols.extension_rounded,
    LibraryKind.netease || LibraryKind.subsonic || LibraryKind.jellyfin => null,
  };

  /// The glyph beside this kind's name in the setup menu.
  ///
  /// Unlike [mark] this is always set: inside a menu every row has room for a
  /// small symbol, and a row with an icon next to one without reads as a
  /// rendering bug rather than as a distinction.
  IconData get pickerIcon => switch (this) {
    LibraryKind.netease => Symbols.music_note_rounded,
    LibraryKind.subsonic => Symbols.dns_rounded,
    LibraryKind.jellyfin => Symbols.movie_rounded,
    LibraryKind.appleMusic => Symbols.cloud_rounded,
    LibraryKind.local => Symbols.smartphone_rounded,
    LibraryKind.plugin => Symbols.extension_rounded,
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

  /// Everything [query] matches among what this library **holds**: the
  /// account's own playlists, favourites and albums, plus the device's files.
  ///
  /// Never the store's wider catalogue: a provider whose search endpoint
  /// answers the whole cloud (NetEase's `/cloudsearch`) would otherwise offer
  /// rows the user cannot play and never added, and an "in your library"
  /// section full of them is a lie. The wide question is
  /// [CatalogueSource.searchCatalogue], and only the callers that mean it —
  /// playback's fallback, a cloud playlist naming a track — ask it.
  Future<List<LibrarySong>> search(String query, {int limit});
  Future<List<LibrarySong>> randomSongs({int size});

  /// Lyrics for [song], synced when the server has a timed version.
  ///
  /// Never throws for "this song has none": an empty [Lyrics] is the answer.
  /// A network failure does throw, so a caller can tell "no lyrics" from
  /// "could not ask".
  Future<Lyrics> lyrics(LibrarySong song);
  Uri streamUri(LibrarySong song);

  /// Extra headers the stream server requires (a `Referer`, a `Range` gate).
  ///
  /// Empty when the URL plays bare, which is every built-in source. A provider
  /// whose CDN refuses requests without one answers from what it already
  /// learned when the URL was resolved: this is asked *after* that, when the
  /// stream is opened, and it cannot perform a request of its own.
  Map<String, String> streamHeaders(LibrarySong song) => const {};
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

/// A library whose tracks can be marked as favourites.
///
/// Every service the app speaks to has this: Subsonic stars a song, Jellyfin
/// sets `IsFavorite`, Apple Music writes a rating. It used to live inside
/// [ExtendableSource], which is a *store* capability — so a Subsonic server,
/// which has no store, silently lost the heart on the player page even though
/// it could have answered. The two are separate questions: what the account
/// can remember, and what the catalogue can sell.
abstract interface class RatedSource implements LibrarySource {
  /// Whether the account has favourited [song].
  ///
  /// A favourite is the account's own opinion, not the library's: it is the
  /// value the service's own app shows, so it stays in step when the count
  /// changes elsewhere. A source that cannot answer says false rather than
  /// throwing — the tap is what reports a failure.
  Future<bool> isFavourite(LibrarySong song);

  /// Sets or clears [song]'s favourite. A write, so it is never done by a
  /// read or a play. Throws [LibraryException] when the service refuses it.
  Future<void> setFavourite(LibrarySong song, {required bool value});

  /// Every track the account has favourited, as this source describes them.
  ///
  /// This is the import half of the capability: Solar Network is where the
  /// app keeps its own hearts, so a provider whose account already has them
  /// (Apple Music's ratings, a Navidrome server's stars) must be able to hand
  /// them over in one read rather than one `isFavourite` call per track.
  /// Throws [LibraryException] when the service refuses the read.
  Future<List<LibrarySong>> favouriteSongs();
}

/// A library whose search can reach past what the account holds.
///
/// A server's library and its search are the same set: a Subsonic `search3`
/// only answers the files the server carries, which is exactly what the user
/// connected it for. A cloud account is the other shape — NetEase's
/// `/cloudsearch` answers the whole service, so its hits include tracks the
/// user never added and may not be able to play at all. Asking the two the
/// same question is what made "In your libraries" list strangers.
///
/// This capability is the wide question, asked only where "find this exact
/// recording somewhere I can play it from" is the point: playback's fallback
/// through `findCopies`, and resolving a track a cloud playlist names. The
/// library search a page shows does not read it.
abstract interface class CatalogueSource implements LibrarySource {
  /// Everything [query] matches in the service's catalogue, held or not.
  Future<List<LibrarySong>> searchCatalogue(String query, {int limit});
}

/// A stream URL that has to be fetched before it exists.
///
/// Subsonic and Jellyfin answer [LibrarySource.streamUri] from the item they
/// already described; a provider that mints per-request playback URLs has to
/// be *asked* first. The transport awaits this when the source has it and
/// falls back to the plain URL when it does not, so adding a minting provider
/// touches nothing but the source itself.
abstract interface class ResolvedStreamSource implements LibrarySource {
  /// The playback URL for [song], resolved now.
  ///
  /// Minted URLs expire, so implementations cache against their own TTL.
  /// Throws [LibraryException] when the provider refuses the track (no
  /// entitlement, or the region has no licence).
  Future<Uri> resolveStreamUri(LibrarySong song);

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
///
/// A store always answers the wide question too: what it sells is the set
/// [CatalogueSource.searchCatalogue] reads, and [searchCatalog] is the same
/// search shaped for the page that offers adds.
abstract interface class ExtendableSource
    implements RatedSource, CatalogueSource {
  /// Search the store, not just the account. [limit] is per kind.
  Future<CatalogSearch> searchCatalog(String query, {int limit});

  /// Adds the catalog items [ids] to the account's library.
  ///
  /// Returns how many the store accepted. Throws [LibraryException] when the
  /// account cannot add (no subscription, or a token that lost its write
  /// scope).
  Future<int> addToLibrary(CatalogKind kind, List<String> ids);

  /// Puts [song] into one of the account's own [playlist]s.
  ///
  /// Only a playlist the account owns can be edited, so the picker offers the
  /// ones [editablePlaylists] returns. Throws [LibraryException] when the
  /// store refuses the write.
  Future<void> addToPlaylist(LibraryPlaylist playlist, LibrarySong song);

  /// The account's playlists it can still add to, in the order the account
  /// lists them. The favourites mix is excluded by the service itself, so
  /// this filter is the only thing that keeps the picker honest.
  Future<List<LibraryPlaylist>> editablePlaylists();
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

  /// What the source wants to say about itself where its connection is
  /// managed: who is signed in, and how many tracks the account holds. Null
  /// when there is nothing to say.
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
  ///
  /// [cache] is the device's response cache. A source that takes it answers
  /// its reads from disk when the network is gone; one that does not (a test
  /// double, an adapter with nothing to cache) ignores it.
  LibrarySource sourceFor(SourceConfig config, {ResponseCache? cache});

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

/// A login that cannot be typed into a form: it runs as a sequence the user
/// follows (scan a QR code, confirm on the phone, wait for the poll to say
/// yes) rather than a single credential check.
///
/// The setup screen renders the steps this capability yields and never asks
/// the adapter's kind, so the next interactive provider plugs in without a
/// special case. [connect] stays the contract for an adapter whose login is
/// one synchronous call with an address and a secret.
abstract interface class InteractiveLoginAdapter implements LibraryAdapter {
  /// The login steps, in display order.
  ///
  /// Each step is one of the shapes [LoginStep] names. The screen walks the
  /// list once and redraws as the stream updates the last step's state.
  List<LoginStep> loginSteps(String baseUrl);

  /// Completes the login and returns the config to store, or throws
  /// [LibraryException] when the user aborted or the service refused.
  Future<SourceConfig> completeLogin(String baseUrl, List<LoginStep> steps);
}

/// One interactive login step.
///
/// A step is declarative on purpose: the screen draws a spinner, a QR image
/// or a text prompt from the shape alone, and the adapter stays free to
/// reorder or extend steps without the screen learning about them.
sealed class LoginStep {
  const LoginStep();

  /// Stable identity within one adapter's step list.
  String get id;

  /// What the step asks of the user, already localized by the adapter (the
  /// adapter knows the service's own vocabulary; the screen only draws).
  String get prompt;
}

/// A step that shows a QR code and watches it being scanned.
///
/// The adapter owns the state the code is minted against (a unikey, a
/// session), so [prepare] produces the code and [poll] watches it. The screen
/// only draws what it is handed: it never learns a service's vocabulary.
class QrLoginStep extends LoginStep {
  @override
  final String id;
  @override
  final String prompt;

  /// Mints the code and returns it: a `data:` URL for an image the adapter
  /// has already rendered. Throws [LibraryException] when the service
  /// refuses.
  final Future<String> Function() prepare;

  /// Polls the service for the scan state. Yields `800` (expired), `801`
  /// (waiting), `802` (scanned, awaiting confirm) and `803` (authorized).
  /// Done when it yields 803, or throws when it yields 800.
  final Stream<int> Function() poll;

  const QrLoginStep({
    required this.id,
    required this.prompt,
    required this.prepare,
    required this.poll,
  });
}

/// A step that only reports progress while the adapter works.
class BusyLoginStep extends LoginStep {
  @override
  final String id;
  @override
  final String prompt;
  const BusyLoginStep({required this.id, required this.prompt});
}

/// One adapter per kind.
final Map<LibraryKind, LibraryAdapter> libraryAdapters = {
  LibraryKind.subsonic: SubsonicAdapter(),
  LibraryKind.jellyfin: JellyfinAdapter(),
  LibraryKind.netease: NeteaseAdapter(),
  LibraryKind.appleMusic: AppleMusicAdapter(),
};

/// One row of the setup picker: a built-in kind, or a provider an installed
/// plugin contributes.
///
/// One sealed type rather than two dropdowns, because the choice is a single
/// question — "which library am I adding" — and a plugin's provider answers it
/// exactly as a Subsonic server does.
sealed class SetupOption {
  const SetupOption();

  String get label;

  IconData get icon;
}

class BuiltInOption extends SetupOption {
  const BuiltInOption(this.kind);

  final LibraryKind kind;

  @override
  String get label => kind.label;

  @override
  IconData get icon => kind.pickerIcon;

  /// The dropdown compares its value by equality, and the selected option is
  /// rebuilt on every frame; identity would make it look unselected.
  @override
  bool operator ==(Object other) =>
      other is BuiltInOption && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

class PluginOption extends SetupOption {
  const PluginOption(this.provider);

  final PluginProvider provider;

  @override
  String get label => provider.name;

  @override
  IconData get icon => Symbols.extension_rounded;

  /// The dropdown holds one of these as its selected value and compares by
  /// equality, so two options for one provider must be the same option.
  @override
  bool operator ==(Object other) =>
      other is PluginOption && other.provider == provider;

  @override
  int get hashCode => provider.hashCode;
}

/// Everything the setup picker can offer, built-ins first.
///
/// [libraryAdapters] is enumerated rather than [LibraryKind.values]: the local
/// library has no adapter (there is nothing to connect to) and `plugin` has
/// none either (the plugin is a per-config fact).
List<SetupOption> setupOptions(List<PluginProvider> plugins) => [
  for (final entry in libraryAdapters.entries)
    if (entry.value.isAvailable) BuiltInOption(entry.key),
  for (final provider in plugins) PluginOption(provider),
];

/// A stored config's source.
///
/// A plugin-backed config branches before the adapter map is indexed: which
/// plugin it belongs to is a per-config fact (`auth['providerId']`), so
/// [libraryAdapters] has no `plugin` entry and means it. The branch is what
/// folds an installed plugin into `librarySourcesWithLocal`, and therefore
/// into search, `findCopies` and playback, with no further change.

LibrarySource librarySourceFromConfig(
  SourceConfig config, {
  ResponseCache? cache,
}) {
  if (config.kind == LibraryKind.plugin) {
    final host = PluginHost.instance;
    // No runtime (an unsupported platform) or a plugin that was uninstalled is
    // a source that reports itself missing, never a crash at resolve time.
    return PluginSource(
      config,
      host: host,
      missing: host == null || !host.knows(config.baseUrl),
    );
  }
  return libraryAdapters[config.kind]!.sourceFor(config, cache: cache);
}

/// `'<kind>-<base36 microseconds>'`; collision-free within a device.
String newSourceId(LibraryKind kind) =>
    '${kind.name}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
