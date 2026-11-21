import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
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
import 'package:groovy_box/player/session.dart';
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
  bool stopped = false;

  @override
  Future<void> stop() async {
    stopped = true;
  }

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
class _PlatformSource extends Fake
    implements LibrarySource, PlatformPlayedSource {
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
  Map<String, dynamic> platformResource(LibrarySong song) => {
    'id': song.id,
    'type': 'songs',
    'attributes': {'name': song.title},
  };

  @override
  String platformItemType(LibrarySong song) => 'songs';

  /// No catalog behind this fake: covers come from the item itself, and there
  /// is nothing further to say about an item.
  @override
  Future<String?> artworkTemplate(LibrarySong song) async => null;

  @override
  Future<LibrarySong?> describe(LibrarySong song) async => null;

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  Uri streamUri(LibrarySong song) =>
      throw StateError('a platform-played item has no stream URL');
}

/// A streamed library that answers one search, so a lookup can find a copy.
///
/// Stands for a second connected library holding the same recording Apple
/// described without credits; nothing about it is playable in these tests,
/// only *knowable*.
class _NamedSource extends Fake implements LibrarySource {
  _NamedSource({required this.id, required this.songs});

  @override
  final String id;
  final List<LibrarySong> songs;

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://$id.example.com',
    displayName: id,
  );

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async =>
      songs;

  @override
  Uri streamUri(LibrarySong song) =>
      Uri.parse('https://$id.example.com/${song.id}.mp3');

  @override
  Map<String, String> streamHeaders(LibrarySong song) => const {};

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;
}

/// A streamed library whose URL is minted when asked, behind a gate.
///
/// Opening a track is a sequence of awaits, and this makes one of them
/// controllable: what the transport does when a *second* open is asked for
/// while the first is still waiting is exactly what decides whether one track
/// or two is heard.
class _GatedSource extends Fake implements LibrarySource, ResolvedStreamSource {
  _GatedSource({required this.id, required this.gate, this.entered});

  @override
  final String id;
  final Future<void> gate;

  /// Completes the moment the mint is actually waiting, so a test can land a
  /// skip inside the window instead of racing the scheduler to it.
  final Completer<void>? entered;

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://$id.example.com',
    displayName: id,
  );

  @override
  Future<Uri> resolveStreamUri(LibrarySong song) async {
    entered?.complete();
    await gate;
    return Uri.parse('https://$id.example.com/${song.id}.mp3');
  }

  @override
  Uri streamUri(LibrarySong song) =>
      throw StateError('this library mints its URLs');

  @override
  Map<String, String> streamHeaders(LibrarySong song) => const {};

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;
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
  Future<void> clearQueue() async => calls.add('clearQueue');

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

  /// The track the system reports, which is how a station's own generated run
  /// reaches the app.
  final tracks = StreamController<AppleQueueEntry>.broadcast();

  @override
  Stream<AppleQueueEntry> get currentTrack => tracks.stream;

  final skipped = <String>[];

  @override
  Future<void> skipNext() async => skipped.add('next');

  @override
  Future<void> skipPrevious() async => skipped.add('previous');

  final playedQueues = StreamController<AppleQueue>.broadcast();

  @override
  Stream<AppleQueue> get queue => playedQueues.stream;

  final statuses = StreamController<ApplePlayerStatus>.broadcast();

  @override
  Stream<ApplePlayerStatus> get status => statuses.stream;
}

void main() {
  late _RecordingKit kit;
  late _FakePlayer player;
  late ProviderContainer container;
  late LibraryDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_infinite_playback': false});
    final prefs = await SharedPreferences.getInstance();
    db = LibraryDatabase(NativeDatabase.memory());
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
    addTearDown(kit.tracks.close);
    addTearDown(kit.playedQueues.close);
    addTearDown(kit.statuses.close);
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

  test('a run stops at the first track the system cannot resolve', () async {
    // A favourite list built from two libraries is the real case: the Apple
    // items are playable, a Subsonic copy is not, and the whole run used to be
    // handed over anyway — which fails as MPMusicPlayerControllerErrorDomain 6.
    await container.read(playbackProvider.notifier).playQueue([
      song,
      const LibrarySong(
        sourceId: 'subsonic-1',
        id: 's.1',
        title: 'Streamed',
        duration: Duration(minutes: 2),
      ),
    ]);
    await pumpEventQueue();

    expect(kit.queues.single.map((item) => item['id']), ['i.1']);
    expect(kit.calls, contains('play'));
  });

  test('leaving a streamed track for the platform stops media-kit', () async {
    // A streamed song is loaded first, so there is something sounding.
    await container.read(playbackProvider.notifier).playQueue([
      const LibrarySong(
        sourceId: 'subsonic-1',
        id: 's.1',
        title: 'Streamed',
        duration: Duration(minutes: 2),
      ),
    ]);
    await pumpEventQueue();

    await container.read(playbackProvider.notifier).playQueue([song]);
    await pumpEventQueue();

    // Two players sounding one after the other is the bug: the streamed track
    // must be stopped, not left running under the system player.
    expect(player.stopped, isTrue);
    expect(kit.queues, hasLength(1));
  });

  test('switching version replaces the row and keeps the queue', () async {
    final transport = container.read(playbackProvider.notifier);
    await transport.playQueue([
      song,
      const LibrarySong(
        sourceId: 'apple-1',
        id: 'i.2',
        title: 'Second',
        duration: Duration(minutes: 2),
      ),
    ]);
    await pumpEventQueue();
    await transport.seek(const Duration(seconds: 30));
    await pumpEventQueue();

    // Another library's copy of the same recording.
    final copy = LibrarySong(
      sourceId: 'apple-1',
      id: 'i.99',
      title: 'Daytona Sand',
      artist: 'Orville Peck',
      album: 'Bronco',
      duration: const Duration(minutes: 3),
    );
    await transport.switchVersion(copy);
    await pumpEventQueue();

    final state = container.read(playbackProvider);
    expect(state.queue, hasLength(2), reason: 'the queue keeps its shape');
    expect(state.queue.first.id, 'i.99');
    expect(state.currentIndex, 0);
    expect(state.position, const Duration(seconds: 30));
  });

  test('a different song is not a version', () async {
    final transport = container.read(playbackProvider.notifier);
    await transport.playQueue([song]);
    await pumpEventQueue();

    await transport.switchVersion(
      const LibrarySong(
        sourceId: 'apple-1',
        id: 'i.other',
        title: 'Completely Different',
        artist: 'Someone Else',
        duration: Duration(minutes: 3),
      ),
    );
    await pumpEventQueue();

    // A lookup must never quietly replace the track with another one.
    expect(container.read(playbackProvider).current?.id, 'i.1');
  });

  test('a station names the track it is playing, not itself', () async {
    final station = LibrarySong(
      sourceId: 'apple-1',
      id: 'ra.1',
      title: 'Mirror Mirror Radio',
      duration: Duration.zero,
      isRadio: true,
      radioUrl: 'https://music.apple.com/cn/station/x/ra.1',
      radioPlayParams: const {'id': 'ra.1', 'kind': 'radioStation'},
    );
    await container.read(playbackProvider.notifier).playQueue([station]);
    await pumpEventQueue();

    // A station generates its own run: the system player is the only thing
    // that knows a track started.
    kit.tracks.add(
      const AppleQueueEntry(
        id: '1745015575',
        title: 'Mesmerizer',
        artist: 'サツキ, Hatsune Miku & 重音テト',
        duration: Duration(milliseconds: 156000),
      ),
    );
    await pumpEventQueue();

    final state = container.read(playbackProvider);
    // Everything that describes a track reads the track on the air: artwork,
    // lyrics and the scrobbler all ask `current`.
    expect(state.current?.title, 'Mesmerizer');
    expect(state.current?.artist, 'サツキ, Hatsune Miku & 重音テト');
    expect(state.duration, const Duration(milliseconds: 156000));
    // The queue row is still the station, so it keeps what playing needs.
    expect(state.queueRow?.isRadio, isTrue);
    expect(state.queueRow?.title, 'Mirror Mirror Radio');
    expect(
      state.queueRow?.radioUrl,
      'https://music.apple.com/cn/station/x/ra.1',
    );
  });

  test('inside a station, next and previous skip the station itself', () async {
    final transport = container.read(playbackProvider.notifier);
    await transport.playQueue([
      const LibrarySong(
        sourceId: 'apple-1',
        id: 'ra.1',
        title: 'Mirror Mirror Radio',
        duration: Duration.zero,
        isRadio: true,
        radioUrl: 'https://music.apple.com/cn/station/x/ra.1',
        radioPlayParams: {'id': 'ra.1', 'kind': 'radioStation'},
      ),
      const LibrarySong(
        sourceId: 'apple-1',
        id: 'i.2',
        title: 'A track queued after the station',
        duration: Duration(minutes: 2),
      ),
    ]);
    await pumpEventQueue();

    // The run the platform player generated, as it reports it.
    kit.playedQueues.add(
      const AppleQueue(
        entries: [
          AppleQueueEntry(id: 'a', title: 'First'),
          AppleQueueEntry(id: 'b', title: 'Second'),
        ],
        currentIndex: 0,
      ),
    );
    await pumpEventQueue();
    expect(
      container.read(playbackProvider).stationTracks.map((song) => song.title),
      ['First', 'Second'],
    );

    await transport.next();
    await pumpEventQueue();
    // Not the row after the station: the station's own next track.
    expect(kit.skipped, contains('next'));
    expect(container.read(playbackProvider).currentIndex, 0);

    await transport.previous();
    await pumpEventQueue();
    expect(kit.skipped, contains('previous'));
  });

  test(
    'a station records its tracks in the play history, not itself',
    () async {
      await container.read(playbackProvider.notifier).playQueue([
        const LibrarySong(
          sourceId: 'apple-1',
          id: 'ra.1',
          title: 'Mirror Mirror Radio',
          duration: Duration.zero,
          isRadio: true,
          radioUrl: 'https://music.apple.com/cn/station/x/ra.1',
          radioPlayParams: {'id': 'ra.1', 'kind': 'radioStation'},
        ),
      ]);
      await pumpEventQueue();

      kit.tracks.add(
        const AppleQueueEntry(
          id: '1745015575',
          title: 'Mesmerizer',
          artist: 'サツキ, Hatsune Miku & 重音テト',
          duration: Duration(milliseconds: 156000),
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      // The station row has no length and no title worth counting; the row a
      // listener would see in their history is the track that played.
      final tracks = await db.select(db.tracks).get();
      expect(
        tracks.map((row) => row.title),
        isNot(contains('Mirror Mirror Radio')),
      );
      expect(tracks.map((row) => row.title), contains('Mesmerizer'));
    },
  );

  test('a station track starts its own clock at zero', () async {
    await container.read(playbackProvider.notifier).playQueue([
      const LibrarySong(
        sourceId: 'apple-1',
        id: 'ra.1',
        title: 'Mirror Mirror Radio',
        duration: Duration.zero,
        isRadio: true,
        radioUrl: 'https://music.apple.com/cn/station/x/ra.1',
        radioPlayParams: {'id': 'ra.1', 'kind': 'radioStation'},
      ),
    ]);
    await pumpEventQueue();

    // The platform clock is polled once a second, so the position the app
    // sees before the station moves on is whatever the system reports then.
    kit.position = const Duration(seconds: 5);
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (container.read(playbackProvider).position.inSeconds == 5) break;
    }
    expect(container.read(playbackProvider).position.inSeconds, 5);
    kit.tracks.add(
      const AppleQueueEntry(
        id: '1745015575',
        title: 'Mesmerizer',
        duration: Duration(milliseconds: 156000),
      ),
    );
    await pumpEventQueue();

    // The new track's clock starts where the track does. Carrying the old
    // position over reported progress against a track that had not played,
    // and a presence session cannot be described by that.
    final playback = container.read(playbackProvider);
    expect(playback.position, Duration.zero);
    expect(playback.duration, const Duration(milliseconds: 156000));
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

  test(
    'a station track Apple cannot name borrows another library credits',
    () async {
      // Apple reported the track with a title and an id, and the store has no
      // row for it — the case that left the dock, the player page and the
      // scrobbler saying "Unknown artist". A neighbour holds the same
      // recording, and its credits name it.
      final neighbour = _NamedSource(
        id: 'jam-1',
        songs: const [
          LibrarySong(
            sourceId: 'jam-1',
            id: 's-1',
            title: 'Mesmerizer',
            artist: 'サツキ',
            album: 'Mesmerizer',
            duration: Duration(milliseconds: 156000),
          ),
        ],
      );
      final List<LibrarySource> sources = [_PlatformSource(), neighbour];
      final prefs = await SharedPreferences.getInstance();
      final local = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryDatabaseProvider.overrideWithValue(db),
          librarySourcesProvider.overrideWithValue(sources),
          musicKitClientProvider.overrideWithValue(kit),
          playbackProvider.overrideWith(() => Playback(player)),
        ],
      );
      addTearDown(local.dispose);

      await local.read(playbackProvider.notifier).playQueue([
        const LibrarySong(
          sourceId: 'apple-1',
          id: 'ra.1',
          title: 'Mirror Mirror Radio',
          duration: Duration.zero,
          isRadio: true,
          radioUrl: 'https://music.apple.com/cn/station/x/ra.1',
          radioPlayParams: {'id': 'ra.1', 'kind': 'radioStation'},
        ),
      ]);
      await pumpEventQueue();
      kit.tracks.add(
        const AppleQueueEntry(
          id: '1745015575',
          title: 'Mesmerizer',
          duration: Duration(milliseconds: 156000),
        ),
      );
      // The lookup is a network read per connected library; one turn is not
      // enough for it to land.
      for (var i = 0; i < 30; i++) {
        await pumpEventQueue();
        if (local.read(playbackProvider).current?.artist != null) break;
      }

      final playing = local.read(playbackProvider).current!;
      expect(playing.artist, 'サツキ');
      expect(playing.album, 'Mesmerizer');
      // The row still plays from Apple: only the names were borrowed.
      expect(playing.sourceId, 'apple-1');
      expect(playing.artistId, isNull);
    },
  );

  test('a skip during an open never leaves two players sounding', () async {
    // The bug: a streamed track is mid-open (its URL is being minted) when a
    // skip lands on an Apple Music track. Both opens ran, so the older one
    // resumed afterwards and opened media-kit on top of MusicKit — two tracks
    // audible at once. The gate holds the first open mid-await to reproduce
    // exactly that window.
    final gate = Completer<void>();
    final entered = Completer<void>();
    final streamed = _GatedSource(
      id: 'ne-1',
      gate: gate.future,
      entered: entered,
    );
    final List<LibrarySource> sources = [streamed, _PlatformSource()];
    final prefs = await SharedPreferences.getInstance();
    final local = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        librarySourcesProvider.overrideWithValue(sources),
        musicKitClientProvider.overrideWithValue(kit),
        playbackProvider.overrideWith(() => Playback(player)),
      ],
    );
    addTearDown(local.dispose);
    final transport = local.read(playbackProvider.notifier);

    const streamedSong = LibrarySong(
      sourceId: 'ne-1',
      id: '101',
      title: 'Streamed',
      duration: Duration(minutes: 2),
    );
    const appleSong = LibrarySong(
      sourceId: 'apple-1',
      id: 'i.1',
      title: 'Daytona Sand',
      duration: Duration(minutes: 3),
    );

    // First open: parked inside the mint. Waiting for [entered] rather than a
    // turn of the scheduler is what puts the skip *inside* the window the
    // bug needs.
    final first = transport.playQueue([streamedSong]);
    await entered.future;
    // The skip lands while it is parked.
    final second = transport.playQueue([appleSong]);
    await pumpEventQueue();

    // Let the abandoned mint finish: it must not open anything, and the
    // queued Apple open must be the only one that reaches a player.
    gate.complete();
    await first;
    await second;
    await pumpEventQueue();

    expect(
      kit.calls,
      contains('play'),
      reason: 'MusicKit took over from the streamed open',
    );

    expect(
      player.opened,
      isEmpty,
      reason: 'the superseded open must not start media-kit',
    );
    expect(local.read(playbackProvider).current?.id, 'i.1');
  });

  test(
    'MusicKit playback keeps the app audio_service handler stood down across tracks',
    () async {
      final handler = GroovyBoxAudioHandler();
      final emitted = <audio_service.PlaybackState>[];
      final sub = handler.playbackState.skip(1).listen(emitted.add);
      addTearDown(sub.cancel);

      final streamed = _NamedSource(id: 'subsonic-1', songs: const []);
      final prefs = await SharedPreferences.getInstance();
      final local = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryDatabaseProvider.overrideWithValue(db),
          librarySourcesProvider.overrideWithValue([_PlatformSource(), streamed]),
          musicKitClientProvider.overrideWithValue(kit),
          audioHandlerProvider.overrideWithValue(handler),
          playbackProvider.overrideWith(() => Playback(player)),
        ],
      );
      addTearDown(local.dispose);
      final transport = local.read(playbackProvider.notifier);

      // 1. Fresh start with an Apple Music track: audio_service must never be
      // woken with `playing: true` or a non-idle state.
      await transport.playQueue([song]);
      kit.statuses.add(ApplePlayerStatus.playing);
      await pumpEventQueue();

      expect(local.read(playbackProvider).playing, isTrue);
      expect(
        emitted,
        isEmpty,
        reason: 'audio_service stays untouched while MusicKit owns playback',
      );
      expect(
        handler.playbackState.value.processingState,
        audio_service.AudioProcessingState.idle,
      );
      expect(handler.playbackState.value.playing, isFalse);

      // 2. Switching to a second Apple Music track: a trailing `stopped` event
      // from retiring the previous queue must not leak a platformOwned=false
      // publish into audio_service.
      const second = LibrarySong(
        sourceId: 'apple-1',
        id: 'i.2',
        title: 'Second',
        duration: Duration(minutes: 2),
      );
      final nextOpen = transport.playQueue([second]);
      kit.statuses.add(ApplePlayerStatus.stopped);
      await nextOpen;
      kit.statuses.add(ApplePlayerStatus.playing);
      await pumpEventQueue();

      expect(
        emitted,
        isEmpty,
        reason: 'switching between MusicKit tracks must not wake audio_service',
      );

      // 3. Handing over to a streamed track wakes audio_service, and handing
      // back to MusicKit retires it with idle + playing: false.
      await transport.playQueue([
        const LibrarySong(
          sourceId: 'subsonic-1',
          id: 's.1',
          title: 'Streamed',
          duration: Duration(minutes: 2),
        ),
      ]);
      await pumpEventQueue();
      expect(
        handler.playbackState.value.processingState,
        audio_service.AudioProcessingState.ready,
      );

      await transport.playQueue([song]);
      kit.statuses.add(ApplePlayerStatus.playing);
      await pumpEventQueue();

      expect(
        handler.playbackState.value.processingState,
        audio_service.AudioProcessingState.idle,
      );
      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.mediaItem.value, isNull);
    },
  );
}
