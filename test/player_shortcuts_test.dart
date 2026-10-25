import 'package:audio_service/audio_service.dart' as audio;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/player/session.dart';
import 'package:groovy_box/screens/player_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends LibrarySource {
  @override
  String get id => 'a';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'a',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Home',
  );

  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');

  @override
  Future<Lyrics> lyrics(LibrarySong song) async => Lyrics.empty;

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Answers the keys the page and the notification share, and counts them.
class _RecordingPlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState(
    queue: [
      LibrarySong(
        sourceId: 'a',
        id: 's1',
        title: 'Sunset Overdrive',
        artist: 'The Paper Kites',
        duration: Duration(seconds: 254),
      ),
    ],
    currentIndex: 0,
    duration: Duration(seconds: 254),
    position: Duration(seconds: 20),
  );

  int playPauseCalls = 0;
  int previousCalls = 0;
  final seeks = <Duration>[];

  @override
  Future<void> togglePlayPause() async {
    playPauseCalls++;
    state = state.copyWith(playing: !state.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    state = state.copyWith(position: position);
  }

  @override
  Future<void> previous() async {
    previousCalls++;
  }

  @override
  Future<void> next() async {}
}

late _RecordingPlayback _playback;

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Source()]),
        playbackProvider.overrideWith(() {
          _playback = _RecordingPlayback();
          return _playback;
        }),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const PlayerScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A transport that only records, so the handler can be exercised without a
/// media-kit player.
class _Transport implements AudioTransport {
  final calls = <String>[];
  Duration? lastSeek;

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    calls.add('seek');
  }

  @override
  Future<void> next() async => calls.add('next');
  @override
  Future<void> previous() async => calls.add('previous');
  @override
  Future<void> setShuffle(bool shuffle) async => calls.add('shuffle $shuffle');
  @override
  Future<void> setRepeatMode(audio.AudioServiceRepeatMode mode) async =>
      calls.add('repeat ${mode.name}');
  @override
  Future<void> skipToQueueIndex(int index) async => calls.add('index $index');
}

void main() {
  testWidgets('space pauses, arrows seek, L shows the words', (tester) async {
    await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_playback.playPauseCalls, 1);
    expect(_playback.state.playing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_playback.seeks.last, const Duration(seconds: 25));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_playback.seeks.last, const Duration(seconds: 20));

    expect(find.byTooltip('Show lyrics'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    // Fixed pumps, not `pumpAndSettle`: the lyric pane is still waiting on its
    // download, and a spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('Hide lyrics'), findsOneWidget);
  });

  testWidgets('a seek stops at the ends of the track', (tester) async {
    await _pump(tester);

    // 20s in, a 5s jump back is 15s; one more is 10s, not 5s short of zero
    // and certainly not negative.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
    }
    expect(_playback.seeks.last, Duration.zero);
  });

  testWidgets('shift+arrow is the track button, not a bigger jump', (
    tester,
  ) async {
    await _pump(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(_playback.previousCalls, 1);
    expect(_playback.seeks, isEmpty);
  });

  testWidgets('escape closes the words before it closes the page', (
    tester,
  ) async {
    await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('Hide lyrics'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('Show lyrics'), findsOneWidget);
    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('clicking the backdrop hands the keys back to the page', (
    tester,
  ) async {
    await _pump(tester);

    // Tab onto a control, where Space belongs to that control rather than to
    // the transport.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    // A click on empty space returns the page to being the key owner, so the
    // transport shortcuts work again without tabbing back around. The point
    // is the shell's left gutter, level with the middle of the page: the
    // corner belongs to the floating close control.
    await tester.tapAt(const Offset(6, 400));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_playback.playPauseCalls, 1);
  });

  test('the handler passes system callbacks to the transport', () async {
    final handler = GroovyBoxAudioHandler();
    final transport = _Transport();
    handler.transport = transport;

    await handler.play();
    await handler.pause();
    await handler.seek(const Duration(seconds: 12));
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.skipToQueueItem(2);
    await handler.setShuffleMode(audio.AudioServiceShuffleMode.all);
    await handler.setRepeatMode(audio.AudioServiceRepeatMode.one);

    expect(transport.calls, [
      'play',
      'pause',
      'seek',
      'next',
      'previous',
      'index 2',
      'shuffle true',
      'repeat one',
    ]);
    expect(transport.lastSeek, const Duration(seconds: 12));
  });

  test('a published snapshot is what the notification draws', () {
    final handler = GroovyBoxAudioHandler();
    const song = LibrarySong(
      sourceId: 'a',
      id: 's1',
      title: 'Sunset Overdrive',
      artist: 'The Paper Kites',
      album: 'On the Corner Where You Live',
      duration: Duration(seconds: 254),
    );

    handler.publish(
      AudioSnapshot(
        items: [AudioSnapshot.itemOf(song)],
        index: 0,
        playing: true,
        position: const Duration(seconds: 30),
        repeatMode: audio.AudioServiceRepeatMode.none,
        shuffle: false,
      ),
    );

    final state = handler.playbackState.value;
    expect(state.playing, isTrue);
    expect(state.processingState, audio.AudioProcessingState.ready);
    expect(state.updatePosition, const Duration(seconds: 30));
    expect(state.controls, contains(audio.MediaControl.pause));
    expect(handler.mediaItem.value?.title, 'Sunset Overdrive');
    // Ids are qualified by source, so two libraries cannot collide.
    expect(handler.queue.value.single.id, 'a:s1');
  });

  test('an empty queue puts the session to sleep', () {
    final handler = GroovyBoxAudioHandler();
    handler.publish(
      const AudioSnapshot(
        items: [],
        index: null,
        playing: false,
        position: Duration.zero,
        repeatMode: audio.AudioServiceRepeatMode.none,
        shuffle: false,
      ),
    );

    expect(
      handler.playbackState.value.processingState,
      audio.AudioProcessingState.idle,
    );
    expect(handler.mediaItem.value, isNull);
  });
}
