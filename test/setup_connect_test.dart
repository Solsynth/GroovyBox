import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/http_cache.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/explore.dart';
import 'package:groovy_box/screens/setup.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connects without a network: the page's job is to store the config, say so
class _FakeSubsonic implements LibraryAdapter {
  @override
  LibraryKind get kind => LibraryKind.subsonic;

  @override
  bool get isAvailable => true;

  @override
  bool get needsCredentials => true;

  @override
  Future<SourceConfig> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) async => SourceConfig(
    id: 'subsonic-test',
    kind: LibraryKind.subsonic,
    baseUrl: baseUrl,
    displayName: 'Home library',
    auth: {'username': username, 'token': 't', 'salt': 's'},
  );

  @override
  LibrarySource sourceFor(SourceConfig config, {ResponseCache? cache}) =>
      throw UnimplementedError();
}

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue(const []),
        libraryDatabaseProvider.overrideWithValue(null),
        playbackProvider.overrideWith(_IdlePlayback.new),
      ],
      child: MaterialApp.router(
        theme: createAppThemeSet().light,
        routerConfig: AppRouter().config(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late LibraryAdapter original;

  setUp(() {
    original = libraryAdapters[LibraryKind.subsonic]!;
    libraryAdapters[LibraryKind.subsonic] = _FakeSubsonic();
  });
  tearDown(() => libraryAdapters[LibraryKind.subsonic] = original);

  // The page used to keep its spinner up through the pop, so `PopScope` — which
  // refuses to leave while a connect is in flight — swallowed it: the library
  // was stored and the form simply sat there, said nothing, and invited a
  // second "Connect" that would have added it twice.
  testWidgets('connecting says so and returns to the page that asked', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Connect a library').first);
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'https://music.example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'someone');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret');
    await tester.tap(find.text('Connect'));
    // The store write crosses a platform channel, which only resolves outside
    // the fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.text('Connected Home library.'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExploreScreen)),
    );
    expect(container.read(sourceStoreProvider), hasLength(1));
  });
}
