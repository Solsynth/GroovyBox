import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/now_playing_dock.dart';
import 'package:groovy_box/widgets/queue_sheet.dart';
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
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Playback extends Playback {
  @override
  PlaybackState build() => const PlaybackState(
    queue: [
      LibrarySong(
        sourceId: 'a',
        id: 's1',
        title: 'Sunset Overdrive',
        duration: Duration(seconds: 254),
      ),
      LibrarySong(
        sourceId: 'a',
        id: 's2',
        title: 'Tender Is the Night',
        duration: Duration(seconds: 198),
      ),
    ],
    currentIndex: 0,
    duration: Duration(seconds: 254),
    position: Duration(seconds: 97),
  );

  /// The queue runs out: nothing is current any more.
  void finishQueue() => state = const PlaybackState();
}

/// The capsule's collapsed height: the transport row plus the glass's own
/// vertical padding.
const _capsuleHeight = kNowPlayingDockHeight + SolSpace.sm * 2;

Future<_Playback> _pumpDock(WidgetTester tester) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final playback = _Playback();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Source()]),
        playbackProvider.overrideWith(() => playback),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NowPlayingDock(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return playback;
}

Finder _capsule() => find.descendant(
  of: find.byType(NowPlayingDock),
  matching: find.byType(GlassSurface),
);

void main() {
  testWidgets('a sheet folds back into the transport instead of vanishing', (
    tester,
  ) async {
    await _pumpDock(tester);

    await tester.tap(find.byTooltip('Show queue'));
    await tester.pumpAndSettle();
    final open = tester.getSize(_capsule()).height;
    expect(open, greaterThan(_capsuleHeight));

    await tester.tap(find.byTooltip('Hide queue'));
    // The first frame after the tap only starts the fall's clock; a beat
    // later the panel is still on screen, part-way down.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(QueueSheet), findsOneWidget);
    final folding = tester.getSize(_capsule()).height;
    expect(folding, lessThan(open));
    expect(folding, greaterThan(_capsuleHeight));

    await tester.pumpAndSettle();
    expect(find.byType(QueueSheet), findsNothing);
    expect(tester.getSize(_capsule()).height, closeTo(_capsuleHeight, 1));
  });

  testWidgets('the dock folds away when the music stops instead of vanishing', (
    tester,
  ) async {
    final playback = await _pumpDock(tester);
    final dock = find.byType(NowPlayingDock);
    expect(tester.getSize(dock).height, closeTo(_capsuleHeight, 1));

    playback.finishQueue();
    // The first frame only starts the fold's clock; a beat later the
    // capsule is still on screen, part-way down.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_capsule(), findsOneWidget);
    final folding = tester.getSize(dock).height;
    expect(folding, lessThan(_capsuleHeight));
    expect(folding, greaterThan(0));

    await tester.pumpAndSettle();
    expect(_capsule(), findsNothing);
    expect(tester.getSize(dock).height, 0);
  });

  testWidgets('a dock with no song rises into view when one starts', (
    tester,
  ) async {
    final playback = await _pumpDock(tester);

    playback.finishQueue();
    await tester.pumpAndSettle();
    final dock = find.byType(NowPlayingDock);
    expect(tester.getSize(dock).height, 0);

    playback.state = const PlaybackState(
      queue: [
        LibrarySong(
          sourceId: 'a',
          id: 's3',
          title: 'After the Rain',
          duration: Duration(seconds: 210),
        ),
      ],
      currentIndex: 0,
      duration: Duration(seconds: 210),
    );
    // The first frame only starts the rise's clock; a beat later the
    // capsule is already on screen, on its way up.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final rising = tester.getSize(dock).height;
    expect(rising, greaterThan(0));
    expect(rising, lessThan(_capsuleHeight));

    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(_capsuleHeight, 1));
    expect(find.text('After the Rain'), findsOneWidget);
  });
}
