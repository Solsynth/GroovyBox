/// The device half of Library Sync: pushes local changes, pulls remote ones and
/// writes them into the same drift database the rest of the app reads.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/local/library_database.dart';
import '../library/models.dart';
import '../library/track_identity.dart';
import '../solarpass/models.dart';
import 'client.dart';
import 'marshal.dart';
import 'models.dart';
import 'store.dart';

/// How many changes one push carries, and how many rows one pull page holds.
const librarySyncBatch = 500;

/// What one run did, whether or not it succeeded.
class SyncRunResult {
  const SyncRunResult({
    required this.at,
    this.pushed = 0,
    this.pulled = 0,
    this.error,
  });

  final DateTime at;
  final int pushed;
  final int pulled;
  final String? error;

  bool get succeeded => error == null;

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'pushed': pushed,
    'pulled': pulled,
    'error': error,
  };

  factory SyncRunResult.fromJson(Map<String, dynamic> json) => SyncRunResult(
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    pushed: (json['pushed'] as num?)?.toInt() ?? 0,
    pulled: (json['pulled'] as num?)?.toInt() ?? 0,
    error: json['error'] as String?,
  );
}

/// Runs one sync: local changes out, remote changes in.
///
/// Every write is guarded by a clock comparison, so a device's own push coming
/// back in the next pull rewrites nothing.
class LibrarySyncEngine {
  LibrarySyncEngine({
    required this.db,
    required this.client,
    required this.state,
    required this.connectedSourceIds,
    required this.readSettings,
    required this.applySettings,
    required this.invalidate,
  });

  final LibraryDatabase? db;
  final LibrarySyncClient client;
  final LibrarySyncStateStore state;

  /// The sources this device has connected. A link naming any other source is
  /// not adopted: its credentials live with the source, not with the link.
  final List<String> Function() connectedSourceIds;

  /// The settings values this device currently holds.
  final Map<String, dynamic> Function() readSettings;

  /// Writes a settings document that a remote device owns.
  final Future<void> Function(Map<String, dynamic>) applySettings;

  /// Rebuilds the providers a pull may have changed.
  final void Function() invalidate;

  Future<SyncRunResult>? _running;

  /// Runs a sync, or joins the one already in flight.
  Future<SyncRunResult> run({
    required OAuthSession session,
    Future<OAuthSession?> Function()? refreshSession,
  }) {
    final inFlight = _running;
    if (inFlight != null) return inFlight;
    final future = _run(session: session, refreshSession: refreshSession);
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<SyncRunResult> _run({
    required OAuthSession session,
    Future<OAuthSession?> Function()? refreshSession,
  }) async {
    final startedAt = DateTime.now();
    final loaded = state.load();
    if (!loaded.enabled) {
      return SyncRunResult(at: startedAt, error: 'disabled');
    }
    final database = db;
    if (database == null) {
      return SyncRunResult(at: startedAt, error: 'no-database');
    }

    var pushed = 0;
    var pulled = 0;
    try {
      var current = session;
      try {
        pushed = await _pushAll(database, current, loaded);
        pulled = await _pullAll(database, current, loaded);
      } on LibrarySyncUnauthorized {
        // One refresh, one retry: a revoked token must not spin.
        final refreshed = await refreshSession?.call();
        if (refreshed == null) rethrow;
        current = refreshed;
        pushed = await _pushAll(database, current, loaded);
        pulled = await _pullAll(database, current, loaded);
      }

      final finalState = state.load().copyWith(
        lastPullAt: wireTime(DateTime.now()),
      );
      await state.save(finalState);
      invalidate();
      return SyncRunResult(at: startedAt, pushed: pushed, pulled: pulled);
    } catch (error) {
      debugPrint('[LibrarySync] run failed: $error');
      return SyncRunResult(
        at: startedAt,
        pushed: pushed,
        pulled: pulled,
        error: error.toString(),
      );
    }
  }

  // ── Push ────────────────────────────────────────────────────────────────

  Future<int> _pushAll(
    LibraryDatabase database,
    OAuthSession session,
    LibrarySyncState syncState,
  ) async {
    var cursor = syncState.lastPushAt;
    var sent = 0;

    // Deletes go first and alone: an entity batch that fails must not lose the
    // tombstone behind it, and the queue is cleared only once the server
    // accepted it.
    if (syncState.pendingDeletes.isNotEmpty) {
      final deletes = [
        for (final entry in syncState.pendingDeletes)
          deleteChange(
            entity: SyncEntity.fromWire(entry.entity) ?? SyncEntity.link,
            fingerprint: entry.fields['track_fingerprint'],
            sourceId: entry.fields['source_id'],
            externalId: entry.fields['external_id'],
            deletedAt: DateTime.tryParse(entry.deletedAt) ?? DateTime.now(),
          ),
      ];
      await client.push(session, syncState.deviceId, deletes);
      await state.save(state.load().copyWith(pendingDeletes: const []));
      sent += deletes.length;
    }

    while (true) {
      final batch = await _collectChanges(database, syncState, since: cursor);
      if (batch.changes.isEmpty) break;
      await client.push(session, syncState.deviceId, batch.changes);
      cursor = batch.newestClock;
      await state.save(
        state.load().copyWith(
          lastPushAt: cursor,
          pushedSettings: batch.settings,
        ),
      );
      sent += batch.changes.length;
      if (batch.exhausted) break;
    }
    return sent;
  }

  /// Reads every row newer than [since], oldest first, into at most one batch.
  ///
  /// The batch never stops inside a group of rows sharing one clock: the next
  /// run reads strictly newer rows, so a row left behind would be skipped
  /// forever.
  Future<_PushBatch> _collectChanges(
    LibraryDatabase database,
    LibrarySyncState syncState, {
    String? since,
  }) async {
    final sinceTime = DateTime.tryParse(since ?? '')?.toLocal();
    final fingerprintOf = await _fingerprintMap(database);
    final connected = connectedSourceIds().toSet();

    final entries = <({DateTime clock, SyncChange change})>[];

    final trackRows =
        await (database.select(database.tracks)
              ..where(
                (row) => sinceTime == null
                    ? const Constant(true)
                    : row.updatedAt.isBiggerThanValue(sinceTime),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)]))
            .get();
    for (final row in trackRows) {
      entries.add((clock: row.updatedAt, change: trackChange(row)));
    }

    final linkRows =
        await (database.select(database.trackLinks)
              ..where(
                (row) =>
                    row.sourceId.equals(kLocalSourceId).not() &
                    (sinceTime == null
                        ? const Constant(true)
                        : row.lastSeenAt.isBiggerThanValue(sinceTime)),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.lastSeenAt)]))
            .get();
    for (final row in linkRows) {
      if (!connected.contains(row.sourceId)) continue;
      final fingerprint = fingerprintOf[row.trackId];
      if (fingerprint == null) continue;
      entries.add((
        clock: row.lastSeenAt,
        change: linkChange(row, fingerprint),
      ));
    }

    final lyricsRows =
        await (database.select(database.lyricsEntries)
              ..where(
                (row) => sinceTime == null
                    ? const Constant(true)
                    : row.fetchedAt.isBiggerThanValue(sinceTime),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.fetchedAt)]))
            .get();
    for (final row in lyricsRows) {
      final fingerprint = fingerprintOf[row.trackId];
      if (fingerprint == null) continue;
      entries.add((
        clock: row.fetchedAt,
        change: lyricsChange(row, fingerprint),
      ));
    }

    final playRows =
        await (database.select(database.playEvents)
              ..where((row) {
                final touched = row.touchedAt;
                if (sinceTime == null) return const Constant(true);
                return touched.isBiggerThanValue(sinceTime) |
                    row.startedAt.isBiggerThanValue(sinceTime);
              })
              ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]))
            .get();
    for (final row in playRows) {
      final fingerprint = fingerprintOf[row.trackId];
      if (fingerprint == null) continue;
      entries.add((
        clock: row.touchedAt ?? row.startedAt,
        change: playChange(row, fingerprint),
      ));
    }

    // The session document is pushed only when this device owns it: a newer
    // remote clock means another device is the writer and this one must not
    // fight it.
    final sessionRow = await database.loadPlaybackSession();
    final sessionClock = writeClock(sessionRow?.updatedAt);
    if (sessionRow != null &&
        (syncState.remoteSessionClock == null ||
            _isNewer(sessionClock, syncState.remoteSessionClock))) {
      if (sinceTime == null || sessionRow.updatedAt.isAfter(sinceTime)) {
        entries.add((
          clock: sessionRow.updatedAt,
          change: sessionChange(sessionRow),
        ));
      }
    }

    entries.sort((a, b) => a.clock.compareTo(b.clock));
    // Cut on a clock boundary, never inside one: a shrunk batch just means one
    // more round trip, while a split would drop rows the next run never asks for.
    var cut = entries.length > librarySyncBatch
        ? librarySyncBatch
        : entries.length;
    while (cut > 0 &&
        cut < entries.length &&
        !entries[cut].clock.isAfter(entries[cut - 1].clock)) {
      cut--;
    }
    final batch = entries.take(cut).toList();

    // Settings travel as one document keyed by the values themselves, so an
    // unchanged map produces nothing. They ride along in the last batch only:
    // the snapshot saved afterwards must describe the whole run.
    final values = readSettings();
    final previous = syncState.pushedSettings;
    final settingsDiffer = previous == null || !_sameSettings(previous, values);
    final exhausted = cut >= entries.length;
    final changes = [for (final entry in batch) entry.change];
    if (settingsDiffer && exhausted) {
      changes.add(settingsChange(values));
    }

    // The next push reads everything newer than the newest clock sent. With
    // nothing to send, the previous boundary stands.
    final boundary = batch.isEmpty
        ? (since ?? writeClock(DateTime.now()))
        : writeClock(batch.last.clock);

    return _PushBatch(
      changes: changes,
      newestClock: boundary,
      settings: settingsDiffer && exhausted ? values : null,
      exhausted: exhausted,
    );
  }

  // ── Pull ────────────────────────────────────────────────────────────────

  Future<int> _pullAll(
    LibraryDatabase database,
    OAuthSession session,
    LibrarySyncState syncState,
  ) async {
    var applied = 0;
    var cursor = syncState.lastRev;
    while (true) {
      final page = await client.pull(
        session,
        since: cursor,
        limit: librarySyncBatch,
      );
      applied += await _applyPage(database, page);
      cursor = page.rev;
      await state.save(state.load().copyWith(lastRev: cursor));
      if (!page.hasMore) break;
    }
    return applied;
  }

  Future<int> _applyPage(LibraryDatabase database, PullPage page) async {
    var applied = 0;
    final connected = connectedSourceIds().toSet();

    for (final track in page.tracks) {
      if (await _applyTrack(database, track)) applied++;
    }

    if (page.links.isNotEmpty) {
      final fingerprintOf = await _trackIdMap(database);
      for (final link in page.links) {
        if (link.sourceId == kLocalSourceId) continue;
        if (!connected.contains(link.sourceId)) {
          debugPrint(
            '[LibrarySync] skipping link for unconnected source ${link.sourceId}',
          );
          continue;
        }
        final trackId = fingerprintOf[link.trackFingerprint];
        if (trackId == null) continue;
        await _applyLink(database, link, trackId);
        applied++;
      }
    }

    if (page.lyrics.isNotEmpty) {
      final fingerprintOf = await _trackIdMap(database);
      for (final lyrics in page.lyrics) {
        final trackId = fingerprintOf[lyrics.trackFingerprint];
        if (trackId == null) continue;
        if (await _applyLyrics(database, lyrics, trackId)) applied++;
      }
    }

    if (page.plays.isNotEmpty) {
      final fingerprintOf = await _trackIdMap(database);
      for (final play in page.plays) {
        final trackId = fingerprintOf[play.trackFingerprint];
        if (trackId == null) continue;
        await _applyPlay(database, play, trackId);
        applied++;
      }
    }

    applied += await _applyRemoved(database, page);

    for (final entry in page.removed.entries) {
      debugPrint('[LibrarySync] removed ${entry.key}: ${entry.value.length}');
    }

    final session = page.session;
    final sessionClock = page.sessionClock;
    if (session != null && sessionClock != null) {
      final current = state.load();
      if (_isNewer(sessionClock, current.remoteSessionClock)) {
        await database.savePlaybackSession(
          queueJson: session.queueJson,
          currentIndex: session.currentIndex,
          positionMs: session.positionMs,
          durationMs: session.durationMs,
          shuffle: session.shuffle,
          repeatMode: session.repeatMode,
          updatedAt: DateTime.tryParse(session.updatedAt),
        );
        await state.save(
          state.load().copyWith(remoteSessionClock: sessionClock),
        );
        applied++;
      }
    } else if (sessionClock != null) {
      // A cleared document: nothing to write, but its clock must be recorded so
      // this device does not re-push its own session over it.
      final current = state.load();
      if (_isNewer(sessionClock, current.remoteSessionClock)) {
        await state.save(
          state.load().copyWith(remoteSessionClock: sessionClock),
        );
      }
    }

    final settingsClock = page.settingsClock;
    if (settingsClock != null) {
      final current = state.load();
      if (_isNewer(settingsClock, current.remoteSettingsClock)) {
        if (page.settings.isNotEmpty) {
          await applySettings(page.settings);
          applied++;
        }
        await state.save(
          state.load().copyWith(
            remoteSettingsClock: settingsClock,
            // The adopted map is what this device now holds, so the next push
            // sees no difference.
            pushedSettings: page.settings,
          ),
        );
      }
    }

    return applied;
  }

  Future<bool> _applyTrack(LibraryDatabase database, SyncTrack track) async {
    final identity = TrackIdentity(
      title: track.title,
      artist: track.artist,
      albumArtist: track.albumArtist,
      album: track.album,
      genre: track.genre,
      year: track.year,
      trackNumber: track.trackNumber,
      discNumber: track.discNumber,
      duration: Duration(milliseconds: track.durationMs),
      mbid: track.mbid,
    );
    final createdAt = DateTime.tryParse(track.createdAt) ?? DateTime.now();
    final updatedAt = DateTime.tryParse(track.updatedAt) ?? createdAt;

    final matched = await database.findMatchingTrack(identity);
    if (matched == null) {
      await database
          .into(database.tracks)
          .insert(
            TracksCompanion.insert(
              title: track.title,
              fingerprint: track.fingerprint,
              createdAt: createdAt,
              updatedAt: updatedAt,
              artist: Value.absentIfNull(track.artist),
              albumArtist: Value.absentIfNull(track.albumArtist),
              album: Value.absentIfNull(track.album),
              genre: Value.absentIfNull(track.genre),
              year: Value.absentIfNull(track.year),
              trackNumber: Value.absentIfNull(track.trackNumber),
              discNumber: Value.absentIfNull(track.discNumber),
              durationMs: Value(track.durationMs),
              mbid: Value.absentIfNull(track.mbid),
            ),
          );
      return true;
    }

    // Fill what this device is missing; overwrite whenever the incoming row is
    // newer than the one already stored.
    final newer = updatedAt.isAfter(matched.updatedAt);
    final fill = <String, dynamic>{};
    if (newer || (matched.artist == null && track.artist != null)) {
      fill['artist'] = track.artist;
    }
    if (newer || (matched.albumArtist == null && track.albumArtist != null)) {
      fill['albumArtist'] = track.albumArtist;
    }
    if (newer || (matched.album == null && track.album != null)) {
      fill['album'] = track.album;
    }
    if (newer || (matched.genre == null && track.genre != null)) {
      fill['genre'] = track.genre;
    }
    if (newer || (matched.year == null && track.year != null)) {
      fill['year'] = track.year;
    }
    if (newer || (matched.trackNumber == null && track.trackNumber != null)) {
      fill['trackNumber'] = track.trackNumber;
    }
    if (newer || (matched.discNumber == null && track.discNumber != null)) {
      fill['discNumber'] = track.discNumber;
    }
    if (newer || (matched.mbid == null && track.mbid != null)) {
      fill['mbid'] = track.mbid;
    }
    if (fill.isEmpty) return false;

    await (database.update(
      database.tracks,
    )..where((row) => row.id.equals(matched.id))).write(
      TracksCompanion(
        artist: fill.containsKey('artist')
            ? Value(track.artist)
            : const Value.absent(),
        albumArtist: fill.containsKey('albumArtist')
            ? Value(track.albumArtist)
            : const Value.absent(),
        album: fill.containsKey('album')
            ? Value(track.album)
            : const Value.absent(),
        genre: fill.containsKey('genre')
            ? Value(track.genre)
            : const Value.absent(),
        year: fill.containsKey('year')
            ? Value(track.year)
            : const Value.absent(),
        trackNumber: fill.containsKey('trackNumber')
            ? Value(track.trackNumber)
            : const Value.absent(),
        discNumber: fill.containsKey('discNumber')
            ? Value(track.discNumber)
            : const Value.absent(),
        mbid: fill.containsKey('mbid')
            ? Value(track.mbid)
            : const Value.absent(),
        // The row's own clock records when it was last described, so a later
        // pull of an older row does not look newer than this one.
        updatedAt: Value(newer ? updatedAt : matched.updatedAt),
      ),
    );
    return true;
  }

  Future<void> _applyLink(
    LibraryDatabase database,
    SyncLink link,
    int trackId,
  ) async {
    final linkedAt = DateTime.tryParse(link.linkedAt) ?? DateTime.now();
    final lastSeenAt = DateTime.tryParse(link.lastSeenAt) ?? linkedAt;
    final existing =
        await (database.select(database.trackLinks)..where(
              (row) =>
                  row.sourceId.equals(link.sourceId) &
                  row.externalId.equals(link.externalId),
            ))
            .getSingleOrNull();
    if (existing != null && !lastSeenAt.isAfter(existing.lastSeenAt)) {
      // Nothing newer: leave the local link, including its track, alone.
      return;
    }
    await database
        .into(database.trackLinks)
        .insert(
          TrackLinksCompanion.insert(
            trackId: trackId,
            sourceId: link.sourceId,
            externalId: link.externalId,
            albumExternalId: Value.absentIfNull(link.albumExternalId),
            artistExternalId: Value.absentIfNull(link.artistExternalId),
            artId: Value.absentIfNull(link.artId),
            linkedAt: existing?.linkedAt ?? linkedAt,
            lastSeenAt: lastSeenAt,
          ),
          onConflict: DoUpdate(
            (old) => TrackLinksCompanion(
              trackId: Value(trackId),
              albumExternalId: Value.absentIfNull(link.albumExternalId),
              artistExternalId: Value.absentIfNull(link.artistExternalId),
              artId: Value.absentIfNull(link.artId),
              lastSeenAt: Value(lastSeenAt),
            ),
            target: [
              database.trackLinks.sourceId,
              database.trackLinks.externalId,
            ],
          ),
        );
  }

  Future<bool> _applyLyrics(
    LibraryDatabase database,
    SyncLyrics lyrics,
    int trackId,
  ) async {
    final fetchedAt = DateTime.tryParse(lyrics.fetchedAt) ?? DateTime.now();
    final existing = await (database.select(
      database.lyricsEntries,
    )..where((row) => row.trackId.equals(trackId))).getSingleOrNull();
    final incomingHasLyrics = lyrics.origin != 'none';

    if (existing == null) {
      await database
          .into(database.lyricsEntries)
          .insert(
            LyricsEntriesCompanion.insert(
              trackId: Value(trackId),
              lines: lyrics.lines,
              synced: lyrics.synced,
              language: Value.absentIfNull(lyrics.language),
              origin: lyrics.origin,
              remoteId: Value.absentIfNull(lyrics.remoteId),
              fetchedAt: fetchedAt,
              translationLanguage: Value.absentIfNull(
                lyrics.translationLanguage,
              ),
            ),
          );
      return true;
    }
    // A stored miss is replaced by real lyrics; otherwise the newer answer wins.
    final replaces =
        (existing.origin == 'none' && incomingHasLyrics) ||
        (incomingHasLyrics && fetchedAt.isAfter(existing.fetchedAt));
    if (!replaces) return false;
    await (database.update(
      database.lyricsEntries,
    )..where((row) => row.trackId.equals(trackId))).write(
      LyricsEntriesCompanion(
        lines: Value(lyrics.lines),
        synced: Value(lyrics.synced),
        language: Value(lyrics.language),
        origin: Value(lyrics.origin),
        remoteId: Value(lyrics.remoteId),
        fetchedAt: Value(fetchedAt),
        translationLanguage: Value(lyrics.translationLanguage),
      ),
    );
    return true;
  }

  Future<void> _applyPlay(
    LibraryDatabase database,
    SyncPlay play,
    int trackId,
  ) async {
    final startedAt = DateTime.tryParse(play.startedAt);
    if (startedAt == null) return;
    final existing =
        await (database.select(database.playEvents)..where(
              (row) =>
                  row.trackId.equals(trackId) & row.startedAt.equals(startedAt),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await database
          .into(database.playEvents)
          .insert(
            PlayEventsCompanion.insert(
              trackId: trackId,
              sourceId: play.sourceId,
              startedAt: startedAt,
              listenedMs: Value(play.listenedMs),
              positionMs: Value(play.positionMs),
              completed: Value(play.completed),
              touchedAt: Value(DateTime.tryParse(play.clock)),
            ),
          );
      return;
    }
    // Two devices' progress folds into the wider one; a play is never dropped.
    final listened = play.listenedMs > existing.listenedMs
        ? play.listenedMs
        : existing.listenedMs;
    final position = play.positionMs > existing.positionMs
        ? play.positionMs
        : existing.positionMs;
    final completed = existing.completed || play.completed;
    if (listened == existing.listenedMs &&
        position == existing.positionMs &&
        completed == existing.completed) {
      return;
    }
    await (database.update(
      database.playEvents,
    )..where((row) => row.id.equals(existing.id))).write(
      PlayEventsCompanion(
        listenedMs: Value(listened),
        positionMs: Value(position),
        completed: Value(completed),
        touchedAt: Value(DateTime.tryParse(play.clock) ?? existing.touchedAt),
      ),
    );
  }

  Future<int> _applyRemoved(LibraryDatabase database, PullPage page) async {
    var removed = 0;
    for (final entry in page.removed.entries) {
      final entity = SyncEntity.fromWire(entry.key);
      for (final raw in entry.value) {
        final RemovedEntry? decoded = _decodeRemoval(raw);
        if (decoded == null) continue;
        switch (entity) {
          case SyncEntity.track:
            final fingerprint = decoded.fields['fingerprint'];
            if (fingerprint is! String) break;
            final row =
                await (database.select(database.tracks)
                      ..where((track) => track.fingerprint.equals(fingerprint)))
                    .getSingleOrNull();
            if (row == null || row.updatedAt.isAfter(decoded.deletedAt)) break;
            // Links, lyrics and plays cascade with the track.
            await (database.delete(
              database.tracks,
            )..where((track) => track.id.equals(row.id))).go();
            removed++;
          case SyncEntity.link:
            final sourceId = decoded.fields['source_id'];
            final externalId = decoded.fields['external_id'];
            if (sourceId is! String || externalId is! String) break;
            final row =
                await (database.select(database.trackLinks)..where(
                      (link) =>
                          link.sourceId.equals(sourceId) &
                          link.externalId.equals(externalId),
                    ))
                    .getSingleOrNull();
            if (row == null || row.lastSeenAt.isAfter(decoded.deletedAt)) break;
            await (database.delete(
              database.trackLinks,
            )..where((link) => link.id.equals(row.id))).go();
            removed++;
          case SyncEntity.lyrics:
            final fingerprint = decoded.fields['track_fingerprint'];
            if (fingerprint is! String) break;
            final track =
                await (database.select(database.tracks)
                      ..where((row) => row.fingerprint.equals(fingerprint)))
                    .getSingleOrNull();
            if (track == null) break;
            final row =
                await (database.select(database.lyricsEntries)
                      ..where((entry) => entry.trackId.equals(track.id)))
                    .getSingleOrNull();
            if (row == null || row.fetchedAt.isAfter(decoded.deletedAt)) break;
            await (database.delete(
              database.lyricsEntries,
            )..where((entry) => entry.trackId.equals(track.id))).go();
            removed++;
          case SyncEntity.play ||
              SyncEntity.session ||
              SyncEntity.settings ||
              null:
            break;
        }
      }
    }
    return removed;
  }

  RemovedEntry? _decodeRemoval(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final fields = decoded.cast<String, dynamic>();
      final deletedAt = DateTime.tryParse(
        fields['deleted_at'] as String? ?? '',
      );
      if (deletedAt == null) return null;
      fields.remove('deleted_at');
      return RemovedEntry(fields: fields, deletedAt: deletedAt);
    } on FormatException {
      return null;
    }
  }

  /// Track id to fingerprint, for every row a link or play can address.
  Future<Map<int, String>> _fingerprintMap(LibraryDatabase database) async {
    final rows = await database.select(database.tracks).get();
    return {for (final row in rows) row.id: row.fingerprint};
  }

  /// Fingerprint to track id, for every track a pulled record can name.
  Future<Map<String, int>> _trackIdMap(LibraryDatabase database) async {
    final rows = await database.select(database.tracks).get();
    return {for (final row in rows) row.fingerprint: row.id};
  }

  static bool _sameSettings(
    Map<String, dynamic> previous,
    Map<String, dynamic> next,
  ) {
    if (previous.length != next.length) return false;
    for (final entry in previous.entries) {
      if (next[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Whether [clock] is strictly newer than [reference]; a missing reference
  /// means anything counts as newer.
  static bool _isNewer(String? clock, String? reference) {
    if (clock == null) return false;
    if (reference == null) return true;
    final parsed = DateTime.tryParse(clock);
    final parsedReference = DateTime.tryParse(reference);
    if (parsed == null) return false;
    if (parsedReference == null) return true;
    return parsed.isAfter(parsedReference);
  }
}

/// One push's payload and the bookkeeping that follows a success.
class _PushBatch {
  const _PushBatch({
    required this.changes,
    required this.newestClock,
    required this.settings,
    required this.exhausted,
  });

  final List<SyncChange> changes;

  /// The newest clock in this batch; the next push reads everything after it.
  final String? newestClock;

  /// The settings values this batch carried, or null when they did not change.
  final Map<String, dynamic>? settings;

  /// Whether every row newer than the cursor fitted into this batch.
  final bool exhausted;
}

/// Renders a drift time as the wire's second-precision RFC3339 UTC string.
String? writeClock(DateTime? value) => value == null ? null : wireTime(value);
