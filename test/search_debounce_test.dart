import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/search.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One server, so the page is not in its "nothing to search" state.
class _Server extends LibrarySource {
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

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// Records every query the page actually asks the libraries for.
final _asked = <String>[];

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  _asked.clear();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playbackProvider.overrideWith(_Idle.new),
        librarySourcesProvider.overrideWithValue([_Server()]),
        searchSongsProvider.overrideWith((ref, query) async {
          if (query.trim().isEmpty) return const <LibrarySong>[];
          _asked.add(query);
          return const <LibrarySong>[];
        }),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const SearchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing asks the library once, after the typist pauses', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(SearchBar), 'sun');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(SearchBar), 'sunset over');
    await tester.pump();

    // Nothing yet: the field is still being typed into.
    expect(_asked, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      _asked,
      ['sunset over'],
      reason: 'one request for the word, not one per keystroke',
    );
  });

  testWidgets('clearing the field drops the results at once', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(SearchBar), 'sunset');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.text('Nothing in your libraries matches “sunset”.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(
      find.text('Nothing in your libraries matches “sunset”.'),
      findsNothing,
    );
  });
}
