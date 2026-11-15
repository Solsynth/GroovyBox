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

  for (final size in const [
    // Body sizes, i.e. window minus the frame's 32px title band.
    Size(340, kMiniPlayerBarContentHeight),
    Size(300, kMiniPlayerBarContentHeight),
    Size(480, 228),
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

  testWidgets('an open pane sits between the header and the transport', (
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
            (ref, song, {languageCode}) async => const Lyrics(
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
    // The pane starts below the header and ends above the scrubber: anything
    // else draws lyric lines behind the transport, which is the overlap this
    // test exists to catch.
    expect(pane.top, greaterThanOrEqualTo(header.bottom));
    expect(pane.bottom, lessThanOrEqualTo(scrubber.top));
  });
}
