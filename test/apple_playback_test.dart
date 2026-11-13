import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/apple_kit.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/apple_player.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentPlayerStream extends Fake implements PlayerStream {
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
  /// Every URL this player was asked to open.
  final opened = <String>[];

  @override
  PlayerStream get stream => _SilentPlayerStream();

  @override
  Future<void> open(Playable playable, {bool? play = true}) async {
    opened.add('$playable');
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {}
  @override
  Future<void> dispose() async {}
}

/// A source the device cannot stream: every item is played by the platform.
class _PlatformSource extends Fake implements LibrarySource {
  @override
  final String id = 'apple-1';

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.appleMusic,
    baseUrl: '',
    displayName: 'Apple Music',
  );

  @override
  bool get usesPlatformPlayer => true;

  @override
  Uri streamUri(LibrarySong song) =>
      throw StateError('a platform-played item has no stream URL');
}

/// Records what the transport asked the platform player to do.
class _RecordingKit extends Fake implements MusicKitClient {
  final queues = <List<Map<String, dynamic>>>[];
  final calls = <String>[];
  final sought = <Duration>[];
  Duration position = Duration.zero;

  @override
  Future<void> setQueue(
    List<Map<String, dynamic>> items, {
    int startingAt = 0,
    String itemType = 'songs',
  }) async {
    queues.add(items);
    calls.add('queue');
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration target) async {
    sought.add(target);
    position = target;
    calls.add('seek');
  }

  @override
  Future<Duration> playbackTime() async => position;

  /// What the system player reports it is on. Driven by a test to stand for
  /// the system advancing by itself when a track ends.
  final queueIndices = StreamController<int>.broadcast();

  @override
  Stream<int> get queueIndex => queueIndices.stream;

  @override
  Stream<ApplePlayerStatus> get status => const Stream.empty();
}

void main() {
  late _RecordingKit kit;
  late _FakePlayer player;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_infinite_playback': false});
    final prefs = await SharedPreferences.getInstance();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    kit = _RecordingKit();
    player = _FakePlayer();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        librarySourcesProvider.overrideWithValue([_PlatformSource()]),
        musicKitClientProvider.overrideWithValue(kit),
        playbackProvider.overrideWith(() => Playback(player)),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(kit.queueIndices.close);
  });

  const song = LibrarySong(
    sourceId: 'apple-1',
    id: 'i.1',
    title: 'Daytona Sand',
    artist: 'Orville Peck',
    album: 'Bronco',
    duration: Duration(minutes: 3),
  );

  test('a platform-played song never reaches the media-kit player', () async {
    await container.read(playbackProvider.notifier).playQueue([song]);

    expect(player.opened, isEmpty, reason: 'no stream URL was opened');
    expect(kit.queues, hasLength(1));
    expect(kit.queues.single.single['id'], 'i.1');
    expect(kit.calls, contains('play'));
  });

  test(
    'the whole run is handed over, so the system can advance on its own',
    () async {
      await container.read(playbackProvider.notifier).playQueue([
        song,
        const LibrarySong(
          sourceId: 'apple-1',
          id: 'i.2',
          title: 'Second',
          duration: Duration(minutes: 2),
        ),
      ]);

      // One item at a time would leave the system player stopped at the end of
      // that item: it has nowhere to advance to.
      expect(kit.queues.single.map((item) => item['id']), ['i.1', 'i.2']);
    },
  );

  test('when the system advances, the app follows it', () async {
    await container.read(playbackProvider.notifier).playQueue([
      song,
      const LibrarySong(
        sourceId: 'apple-1',
        id: 'i.2',
        title: 'Second',
        duration: Duration(minutes: 2),
      ),
    ]);
    await pumpEventQueue();
    expect(container.read(playbackProvider).current?.id, 'i.1');

    // The system reports the second entry, which is what reaching the end of
    // the first track looks like from here.
    kit.queueIndices.add(1);
    await pumpEventQueue();

    expect(container.read(playbackProvider).current?.id, 'i.2');
    expect(container.read(playbackProvider).currentIndex, 1);
    // The new track's own length and a clock back at zero: the app is on the
    // second track, not on the first one's timings.
    expect(
      container.read(playbackProvider).duration,
      const Duration(minutes: 2),
    );
    expect(container.read(playbackProvider).position, Duration.zero);
    // Following the system must not re-push the queue and restart the track.
    expect(kit.queues, hasLength(1));
  });

  test('pause, seek and play go to the platform player', () async {
    final transport = container.read(playbackProvider.notifier);
    await transport.playQueue([song]);

    await transport.pause();
    expect(kit.calls, contains('pause'));
    expect(container.read(playbackProvider).playing, isFalse);

    await transport.seek(const Duration(seconds: 40));
    expect(kit.sought.single, const Duration(seconds: 40));

    await transport.play();
    expect(kit.calls.where((call) => call == 'play'), hasLength(2));
    expect(player.opened, isEmpty);
  });

  test('a streamed song takes the transport back from the platform', () async {
    final transport = container.read(playbackProvider.notifier);
    await transport.playQueue([song]);
    expect(kit.calls, contains('play'));

    // The queue is replaced by a song from a streamed source: the platform
    // player must be stopped, or it keeps sounding under a track the app
    // thinks it started.
    await transport.playQueue([
      LibrarySong(
        sourceId: 'subsonic-1',
        id: 's.1',
        title: 'Streamed',
        duration: const Duration(minutes: 2),
      ),
    ]);

    expect(kit.calls, contains('stop'));
    // No such source is connected, so nothing opens: the hand-over is what
    // this test is about, not the open.
    expect(player.opened, isEmpty);
  });
}
