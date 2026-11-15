/// Solar Network as the account's record of favourites: keep this device's
/// hearts and the account's in step, and import what another provider already
/// knows.
///
/// The direction is union, never deletion. A heart is an opinion; one device
/// clearing it is not proof the user changed their mind everywhere, and a
/// sync that deleted on the account's behalf would lose decisions nobody made
/// here. What this *does* guarantee is that a heart written anywhere — this
/// device, another device, or an imported provider — is everywhere.
library;

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app.dart';
import '../library/catalog.dart';
import '../library/models.dart';
import '../library/providers.dart';
import '../library/source.dart';
import '../library/track_identity.dart';
import '../player/player.dart';
import '../solarpass/models.dart';
import '../solarpass/providers.dart';
import 'client.dart';
import 'models.dart';
import 'providers.dart';

/// How many library searches one favourites build spends on entries no link
/// or known track can name. A search is one request per library, so a list
/// that is entirely from another device's libraries is not worth an unbounded
/// fan-out.
const solarFavouriteSearchBudget = 30;

/// What one run of [SolarFavouritesSync.sync] did.
class SolarFavouriteRun {
  const SolarFavouriteRun({
    required this.at,
    this.pushed = 0,
    this.pulled = 0,
    this.error,
  });

  final DateTime at;

  /// Hearts this device had and the account did not.
  final int pushed;

  /// Hearts the account had and this device did not.
  final int pulled;

  final String? error;

  bool get succeeded => error == null;

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'pushed': pushed,
    'pulled': pulled,
    'error': error,
  };

  factory SolarFavouriteRun.fromJson(Map<String, dynamic> json) =>
      SolarFavouriteRun(
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        pushed: (json['pushed'] as num?)?.toInt() ?? 0,
        pulled: (json['pulled'] as num?)?.toInt() ?? 0,
        error: json['error'] as String?,
      );
}

/// What one import from a provider did.
class SolarFavouriteImport {
  const SolarFavouriteImport({
    required this.sourceId,
    this.found = 0,
    this.pushed = 0,
    this.error,
  });

  final String sourceId;

  /// Favourites the provider reports.
  final int found;

  /// Of those, how many the account did not already hold.
  final int pushed;

  final String? error;

  bool get succeeded => error == null;

  Map<String, dynamic> toJson() => {
    'source_id': sourceId,
    'found': found,
    'pushed': pushed,
    'error': error,
  };
}

/// Turns a Solar catalog entry back into something this device can play.
///
/// The account names a recording by a source-scoped key, which only means
/// something if a library here mints the same ids. Everything else falls back
/// to the canonical track the device already knows, then to the libraries
/// themselves — in that order, because each step is more expensive than the
/// last.
class SolarFavouriteResolver {
  const SolarFavouriteResolver(this._ref);

  final Ref _ref;

  /// The payload every write to the account spells a track with.
  static PulsarTrackPayload payload(
    LibrarySong song,
    Map<String, LibrarySource> sources,
  ) => PulsarTrackPayload(
    title: song.title,
    artist: song.artist,
    album: song.album,
    artworkUrl: sources[song.sourceId]?.artworkUri(song.artId)?.toString(),
    durationSeconds: song.duration.inSeconds,
    providerKey: pulsarTrackKey(song),
  );

  /// The source-scoped item behind [key], from the catalog's own links.
  Future<LibrarySong?> songForKey(String key) async {
    final catalog = _ref.read(libraryCatalogProvider);
    if (catalog == null) return null;
    final sourceIds = _ref.read(librarySourceByIdProvider).keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final sourceId in sourceIds) {
      final prefix = '$sourceId:';
      if (!key.startsWith(prefix)) continue;
      final song = await catalog.songForLink(
        sourceId,
        key.substring(prefix.length),
      );
      if (song != null) return song;
    }
    return null;
  }

  /// The playable copy of one account entry, or null when no library holds it.
  ///
  /// [search] spends a library request; the caller budgets how many of those
  /// one build may spend.
  Future<LibrarySong?> resolve(CatalogItem item, {bool search = false}) async {
    final key = item.providerKey;
    if (key != null && key.isNotEmpty) {
      final byKey = await songForKey(key);
      if (byKey != null) return byKey;
    }
    final catalog = _ref.read(libraryCatalogProvider);
    if (catalog != null) {
      final byIdentity = await catalog.songForIdentity(
        TrackIdentity(
          title: item.title,
          artist: item.subtitle,
          duration: Duration(seconds: item.durationSeconds ?? 0),
        ),
        connectedSourceIds: _ref.read(librarySourceByIdProvider).keys.toSet(),
      );
      if (byIdentity != null) return byIdentity;
    }
    if (!search) return null;
    final query = [item.title, ?item.subtitle].join(' ');
    if (query.trim().isEmpty) return null;
    try {
      final matches = await _ref
          .read(libraryAggregatorProvider)
          .search(query, limit: 5);
      return matches.firstOrNull;
    } catch (error) {
      debugPrint('[Solar] Could not resolve "${item.title}": $error');
      return null;
    }
  }
}

/// Keeps the account's favourites and this device's in step.
///
/// Runs coalesce: a resume, the settings button and a track end arriving
/// together are one pass, not three.
class SolarFavouritesSync {
  SolarFavouritesSync(this._ref);

  final Ref _ref;
  Future<SolarFavouriteRun>? _running;

  /// Pushes every heart the account is missing, then pulls every heart this
  /// device is missing.
  Future<SolarFavouriteRun> sync() {
    final inFlight = _running;
    if (inFlight != null) return inFlight;
    final future = _sync();
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<SolarFavouriteRun> _sync() async {
    final startedAt = DateTime.now();
    final session = await _ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    final catalog = _ref.read(libraryCatalogProvider);
    if (session == null || catalog == null) {
      return SolarFavouriteRun(
        at: startedAt,
        error: session == null ? 'needs-sign-in' : 'no-database',
      );
    }
    final client = _ref.read(pulsarClientProvider);

    try {
      final account = await client.favourites(session);
      final pushed = await _push(session, account, catalog);
      final pulled = await _pull(account, catalog);
      if (pushed > 0 || pulled > 0) _invalidateFavourites();
      return SolarFavouriteRun(at: startedAt, pushed: pushed, pulled: pulled);
    } on PulsarException catch (error) {
      debugPrint('[Solar] Favourites sync failed: $error');
      return SolarFavouriteRun(at: startedAt, error: error.message);
    } catch (error) {
      debugPrint('[Solar] Favourites sync failed: $error');
      return SolarFavouriteRun(at: startedAt, error: error.toString());
    }
  }

  Future<int> _push(
    OAuthSession session,
    List<PlaylistItem> account,
    LibraryCatalog catalog,
  ) async {
    final sources = _ref.read(librarySourceByIdProvider);
    final client = _ref.read(pulsarClientProvider);
    final known = {
      for (final item in account)
        if (item.catalogItem?.providerKey != null)
          item.catalogItem!.providerKey!,
    };
    var pushed = 0;
    for (final favourite in await catalog.favourites()) {
      final song = favourite.song;
      if (song == null) continue;
      final key = pulsarTrackKey(song);
      if (known.contains(key)) continue;
      try {
        await client.addFavourite(
          session,
          SolarFavouriteResolver.payload(song, sources),
        );
        known.add(key);
        pushed++;
      } catch (error) {
        // One unreachable track must not stop the rest of the taste from
        // travelling; the next run offers it again.
        debugPrint('[Solar] Could not push "${song.title}": $error');
      }
    }
    return pushed;
  }

  Future<int> _pull(List<PlaylistItem> account, LibraryCatalog catalog) async {
    final resolver = _ref.read(solarFavouriteResolverProvider);
    var pulled = 0;
    var searches = 0;
    for (final item in account) {
      final track = item.catalogItem;
      if (track == null) continue;
      // A search is the only expensive step, so only a search spends the
      // budget: links and known tracks cost a local query.
      final maySearch = searches < solarFavouriteSearchBudget;
      final song = await resolver.resolve(track, search: maySearch);
      if (maySearch) searches++;
      if (song == null) continue;
      if (await catalog.favouriteOf(song) == true) continue;
      await catalog.setFavourite(song, value: true);
      pulled++;
    }
    return pulled;
  }

  /// Imports what [sourceId]'s own account already likes: the provider's
  /// favourites become this device's hearts and the account's, without
  /// asking the user to re-tap them one by one.
  Future<SolarFavouriteImport> importFrom(String sourceId) async {
    final session = await _ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (session == null) {
      return SolarFavouriteImport(sourceId: sourceId, error: 'needs-sign-in');
    }
    final source = _ref.read(librarySourceByIdProvider)[sourceId];
    if (source is! RatedSource) {
      return SolarFavouriteImport(sourceId: sourceId, error: 'not-rated');
    }
    final catalog = _ref.read(libraryCatalogProvider);
    if (catalog == null) {
      return SolarFavouriteImport(sourceId: sourceId, error: 'no-database');
    }
    final client = _ref.read(pulsarClientProvider);
    final sources = _ref.read(librarySourceByIdProvider);

    final List<LibrarySong> songs;
    try {
      songs = await source.favouriteSongs();
    } catch (error) {
      debugPrint('[Solar] Import from ${source.displayName} failed: $error');
      return SolarFavouriteImport(sourceId: sourceId, error: '$error');
    }
    await catalog.adoptAll(songs);

    final account = await client.favourites(session);
    final known = {
      for (final item in account)
        if (item.catalogItem?.providerKey != null)
          item.catalogItem!.providerKey!,
    };
    var pushed = 0;
    for (final song in songs) {
      await catalog.setFavourite(song, value: true);
      final key = pulsarTrackKey(song);
      if (known.contains(key)) continue;
      try {
        await client.addFavourite(
          session,
          SolarFavouriteResolver.payload(song, sources),
        );
        known.add(key);
        pushed++;
      } catch (error) {
        debugPrint('[Solar] Could not import "${song.title}": $error');
      }
    }
    _invalidateFavourites();
    return SolarFavouriteImport(
      sourceId: sourceId,
      found: songs.length,
      pushed: pushed,
    );
  }

  void _invalidateFavourites() {
    _ref.invalidate(pulsarFavouritesProvider);
    _ref.invalidate(solarFavouriteSongsProvider);
  }
}

/// Runs the favourites sync without the user asking: on launch once the
/// session is known, when the window resumes, and when a track ends — the
/// moments a device is most likely to be behind the account.
///
/// Wired from one place rather than per screen, so the listener survives tab
/// switches.
class SolarFavouritesAuto {
  SolarFavouritesAuto(this._ref);

  final Ref _ref;
  bool _disposed = false;
  AppLifecycleListener? _lifecycle;

  /// The minimum gap between two automatic runs; a manual run is never
  /// throttled. In one place so the throttle has one meaning.
  static const minInterval = Duration(minutes: 15);

  void init() {
    _lifecycle = AppLifecycleListener(onResume: () => run('resume'));
    _ref.listen<PlaybackState>(playbackProvider, (previous, next) {
      if (_disposed) return;
      if (previous?.playing == true && !next.playing) run('track-ended');
    });
    // Launch is the first moment worth syncing: the account may hold hearts
    // another device set while this one was closed.
    run('launch');
  }

  /// The window resumed, or a caller asked to catch up.
  Future<void> run(String reason) async {
    if (_disposed) return;
    await _runWhenSignedIn(reason);
  }

  Future<void> _runWhenSignedIn(String reason) async {
    final session = await _ref
        .read(solarpassSessionProvider.notifier)
        .validSession();
    if (_disposed || session == null) return;
    final last = readSolarFavouriteLastRun(
      _ref.read(sharedPreferencesProvider),
    );
    if (last != null &&
        DateTime.now().difference(last.at) < minInterval &&
        reason != 'manual') {
      return;
    }
    final result = await _ref.read(solarFavouritesSyncProvider).sync();
    if (_disposed) return;
    await _ref
        .read(sharedPreferencesProvider)
        .setString(solarFavouritesLastRunKey, jsonEncode(result.toJson()));
  }

  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

/// The session-level trigger, created with the shell.
final solarFavouritesAutoProvider = Provider<SolarFavouritesAuto>((ref) {
  final auto = SolarFavouritesAuto(ref);
  ref.onDispose(auto.dispose);
  auto.init();
  return auto;
});

/// The resolver, so the engine and the section share one.
final solarFavouriteResolverProvider = Provider<SolarFavouriteResolver>(
  SolarFavouriteResolver.new,
);

/// The engine behind the settings button and the automatic runs.
final solarFavouritesSyncProvider = Provider<SolarFavouritesSync>(
  SolarFavouritesSync.new,
);

/// Where the last run is remembered, for the Settings subtitle.
const solarFavouritesLastRunKey = 'solar_favourites_last_run';

/// The provider ids the user chose to import favourites from.
const solarFavouriteImportSourcesKey = 'solar_favourite_import_sources';

/// The last completed run, or null before the first one.
SolarFavouriteRun? readSolarFavouriteLastRun(SharedPreferences prefs) {
  final raw = prefs.getString(solarFavouritesLastRunKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return SolarFavouriteRun.fromJson(decoded.cast<String, dynamic>());
    }
  } on FormatException {
    // A corrupt record is treated as absent.
  }
  return null;
}

/// The providers the user asked to import favourites from.
Set<String> readSolarFavouriteImportSources(SharedPreferences prefs) =>
    (prefs.getStringList(solarFavouriteImportSourcesKey) ?? const []).toSet();

/// The Settings view of the favourites sync: the last run, and the button
/// that runs one now.
class SolarFavouritesStatus extends Notifier<SolarFavouriteRun?> {
  @override
  SolarFavouriteRun? build() =>
      readSolarFavouriteLastRun(ref.watch(sharedPreferencesProvider));

  /// Runs a sync the user asked for, bypassing the automatic throttle.
  Future<SolarFavouriteRun> runNow() async {
    final result = await ref.read(solarFavouritesSyncProvider).sync();
    await ref
        .read(sharedPreferencesProvider)
        .setString(solarFavouritesLastRunKey, jsonEncode(result.toJson()));
    state = result;
    return result;
  }

  /// Imports one provider's favourites, then records the choice.
  Future<SolarFavouriteImport> importFrom(String sourceId) async {
    final result = await ref
        .read(solarFavouritesSyncProvider)
        .importFrom(sourceId);
    if (result.succeeded) {
      final prefs = ref.read(sharedPreferencesProvider);
      final chosen = readSolarFavouriteImportSources(prefs).toList();
      if (!chosen.contains(sourceId)) {
        chosen.add(sourceId);
        await prefs.setStringList(solarFavouriteImportSourcesKey, chosen);
      }
    }
    return result;
  }
}

final solarFavouritesStatusProvider =
    NotifierProvider<SolarFavouritesStatus, SolarFavouriteRun?>(
      SolarFavouritesStatus.new,
    );
