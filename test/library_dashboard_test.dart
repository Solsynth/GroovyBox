import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/explore.dart';
import 'package:groovy_box/screens/settings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An Apple Music account: it curates its own shelves and reports its size.
class _AccountSource extends LibrarySource implements CuratedSource {
  _AccountSource(this.digestValue, this.shelves);

  final LibraryDigest? digestValue;
  final List<LandingShelf> shelves;

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
  Future<List<LandingShelf>> landingShelves() async => shelves;

  @override
  Future<LibraryDigest?> digest() async => digestValue;

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

Future<void> _pump(
  WidgetTester tester,
  _AccountSource source,
  Widget page,
) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([source]),
        playbackProvider.overrideWith(_IdlePlayback.new),
      ],
      child: MaterialApp(theme: createAppThemeSet().light, home: page),
    ),
  );
  // The page waits on its reads before it shows anything.
  await tester.pumpAndSettle();
}

void main() {
  // The account's numbers are a property of the connection, so they sit on the
  // row that manages it rather than above the shelves that page plays from.
  testWidgets('settings reports the account inside its library row', (
    tester,
  ) async {
    await _pump(
      tester,
      _AccountSource(
        const LibraryDigest(sourceId: 'apple-1', libraryTracks: 604),
        const [],
      ),
      const SettingsScreen(),
    );

    await tester.scrollUntilVisible(
      find.textContaining('604 tracks'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('604 tracks'), findsOneWidget);
    expect(find.textContaining('Signed in on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an account with nothing to report adds no line', (tester) async {
    await _pump(tester, _AccountSource(null, const []), const SettingsScreen());

    await tester.scrollUntilVisible(
      find.text('Add library'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Signed in on this device'), findsNothing);
  });

  testWidgets('the explore page keeps the account shelves, not its numbers', (
    tester,
  ) async {
    await _pump(
      tester,
      _AccountSource(
        const LibraryDigest(sourceId: 'apple-1', libraryTracks: 604),
        [
          LandingShelf(
            title: 'Stations for you',
            sourceId: 'apple-1',
            songs: [
              LibrarySong(
                sourceId: 'apple-1',
                id: 'ra.1',
                title: 'Mirror Mirror Radio',
                duration: Duration.zero,
                isRadio: true,
                radioUrl: 'https://music.apple.com/cn/station/x/ra.1',
                radioPlayParams: const {'id': 'ra.1', 'kind': 'radioStation'},
              ),
            ],
          ),
        ],
      ),
      const ExploreScreen(),
    );

    expect(find.text('Stations for you'), findsOneWidget);
    expect(find.text('Mirror Mirror Radio'), findsOneWidget);
    // No digest card: the landing page is for playing, the library row is for
    // the connection's own numbers.
    expect(find.textContaining('604'), findsNothing);
    expect(find.textContaining('libraryAccountLabel'.tr()), findsNothing);
  });
}
