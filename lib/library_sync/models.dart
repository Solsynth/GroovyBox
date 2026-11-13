/// The library sync wire contract, mirrored from Pulsar's
/// `internal/pulsar/modules/librarysync/wire.go`.
///
/// Times are RFC3339 strings in UTC; a null field means "absent", never
/// "unchanged". [Duration] never appears here: durations travel as plain
/// milliseconds, and the engine converts them at the drift boundary.
library;

/// The operation one change represents.
enum ChangeKind { upsert, delete }

/// The entity a change touches.
enum SyncEntity {
  track,
  link,
  lyrics,
  play,
  session,
  settings;

  /// The wire name of this entity.
  String get wire => name;

  static SyncEntity? fromWire(String? value) {
    for (final entity in SyncEntity.values) {
      if (entity.name == value) return entity;
    }
    return null;
  }
}

/// One entity mutation.
///
/// An upsert carries exactly one record; a delete carries only the record's
/// natural-key fields plus the tombstone clock in [deletedAt].
class SyncChange {
  const SyncChange({
    required this.kind,
    required this.entity,
    this.deletedAt,
    this.track,
    this.link,
    this.lyrics,
    this.play,
    this.session,
    this.settings,
  });

  final ChangeKind kind;
  final SyncEntity entity;

  /// The tombstone clock of a delete; replaces the record's own clock.
  final String? deletedAt;

  final SyncTrack? track;
  final SyncLink? link;
  final SyncLyrics? lyrics;
  final SyncPlay? play;
  final SyncSession? session;
  final Map<String, dynamic>? settings;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'entity': entity.wire,
    if (deletedAt != null) 'deleted_at': deletedAt,
    if (track != null) 'track': track!.toJson(),
    if (link != null) 'link': link!.toJson(),
    if (lyrics != null) 'lyrics': lyrics!.toJson(),
    if (play != null) 'play': play!.toJson(),
    if (session != null) 'session': session!.toJson(),
    if (settings != null) 'settings': settings,
  };

  factory SyncChange.fromJson(Map<String, dynamic> json) => SyncChange(
    kind: json['kind'] == 'delete' ? ChangeKind.delete : ChangeKind.upsert,
    entity: SyncEntity.fromWire(json['entity'] as String?) ?? SyncEntity.track,
    deletedAt: json['deleted_at'] as String?,
    track: SyncTrack.tryFromJson(json['track']),
    link: SyncLink.tryFromJson(json['link']),
    lyrics: SyncLyrics.tryFromJson(json['lyrics']),
    play: SyncPlay.tryFromJson(json['play']),
    session: SyncSession.tryFromJson(json['session']),
    settings: (json['settings'] as Map?)?.cast<String, dynamic>(),
  );
}

/// One canonical track, keyed by its fingerprint.
class SyncTrack {
  const SyncTrack({
    required this.fingerprint,
    required this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.durationMs = 0,
    this.mbid,
    required this.createdAt,
    required this.updatedAt,
  });

  final String fingerprint;
  final String title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int durationMs;
  final String? mbid;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'title': title,
    'artist': artist,
    'album_artist': albumArtist,
    'album': album,
    'genre': genre,
    'year': year,
    'track_number': trackNumber,
    'disc_number': discNumber,
    'duration_ms': durationMs,
    'mbid': mbid,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory SyncTrack.fromJson(Map<String, dynamic> json) => SyncTrack(
    fingerprint: json['fingerprint'] as String? ?? '',
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String?,
    albumArtist: json['album_artist'] as String?,
    album: json['album'] as String?,
    genre: json['genre'] as String?,
    year: (json['year'] as num?)?.toInt(),
    trackNumber: (json['track_number'] as num?)?.toInt(),
    discNumber: (json['disc_number'] as num?)?.toInt(),
    durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
    mbid: json['mbid'] as String?,
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
  );

  static SyncTrack? tryFromJson(Object? raw) =>
      raw is Map ? SyncTrack.fromJson(raw.cast<String, dynamic>()) : null;
}

/// One track's identity on one source. Local-file links never sync.
class SyncLink {
  const SyncLink({
    required this.sourceId,
    required this.externalId,
    required this.trackFingerprint,
    this.albumExternalId,
    this.artistExternalId,
    this.artId,
    required this.linkedAt,
    required this.lastSeenAt,
  });

  final String sourceId;
  final String externalId;
  final String trackFingerprint;
  final String? albumExternalId;
  final String? artistExternalId;
  final String? artId;
  final String linkedAt;
  final String lastSeenAt;

  Map<String, dynamic> toJson() => {
    'source_id': sourceId,
    'external_id': externalId,
    'track_fingerprint': trackFingerprint,
    'album_external_id': albumExternalId,
    'artist_external_id': artistExternalId,
    'art_id': artId,
    'linked_at': linkedAt,
    'last_seen_at': lastSeenAt,
  };

  factory SyncLink.fromJson(Map<String, dynamic> json) => SyncLink(
    sourceId: json['source_id'] as String? ?? '',
    externalId: json['external_id'] as String? ?? '',
    trackFingerprint: json['track_fingerprint'] as String? ?? '',
    albumExternalId: json['album_external_id'] as String?,
    artistExternalId: json['artist_external_id'] as String?,
    artId: json['art_id'] as String?,
    linkedAt: json['linked_at'] as String? ?? '',
    lastSeenAt: json['last_seen_at'] as String? ?? '',
  );

  static SyncLink? tryFromJson(Object? raw) =>
      raw is Map ? SyncLink.fromJson(raw.cast<String, dynamic>()) : null;
}

/// One track's stored lyrics. [lines] stays the client's raw JSON string.
class SyncLyrics {
  const SyncLyrics({
    required this.trackFingerprint,
    required this.lines,
    required this.synced,
    this.language,
    required this.origin,
    this.remoteId,
    required this.fetchedAt,
    this.translationLanguage,
  });

  final String trackFingerprint;
  final String lines;
  final bool synced;
  final String? language;
  final String origin;
  final int? remoteId;
  final String fetchedAt;
  final String? translationLanguage;

  Map<String, dynamic> toJson() => {
    'track_fingerprint': trackFingerprint,
    'lines': lines,
    'synced': synced,
    'language': language,
    'origin': origin,
    'remote_id': remoteId,
    'fetched_at': fetchedAt,
    'translation_language': translationLanguage,
  };

  factory SyncLyrics.fromJson(Map<String, dynamic> json) => SyncLyrics(
    trackFingerprint: json['track_fingerprint'] as String? ?? '',
    lines: json['lines'] as String? ?? '',
    synced: json['synced'] == true,
    language: json['language'] as String?,
    origin: json['origin'] as String? ?? 'none',
    remoteId: (json['remote_id'] as num?)?.toInt(),
    fetchedAt: json['fetched_at'] as String? ?? '',
    translationLanguage: json['translation_language'] as String?,
  );

  static SyncLyrics? tryFromJson(Object? raw) =>
      raw is Map ? SyncLyrics.fromJson(raw.cast<String, dynamic>()) : null;
}

/// One play of one track, keyed by (fingerprint, startedAt). Append-only.
class SyncPlay {
  const SyncPlay({
    required this.trackFingerprint,
    required this.sourceId,
    required this.startedAt,
    required this.clock,
    this.listenedMs = 0,
    this.positionMs = 0,
    this.completed = false,
  });

  final String trackFingerprint;
  final String sourceId;
  final String startedAt;

  /// max(startedAt, the row's last in-place update).
  final String clock;
  final int listenedMs;
  final int positionMs;
  final bool completed;

  Map<String, dynamic> toJson() => {
    'track_fingerprint': trackFingerprint,
    'source_id': sourceId,
    'started_at': startedAt,
    'clock': clock,
    'listened_ms': listenedMs,
    'position_ms': positionMs,
    'completed': completed,
  };

  factory SyncPlay.fromJson(Map<String, dynamic> json) => SyncPlay(
    trackFingerprint: json['track_fingerprint'] as String? ?? '',
    sourceId: json['source_id'] as String? ?? '',
    startedAt: json['started_at'] as String? ?? '',
    clock: json['clock'] as String? ?? '',
    listenedMs: (json['listened_ms'] as num?)?.toInt() ?? 0,
    positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
    completed: json['completed'] == true,
  );

  static SyncPlay? tryFromJson(Object? raw) =>
      raw is Map ? SyncPlay.fromJson(raw.cast<String, dynamic>()) : null;
}

/// The account's singleton playback session.
class SyncSession {
  const SyncSession({
    required this.queueJson,
    this.currentIndex,
    this.positionMs = 0,
    this.durationMs = 0,
    this.shuffle = false,
    this.repeatMode = 'off',
    required this.updatedAt,
  });

  final String queueJson;
  final int? currentIndex;
  final int positionMs;
  final int durationMs;
  final bool shuffle;
  final String repeatMode;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
    'queue_json': queueJson,
    'current_index': currentIndex,
    'position_ms': positionMs,
    'duration_ms': durationMs,
    'shuffle': shuffle,
    'repeat_mode': repeatMode,
    'updated_at': updatedAt,
  };

  factory SyncSession.fromJson(Map<String, dynamic> json) => SyncSession(
    queueJson: json['queue_json'] as String? ?? '',
    currentIndex: (json['current_index'] as num?)?.toInt(),
    positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
    durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
    shuffle: json['shuffle'] == true,
    repeatMode: json['repeat_mode'] as String? ?? 'off',
    updatedAt: json['updated_at'] as String? ?? '',
  );

  static SyncSession? tryFromJson(Object? raw) =>
      raw is Map ? SyncSession.fromJson(raw.cast<String, dynamic>()) : null;
}

/// The outcome of one push.
class SyncPushResult {
  const SyncPushResult({required this.rev, required this.rejected});

  final int rev;

  /// Indices in the pushed batch whose clock was older than the stored row.
  final List<int> rejected;

  factory SyncPushResult.fromJson(Map<String, dynamic> json) => SyncPushResult(
    rev: (json['rev'] as num?)?.toInt() ?? 0,
    rejected: [
      for (final index in (json['rejected'] as List?) ?? const [])
        if (index is num) index.toInt(),
    ],
  );
}

/// One page of the account's mirror.
class PullPage {
  const PullPage({
    required this.rev,
    required this.hasMore,
    this.sessionClock,
    this.settingsClock,
    this.tracks = const [],
    this.links = const [],
    this.lyrics = const [],
    this.plays = const [],
    this.session,
    this.settings = const {},
    this.removed = const {},
  });

  final int rev;
  final bool hasMore;
  final String? sessionClock;
  final String? settingsClock;
  final List<SyncTrack> tracks;
  final List<SyncLink> links;
  final List<SyncLyrics> lyrics;
  final List<SyncPlay> plays;

  /// Null for a cleared session: the clock in [sessionClock] still advances.
  final SyncSession? session;

  /// Empty for cleared settings: the clock in [settingsClock] still advances.
  final Map<String, dynamic> settings;

  /// Entity wire name to encoded natural keys carrying the tombstone clock.
  final Map<String, List<String>> removed;

  factory PullPage.fromJson(Map<String, dynamic> json) => PullPage(
    rev: (json['rev'] as num?)?.toInt() ?? 0,
    hasMore: json['has_more'] == true,
    sessionClock: json['session_clock'] as String?,
    settingsClock: json['settings_clock'] as String?,
    tracks: [
      for (final raw in (json['tracks'] as List?) ?? const [])
        if (raw is Map) SyncTrack.fromJson(raw.cast<String, dynamic>()),
    ],
    links: [
      for (final raw in (json['links'] as List?) ?? const [])
        if (raw is Map) SyncLink.fromJson(raw.cast<String, dynamic>()),
    ],
    lyrics: [
      for (final raw in (json['lyrics'] as List?) ?? const [])
        if (raw is Map) SyncLyrics.fromJson(raw.cast<String, dynamic>()),
    ],
    plays: [
      for (final raw in (json['plays'] as List?) ?? const [])
        if (raw is Map) SyncPlay.fromJson(raw.cast<String, dynamic>()),
    ],
    session: SyncSession.tryFromJson(json['session']),
    settings: (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    removed: _removedFrom(json['removed']),
  );
}

/// The account's mirror summary.
class LibrarySyncStatus {
  const LibrarySyncStatus({
    this.rev = 0,
    this.tracks = 0,
    this.plays = 0,
    this.deviceCount = 0,
    this.lastDevice,
  });

  final int rev;
  final int tracks;
  final int plays;
  final int deviceCount;
  final String? lastDevice;

  factory LibrarySyncStatus.fromJson(Map<String, dynamic> json) =>
      LibrarySyncStatus(
        rev: (json['rev'] as num?)?.toInt() ?? 0,
        tracks: (json['tracks'] as num?)?.toInt() ?? 0,
        plays: (json['plays'] as num?)?.toInt() ?? 0,
        deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
        lastDevice: (json['last_device'] as String?)?.isEmpty ?? true
            ? null
            : json['last_device'] as String?,
      );
}

Map<String, List<String>> _removedFrom(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is List)
        entry.key.toString(): [
          for (final key in entry.value as List)
            if (key is String) key,
        ],
  };
}

/// One tombstone, decoded from a [PullPage.removed] entry.
class RemovedEntry {
  const RemovedEntry({required this.fields, required this.deletedAt});

  final Map<String, dynamic> fields;
  final DateTime deletedAt;
}
