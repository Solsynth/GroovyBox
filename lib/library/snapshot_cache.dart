/// The last answer of a list read, so a page draws it before the network is
/// asked.
///
/// The HTTP cache in `http_cache.dart` already keeps one *request's* body, but
/// it sits inside an adapter and only answers a request the app already made.
/// A page loading for the first time still awaits every library before it has
/// anything to draw. This layer sits above the fan-out instead: it stores the
/// merged answer a screen last showed, under the name of the read, and hands
/// it back synchronously enough to paint the first frame.
///
/// The states a read walks, in order:
///
///   1. a snapshot exists and answers immediately — the page is drawn from it;
///   2. every library is asked anyway, and a successful answer replaces every
///      snapshot of this read;
///   3. the refresh failed, and the snapshot stays: the page keeps showing
///      what it last showed instead of falling back to spinners.
///
/// Only answers that describe *content the user can browse* are stored. A
/// random draw is stored too, because the point of a shelf is to have something
/// to press on the first frame; it is simply replaced by the next draw.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/local/library_database.dart';
import 'models.dart';

/// Reads and writes the snapshot table, and converts models to and from JSON.
///
/// The conversions live here rather than on the models because a snapshot is
/// not a wire format: it is this app's own record of what a page showed, and a
/// copy of it belongs beside the code that decides which pages are stored at
/// all.
class SnapshotCache {
  SnapshotCache(this._db) {
    // Snapshots are allowed to outlive the data they describe — a library that
    // has not been opened for a fortnight is still worth drawing — but not
    // forever. Pruning on construction keeps the sweep out of the read path.
    unawaited(
      _db.pruneLibrarySnapshots(DateTime.now().subtract(_keepFor)).catchError((
        Object error,
      ) {
        debugPrint('[Snapshots] Could not prune: $error');
        return 0;
      }),
    );
  }

  final LibraryDatabase _db;

  /// How long a snapshot may sit unrefreshed before it is dropped. Long enough
  /// to survive a holiday; short enough that a changed account is not drawn
  /// from a month-old list.
  static const _keepFor = Duration(days: 30);

  /// The snapshot of one read, or null when there is none.
  ///
  /// A body that no longer parses — written by an older build whose model
  /// changed — is treated as absent rather than as an error: the read falls
  /// through to the network, which is what it would have done anyway.
  Future<String?> read(String key) async {
    final row = await _db.librarySnapshot(key);
    return row?.body;
  }

  /// Decodes a stored answer with [parse], returning null when it is absent or
  /// unreadable.
  ///
  /// The two failures are one thing to a caller: a snapshot that cannot be
  /// restored is simply not a snapshot.
  Future<T?> restore<T>(String key, T Function(Object? json) parse) async {
    final body = await read(key);
    if (body == null) return null;
    try {
      return parse(jsonDecode(body));
    } catch (error) {
      debugPrint('[Snapshots] Unreadable $key: $error');
      return null;
    }
  }

  /// Writes [value], encoded by [encode], as the answer of [key].
  ///
  /// Fire-and-forget at every call site but still awaited here: a write is one
  /// row, and a page must never wait on it. Failures are logged, not thrown —
  /// a device that cannot write its cache still plays music.
  Future<void> store(
    String key,
    Object? value,
    Object? Function(Object? value) encode,
  ) async {
    String body;
    try {
      body = jsonEncode(encode(value));
    } catch (error) {
      debugPrint('[Snapshots] Not stored ($key): $error');
      return;
    }
    try {
      await _db.putLibrarySnapshot(
        LibrarySnapshotRow(key: key, body: body, storedAt: DateTime.now()),
      );
    } catch (error) {
      debugPrint('[Snapshots] Could not write $key: $error');
    }
  }

  /// Stores a list of models, using the model's own JSON form.
  Future<void> storeSongs(String key, List<LibrarySong> songs) => store(
    key,
    songs,
    (value) => [for (final song in value! as List<LibrarySong>) song.toJson()],
  );

  /// Restores a list of models from a snapshot, or null when there is none.
  ///
  /// A body that is not a list is not an empty answer: it is a row written by
  /// another shape of this read, and serving it as "nothing here" would blank
  /// a page that has a working network behind it. Null sends the caller to the
  /// network instead, exactly as a missing row would.
  Future<List<T>?> restoreList<T>(
    String key,
    T Function(Map<String, dynamic> json) parse,
  ) => restore(key, (json) {
    if (json is! List) throw const FormatException('not a list');
    return <T>[
      for (final entry in json)
        if (entry is Map) parse(Map<String, dynamic>.from(entry)),
    ];
  });

  /// Forgets every snapshot, for Settings.
  Future<void> clear() => _db.clearLibrarySnapshots();

  /// How many snapshots are held, and how many bytes they take.
  Future<({int count, int bytes})> totals() => _db.librarySnapshotTotals();
}

/// The read names snapshots are stored under.
///
/// Kept together so two pages cannot invent two spellings of one key, and so a
/// key's shape says which provider wrote it. A playlist's key carries its
/// source as well as its id: an id is only unique inside one library.
abstract final class SnapshotKeys {
  static const recentAlbums = 'recentAlbums';
  static const randomSongs = 'randomSongs';
  static const playlists = 'playlists';
  static const artists = 'artists';
  static const landingShelves = 'landingShelves';
  static const friendListening = 'friendListening';
  static const cloudPlaylists = 'cloudPlaylists';

  static String albumSongs(LibraryRef album) =>
      'albumSongs:${album.sourceId}:${album.id}';

  static String playlistSongs(LibraryRef playlist) =>
      'playlistSongs:${playlist.sourceId}:${playlist.id}';

  static String cloudPlaylistDetail(String playlistId) =>
      'cloudPlaylistDetail:$playlistId';

  static String cloudPlaylistSongs(String playlistId) =>
      'cloudPlaylistSongs:$playlistId';
}

/// Models a snapshot has to carry, converted here because none of them is a
/// wire payload in its own right.
extension SnapshotAlbumJson on LibraryAlbum {
  Map<String, dynamic> toSnapshotJson() => {
    'sourceId': sourceId,
    'id': id,
    'name': name,
    if (artist != null) 'artist': artist,
    if (artistId != null) 'artistId': artistId,
    if (artId != null) 'artId': artId,
    if (songCount != null) 'songCount': songCount,
    'durationMs': duration.inMilliseconds,
    if (year != null) 'year': year,
    if (genre != null) 'genre': genre,
  };

  static LibraryAlbum fromSnapshotJson(Map<String, dynamic> json) =>
      LibraryAlbum(
        sourceId: json['sourceId'] as String,
        id: json['id'] as String,
        name: json['name'] as String,
        duration: Duration(
          milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
        ),
        artist: json['artist'] as String?,
        artistId: json['artistId'] as String?,
        artId: json['artId'] as String?,
        songCount: (json['songCount'] as num?)?.toInt(),
        year: (json['year'] as num?)?.toInt(),
        genre: json['genre'] as String?,
      );
}

extension SnapshotArtistJson on LibraryArtist {
  Map<String, dynamic> toSnapshotJson() => {
    'sourceId': sourceId,
    'id': id,
    'name': name,
    if (artId != null) 'artId': artId,
    // The cover's own library travels with the snapshot: a borrowed handle
    // restored without it would be resolved against the wrong server and
    // draw a placeholder until the next refresh.
    if (artSourceId != null) 'artSourceId': artSourceId,
    if (albumCount != null) 'albumCount': albumCount,
  };

  static LibraryArtist fromSnapshotJson(Map<String, dynamic> json) =>
      LibraryArtist(
        sourceId: json['sourceId'] as String,
        id: json['id'] as String,
        name: json['name'] as String,
        artId: json['artId'] as String?,
        artSourceId: json['artSourceId'] as String?,
        albumCount: (json['albumCount'] as num?)?.toInt(),
      );
}

extension SnapshotPlaylistJson on LibraryPlaylist {
  Map<String, dynamic> toSnapshotJson() => {
    'sourceId': sourceId,
    'id': id,
    'name': name,
    if (owner != null) 'owner': owner,
    if (songCount != null) 'songCount': songCount,
    'durationMs': duration.inMilliseconds,
    if (artId != null) 'artId': artId,
  };

  static LibraryPlaylist fromSnapshotJson(Map<String, dynamic> json) =>
      LibraryPlaylist(
        sourceId: json['sourceId'] as String,
        id: json['id'] as String,
        name: json['name'] as String,
        duration: Duration(
          milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
        ),
        owner: json['owner'] as String?,
        songCount: (json['songCount'] as num?)?.toInt(),
        artId: json['artId'] as String?,
      );
}

extension SnapshotShelfJson on LandingShelf {
  Map<String, dynamic> toSnapshotJson() => {
    'title': title,
    'sourceId': sourceId,
    'songs': [for (final song in songs) song.toJson()],
  };

  static LandingShelf fromSnapshotJson(Map<String, dynamic> json) =>
      LandingShelf(
        title: json['title'] as String,
        sourceId: json['sourceId'] as String,
        songs: [
          for (final entry in (json['songs'] as List?) ?? const [])
            if (entry is Map)
              LibrarySong.fromJson(Map<String, dynamic>.from(entry)),
        ],
      );
}
