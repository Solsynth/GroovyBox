/// Translates drift rows into the Library Sync wire records.
///
/// Pure functions: the engine reads the rows and calls these, so nothing here
/// touches a database, a provider or the network.
library;

import '../data/local/library_database.dart';
import 'models.dart';

/// Renders a drift time as the wire's RFC3339 UTC string.
///
/// Drift stores times as local wall clock, so a row is converted to UTC once,
/// here, and never re-interpreted downstream.
String wireTime(DateTime value) {
  final utc = value.toUtc();
  final seconds = DateTime.fromMillisecondsSinceEpoch(
    (utc.millisecondsSinceEpoch ~/ 1000) * 1000,
    isUtc: true,
  );
  // Dart always renders milliseconds; the wire wants whole seconds.
  return '${seconds.toIso8601String().split('.').first}Z';
}

/// One track's upsert, keyed by its fingerprint.
SyncChange trackChange(TrackRow row) => SyncChange(
  kind: ChangeKind.upsert,
  entity: SyncEntity.track,
  track: SyncTrack(
    fingerprint: row.fingerprint,
    title: row.title,
    artist: row.artist,
    albumArtist: row.albumArtist,
    album: row.album,
    genre: row.genre,
    year: row.year,
    trackNumber: row.trackNumber,
    discNumber: row.discNumber,
    durationMs: row.durationMs,
    mbid: row.mbid,
    createdAt: wireTime(row.createdAt),
    updatedAt: wireTime(row.updatedAt),
  ),
);

/// One source link's upsert. [fingerprint] is the link's track's fingerprint.
SyncChange linkChange(TrackLinkRow row, String fingerprint) => SyncChange(
  kind: ChangeKind.upsert,
  entity: SyncEntity.link,
  link: SyncLink(
    sourceId: row.sourceId,
    externalId: row.externalId,
    trackFingerprint: fingerprint,
    albumExternalId: row.albumExternalId,
    artistExternalId: row.artistExternalId,
    artId: row.artId,
    linkedAt: wireTime(row.linkedAt),
    lastSeenAt: wireTime(row.lastSeenAt),
  ),
);

/// One stored lyric's upsert.
SyncChange lyricsChange(LyricsRow row, String fingerprint) => SyncChange(
  kind: ChangeKind.upsert,
  entity: SyncEntity.lyrics,
  lyrics: SyncLyrics(
    trackFingerprint: fingerprint,
    lines: row.lines,
    synced: row.synced,
    language: row.language,
    origin: row.origin,
    remoteId: row.remoteId,
    fetchedAt: wireTime(row.fetchedAt),
    translationLanguage: row.translationLanguage,
  ),
);

/// One play's upsert. A play is append-only, so this is never a delete, and
/// the clock is [PlayEventRow.touchedAt] or, for a row written before that
/// column existed, its start.
SyncChange playChange(PlayEventRow row, String fingerprint) => SyncChange(
  kind: ChangeKind.upsert,
  entity: SyncEntity.play,
  play: SyncPlay(
    trackFingerprint: fingerprint,
    sourceId: row.sourceId,
    startedAt: wireTime(row.startedAt),
    clock: wireTime(row.touchedAt ?? row.startedAt),
    listenedMs: row.listenedMs,
    positionMs: row.positionMs,
    completed: row.completed,
  ),
);

/// The account's session document, as this device hears it.
SyncChange sessionChange(PlaybackSessionRow row) => SyncChange(
  kind: ChangeKind.upsert,
  entity: SyncEntity.session,
  session: SyncSession(
    queueJson: row.queueJson,
    currentIndex: row.currentIndex,
    positionMs: row.positionMs,
    durationMs: row.durationMs,
    shuffle: row.shuffle,
    repeatMode: row.repeatMode,
    updatedAt: wireTime(row.updatedAt),
  ),
);

/// The settings document. [_updatedAt] is the push time: it advances only when
/// the values themselves changed.
SyncChange settingsChange(Map<String, dynamic> values, {DateTime? at}) =>
    SyncChange(
      kind: ChangeKind.upsert,
      entity: SyncEntity.settings,
      settings: {...values, '_updated_at': wireTime(at ?? DateTime.now())},
    );

/// A tombstone for one entity's natural key.
SyncChange deleteChange({
  required SyncEntity entity,
  String? fingerprint,
  String? sourceId,
  String? externalId,
  required DateTime deletedAt,
}) {
  final clock = wireTime(deletedAt);
  return switch (entity) {
    SyncEntity.track => SyncChange(
      kind: ChangeKind.delete,
      entity: SyncEntity.track,
      deletedAt: clock,
      track: SyncTrack(
        fingerprint: fingerprint ?? '',
        title: '',
        createdAt: clock,
        updatedAt: clock,
      ),
    ),
    SyncEntity.link => SyncChange(
      kind: ChangeKind.delete,
      entity: SyncEntity.link,
      deletedAt: clock,
      link: SyncLink(
        sourceId: sourceId ?? '',
        externalId: externalId ?? '',
        trackFingerprint: '',
        linkedAt: clock,
        lastSeenAt: clock,
      ),
    ),
    SyncEntity.lyrics => SyncChange(
      kind: ChangeKind.delete,
      entity: SyncEntity.lyrics,
      deletedAt: clock,
      lyrics: SyncLyrics(
        trackFingerprint: fingerprint ?? '',
        lines: '',
        synced: false,
        origin: 'none',
        fetchedAt: clock,
      ),
    ),
    SyncEntity.play || SyncEntity.session || SyncEntity.settings => SyncChange(
      kind: ChangeKind.delete,
      entity: entity,
      deletedAt: clock,
    ),
  };
}
