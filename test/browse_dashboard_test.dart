import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/browse.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An Apple Music account: it curates its own shelves and reports its size.
class _AccountSource extends LibrarySource {
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
  bool get usesPlatformPlayer => true;

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

Future<void> _pump(WidgetTester tester, _AccountSource source) async {
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
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const BrowseScreen(),
      ),
    ),
  );
  // The page waits on its reads before it shelves anything.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the landing page shows the account card and its own shelves', (
    tester,
  ) async {
    await _pump(
      tester,
      _AccountSource(
        const LibraryDigest(
          sourceId: 'apple-1',
          subtitle: 'Apple Music',
          libraryTracks: 604,
        ),
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
    );

    // The account's own numbers, and the shelf the provider curated.
    expect(find.text('browseAppleMusicDashboard'.tr()), findsOneWidget);
    expect(find.textContaining('604'), findsOneWidget);
    expect(find.text('Stations for you'), findsOneWidget);
    expect(find.text('Mirror Mirror Radio'), findsOneWidget);
    // The card names the count of stations the page is actually showing.
    expect(find.textContaining('1 station'), findsOneWidget);
  });

  testWidgets('a server library renders no account card', (tester) async {
    await _pump(tester, _AccountSource(null, const []));

    expect(find.text('browseAppleMusicDashboard'.tr()), findsNothing);
  });
}
