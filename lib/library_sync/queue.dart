/// Queues local deletions for the next Library Sync push.
///
/// Lives outside `providers.dart` so the library layer can queue a tombstone
/// without importing the Riverpod graph that reads the library.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'marshal.dart';
import 'models.dart';
import 'store.dart';

/// Appends tombstones to the persisted queue, keeping the entries already
/// waiting.
Future<void> queueDeletes(
  SharedPreferences prefs,
  Iterable<PendingDelete> entries,
) async {
  if (entries.isEmpty) return;
  final store = LibrarySyncStateStore(prefs);
  final state = store.load();
  await store.save(
    state.copyWith(pendingDeletes: [...state.pendingDeletes, ...entries]),
  );
}

/// Queues one tombstone per link a forgotten source had.
Future<void> queueLinkDeletes(
  SharedPreferences prefs,
  String sourceId,
  Iterable<String> externalIds, {
  DateTime? at,
}) => queueDeletes(prefs, [
  for (final externalId in externalIds)
    PendingDelete(
      entity: SyncEntity.link.wire,
      fields: {'source_id': sourceId, 'external_id': externalId},
      deletedAt: wireTime(at ?? DateTime.now()),
    ),
]);

/// Queues one tombstone per track whose stored lyrics were dropped.
Future<void> queueLyricsDeletes(
  SharedPreferences prefs,
  Iterable<String> fingerprints, {
  DateTime? at,
}) => queueDeletes(prefs, [
  for (final fingerprint in fingerprints)
    PendingDelete(
      entity: SyncEntity.lyrics.wire,
      fields: {'track_fingerprint': fingerprint},
      deletedAt: wireTime(at ?? DateTime.now()),
    ),
]);
