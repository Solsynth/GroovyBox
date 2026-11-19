import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentStream extends Fake implements PlayerStream {
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<bool> get completed => const Stream.empty();
  @override
  Stream<double> get volume => const Stream.empty();
}

class _FakePlayer extends Fake implements Player {
  final opened = <String>[];

  @override
  PlayerStream get stream => _SilentStream();

  @override
  Future<void> open(Playable playable, {bool? play = true}) async {
    opened.add((playable as Media).uri);
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {}
  @override
  Future<void> dispose() async {}
}

/// A library that would answer if asked, and records whether it was.
class _Source extends LibrarySource {
  var streamed = 0;

  @override
  SourceConfig get config => const SourceConfig(
    id: 'home',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Home',
  );

  @override
  Uri streamUri(LibrarySong song) {
    streamed++;
    return Uri.parse('https://music.example.com/rest/stream?id=${song.id}');
  }

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _song = LibrarySong(
  sourceId: 'home',
  id: 's1',
  title: 'Yellow',
  artist: 'Coldplay',
  duration: Duration(seconds: 266),
);

void main() {
  late _FakePlayer player;
  late LibraryDatabase db;
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = LibraryDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('groovybox-offline');
  });

  tearDown(() async {
    await db.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<ProviderContainer> containerWith(bool downloaded) async {
    final prefs = await SharedPreferences.getInstance();
    final source = _Source();
    if (downloaded) {
      final file = File('${directory.path}/yellow.mp3');
      await file.writeAsBytes(List<int>.filled(2048, 7));
      await db.upsertDownload(
        DownloadsCompanion.insert(
          sourceId: 'home',
          externalId: 's1',
          path: 'yellow.mp3',
          sizeBytes: 2048,
          title: 'Yellow',
          downloadedAt: DateTime.now(),
        ),
      );
    }
    player = _FakePlayer();
    final service = DownloadService(
      database: db,
      directory: directory.path,
      sources: () => {'home': source},
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        librarySourcesProvider.overrideWithValue([source]),
        downloadServiceProvider.overrideWith((ref) async => service),
        playbackProvider.overrideWith(() => Playback(player)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a downloaded track opens from disk, not the stream', () async {
    final container = await containerWith(true);

    await container.read(playbackProvider.notifier).playQueue([_song]);

    expect(player.opened, hasLength(1));
    // libmpv takes the path itself; no scheme is added on the way in.
    expect(player.opened.single, contains('yellow.mp3'));
    expect(player.opened.single, isNot(contains('rest/stream')));
  });

  test('a track that is not downloaded still streams', () async {
    final container = await containerWith(false);

    await container.read(playbackProvider.notifier).playQueue([_song]);

    expect(player.opened.single, contains('rest/stream'));
  });

  test('a download plays after its library is disconnected', () async {
    final container = await containerWith(true);
    // The download's row names the library; playback asks the disk before it
    // asks the library, so the same open works with nothing connected.
    await container.read(playbackProvider.notifier).playQueue([_song]);

    expect(jsonEncode(player.opened), contains('yellow.mp3'));
  });
}
