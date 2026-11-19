import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/downloads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

void main() {
  testWidgets('the downloads page lists what is kept and what it costs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Synchronous on purpose: a widget test runs in fake async, and awaiting
    // real file IO there never completes.
    final directory = Directory.systemTemp.createTempSync('groovybox-page');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    await db.upsertDownload(
      DownloadsCompanion.insert(
        sourceId: 'home',
        externalId: 's1',
        path: 'yellow.mp3',
        sizeBytes: 3 * 1024 * 1024,
        title: 'Yellow',
        artist: const Value('Coldplay'),
        durationMs: const Value(266000),
        downloadedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryDatabaseProvider.overrideWithValue(db),
          librarySourcesProvider.overrideWithValue(const []),
          downloadDirectoryProvider.overrideWithValue(directory.path),
          playbackProvider.overrideWith(_Idle.new),
        ],
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: const DownloadsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Downloads'), findsWidgets);
    expect(find.text('Yellow'), findsOneWidget);
    // Twice: the header's total and the row's own size, which is the point.
    expect(find.textContaining('3.0 MB'), findsNWidgets(2));
    expect(find.textContaining('Coldplay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty page says so instead of showing nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryDatabaseProvider.overrideWithValue(db),
          librarySourcesProvider.overrideWithValue(const []),
          playbackProvider.overrideWith(_Idle.new),
        ],
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: const DownloadsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing downloaded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
