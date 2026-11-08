import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/local_import.dart';
import 'package:groovy_box/library/local_library.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A WAV file whose tag support is irrelevant: what is under test is the copy,
/// the adoption and the way the source answers, not the tag parser.
Directory _tempMusic() {
  final dir = Directory.systemTemp.createTempSync('groovybox_import_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

File _wav(Directory dir, String name) {
  // 0.2 s of silence at 8 kHz, mono, 16-bit.
  const sampleRate = 8000;
  const seconds = 1;
  const samples = sampleRate * seconds;
  final data = ByteData(44 + samples * 2);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);

  final file = File(p.join(dir.path, name));
  file.writeAsBytesSync(data.buffer.asUint8List());
  return file;
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;

  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an imported file is copied in, adopted, and playable from the copy',
      () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = LyricsStore(db);

    final picked = _tempMusic();
    final support = _tempMusic();
    PathProviderPlatform.instance = _FakePathProvider(support);

    final source = _wav(picked, 'Sunset Overdrive.wav');
    final directory = await localMusicDirectory();

    var refreshed = 0;
    final service = LocalImportService(
      database: db,
      directory: directory,
      lyrics: store,
      onImported: () => refreshed++,
    );

    final result = await service.importFiles([source]);

    expect(result.imported, 1);
    expect(result.failures, isEmpty);
    expect(refreshed, 1, reason: 'cached reads rebuild after an import');

    // The copy lives in the library, not next to the file the user picked.
    final copy = File(p.join(directory, 'Sunset Overdrive.wav'));
    expect(copy.existsSync(), isTrue);
    expect(copy.path, isNot(source.path));

    // The original is untouched, so deleting it cannot break playback.
    source.deleteSync();
    expect(copy.existsSync(), isTrue);

    final local = LocalLibrarySource(database: db, directory: directory);
    final songs = await local.randomSongs();
    expect(songs, hasLength(1));
    expect(songs.single.title, 'Sunset Overdrive');
    expect(songs.single.sourceId, kLocalSourceId);
    expect(local.fileOf(songs.single).existsSync(), isTrue);
    expect(local.streamUri(songs.single).isScheme('file'), isTrue);

    // The song joins the canonical library, so its play history is kept like
    // a streamed song's.
    expect(await db.trackCount(), 1);

    // Importing the same file again is recognised instead of duplicating it.
    final again = await service.importFiles([copy]);
    expect(again.imported, 0);
    expect(again.skipped, 1);
    expect(await db.trackCount(), 1);
    expect(await local.randomSongs(), hasLength(1));
  });

  test('a second file with the same name is kept alongside the first',
      () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final picked = _tempMusic();
    final support = _tempMusic();
    PathProviderPlatform.instance = _FakePathProvider(support);

    final service = LocalImportService(
      database: db,
      directory: await localMusicDirectory(),
      lyrics: null,
      onImported: () {},
    );

    final first = _wav(picked, 'track.wav');
    await service.importFiles([first]);
    // Different bytes, same name.
    first.writeAsBytesSync([...first.readAsBytesSync(), 0], flush: true);
    final second = await service.importFiles([first]);

    expect(second.imported, 1);
    final rows = await db.localFileRows();
    expect(rows, hasLength(2), reason: 'neither song is overwritten');
    expect(rows.map((row) => row.path).toSet(), hasLength(2));
  });

  test('tags from the file name the album, artist and cover', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final support = _tempMusic();
    PathProviderPlatform.instance = _FakePathProvider(support);
    final directory = await localMusicDirectory();
    final service = LocalImportService(
      database: db,
      directory: directory,
      lyrics: null,
      onImported: () {},
    );

    final result = await service.importFiles([
      File('test/fixtures/tagged.mp3'),
    ]);
    expect(result.imported, 1);
    expect(result.failures, isEmpty);

    final local = LocalLibrarySource(database: db, directory: directory);
    final song = (await local.randomSongs()).single;
    expect(song.title, 'Sunset Overdrive');
    expect(song.artist, 'The Paper Kites');
    expect(song.album, 'States');
    expect(song.track, 3);
    expect(song.year, 2013);
    expect(song.genre, 'Indie');
    expect(song.duration.inSeconds, 2, reason: 'the tag length is kept');

    // The embedded cover is extracted once and served from disk.
    final art = local.artworkUri(song.artId);
    expect(art, isNotNull);
    expect(art!.isScheme('file'), isTrue);
    expect(File(art.toFilePath()).existsSync(), isTrue);

    // The album is found by its tag, and the detail page can list it back.
    final album = (await local.albums()).single;
    expect(album.name, 'States');
    expect(album.songCount, 1);
    expect(album.artId, song.artId);
    expect(await local.albumSongs(album.id), hasLength(1));
    expect(await local.album(album.id), isNotNull);
    expect(await local.recentlyAdded(), hasLength(1));

    // Search reads the tags too, not the file name.
    expect(await local.search('paper kites'), hasLength(1));
    expect(await local.search('states'), hasLength(1));
    expect(await local.search('nothing here'), isEmpty);
  });

  test('lyrics carried by the tags are stored, timed and all', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final support = _tempMusic();
    PathProviderPlatform.instance = _FakePathProvider(support);
    final store = LyricsStore(db);
    final service = LocalImportService(
      database: db,
      directory: await localMusicDirectory(),
      lyrics: store,
      onImported: () {},
    );

    final result = await service.importFiles([
      File('test/fixtures/with_lyrics.flac'),
    ]);
    expect(result.imported, 1);

    final trackId = await db.trackIdForLink('local', 'with_lyrics.flac');
    expect(trackId, isNotNull);
    final cached = await store.read(trackId!);
    expect(cached, isNotNull);
    expect(cached!.origin, LyricsOrigin.file);
    expect(cached.lyrics.synced, isTrue);
    expect(cached.lyrics.lines.single.text, 'First line');
    expect(cached.lyrics.lines.single.at, const Duration(seconds: 1));
  });

  test('untagged files fall back to the file name', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final support = _tempMusic();
    PathProviderPlatform.instance = _FakePathProvider(support);
    final service = LocalImportService(
      database: db,
      directory: await localMusicDirectory(),
      lyrics: null,
      onImported: () {},
    );

    // A file with no readable tags still lands in the library under its name.
    final untagged = _wav(_tempMusic(), 'Untagged Take.wav');
    final result = await service.importFiles([untagged]);
    expect(result.imported, 1);

    final local = LocalLibrarySource(
      database: db,
      directory: await localMusicDirectory(),
    );
    final songs = await local.randomSongs();
    expect(songs.single.title, 'Untagged Take');
    expect(songs.single.album, isNull);
    expect(await local.albums(), isEmpty, reason: 'no album tag, no album');

    // Album keys are stable across runs, so a later import joins the album
    // instead of creating a second one with the same name.
    final key = localAlbumKey(album: 'Parachutes', albumArtist: 'Coldplay');
    expect(key, localAlbumKey(album: 'Parachutes', albumArtist: 'Coldplay'));
    expect(key, isNot(localAlbumKey(album: 'Parachutes', albumArtist: 'U2')));
    expect(RegExp(r'^[a-z0-9-]+$').hasMatch(key), isTrue,
        reason: 'the album id is a URL path segment');
  });
}
