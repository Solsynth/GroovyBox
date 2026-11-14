/// The library this device owns: audio files imported into GroovyBox's own
/// storage.
///
/// It is a [LibrarySource] like any server, so browsing, search, albums and the
/// play history see local files through the same paths they see a Subsonic or
/// Jellyfin response — no screen knows the difference. It is implicit rather
/// than a stored connection: there is nothing to sign in to, and the library
/// exists (empty) from the first launch.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../data/local/library_database.dart';
import 'lyrics.dart';
import 'models.dart';
import 'source.dart';

/// The directory the source joins: relative ids from the database resolve
/// against it.
class LocalLibrarySource extends LibrarySource {
  LocalLibrarySource({required this.database, required this.directory});

  final LibraryDatabase database;

  /// Where imported files live. Absolute, so a `file:` URI can be built
  /// without an await; the ids stored in the database are relative to it, so
  /// the app's container moving does not invalidate them.
  final String directory;

  static const _config = SourceConfig(
    id: kLocalSourceId,
    kind: LibraryKind.local,
    baseUrl: '',
    displayName: 'Local',
  );

  @override
  SourceConfig get config => _config;

  @override
  String get displayName => LibraryKind.local.label;

  /// The absolute path of an imported file.
  File fileOf(LibrarySong song) => File(p.join(directory, song.id));

  LibrarySong _songOf(LocalFileRow row) => LibrarySong(
    sourceId: id,
    id: row.path,
    title: row.title,
    artist: row.artist,
    // The local source groups artists by their lowercase name, and the
    // artist page addresses that group with it — the name *is* the id here.
    artistId: row.artist?.trim().toLowerCase(),
    album: row.album,
    albumId: row.albumKey,
    artId: row.artPath,
    duration: Duration(milliseconds: row.durationMs),
    track: row.trackNumber,
    discNumber: row.discNumber,
    year: row.year,
    genre: row.genre,
  );

  Future<List<LocalFileRow>> _rows() => database.localFileRows();

  @override
  Future<LibraryAlbum?> album(String albumId) async {
    final members = [
      for (final row in await _rows())
        if (row.albumKey == albumId) row,
    ];
    if (members.isEmpty) return null;
    return _albumOf(members);
  }

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async => [
    for (final row in await _rows())
      if (row.albumKey == albumId) _songOf(row),
  ];

  @override
  Future<List<LibraryAlbum>> albums({int limit = 60, int offset = 0}) async {
    final albums = _albumsOf(await _rows())
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return albums.skip(offset).take(limit).toList();
  }

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) async {
    final rows = [...await _rows()]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final seen = <String>{};
    final albums = <LibraryAlbum>[];
    for (final row in rows) {
      final key = row.albumKey;
      if (key == null || !seen.add(key)) continue;
      final album = await this.album(key);
      if (album != null) albums.add(album);
      if (albums.length >= limit) break;
    }
    return albums;
  }

  @override
  Future<List<LibraryArtist>> artists() async {
    final rows = await _rows();
    final grouped = <String, List<LocalFileRow>>{};
    for (final row in rows) {
      final name = row.artist?.trim();
      if (name == null || name.isEmpty) continue;
      grouped.putIfAbsent(name.toLowerCase(), () => []).add(row);
    }
    return [
      for (final entry in grouped.entries)
        LibraryArtist(
          sourceId: id,
          id: entry.key,
          name: entry.value.first.artist ?? '',
          artId: entry.value
              .map((row) => row.artPath)
              .whereType<String>()
              .firstOrNull,
          albumCount: {
            for (final row in entry.value)
              if (row.albumKey != null) row.albumKey!,
          }.length,
        ),
    ];
  }

  @override
  Future<List<LibraryAlbum>> artistAlbums(String artistId) async {
    final rows = [
      for (final row in await _rows())
        if (row.artist?.trim().toLowerCase() == artistId) row,
    ];
    return _albumsOf(rows);
  }

  /// Playlists are the server's, not the app's; a local library has none.
  @override
  Future<List<LibraryPlaylist>> playlists() async => const [];

  @override
  Future<List<LibrarySong>> playlistSongs(String playlistId) async => const [];

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return [
      for (final row in await _rows())
        if (row.title.toLowerCase().contains(needle) ||
            (row.artist?.toLowerCase().contains(needle) ?? false) ||
            (row.album?.toLowerCase().contains(needle) ?? false))
          _songOf(row),
    ].take(limit).toList();
  }

  @override
  Future<List<LibrarySong>> randomSongs({int size = 40}) async {
    final rows = [...await _rows()]..shuffle();
    return [for (final row in rows.take(size)) _songOf(row)];
  }

  /// Words in an imported file come from its tags, which the importer writes
  /// onto the canonical track; there is nobody to ask over the network.
  @override
  Future<Lyrics> lyrics(LibrarySong song) async => Lyrics.empty;

  @override
  Uri streamUri(LibrarySong song) => fileOf(song).uri;

  @override
  Uri? artworkUri(String? artId, {int size = 600}) {
    if (artId == null || artId.isEmpty) return null;
    return File(p.join(directory, artId)).uri;
  }

  /// Groups rows by the album key their tags produced.
  List<LibraryAlbum> _albumsOf(List<LocalFileRow> rows) {
    final grouped = <String, List<LocalFileRow>>{};
    for (final row in rows) {
      final key = row.albumKey;
      if (key == null) continue;
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return [for (final members in grouped.values) _albumOf(members)];
  }

  LibraryAlbum _albumOf(List<LocalFileRow> members) {
    final first = members.first;
    final years = members.map((member) => member.year).whereType<int>();
    return LibraryAlbum(
      sourceId: id,
      id: first.albumKey ?? first.path,
      name: first.album ?? first.title,
      artist: first.albumArtist ?? first.artist,
      artId: members
          .map((member) => member.artPath)
          .whereType<String>()
          .firstOrNull,
      songCount: members.length,
      duration: members.fold(
        Duration.zero,
        (sum, member) => sum + Duration(milliseconds: member.durationMs),
      ),
      year: years.isEmpty ? null : years.reduce((a, b) => a < b ? a : b),
      genre: members
          .map((member) => member.genre)
          .whereType<String>()
          .firstOrNull,
    );
  }
}

/// A URL-safe key for the album a set of tags names.
///
/// The album detail route takes the id as a path segment, so the raw title
/// cannot be used. Album artist is part of the key because two records can
/// share a title.
String localAlbumKey({required String album, String? albumArtist}) =>
    _slug('${albumArtist ?? ''}\u0000$album');

String _slug(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  // `hashCode` is only stable within one process; the key is persisted, and a
  // key that changed on restart would split every album in two.
  final digest = md5.convert(utf8.encode(value)).toString().substring(0, 8);
  return normalized.isEmpty ? digest : '$normalized-$digest';
}
