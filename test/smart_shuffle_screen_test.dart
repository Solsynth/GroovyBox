import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/smart_shuffle.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  final queues = <List<LibrarySong>>[];

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> playQueue(List<LibrarySong> songs, {int startIndex = 0}) async {
    queues.add(songs);
    state = state.copyWith(queue: songs, currentIndex: startIndex);
  }
}

void main() {
  testWidgets('smart shuffle plans from hearts and history', (tester) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);
    for (final entry in [
      ('Yellow', 'Coldplay', 'Parachutes', 'Rock'),
      ('Fix You', 'Coldplay', 'X&Y', 'Rock'),
      ('Clocks', 'Coldplay', 'A Rush of Blood', 'Rock'),
      ('La Vie en Rose', 'Édith Piaf', null, 'Chanson'),
    ]) {
      await catalog.adopt(
        LibrarySong(
          sourceId: 'a',
          id: entry.$1,
          title: entry.$1,
          artist: entry.$2,
          album: entry.$3,
          genre: entry.$4,
          duration: const Duration(seconds: 200),
        ),
      );
    }
    await catalog.setFavourite(
      LibrarySong(
        sourceId: 'a',
        id: 'Yellow',
        title: 'Yellow',
        artist: 'Coldplay',
        duration: const Duration(seconds: 200),
      ),
      value: true,
    );

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryDatabaseProvider.overrideWithValue(db),
          librarySourcesProvider.overrideWithValue(const []),
          playbackProvider.overrideWith(_Idle.new),
        ],
        child: MaterialApp.router(
          theme: createAppThemeSet().light,
          routerConfig: AppRouter().config(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Smart shuffle'));
    await tester.pumpAndSettle();

    expect(find.text('Smart shuffle'), findsWidgets);
    // The headline says how many tracks the mix drew.
    expect(find.textContaining('tracks from your hearts'), findsOneWidget);
    // The heart is in the mix and the genre shelf exists.
    expect(find.text('Yellow'), findsWidgets);
    expect(find.text('Rock'), findsOneWidget);

    // Play the whole mix: the transport receives the planned queue.
    await tester.tap(find.text('Play the mix'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('every mood bucket has a label in both catalogs', () {
    for (final catalog in ['en-US', 'zh-CN']) {
      final json = jsonDecode(
        File('assets/i18n/$catalog.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final mood in ShuffleMood.values) {
        final key =
            'shuffleMood${mood.name[0].toUpperCase()}${mood.name.substring(1)}';
        expect(json[key], isA<String>(), reason: '$catalog is missing $key');
      }
    }
  });
}
