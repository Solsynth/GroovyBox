import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/play_tracker.dart';

({LibraryDatabase db, LibraryCatalog catalog, PlayTracker tracker}) _open({
  bool withDatabase = true,
}) {
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = LibraryCatalog(db);
  return (
    db: db,
    catalog: catalog,
    tracker: PlayTracker(withDatabase ? catalog : null),
  );
}

const _song = LibrarySong(
  sourceId: 'a',
  id: 's1',
  title: 'Yellow',
  artist: 'Coldplay',
  duration: Duration(seconds: 266),
);

void main() {
  test('starting a track opens one play row for its song', () async {
    final (:db, :catalog, :tracker) = _open();

    await tracker.start(_song);

    final trackId = (await db.trackIdForLink('a', 's1'))!;
    expect(await catalog.statsOf(trackId), isA<PlayStats>());
    final row = await db.select(db.playEvents).getSingle();
    expect(row.trackId, trackId);
    expect(row.sourceId, 'a');
    expect(row.completed, isFalse);
  });

  test('checkpoints record the furthest point, never a rewind', () async {
    final (:db, :catalog, :tracker) = _open();
    await tracker.start(_song);

    await tracker.observe(const Duration(seconds: 12));
    await tracker.observe(const Duration(seconds: 4));
    await tracker.flush();

    final row = await db.select(db.playEvents).getSingle();
    expect(row.listenedMs, 12000);
  });

  test('a track played to its end is marked completed', () async {
    final (:db, :catalog, :tracker) = _open();
    await tracker.start(_song);
    await tracker.observe(const Duration(seconds: 266));
    await tracker.finish();

    final row = await db.select(db.playEvents).getSingle();
    expect(row.completed, isTrue);
    expect(row.listenedMs, 266000);
  });

  test('a new track closes the previous play and opens another', () async {
    final (:db, :catalog, :tracker) = _open();
    await tracker.start(_song);
    await tracker.observe(const Duration(seconds: 12));

    await tracker.start(
      const LibrarySong(
        sourceId: 'a',
        id: 's2',
        title: 'Fix You',
        artist: 'Coldplay',
        duration: Duration(seconds: 295),
      ),
    );
    await tracker.flush();

    final rows = await db.select(db.playEvents).get();
    expect(rows, hasLength(2));
    expect(rows.first.listenedMs, 12000, reason: 'the finished play');
    expect(rows.last.trackId, isNot(rows.first.trackId));
  });

  test('a tracker without a database plays on and records nothing', () async {
    final (:db, :catalog, :tracker) = _open(withDatabase: false);

    await tracker.start(_song);
    await tracker.observe(const Duration(seconds: 30));
    await tracker.finish();
    await tracker.flush();

    expect(await db.select(db.playEvents).get(), isEmpty);
  });

  test('seeking forward past the end of a track marks it completed', () async {
    final (:db, :catalog, :tracker) = _open();
    await tracker.start(_song);
    await tracker.observe(const Duration(seconds: 300));

    final row = await db.select(db.playEvents).getSingle();
    expect(row.completed, isTrue);
  });
}
