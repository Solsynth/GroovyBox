import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlayerStream extends Fake implements PlayerStream {
  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _volume = StreamController<double>.broadcast();

  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<bool> get buffering => _buffering.stream;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<double> get volume => _volume.stream;
}

class _FakePlayer extends Fake implements Player {
  final _streams = _FakePlayerStream();

  @override
  PlayerStream get stream => _streams;

  @override
  Future<void> open(Playable playable, {bool? play = true}) async {}

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

class _FakeSource extends Fake implements LibrarySource {
  _FakeSource(this.id, this._songs);

  @override
  final String id;
  final List<LibrarySong> _songs;

  @override
  LibraryKind get kind => LibraryKind.subsonic;

  @override
  String get displayName => 'Fake Source';

  @override
  Future<List<LibrarySong>> randomSongs({int size = 40}) async => _songs;

  @override
  Uri streamUri(LibrarySong song) => Uri.parse('http://fake.stream/${song.id}');
}

void main() {
  test('restores saved session on Playback initialization', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);

    const savedSongs = [
      LibrarySong(
        sourceId: 'src1',
        id: 's1',
        title: 'Song One',
        artist: 'Artist One',
        duration: Duration(seconds: 180),
      ),
      LibrarySong(
        sourceId: 'src1',
        id: 's2',
        title: 'Song Two',
        artist: 'Artist Two',
        duration: Duration(seconds: 220),
      ),
    ];

    await catalog.savePlaybackSession(
      queueJson: jsonEncode(savedSongs.map((s) => s.toJson()).toList()),
      currentIndex: 1,
      positionMs: 45000,
      durationMs: 220000,
      shuffle: true,
      repeatMode: 'all',
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        playbackProvider.overrideWith(() => Playback(_FakePlayer())),
      ],
    );
    addTearDown(container.dispose);

    // Read playback provider
    final state = container.read(playbackProvider);
    expect(state.queue, isEmpty); // synchronously returns empty

    // Allow asynchronous _restoreSession to complete
    await pumpEventQueue();

    final restored = container.read(playbackProvider);
    expect(restored.queue, hasLength(2));
    expect(restored.current?.title, 'Song Two');
    expect(restored.currentIndex, 1);
    expect(restored.position, const Duration(milliseconds: 45000));
    expect(restored.duration, const Duration(milliseconds: 220000));
    expect(restored.shuffle, isTrue);
    expect(restored.repeatMode, PlaybackRepeatMode.all);
    expect(restored.playing, isFalse);
  });

  test('infinite playback appends random library tracks when queue reaches the end', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    const randomSong = LibrarySong(
      sourceId: 'src-random',
      id: 'rand-1',
      title: 'Infinite Random Track',
      artist: 'Random Artist',
      duration: Duration(seconds: 200),
    );

    final fakeSource = _FakeSource('src-random', [randomSong]);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        librarySourcesProvider.overrideWithValue([fakeSource]),
        playbackProvider.overrideWith(() => Playback(_FakePlayer())),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playbackProvider.notifier);

    const queueSongs = [
      LibrarySong(
        sourceId: 'src-random',
        id: 'initial-1',
        title: 'Initial Song',
        duration: Duration(seconds: 120),
      ),
    ];

    await controller.playQueue(queueSongs, startIndex: 0);
    expect(container.read(playbackProvider).queue, hasLength(1));
    expect(container.read(playbackProvider).hasNext, isFalse);

    // Call next() at end of queue: infinite playback should fetch and append
    await controller.next();

    final updated = container.read(playbackProvider);
    expect(updated.queue, hasLength(2));
    expect(updated.queue.last.title, 'Infinite Random Track');
    expect(updated.currentIndex, 1);
  });

  test('infinite playback can be disabled via preference', () async {
    SharedPreferences.setMockInitialValues({
      'app_infinite_playback': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    const randomSong = LibrarySong(
      sourceId: 'src-random',
      id: 'rand-1',
      title: 'Infinite Random Track',
      artist: 'Random Artist',
      duration: Duration(seconds: 200),
    );

    final fakeSource = _FakeSource('src-random', [randomSong]);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        librarySourcesProvider.overrideWithValue([fakeSource]),
        playbackProvider.overrideWith(() => Playback(_FakePlayer())),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playbackProvider.notifier);

    const queueSongs = [
      LibrarySong(
        sourceId: 'src-random',
        id: 'initial-1',
        title: 'Initial Song',
        duration: Duration(seconds: 120),
      ),
    ];

    await controller.playQueue(queueSongs, startIndex: 0);
    await controller.next();

    // Does not append random tracks when disabled
    final updated = container.read(playbackProvider);
    expect(updated.queue, hasLength(1));
    expect(updated.currentIndex, 0);
  });
}
