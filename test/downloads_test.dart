import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/subsonic_adapter.dart';

/// A server that hands out one track and one cover, and can go away.
class _Server {
  _Server._(this._server);

  final HttpServer _server;

  /// Bytes served by the stream endpoint, so a test can check the copy is the
  /// answer and not a placeholder.
  static final audio = List<int>.generate(64 * 1024, (index) => index % 251);

  static Future<_Server> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _Server._(server);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  SourceConfig get config => SourceConfig(
    id: 'home',
    kind: LibraryKind.subsonic,
    baseUrl: baseUrl,
    displayName: 'Home',
    auth: {'username': 'u', 'token': 't', 'salt': 's'},
  );

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path.endsWith('/rest/stream')) {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.contentLength = audio.length;
      request.response.add(audio);
      await request.response.close();
      return;
    }
    if (path.endsWith('/rest/getCoverArt')) {
      // A one-pixel GIF: enough for the cover path to write a file.
      final bytes = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );
      request.response.headers.contentType = ContentType('image', 'gif');
      request.response.add(bytes);
      await request.response.close();
      return;
    }
    request.response.statusCode = 404;
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

const _song = LibrarySong(
  sourceId: 'home',
  id: 's1',
  title: 'Yellow',
  artist: 'Coldplay',
  album: 'Parachutes',
  artId: 'a1',
  duration: Duration(seconds: 266),
);

void main() {
  late _Server server;
  late LibraryDatabase db;
  late Directory directory;
  late DownloadService service;

  setUp(() async {
    server = await _Server.start();
    db = LibraryDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('groovybox-downloads');
    service = DownloadService(
      database: db,
      directory: directory.path,
      sources: () => {'home': SubsonicSource(server.config)},
    );
  });

  tearDown(() async {
    await server.close();
    await db.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('a downloaded track is the bytes the server served', () async {
    final fractions = <double>[];
    await service.download(_song, onProgress: fractions.add);

    final path = await service.downloadedFile(_song);
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), _Server.audio);
    // The size is reported as the copy grows, not only at the end.
    expect(fractions, isNotEmpty);

    final row = await db.downloadOf('home', 's1');
    expect(row, isNotNull);
    expect(row!.title, 'Yellow');
    expect(row.artist, 'Coldplay');
    expect(row.sizeBytes, _Server.audio.length);
    expect(row.artPath, isNotNull);
    expect(await File('${directory.path}/${row.artPath}').exists(), isTrue);
  });

  test('the copy plays after the library is gone', () async {
    await service.download(_song);
    await server.close();

    final path = await service.downloadedFile(_song);
    expect(path, isNotNull);
    expect(await File(path!).length(), _Server.audio.length);
  });

  test('downloading twice keeps one copy', () async {
    await service.download(_song);
    await service.download(_song);

    expect((await db.downloadTotals()).count, 1);
    final files = await directory
        .list()
        .where((entry) => entry is File)
        .toList();
    expect(files.where((file) => file.path.endsWith('.mp3')), hasLength(1));
  });

  test('removing a download deletes the bytes and the row', () async {
    await service.download(_song);
    final path = await service.downloadedFile(_song);

    await service.remove(_song);

    expect(await db.downloadOf('home', 's1'), isNull);
    expect(await File(path!).exists(), isFalse);
    expect(await service.downloadedFile(_song), isNull);
  });

  test('a removed row is not a download, even if bytes survive', () async {
    await service.download(_song);
    final path = await service.downloadedFile(_song);
    await db.removeDownload('home', 's1');

    // The file on disk is orphaned, not playable: the row is the record.
    expect(await service.downloadedFile(_song), isNull);
    expect(await File(path!).exists(), isTrue);
  });

  test('sweeping deletes files no row claims', () async {
    await service.download(_song);
    final orphan = File('${directory.path}/leftover.mp3');
    await orphan.writeAsBytes([1, 2, 3]);

    await service.sweep();

    expect(await orphan.exists(), isFalse);
    expect(await service.downloadedFile(_song), isNotNull);
  });

  test('everything downloaded can be emptied at once', () async {
    await service.download(_song);
    await service.removeAll();

    expect((await db.downloadTotals()).count, 0);
    expect((await service.all()), isEmpty);
  });

  test('a radio station is refused before any request', () async {
    await expectLater(
      service.download(
        const LibrarySong(
          sourceId: 'home',
          id: 'station',
          title: 'Radio',
          duration: Duration.zero,
          isRadio: true,
        ),
      ),
      throwsA(isA<LibraryException>()),
    );
  });
}
