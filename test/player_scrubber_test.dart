import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/player_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
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
  Future<Lyrics> lyrics(LibrarySong song) async => Lyrics.empty;

  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingPlayback extends Playback {
  _RecordingPlayback({this.repeatMode = PlaybackRepeatMode.off});

  final PlaybackRepeatMode repeatMode;
  final seeks = <Duration>[];

  @override
  PlaybackState build() => PlaybackState(
    queue: const [
      LibrarySong(
        sourceId: 'a',
        id: 's1',
        title: 'Sunset Overdrive',
        artist: 'The Paper Kites',
        duration: Duration(seconds: 240),
      ),
    ],
    currentIndex: 0,
    duration: const Duration(seconds: 240),
    position: const Duration(seconds: 60),
    repeatMode: repeatMode,
  );

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    state = state.copyWith(position: position);
  }
}

late _RecordingPlayback _playback;

Future<void> _pump(
  WidgetTester tester, {
  PlaybackRepeatMode repeatMode = PlaybackRepeatMode.off,
  bool infinite = false,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'app_infinite_playback': infinite});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Source()]),
        libraryDatabaseProvider.overrideWithValue(null),
        playbackProvider.overrideWith(() {
          _playback = _RecordingPlayback(repeatMode: repeatMode);
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

void main() {
  testWidgets('a drag previews and seeks once, on release', (tester) async {
    await _pump(tester);

    final slider = find.byType(Slider);
    final before = tester.getRect(slider);
    final gesture = await tester.startGesture(
      Offset(before.left + before.width * 0.25, before.center.dy),
    );
    await gesture.moveTo(Offset(before.left + before.width * 0.6, before.center.dy));
    await tester.pump();

    // Mid-drag the transport has not been asked to move: the bar is a
    // preview, and a seek per pixel would hammer the stream.
    expect(_playback.seeks, isEmpty);
    // The left clock names the point under the finger, not the player's.
    // A scrub to 60% of four minutes, named by the left clock.
    // The left clock names the point under the finger, not the player's:
    // the finger is at 60% of four minutes, whatever the thumb's own padding
    // costs the exact pixel.
    expect(find.text('1:00'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(r'^2:[0-9]{2}$').hasMatch(widget.data!),
      ),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pump();

    expect(_playback.seeks, hasLength(1));
    expect(
      _playback.seeks.single.inSeconds,
      inInclusiveRange(130, 155),
      reason: '60% of four minutes',
    );
  });

  testWidgets('Next is offered when the queue has somewhere to go', (
    tester,
  ) async {
    await _pump(tester);

    // One song, no repeat, no endless library: the queue really is over.
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Symbols.skip_next_rounded),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('Next stays live when the library may keep going', (
    tester,
  ) async {
    await _pump(tester, infinite: true);

    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Symbols.skip_next_rounded),
    );
    expect(next.onPressed, isNotNull);
  });

  testWidgets('Next stays live under repeat-all', (tester) async {
    await _pump(tester, repeatMode: PlaybackRepeatMode.all);

    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Symbols.skip_next_rounded),
    );
    expect(
      next.onPressed,
      isNotNull,
      reason: 'repeat-all wraps to the first row, so the button does something',
    );
  });
}
