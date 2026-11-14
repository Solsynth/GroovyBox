import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/player_screen.dart';
import 'package:groovy_box/shell/dock_morph.dart';
import 'package:groovy_box/widgets/now_playing_dock.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake extends LibrarySource {
  _Fake(this.id);
  @override
  final String id;
  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Home library',
  );
  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;
  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakePlayback extends Playback {
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
    position: Duration(seconds: 97),
  );
}

ProviderScope _scope(Widget child, SharedPreferences prefs) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    librarySourcesProvider.overrideWithValue([_Fake('a')]),
    playbackProvider.overrideWith(_FakePlayback.new),
  ],
  child: child,
);

void main() {
  testWidgets('tapping the dock body opens the player from the capsule rect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    DockMorphOrigin.clear();

    final router = AppRouter();
    await tester.pumpWidget(
      _scope(
        MaterialApp.router(
          theme: createAppThemeSet().light,
          routerConfig: router.config(),
        ),
        prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NowPlayingDock), findsOneWidget);

    // Tap the capsule's own padding, not a control inside it: the whole
    // surface is the way in.
    final capsule = find
        .descendant(
          of: find.byType(NowPlayingDock),
          matching: find.byType(PillSurface),
        )
        .first;
    expect(capsule, findsOneWidget);

    await tester.tapAt(tester.getTopLeft(capsule) + const Offset(300, 8));
    await tester.pump();

    // The tap must record where the capsule was before the player builds.
    expect(DockMorphOrigin.rect, isNotNull, reason: 'dock captured its rect');
    // The capsule's own box: content height plus its vertical padding.
    expect(
      DockMorphOrigin.rect!.height,
      closeTo(kNowPlayingDockHeight + SolSpace.sm * 2, 1),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('the transport buttons do not open the player', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    DockMorphOrigin.clear();

    final router = AppRouter();
    await tester.pumpWidget(
      _scope(
        MaterialApp.router(
          theme: createAppThemeSet().light,
          routerConfig: router.config(),
        ),
        prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(
      find.descendant(
        of: find.byType(NowPlayingDock),
        matching: find.byIcon(Symbols.skip_next_rounded),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(DockMorphOrigin.rect, isNull);
    expect(find.byType(PlayerScreen), findsNothing);
  });

  testWidgets('a push without a dock capture still opens the player', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    DockMorphOrigin.clear();

    final router = AppRouter();
    await tester.pumpWidget(
      _scope(
        MaterialApp.router(
          theme: createAppThemeSet().light,
          routerConfig: router.config(),
        ),
        prefs,
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(NowPlayingDock));
    context.router.push(const PlayerRoute());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
  });
}
