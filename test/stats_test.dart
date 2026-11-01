import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/stats.dart';
import 'package:groovy_box/widgets/format.dart';
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
    baseUrl: 'https://$id',
    displayName: 'Alpha',
  );
  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;
  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://$id/${song.id}');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

LibrarySong _song(String id, String title, {String? artist}) => LibrarySong(
  sourceId: 'a',
  id: id,
  title: title,
  artist: artist,
  duration: const Duration(minutes: 3),
);

/// Yellow played three times (two of them to the end) and Fix You once, which
/// is the shape every aggregate on the page has to get right: a repeat count,
/// a completion count, a distinct-track count and a most-recent order.
Future<LibraryCatalog> _seed(LibraryDatabase db) async {
  final catalog = LibraryCatalog(db);
  final yellow = await catalog.adopt(
    _song('s1', 'Yellow', artist: 'Coldplay'),
  );
  final fixYou = await catalog.adopt(
    _song('s2', 'Fix You', artist: 'Coldplay'),
  );
  for (var i = 0; i < 2; i++) {
    final play = await catalog.recordPlay(
      trackId: yellow,
      sourceId: 'a',
      startedAt: DateTime.now().subtract(Duration(days: i + 1)),
    );
    await catalog.updatePlay(
      play,
      listened: const Duration(minutes: 3),
      position: const Duration(minutes: 3),
      completed: true,
    );
  }
  await catalog.recordPlay(
    trackId: yellow,
    sourceId: 'a',
    startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
  await catalog.recordPlay(
    trackId: fixYou,
    sourceId: 'a',
    startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
  );
  return catalog;
}

Future<void> _pumpScreen(WidgetTester tester, LibraryDatabase db) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Fake('a')]),
        libraryDatabaseProvider.overrideWithValue(db),
        playbackProvider.overrideWith(_Idle.new),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const Scaffold(body: StatsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the history aggregates into plays, completion and rankings', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = await _seed(db);

    final stats = await catalog.listeningStats();

    expect(stats.plays, 4);
    expect(stats.completedPlays, 2);
    expect(stats.distinctTracks, 2, reason: 'Yellow three times is one song');
    expect(stats.listened, const Duration(minutes: 6));
    expect(stats.libraryTracks, 2);
    expect(stats.orphaned, 0);

    expect(stats.topTracks.first.track.title, 'Yellow');
    expect(stats.topTracks.first.plays, 3);
    expect(stats.topTracks.first.song?.id, 's1');

    expect(stats.topArtists.single.name, 'Coldplay');
    expect(stats.topArtists.single.plays, 4);

    expect(stats.recent.first.track.title, 'Fix You');
    expect(stats.recent.last.track.title, 'Yellow');
  });

  test('a song only a removed source had is kept, but not playable', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);
    final id = await catalog.adopt(_song('s1', 'Gone', artist: 'Nobody'));
    await catalog.recordPlay(
      trackId: id,
      sourceId: 'a',
      startedAt: DateTime.now(),
    );

    await catalog.forgetSource('a');
    final stats = await catalog.listeningStats();

    expect(stats.recent.single.track.title, 'Gone');
    expect(stats.recent.single.song, isNull, reason: 'nowhere to stream it');
    expect(stats.orphaned, 1);
  });

  testWidgets('the page shows what the history says', (tester) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);

    await _pumpScreen(tester, db);

    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('plays'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('songs'), findsOneWidget);
    expect(find.textContaining('3 plays'), findsOneWidget);
    expect(find.text('MOST PLAYED'), findsOneWidget);
    expect(find.text('RECENTLY PLAYED'), findsOneWidget);
    expect(find.text('Yellow'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty history says so instead of showing zeroes', (
    tester,
  ) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _pumpScreen(tester, db);

    expect(find.text('Nothing to count yet'), findsOneWidget);
    expect(find.text('MOST PLAYED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shell carries Stats where the queue tab used to be', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryDatabaseProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_Idle.new),
        ],
        child: MaterialApp.router(
          theme: createAppThemeSet().light,
          routerConfig: AppRouter().config(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The queue is the player's pane now, so its tab is gone and the fourth
    // slot belongs to the history.
    expect(find.byIcon(Symbols.queue_music), findsNothing);
    await tester.tap(find.byIcon(Symbols.query_stats));
    await tester.pumpAndSettle();

    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Yellow'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('formatting', () {
    test('listening time reads in the unit people say it in', () {
      expect(formatListeningTime(Duration.zero), 'Nothing yet');
      expect(formatListeningTime(const Duration(seconds: 30)), 'Under a minute');
      expect(formatListeningTime(const Duration(minutes: 12)), '12 min');
      expect(
        formatListeningTime(const Duration(hours: 3, minutes: 12)),
        '3 h 12 min',
      );
      expect(formatListeningTime(const Duration(hours: 3)), '3 h');
      expect(
        formatListeningTime(const Duration(days: 2, hours: 4)),
        '2 d 4 h',
      );
    });

    test('relative time counts calendar days, not 24-hour spans', () {
      final now = DateTime(2026, 3, 10, 1);
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 20)), now: now),
        'Just now',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 20)), now: now),
        '20 min ago',
      );
      // Two hours apart, but a different calendar day: "yesterday" is what a
      // reader would say, and what the play history is read at.
      expect(
        formatRelativeTime(DateTime(2026, 3, 9, 23), now: now),
        'Yesterday',
      );
      // Same calendar day, hours earlier.
      expect(formatRelativeTime(DateTime(2026, 3, 10, 0), now: now), 'Today');
      expect(formatRelativeTime(DateTime(2026, 3, 6), now: now), '4 days ago');
      expect(
        formatRelativeTime(DateTime(2025, 12, 1), now: now),
        '3 months ago',
      );
    });
  });
}
