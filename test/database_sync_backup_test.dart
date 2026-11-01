import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/backup.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/store.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryDatabase _openDb() {
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LibraryDatabase export and import', () {
    test('exports and imports clean round-trip on empty destination database', () async {
      final dbA = _openDb();
      final catalogA = LibraryCatalog(dbA);
      final lyricsA = LyricsStore(dbA);

      final trackId1 = await catalogA.adopt(
        const LibrarySong(
          sourceId: 'subsonic-1',
          id: 'song-1',
          title: 'Yesterday',
          artist: 'The Beatles',
          album: 'Help!',
          duration: Duration(seconds: 125),
        ),
      );

      await catalogA.adopt(
        const LibrarySong(
          sourceId: 'subsonic-1',
          id: 'song-2',
          title: 'Hey Jude',
          artist: 'The Beatles',
          duration: Duration(seconds: 431),
        ),
      );

      await lyricsA.write(
        trackId1,
        const Lyrics(
          lines: [
            LyricLine(Duration(seconds: 5), 'Yesterday...'),
          ],
          synced: true,
          language: 'en',
        ),
        origin: LyricsOrigin.lrclib,
      );

      await catalogA.recordPlay(
        trackId: trackId1,
        sourceId: 'subsonic-1',
        startedAt: DateTime.utc(2026, 11, 1, 10, 0),
        listened: const Duration(seconds: 120),
        position: const Duration(seconds: 120),
        completed: true,
      );

      // Export from A
      final exported = await dbA.exportData();
      expect(exported['tracks'], hasLength(2));
      expect(exported['links'], hasLength(2));
      expect(exported['lyrics'], hasLength(1));
      expect(exported['plays'], hasLength(1));

      // Import into B
      final dbB = _openDb();
      final lyricsB = LyricsStore(dbB);
      final result = await dbB.importData(exported);

      expect(result.tracks, 2);
      expect(result.links, 2);
      expect(result.lyrics, 1);
      expect(result.plays, 1);

      expect(await dbB.trackCount(), 2);

      final destTrack1 = await dbB.trackIdForLink('subsonic-1', 'song-1');
      expect(destTrack1, isNotNull);

      final cachedLyrics = await lyricsB.read(destTrack1!);
      expect(cachedLyrics, isNotNull);
      expect(cachedLyrics!.lyrics.lines.first.text, 'Yesterday...');
      expect(cachedLyrics.origin, LyricsOrigin.lrclib);

      expect(await dbB.playCountOf(destTrack1), 1);
    });

    test('importing into destination with existing tracks matches fingerprint and avoids duplicates', () async {
      final dbA = _openDb();
      final catalogA = LibraryCatalog(dbA);
      final lyricsA = LyricsStore(dbA);

      final trackA = await catalogA.adopt(
        const LibrarySong(
          sourceId: 'source-A',
          id: 'ext-1',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          duration: Duration(seconds: 354),
        ),
      );

      await lyricsA.write(
        trackA,
        const Lyrics(
          lines: [LyricLine(Duration.zero, 'Is this the real life?')],
          synced: true,
        ),
        origin: LyricsOrigin.lrclib,
      );

      final exported = await dbA.exportData();

      // Destination B already has the same song from a different source (source-B)
      final dbB = _openDb();
      final catalogB = LibraryCatalog(dbB);
      final lyricsB = LyricsStore(dbB);

      final trackB = await catalogB.adopt(
        const LibrarySong(
          sourceId: 'source-B',
          id: 'jellyfin-99',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          duration: Duration(seconds: 354),
        ),
      );

      // Import export from A into B
      final result = await dbB.importData(exported);
      expect(result.tracks, 0); // Matched existing track, no new track inserted
      expect(result.links, 1); // Source-A link added
      expect(result.lyrics, 1); // Lyrics attached to matched track

      // Total canonical tracks should still be 1!
      expect(await dbB.trackCount(), 1);

      // Links of trackB should now contain both source-B and source-A!
      final links = await dbB.linksOf(trackB);
      expect(links, hasLength(2));
      expect(links.map((l) => l.sourceId), containsAll(['source-A', 'source-B']));

      // Lyrics are accessible on trackB
      final words = await lyricsB.read(trackB);
      expect(words?.lyrics.lines.first.text, 'Is this the real life?');
    });

    test('importing replaces miss lyrics with real lyrics and ignores duplicate plays', () async {
      final dbA = _openDb();
      final catalogA = LibraryCatalog(dbA);
      final lyricsA = LyricsStore(dbA);

      const song = LibrarySong(
        sourceId: 's1',
        id: '1',
        title: 'Song X',
        artist: 'Artist Y',
        duration: Duration(seconds: 200),
      );

      final trackA = await catalogA.adopt(song);
      await lyricsA.write(
        trackA,
        Lyrics.empty,
        origin: LyricsOrigin.none,
      );

      final playTime = DateTime.utc(2026, 11, 1, 12, 0);
      await catalogA.recordPlay(
        trackId: trackA,
        sourceId: 's1',
        startedAt: playTime,
        listened: const Duration(seconds: 200),
        position: const Duration(seconds: 200),
        completed: true,
      );

      // DB B has real lyrics for the same song
      final dbB = _openDb();
      final catalogB = LibraryCatalog(dbB);
      final lyricsB = LyricsStore(dbB);

      final trackB = await catalogB.adopt(song);
      await lyricsB.write(
        trackB,
        const Lyrics(
          lines: [LyricLine(Duration.zero, 'Real lyrics')],
          synced: false,
        ),
        origin: LyricsOrigin.library,
      );
      await catalogB.recordPlay(
        trackId: trackB,
        sourceId: 's1',
        startedAt: playTime,
        listened: const Duration(seconds: 200),
        position: const Duration(seconds: 200),
        completed: true,
      );

      final exportedB = await dbB.exportData();

      // Import B into A
      await dbA.importData(exportedB);

      // Track A's lyrics should now be 'Real lyrics'
      final updated = await lyricsA.read(trackA);
      expect(updated?.origin, LyricsOrigin.library);
      expect(updated?.lyrics.lines.first.text, 'Real lyrics');

      // Duplicate play at playTime was not added again
      expect(await dbA.playCountOf(trackA), 1);
    });
  });

  group('SourceStore mergeSources', () {
    test('merges new sources and updates modified ones', () async {
      SharedPreferences.setMockInitialValues({
        'app_sources': jsonEncode([
          {
            'id': 's1',
            'kind': 'subsonic',
            'baseUrl': 'https://music1.test',
            'displayName': 'Music 1',
            'auth': {'username': 'user1', 'token': 't1', 'salt': 's1'},
          },
        ]),
      });

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(sourceStoreProvider.notifier);
      expect(notifier.state, hasLength(1));

      final incoming = [
        const SourceConfig(
          id: 's1',
          kind: LibraryKind.subsonic,
          baseUrl: 'https://music1.test',
          displayName: 'Updated Music 1',
          auth: {'username': 'user1', 'token': 'new_t1', 'salt': 's1'},
        ),
        const SourceConfig(
          id: 's2',
          kind: LibraryKind.jellyfin,
          baseUrl: 'https://jellyfin.test',
          displayName: 'Jellyfin Server',
          auth: {'userId': 'u2', 'accessToken': 'tok2'},
        ),
      ];

      final count = await notifier.mergeSources(incoming);
      expect(count, 2);

      final current = notifier.state;
      expect(current, hasLength(2));
      expect(current.firstWhere((s) => s.id == 's1').displayName, 'Updated Music 1');
      expect(current.firstWhere((s) => s.id == 's2').displayName, 'Jellyfin Server');
    });
  });

  group('BackupService roundtrip', () {
    test('creates, inspects, and restores complete backup bundle', () async {
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': 'dark',
        'app_glass_effects': false,
        'app_lyrics_pronunciation': true,
        'app_lyrics_translation': true,
        'app_infinite_playback': true,
        'app_volume': 80.0,
        'app_sources': jsonEncode([
          {
            'id': 'srv1',
            'kind': 'subsonic',
            'baseUrl': 'https://srv.test',
            'displayName': 'Server',
            'auth': {'username': 'u', 'token': 't', 'salt': 's'},
          },
        ]),
      });

      final prefs = await SharedPreferences.getInstance();
      final dbA = _openDb();
      final catalogA = LibraryCatalog(dbA);
      final trackId = await catalogA.adopt(
        const LibrarySong(
          sourceId: 'srv1',
          id: 'track-101',
          title: 'Sync Song',
          artist: 'Sync Artist',
          duration: Duration(seconds: 180),
        ),
      );
      final lyricsStoreA = LyricsStore(dbA);
      await lyricsStoreA.write(
        trackId,
        const Lyrics(
          lines: [LyricLine(Duration.zero, 'Synced words')],
          synced: true,
        ),
        origin: LyricsOrigin.library,
      );

      final containerA = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryDatabaseProvider.overrideWithValue(dbA),
        ],
      );

      final backupData = await containerA.read(backupServiceProvider).createBackupData();
      expect(backupData['version'], 1);
      expect(backupData['app'], 'GroovyBox');
      expect(backupData['sources'], hasLength(1));
      expect(backupData['settings']['themeMode'], 'dark');
      expect(backupData['settings']['glassEffects'], false);
      expect(backupData['settings']['volume'], 80.0);

      final summary = BackupService.inspectBackup(backupData);
      expect(summary, isNotNull);
      expect(summary!.sourcesCount, 1);
      expect(summary.tracksCount, 1);
      expect(summary.lyricsCount, 1);

      // Destination device with clean prefs & clean DB
      SharedPreferences.setMockInitialValues({});
      final destPrefs = await SharedPreferences.getInstance();
      final dbB = _openDb();

      final containerB = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(destPrefs),
          libraryDatabaseProvider.overrideWithValue(dbB),
        ],
      );

      final restoreResult = await containerB.read(backupServiceProvider).restoreBackup(backupData);
      expect(restoreResult.sourcesImported, 1);
      expect(restoreResult.tracksImported, 1);
      expect(restoreResult.lyricsImported, 1);

      // Verify destination settings
      expect(containerB.read(themeModeProvider), AppThemeMode.dark);
      expect(containerB.read(glassEffectsEnabledProvider), false);
      expect(destPrefs.getDouble('app_volume'), 80.0);

      // Verify destination sources
      final destSources = containerB.read(sourceStoreProvider);
      expect(destSources, hasLength(1));
      expect(destSources.first.id, 'srv1');

      // Verify destination database
      expect(await dbB.trackCount(), 1);
      final importedTrack = await dbB.trackIdForLink('srv1', 'track-101');
      expect(importedTrack, isNotNull);
      final destLyricsStore = LyricsStore(dbB);
      final importedLyrics = await destLyricsStore.read(importedTrack!);
      expect(importedLyrics?.lyrics.lines.first.text, 'Synced words');
    });
  });
}
