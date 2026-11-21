import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/snapshot_cache.dart';
import 'package:groovy_box/library/source.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A library whose answer a test decides, and whose delay it decides too.
///
/// The delay is what makes "the page was drawn before the network answered"
/// observable: the album list is served instantly from the snapshot while the
/// source is still thinking.
class _Source extends LibrarySource {
  _Source(this.name, {this.delay = Duration.zero});

  final String name;
  Duration delay;

  /// Flipped to make the next read fail, which is the offline case.
  bool failing = false;

  @override
  final String id = 'home';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'home',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://home.example.com',
    displayName: 'Home',
  );

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failing) throw const LibraryException('server is down');
    return [
      LibraryAlbum(
        sourceId: id,
        id: 'album-$name',
        name: name,
        duration: const Duration(minutes: 40),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A container over one in-memory database and one source.
Future<ProviderContainer> _container(_Source source, LibraryDatabase db) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      libraryDatabaseProvider.overrideWithValue(db),
      librarySourcesProvider.overrideWithValue([source]),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a stored answer is drawn before the network answers', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // The first run: nothing stored, the source answers, the answer is kept.
    final first = await _container(_Source('Yesterday'), db);
    expect(
      (await first.read(recentAlbumsProvider.future)).single.name,
      'Yesterday',
    );
    expect((await first.read(snapshotCacheProvider)!.totals()).count, 1);

    // The next launch: the shelf is served from disk while the source is
    // still being asked — no spinner, and the same rows.
    final second = await _container(
      _Source('Today', delay: const Duration(milliseconds: 50)),
      db,
    );
    final drawn = await second.read(recentAlbumsProvider.future);
    expect(drawn.single.name, 'Yesterday');

    // The refresh lands afterwards and replaces the page with the new answer.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      second.read(recentAlbumsProvider).value!.single.name,
      'Today',
    );
    // And the stored copy follows, so the next launch draws the new page.
    expect(
      (await second.read(snapshotCacheProvider)!.totals()).count,
      1,
      reason: 'one shelf is one row, replaced rather than appended',
    );
    expect(
      (await second.read(snapshotCacheProvider)!.read(
        SnapshotKeys.recentAlbums,
      ))!.contains('Today'),
      isTrue,
    );
    await second.read(recentAlbumsProvider.future);
  });

  test('a failed refresh keeps showing the stored answer', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final first = await _container(_Source('Yesterday'), db);
    await first.read(recentAlbumsProvider.future);

    // A launch where the library is gone: the page must not turn into an
    // error screen over music the user can still browse.
    final offline = await _container(
      _Source('Today')..failing = true,
      db,
    );
    final drawn = await offline.read(recentAlbumsProvider.future);
    expect(drawn.single.name, 'Yesterday');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(offline.read(recentAlbumsProvider).value!.single.name, 'Yesterday');
    expect(offline.read(recentAlbumsProvider).hasError, isFalse);

    // The source's failure is still reported, so Settings can say why.
    expect(offline.read(sourceFailuresProvider).keys, ['home']);
  });

  test('an explicit refresh asks the network instead of the snapshot', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final first = await _container(_Source('Yesterday'), db);
    await first.read(recentAlbumsProvider.future);

    final second = await _container(_Source('Today'), db);
    // Read once to load the snapshot, then refresh: the refresh is the user
    // asking for the answer, and it must not be answered from disk.
    await second.read(recentAlbumsProvider.future);
    await second.read(recentAlbumsProvider.notifier).refresh();
    expect(second.read(recentAlbumsProvider).value!.single.name, 'Today');
  });

  test('a tracklist survives as a snapshot and is restored in order', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cache = SnapshotCache(db);
    const key = 'playlistSongs:home:p1';
    const songs = [
      LibrarySong(
        sourceId: 'home',
        id: 'one',
        title: 'First',
        artist: 'An artist',
        album: 'A record',
        duration: Duration(minutes: 3),
      ),
      LibrarySong(
        sourceId: 'home',
        id: 'two',
        title: 'Second',
        duration: Duration(minutes: 4),
      ),
    ];

    await cache.storeSongs(key, songs);
    final restored = await SnapshotCache(
      db,
    ).restoreList(key, LibrarySong.fromJson);

    expect([for (final song in restored!) song.id], ['one', 'two']);
    expect(restored.first.artist, 'An artist');
    expect(restored.first.album, 'A record');
    expect(restored.first.duration, const Duration(minutes: 3));
    expect(restored.last.artist, isNull, reason: 'absent stays absent');
  });

  test('an unreadable row is treated as no row', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // A row written by an older build whose model changed shape.
    await db.putLibrarySnapshot(
      LibrarySnapshotRow(
        key: 'recentAlbums',
        body: '{"not":"a list"}',
        storedAt: DateTime.now(),
      ),
    );
    expect(await SnapshotCache(db).restoreList('recentAlbums', (json) {
      throw const FormatException('older shape');
    }), isNull);
  });

  test('pruning forgets only what was last written too long ago', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final old = DateTime.now().subtract(const Duration(days: 60));
    await db.putLibrarySnapshot(
      LibrarySnapshotRow(key: 'stale', body: '[]', storedAt: old),
    );
    await db.putLibrarySnapshot(
      LibrarySnapshotRow(
        key: 'fresh',
        body: '[]',
        storedAt: DateTime.now(),
      ),
    );

    expect(await db.pruneLibrarySnapshots(DateTime.now().subtract(
      const Duration(days: 30),
    )), 1);
    expect(await db.librarySnapshot('stale'), isNull);
    expect(await db.librarySnapshot('fresh'), isNotNull);
  });
}
