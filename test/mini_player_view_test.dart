import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/desktop/mini_player/mini_playback.dart';
import 'package:groovy_box/desktop/mini_player/mini_player_app.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
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

/// The guest's mirror, with the link replaced by a recorder: the window's
/// commands are asserted without an engine on the other end.
class _RecordingMini extends MiniPlayback {
  _RecordingMini(this.initial);

  final PlaybackState initial;
  final commands = <String>[];

  @override
  PlaybackState build() {
    send = (method, [arguments]) async => commands.add(method);
    return initial;
  }
}

const _song = LibrarySong(
  sourceId: 'a',
  id: 's1',
  title: 'Sunset Overdrive',
  artist: 'The Paper Kites',
  duration: Duration(seconds: 240),
);

const _next = LibrarySong(
  sourceId: 'a',
  id: 's2',
  title: 'Bloom',
  artist: 'The Paper Kites',
  duration: Duration(seconds: 200),
);

Future<_RecordingMini> _pump(
  WidgetTester tester, {
  PlaybackState state = const PlaybackState(
    queue: [_song, _next],
    currentIndex: 0,
    duration: Duration(seconds: 240),
  ),
  PlaybackState? mirror,
}) async {
  tester.view.physicalSize = const Size(360, 520);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final initial = state;
  late _RecordingMini playback;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Source()]),
        libraryDatabaseProvider.overrideWithValue(null),
        playbackProvider.overrideWith(() {
          playback = _RecordingMini(mirror ?? initial);
          return playback;
        }),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final song = ProviderScope.containerOf(context)
                  .read(playbackProvider)
                  .current;
              return song == null
                  ? const SizedBox.shrink()
                  : MiniPlayerView(song: song);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return playback;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The mini window resizes itself when a pane opens; there is no native
    // window in a widget test, so answer the plugin channel with a fixed size.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async {
          switch (call.method) {
            case 'getSize':
              return {'width': 340.0, 'height': 190.0};
            case 'getBounds':
              return {'x': 0.0, 'y': 0.0, 'width': 340.0, 'height': 190.0};
            default:
              return null;
          }
        });
  });

  tearDown(() {
    miniPlayerPane.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  testWidgets('the window names the track it is playing', (tester) async {
    await _pump(tester);

    expect(find.text('Sunset Overdrive'), findsOneWidget);
    expect(find.text('The Paper Kites'), findsOneWidget);
  });

  testWidgets('the lyrics toggle mounts the lyrics pane', (tester) async {
    await _pump(tester);

    // The strip is a drag handle, so its own double-tap recognizer holds the
    // pointer until the double-tap window closes before the button's tap wins.
    await tester.tap(find.byIcon(Symbols.lyrics_rounded));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();

    expect(find.byType(SongLyricsPane), findsOneWidget);
  });

  testWidgets('the queue toggle mounts the queue panel', (tester) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Symbols.queue_music_rounded));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();

    expect(find.byType(QueuePanel), findsOneWidget);
  });

  testWidgets('next is forwarded to the host', (tester) async {
    final playback = await _pump(tester);

    await tester.tap(find.byIcon(Symbols.skip_next_rounded));
    await tester.pump();

    expect(playback.commands, contains('next'));
  });

  testWidgets('a station has no scrubber', (tester) async {
    await _pump(
      tester,
      state: const PlaybackState(
        queue: [
          // A station still starting up: the row has no run yet, so it is
          // what plays, and it has no length to scrub.
          LibrarySong(
            sourceId: 'a',
            id: 'radio-1',
            title: 'Late Night Radio',
            duration: Duration.zero,
            isRadio: true,
          ),
        ],
        currentIndex: 0,
      ),
    );

    expect(find.byType(Slider), findsNothing);
    expect(find.text('Late Night Radio'), findsOneWidget);
  });
}
