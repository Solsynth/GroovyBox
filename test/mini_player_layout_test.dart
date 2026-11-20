import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/desktop/mini_player/mini_playback.dart';
import 'package:groovy_box/desktop/mini_player/mini_player_app.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovy_box/library/lyrics.dart';

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

class _Mini extends MiniPlayback {
  @override
  PlaybackState build() => const PlaybackState(
    queue: [
      LibrarySong(
        sourceId: 'a',
        id: 's1',
        title: 'Wah Wah World',
        artist: 'Giga, Mitchie M feat. 初音ミク & 鏡音リン',
        duration: Duration(seconds: 208),
      ),
    ],
    currentIndex: 0,
    duration: Duration(seconds: 208),
    position: Duration(seconds: 32),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async => null);
  });

  for (final size in [
    // Both shapes at their opening heights. The view is the whole window: the
    // frame's title band is drawn over it, not above it, so nothing is
    // subtracted here.
    Size(340, kMiniPlayerBarHeight),
    Size(300, kMiniPlayerBarHeight),
    Size(480, kMiniPlayerBarHeight + kMiniPlayerPaneMinHeight),
    Size(340, 458),
  ]) {
    testWidgets('no overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            librarySourcesProvider.overrideWithValue([_Source()]),
            libraryDatabaseProvider.overrideWithValue(null),
            playbackProvider.overrideWith(_Mini.new),
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
                      ? const SizedBox()
                      : MiniPlayerView(song: song);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the pane footer slides away when idle and returns on hover', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 490);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    miniPlayerPane.value = MiniPane.queue;
    addTearDown(() => miniPlayerPane.value = null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          librarySourcesProvider.overrideWithValue([_Source()]),
          libraryDatabaseProvider.overrideWithValue(null),
          playbackProvider.overrideWith(_Mini.new),
        ],
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final song = ProviderScope.containerOf(
                  context,
                ).read(playbackProvider).current!;
                return MiniPlayerView(song: song);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The footer is the only fading row in the view.
    double footerOpacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    // Just opened: the controls are there.
    expect(footerOpacity(), 1);

    // Idle past the hide delay: the footer is transparent (and untouchable).
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();
    expect(footerOpacity(), 0);

    // A hover brings it straight back.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(QueuePanel)));
    await tester.pump();
    await gesture.moveBy(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(footerOpacity(), 1);
    await gesture.removePointer();
  });

  testWidgets('a pane runs under the floating footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 490);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    miniPlayerPane.value = MiniPane.lyrics;
    addTearDown(() => miniPlayerPane.value = null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          librarySourcesProvider.overrideWithValue([_Source()]),
          libraryDatabaseProvider.overrideWithValue(null),
          playbackProvider.overrideWith(_Mini.new),
          songLyricsProvider.overrideWith(
            (ref, song) async => const Lyrics(
              lines: [LyricLine(Duration(seconds: 1), 'first line')],
              synced: true,
            ),
          ),
        ],
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final song = ProviderScope.containerOf(
                  context,
                ).read(playbackProvider).current;
                return song == null
                    ? const SizedBox()
                    : MiniPlayerView(song: song);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pane = tester.getRect(find.byType(SongLyricsPane));
    final scrubber = tester.getRect(find.byType(Slider));
    final header = tester.getRect(find.text('Wah Wah World'));

    expect(tester.takeException(), isNull);
    // The pane starts below the header and runs to the bottom: the footer is
    // an overlay that slides away, so it must not steal a strip of the pane's
    // height. A pane that stopped above the scrubber would be the reserved
    // strip this layout exists to avoid.
    expect(pane.top, greaterThanOrEqualTo(header.bottom));
    expect(pane.bottom, closeTo(490, 0.5));
    // …and the footer floats inside that area, below the words.
    expect(scrubber.top, greaterThan(pane.top));
    expect(scrubber.bottom, lessThanOrEqualTo(pane.bottom));
    // The words keep the page's gutter rather than hugging the edge.
    expect(
      tester.getRect(find.text('first line')).left,
      greaterThanOrEqualTo(SolSpace.xl),
    );
  });
}
