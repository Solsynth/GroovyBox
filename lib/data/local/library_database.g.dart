// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_database.dart';

// ignore_for_file: type=lint
class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    artist,
    albumArtist,
    album,
    genre,
    year,
    trackNumber,
    discNumber,
    durationMs,
    fingerprint,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final int id;
  final String title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int durationMs;

  /// [trackFingerprint] at first sight. It is the key a second source is
  /// matched on, and it is deliberately not recomputed when metadata is
  /// re-tagged: the row's identity is what it was when it was first adopted.
  final String fingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TrackRow({
    required this.id,
    required this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    required this.durationMs,
    required this.fingerprint,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      durationMs: Value(durationMs),
      fingerprint: Value(fingerprint),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      album: serializer.fromJson<String?>(json['album']),
      genre: serializer.fromJson<String?>(json['genre']),
      year: serializer.fromJson<int?>(json['year']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'album': serializer.toJson<String?>(album),
      'genre': serializer.toJson<String?>(genre),
      'year': serializer.toJson<int?>(year),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'discNumber': serializer.toJson<int?>(discNumber),
      'durationMs': serializer.toJson<int>(durationMs),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrackRow copyWith({
    int? id,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> albumArtist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    int? durationMs,
    String? fingerprint,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TrackRow(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
    album: album.present ? album.value : this.album,
    genre: genre.present ? genre.value : this.genre,
    year: year.present ? year.value : this.year,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    durationMs: durationMs ?? this.durationMs,
    fingerprint: fingerprint ?? this.fingerprint,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      album: data.album.present ? data.album.value : this.album,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    artist,
    albumArtist,
    album,
    genre,
    year,
    trackNumber,
    discNumber,
    durationMs,
    fingerprint,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.albumArtist == this.albumArtist &&
          other.album == this.album &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.trackNumber == this.trackNumber &&
          other.discNumber == this.discNumber &&
          other.durationMs == this.durationMs &&
          other.fingerprint == this.fingerprint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> albumArtist;
  final Value<String?> album;
  final Value<String?> genre;
  final Value<int?> year;
  final Value<int?> trackNumber;
  final Value<int?> discNumber;
  final Value<int> durationMs;
  final Value<String> fingerprint;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.artist = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMs = const Value.absent(),
    required String fingerprint,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : title = Value(title),
       fingerprint = Value(fingerprint),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TrackRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? albumArtist,
    Expression<String>? album,
    Expression<String>? genre,
    Expression<int>? year,
    Expression<int>? trackNumber,
    Expression<int>? discNumber,
    Expression<int>? durationMs,
    Expression<String>? fingerprint,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (album != null) 'album': album,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
      if (durationMs != null) 'duration_ms': durationMs,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? albumArtist,
    Value<String?>? album,
    Value<String?>? genre,
    Value<int?>? year,
    Value<int?>? trackNumber,
    Value<int?>? discNumber,
    Value<int>? durationMs,
    Value<String>? fingerprint,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArtist: albumArtist ?? this.albumArtist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationMs: durationMs ?? this.durationMs,
      fingerprint: fingerprint ?? this.fingerprint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TrackLinksTable extends TrackLinks
    with TableInfo<$TrackLinksTable, TrackLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumExternalIdMeta = const VerificationMeta(
    'albumExternalId',
  );
  @override
  late final GeneratedColumn<String> albumExternalId = GeneratedColumn<String>(
    'album_external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistExternalIdMeta = const VerificationMeta(
    'artistExternalId',
  );
  @override
  late final GeneratedColumn<String> artistExternalId = GeneratedColumn<String>(
    'artist_external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artIdMeta = const VerificationMeta('artId');
  @override
  late final GeneratedColumn<String> artId = GeneratedColumn<String>(
    'art_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedAtMeta = const VerificationMeta(
    'linkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> linkedAt = GeneratedColumn<DateTime>(
    'linked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    sourceId,
    externalId,
    albumExternalId,
    artistExternalId,
    artId,
    linkedAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackLinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('album_external_id')) {
      context.handle(
        _albumExternalIdMeta,
        albumExternalId.isAcceptableOrUnknown(
          data['album_external_id']!,
          _albumExternalIdMeta,
        ),
      );
    }
    if (data.containsKey('artist_external_id')) {
      context.handle(
        _artistExternalIdMeta,
        artistExternalId.isAcceptableOrUnknown(
          data['artist_external_id']!,
          _artistExternalIdMeta,
        ),
      );
    }
    if (data.containsKey('art_id')) {
      context.handle(
        _artIdMeta,
        artId.isAcceptableOrUnknown(data['art_id']!, _artIdMeta),
      );
    }
    if (data.containsKey('linked_at')) {
      context.handle(
        _linkedAtMeta,
        linkedAt.isAcceptableOrUnknown(data['linked_at']!, _linkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_linkedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, externalId},
  ];
  @override
  TrackLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackLinkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      albumExternalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_external_id'],
      ),
      artistExternalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_external_id'],
      ),
      artId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}art_id'],
      ),
      linkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}linked_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $TrackLinksTable createAlias(String alias) {
    return $TrackLinksTable(attachedDatabase, alias);
  }
}

class TrackLinkRow extends DataClass implements Insertable<TrackLinkRow> {
  final int id;
  final int trackId;
  final String sourceId;
  final String externalId;
  final String? albumExternalId;
  final String? artistExternalId;
  final String? artId;
  final DateTime linkedAt;
  final DateTime lastSeenAt;
  const TrackLinkRow({
    required this.id,
    required this.trackId,
    required this.sourceId,
    required this.externalId,
    this.albumExternalId,
    this.artistExternalId,
    this.artId,
    required this.linkedAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['source_id'] = Variable<String>(sourceId);
    map['external_id'] = Variable<String>(externalId);
    if (!nullToAbsent || albumExternalId != null) {
      map['album_external_id'] = Variable<String>(albumExternalId);
    }
    if (!nullToAbsent || artistExternalId != null) {
      map['artist_external_id'] = Variable<String>(artistExternalId);
    }
    if (!nullToAbsent || artId != null) {
      map['art_id'] = Variable<String>(artId);
    }
    map['linked_at'] = Variable<DateTime>(linkedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  TrackLinksCompanion toCompanion(bool nullToAbsent) {
    return TrackLinksCompanion(
      id: Value(id),
      trackId: Value(trackId),
      sourceId: Value(sourceId),
      externalId: Value(externalId),
      albumExternalId: albumExternalId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumExternalId),
      artistExternalId: artistExternalId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistExternalId),
      artId: artId == null && nullToAbsent
          ? const Value.absent()
          : Value(artId),
      linkedAt: Value(linkedAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory TrackLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackLinkRow(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      externalId: serializer.fromJson<String>(json['externalId']),
      albumExternalId: serializer.fromJson<String?>(json['albumExternalId']),
      artistExternalId: serializer.fromJson<String?>(json['artistExternalId']),
      artId: serializer.fromJson<String?>(json['artId']),
      linkedAt: serializer.fromJson<DateTime>(json['linkedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'sourceId': serializer.toJson<String>(sourceId),
      'externalId': serializer.toJson<String>(externalId),
      'albumExternalId': serializer.toJson<String?>(albumExternalId),
      'artistExternalId': serializer.toJson<String?>(artistExternalId),
      'artId': serializer.toJson<String?>(artId),
      'linkedAt': serializer.toJson<DateTime>(linkedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  TrackLinkRow copyWith({
    int? id,
    int? trackId,
    String? sourceId,
    String? externalId,
    Value<String?> albumExternalId = const Value.absent(),
    Value<String?> artistExternalId = const Value.absent(),
    Value<String?> artId = const Value.absent(),
    DateTime? linkedAt,
    DateTime? lastSeenAt,
  }) => TrackLinkRow(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    sourceId: sourceId ?? this.sourceId,
    externalId: externalId ?? this.externalId,
    albumExternalId: albumExternalId.present
        ? albumExternalId.value
        : this.albumExternalId,
    artistExternalId: artistExternalId.present
        ? artistExternalId.value
        : this.artistExternalId,
    artId: artId.present ? artId.value : this.artId,
    linkedAt: linkedAt ?? this.linkedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  TrackLinkRow copyWithCompanion(TrackLinksCompanion data) {
    return TrackLinkRow(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      albumExternalId: data.albumExternalId.present
          ? data.albumExternalId.value
          : this.albumExternalId,
      artistExternalId: data.artistExternalId.present
          ? data.artistExternalId.value
          : this.artistExternalId,
      artId: data.artId.present ? data.artId.value : this.artId,
      linkedAt: data.linkedAt.present ? data.linkedAt.value : this.linkedAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackLinkRow(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('sourceId: $sourceId, ')
          ..write('externalId: $externalId, ')
          ..write('albumExternalId: $albumExternalId, ')
          ..write('artistExternalId: $artistExternalId, ')
          ..write('artId: $artId, ')
          ..write('linkedAt: $linkedAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    sourceId,
    externalId,
    albumExternalId,
    artistExternalId,
    artId,
    linkedAt,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackLinkRow &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.sourceId == this.sourceId &&
          other.externalId == this.externalId &&
          other.albumExternalId == this.albumExternalId &&
          other.artistExternalId == this.artistExternalId &&
          other.artId == this.artId &&
          other.linkedAt == this.linkedAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class TrackLinksCompanion extends UpdateCompanion<TrackLinkRow> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<String> sourceId;
  final Value<String> externalId;
  final Value<String?> albumExternalId;
  final Value<String?> artistExternalId;
  final Value<String?> artId;
  final Value<DateTime> linkedAt;
  final Value<DateTime> lastSeenAt;
  const TrackLinksCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.albumExternalId = const Value.absent(),
    this.artistExternalId = const Value.absent(),
    this.artId = const Value.absent(),
    this.linkedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
  });
  TrackLinksCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required String sourceId,
    required String externalId,
    this.albumExternalId = const Value.absent(),
    this.artistExternalId = const Value.absent(),
    this.artId = const Value.absent(),
    required DateTime linkedAt,
    required DateTime lastSeenAt,
  }) : trackId = Value(trackId),
       sourceId = Value(sourceId),
       externalId = Value(externalId),
       linkedAt = Value(linkedAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<TrackLinkRow> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<String>? sourceId,
    Expression<String>? externalId,
    Expression<String>? albumExternalId,
    Expression<String>? artistExternalId,
    Expression<String>? artId,
    Expression<DateTime>? linkedAt,
    Expression<DateTime>? lastSeenAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (sourceId != null) 'source_id': sourceId,
      if (externalId != null) 'external_id': externalId,
      if (albumExternalId != null) 'album_external_id': albumExternalId,
      if (artistExternalId != null) 'artist_external_id': artistExternalId,
      if (artId != null) 'art_id': artId,
      if (linkedAt != null) 'linked_at': linkedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
    });
  }

  TrackLinksCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<String>? sourceId,
    Value<String>? externalId,
    Value<String?>? albumExternalId,
    Value<String?>? artistExternalId,
    Value<String?>? artId,
    Value<DateTime>? linkedAt,
    Value<DateTime>? lastSeenAt,
  }) {
    return TrackLinksCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      sourceId: sourceId ?? this.sourceId,
      externalId: externalId ?? this.externalId,
      albumExternalId: albumExternalId ?? this.albumExternalId,
      artistExternalId: artistExternalId ?? this.artistExternalId,
      artId: artId ?? this.artId,
      linkedAt: linkedAt ?? this.linkedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (albumExternalId.present) {
      map['album_external_id'] = Variable<String>(albumExternalId.value);
    }
    if (artistExternalId.present) {
      map['artist_external_id'] = Variable<String>(artistExternalId.value);
    }
    if (artId.present) {
      map['art_id'] = Variable<String>(artId.value);
    }
    if (linkedAt.present) {
      map['linked_at'] = Variable<DateTime>(linkedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackLinksCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('sourceId: $sourceId, ')
          ..write('externalId: $externalId, ')
          ..write('albumExternalId: $albumExternalId, ')
          ..write('artistExternalId: $artistExternalId, ')
          ..write('artId: $artId, ')
          ..write('linkedAt: $linkedAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }
}

class $LyricsEntriesTable extends LyricsEntries
    with TableInfo<$LyricsEntriesTable, LyricsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _linesMeta = const VerificationMeta('lines');
  @override
  late final GeneratedColumn<String> lines = GeneratedColumn<String>(
    'lines',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    lines,
    synced,
    language,
    origin,
    remoteId,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('lines')) {
      context.handle(
        _linesMeta,
        lines.isAcceptableOrUnknown(data['lines']!, _linesMeta),
      );
    } else if (isInserting) {
      context.missing(_linesMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  LyricsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsRow(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      lines: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lines'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_id'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $LyricsEntriesTable createAlias(String alias) {
    return $LyricsEntriesTable(attachedDatabase, alias);
  }
}

class LyricsRow extends DataClass implements Insertable<LyricsRow> {
  final int trackId;
  final String lines;
  final bool synced;
  final String? language;
  final String origin;
  final int? remoteId;
  final DateTime fetchedAt;
  const LyricsRow({
    required this.trackId,
    required this.lines,
    required this.synced,
    this.language,
    required this.origin,
    this.remoteId,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['lines'] = Variable<String>(lines);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  LyricsEntriesCompanion toCompanion(bool nullToAbsent) {
    return LyricsEntriesCompanion(
      trackId: Value(trackId),
      lines: Value(lines),
      synced: Value(synced),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      origin: Value(origin),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory LyricsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsRow(
      trackId: serializer.fromJson<int>(json['trackId']),
      lines: serializer.fromJson<String>(json['lines']),
      synced: serializer.fromJson<bool>(json['synced']),
      language: serializer.fromJson<String?>(json['language']),
      origin: serializer.fromJson<String>(json['origin']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'lines': serializer.toJson<String>(lines),
      'synced': serializer.toJson<bool>(synced),
      'language': serializer.toJson<String?>(language),
      'origin': serializer.toJson<String>(origin),
      'remoteId': serializer.toJson<int?>(remoteId),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  LyricsRow copyWith({
    int? trackId,
    String? lines,
    bool? synced,
    Value<String?> language = const Value.absent(),
    String? origin,
    Value<int?> remoteId = const Value.absent(),
    DateTime? fetchedAt,
  }) => LyricsRow(
    trackId: trackId ?? this.trackId,
    lines: lines ?? this.lines,
    synced: synced ?? this.synced,
    language: language.present ? language.value : this.language,
    origin: origin ?? this.origin,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  LyricsRow copyWithCompanion(LyricsEntriesCompanion data) {
    return LyricsRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      lines: data.lines.present ? data.lines.value : this.lines,
      synced: data.synced.present ? data.synced.value : this.synced,
      language: data.language.present ? data.language.value : this.language,
      origin: data.origin.present ? data.origin.value : this.origin,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsRow(')
          ..write('trackId: $trackId, ')
          ..write('lines: $lines, ')
          ..write('synced: $synced, ')
          ..write('language: $language, ')
          ..write('origin: $origin, ')
          ..write('remoteId: $remoteId, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trackId,
    lines,
    synced,
    language,
    origin,
    remoteId,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsRow &&
          other.trackId == this.trackId &&
          other.lines == this.lines &&
          other.synced == this.synced &&
          other.language == this.language &&
          other.origin == this.origin &&
          other.remoteId == this.remoteId &&
          other.fetchedAt == this.fetchedAt);
}

class LyricsEntriesCompanion extends UpdateCompanion<LyricsRow> {
  final Value<int> trackId;
  final Value<String> lines;
  final Value<bool> synced;
  final Value<String?> language;
  final Value<String> origin;
  final Value<int?> remoteId;
  final Value<DateTime> fetchedAt;
  const LyricsEntriesCompanion({
    this.trackId = const Value.absent(),
    this.lines = const Value.absent(),
    this.synced = const Value.absent(),
    this.language = const Value.absent(),
    this.origin = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  LyricsEntriesCompanion.insert({
    this.trackId = const Value.absent(),
    required String lines,
    required bool synced,
    this.language = const Value.absent(),
    required String origin,
    this.remoteId = const Value.absent(),
    required DateTime fetchedAt,
  }) : lines = Value(lines),
       synced = Value(synced),
       origin = Value(origin),
       fetchedAt = Value(fetchedAt);
  static Insertable<LyricsRow> custom({
    Expression<int>? trackId,
    Expression<String>? lines,
    Expression<bool>? synced,
    Expression<String>? language,
    Expression<String>? origin,
    Expression<int>? remoteId,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (lines != null) 'lines': lines,
      if (synced != null) 'synced': synced,
      if (language != null) 'language': language,
      if (origin != null) 'origin': origin,
      if (remoteId != null) 'remote_id': remoteId,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  LyricsEntriesCompanion copyWith({
    Value<int>? trackId,
    Value<String>? lines,
    Value<bool>? synced,
    Value<String?>? language,
    Value<String>? origin,
    Value<int?>? remoteId,
    Value<DateTime>? fetchedAt,
  }) {
    return LyricsEntriesCompanion(
      trackId: trackId ?? this.trackId,
      lines: lines ?? this.lines,
      synced: synced ?? this.synced,
      language: language ?? this.language,
      origin: origin ?? this.origin,
      remoteId: remoteId ?? this.remoteId,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (lines.present) {
      map['lines'] = Variable<String>(lines.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsEntriesCompanion(')
          ..write('trackId: $trackId, ')
          ..write('lines: $lines, ')
          ..write('synced: $synced, ')
          ..write('language: $language, ')
          ..write('origin: $origin, ')
          ..write('remoteId: $remoteId, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class $PlayEventsTable extends PlayEvents
    with TableInfo<$PlayEventsTable, PlayEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listenedMsMeta = const VerificationMeta(
    'listenedMs',
  );
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
    'listened_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    sourceId,
    startedAt,
    listenedMs,
    positionMs,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
        _listenedMsMeta,
        listenedMs.isAcceptableOrUnknown(data['listened_ms']!, _listenedMsMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      listenedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listened_ms'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $PlayEventsTable createAlias(String alias) {
    return $PlayEventsTable(attachedDatabase, alias);
  }
}

class PlayEventRow extends DataClass implements Insertable<PlayEventRow> {
  final int id;
  final int trackId;
  final String sourceId;
  final DateTime startedAt;
  final int listenedMs;
  final int positionMs;
  final bool completed;
  const PlayEventRow({
    required this.id,
    required this.trackId,
    required this.sourceId,
    required this.startedAt,
    required this.listenedMs,
    required this.positionMs,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['source_id'] = Variable<String>(sourceId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['listened_ms'] = Variable<int>(listenedMs);
    map['position_ms'] = Variable<int>(positionMs);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  PlayEventsCompanion toCompanion(bool nullToAbsent) {
    return PlayEventsCompanion(
      id: Value(id),
      trackId: Value(trackId),
      sourceId: Value(sourceId),
      startedAt: Value(startedAt),
      listenedMs: Value(listenedMs),
      positionMs: Value(positionMs),
      completed: Value(completed),
    );
  }

  factory PlayEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayEventRow(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      listenedMs: serializer.fromJson<int>(json['listenedMs']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'sourceId': serializer.toJson<String>(sourceId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'listenedMs': serializer.toJson<int>(listenedMs),
      'positionMs': serializer.toJson<int>(positionMs),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  PlayEventRow copyWith({
    int? id,
    int? trackId,
    String? sourceId,
    DateTime? startedAt,
    int? listenedMs,
    int? positionMs,
    bool? completed,
  }) => PlayEventRow(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    sourceId: sourceId ?? this.sourceId,
    startedAt: startedAt ?? this.startedAt,
    listenedMs: listenedMs ?? this.listenedMs,
    positionMs: positionMs ?? this.positionMs,
    completed: completed ?? this.completed,
  );
  PlayEventRow copyWithCompanion(PlayEventsCompanion data) {
    return PlayEventRow(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      listenedMs: data.listenedMs.present
          ? data.listenedMs.value
          : this.listenedMs,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayEventRow(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('sourceId: $sourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('positionMs: $positionMs, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    sourceId,
    startedAt,
    listenedMs,
    positionMs,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayEventRow &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.sourceId == this.sourceId &&
          other.startedAt == this.startedAt &&
          other.listenedMs == this.listenedMs &&
          other.positionMs == this.positionMs &&
          other.completed == this.completed);
}

class PlayEventsCompanion extends UpdateCompanion<PlayEventRow> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<String> sourceId;
  final Value<DateTime> startedAt;
  final Value<int> listenedMs;
  final Value<int> positionMs;
  final Value<bool> completed;
  const PlayEventsCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.completed = const Value.absent(),
  });
  PlayEventsCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required String sourceId,
    required DateTime startedAt,
    this.listenedMs = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.completed = const Value.absent(),
  }) : trackId = Value(trackId),
       sourceId = Value(sourceId),
       startedAt = Value(startedAt);
  static Insertable<PlayEventRow> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<String>? sourceId,
    Expression<DateTime>? startedAt,
    Expression<int>? listenedMs,
    Expression<int>? positionMs,
    Expression<bool>? completed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (sourceId != null) 'source_id': sourceId,
      if (startedAt != null) 'started_at': startedAt,
      if (listenedMs != null) 'listened_ms': listenedMs,
      if (positionMs != null) 'position_ms': positionMs,
      if (completed != null) 'completed': completed,
    });
  }

  PlayEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<String>? sourceId,
    Value<DateTime>? startedAt,
    Value<int>? listenedMs,
    Value<int>? positionMs,
    Value<bool>? completed,
  }) {
    return PlayEventsCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      sourceId: sourceId ?? this.sourceId,
      startedAt: startedAt ?? this.startedAt,
      listenedMs: listenedMs ?? this.listenedMs,
      positionMs: positionMs ?? this.positionMs,
      completed: completed ?? this.completed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayEventsCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('sourceId: $sourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('positionMs: $positionMs, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDatabase extends GeneratedDatabase {
  _$LibraryDatabase(QueryExecutor e) : super(e);
  $LibraryDatabaseManager get managers => $LibraryDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $TrackLinksTable trackLinks = $TrackLinksTable(this);
  late final $LyricsEntriesTable lyricsEntries = $LyricsEntriesTable(this);
  late final $PlayEventsTable playEvents = $PlayEventsTable(this);
  late final Index trackLinksTrack = Index(
    'track_links_track',
    'CREATE INDEX track_links_track ON track_links (track_id)',
  );
  late final Index playEventsTrack = Index(
    'play_events_track',
    'CREATE INDEX play_events_track ON play_events (track_id)',
  );
  late final Index playEventsStarted = Index(
    'play_events_started',
    'CREATE INDEX play_events_started ON play_events (started_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tracks,
    trackLinks,
    lyricsEntries,
    playEvents,
    trackLinksTrack,
    playEventsTrack,
    playEventsStarted,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lyrics_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('play_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  required String title,
  Value<String?> artist,
  Value<String?> albumArtist,
  Value<String?> album,
  Value<String?> genre,
  Value<int?> year,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int> durationMs,
  required String fingerprint,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String?> artist,
  Value<String?> albumArtist,
  Value<String?> album,
  Value<String?> genre,
  Value<int?> year,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int> durationMs,
  Value<String> fingerprint,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$TracksTableReferences
    extends BaseReferences<_$LibraryDatabase, $TracksTable, TrackRow> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrackLinksTable, List<TrackLinkRow>>
  _trackLinksRefsTable(_$LibraryDatabase db) => MultiTypedResultKey.fromTable(
    db.trackLinks,
    aliasName: 'tracks__id__track_links__track_id',
  );

  $$TrackLinksTableProcessedTableManager get trackLinksRefs {
    final manager = $$TrackLinksTableTableManager(
      $_db,
      $_db.trackLinks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LyricsEntriesTable, List<LyricsRow>>
  _lyricsEntriesRefsTable(_$LibraryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.lyricsEntries,
        aliasName: 'tracks__id__lyrics_entries__track_id',
      );

  $$LyricsEntriesTableProcessedTableManager get lyricsEntriesRefs {
    final manager = $$LyricsEntriesTableTableManager(
      $_db,
      $_db.lyricsEntries,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lyricsEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlayEventsTable, List<PlayEventRow>>
  _playEventsRefsTable(_$LibraryDatabase db) => MultiTypedResultKey.fromTable(
    db.playEvents,
    aliasName: 'tracks__id__play_events__track_id',
  );

  $$PlayEventsTableProcessedTableManager get playEventsRefs {
    final manager = $$PlayEventsTableTableManager(
      $_db,
      $_db.playEvents,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$LibraryDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trackLinksRefs(
    Expression<bool> Function($$TrackLinksTableFilterComposer f) f,
  ) {
    final $$TrackLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackLinks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackLinksTableFilterComposer(
            $db: $db,
            $table: $db.trackLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lyricsEntriesRefs(
    Expression<bool> Function($$LyricsEntriesTableFilterComposer f) f,
  ) {
    final $$LyricsEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricsEntries,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsEntriesTableFilterComposer(
            $db: $db,
            $table: $db.lyricsEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playEventsRefs(
    Expression<bool> Function($$PlayEventsTableFilterComposer f) f,
  ) {
    final $$PlayEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playEvents,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayEventsTableFilterComposer(
            $db: $db,
            $table: $db.playEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$LibraryDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> trackLinksRefs<T extends Object>(
    Expression<T> Function($$TrackLinksTableAnnotationComposer a) f,
  ) {
    final $$TrackLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackLinks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.trackLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lyricsEntriesRefs<T extends Object>(
    Expression<T> Function($$LyricsEntriesTableAnnotationComposer a) f,
  ) {
    final $$LyricsEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricsEntries,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.lyricsEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playEventsRefs<T extends Object>(
    Expression<T> Function($$PlayEventsTableAnnotationComposer a) f,
  ) {
    final $$PlayEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playEvents,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.playEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $TracksTable,
          TrackRow,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (TrackRow, $$TracksTableReferences),
          TrackRow,
          PrefetchHooks Function({
            bool trackLinksRefs,
            bool lyricsEntriesRefs,
            bool playEventsRefs,
          })
        > {
  $$TracksTableTableManager(_$LibraryDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                title: title,
                artist: artist,
                albumArtist: albumArtist,
                album: album,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMs: durationMs,
                fingerprint: fingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                required String fingerprint,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TracksCompanion.insert(
                id: id,
                title: title,
                artist: artist,
                albumArtist: albumArtist,
                album: album,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMs: durationMs,
                fingerprint: fingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, TrackRow>(table),
                  $$TracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                trackLinksRefs = false,
                lyricsEntriesRefs = false,
                playEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (trackLinksRefs) db.trackLinks,
                    if (lyricsEntriesRefs) db.lyricsEntries,
                    if (playEventsRefs) db.playEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (trackLinksRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          TrackLinkRow,
                          $TrackLinksTable
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._trackLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackLinksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (lyricsEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          LyricsRow,
                          $LyricsEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._lyricsEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).lyricsEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (playEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          PlayEventRow,
                          $PlayEventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $TracksTable,
      TrackRow,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (TrackRow, $$TracksTableReferences),
      TrackRow,
      PrefetchHooks Function({
        bool trackLinksRefs,
        bool lyricsEntriesRefs,
        bool playEventsRefs,
      })
    >;
typedef $$TrackLinksTableCreateCompanionBuilder = TrackLinksCompanion Function({
  Value<int> id,
  required int trackId,
  required String sourceId,
  required String externalId,
  Value<String?> albumExternalId,
  Value<String?> artistExternalId,
  Value<String?> artId,
  required DateTime linkedAt,
  required DateTime lastSeenAt,
});
typedef $$TrackLinksTableUpdateCompanionBuilder = TrackLinksCompanion Function({
  Value<int> id,
  Value<int> trackId,
  Value<String> sourceId,
  Value<String> externalId,
  Value<String?> albumExternalId,
  Value<String?> artistExternalId,
  Value<String?> artId,
  Value<DateTime> linkedAt,
  Value<DateTime> lastSeenAt,
});

final class $$TrackLinksTableReferences
    extends BaseReferences<_$LibraryDatabase, $TrackLinksTable, TrackLinkRow> {
  $$TrackLinksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$LibraryDatabase db) =>
      db.tracks.createAlias('track_links__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackLinksTableFilterComposer
    extends Composer<_$LibraryDatabase, $TrackLinksTable> {
  $$TrackLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumExternalId => $composableBuilder(
    column: $table.albumExternalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistExternalId => $composableBuilder(
    column: $table.artistExternalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artId => $composableBuilder(
    column: $table.artId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get linkedAt => $composableBuilder(
    column: $table.linkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackLinksTableOrderingComposer
    extends Composer<_$LibraryDatabase, $TrackLinksTable> {
  $$TrackLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumExternalId => $composableBuilder(
    column: $table.albumExternalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistExternalId => $composableBuilder(
    column: $table.artistExternalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artId => $composableBuilder(
    column: $table.artId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get linkedAt => $composableBuilder(
    column: $table.linkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackLinksTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $TrackLinksTable> {
  $$TrackLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumExternalId => $composableBuilder(
    column: $table.albumExternalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artistExternalId => $composableBuilder(
    column: $table.artistExternalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artId =>
      $composableBuilder(column: $table.artId, builder: (column) => column);

  GeneratedColumn<DateTime> get linkedAt =>
      $composableBuilder(column: $table.linkedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackLinksTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $TrackLinksTable,
          TrackLinkRow,
          $$TrackLinksTableFilterComposer,
          $$TrackLinksTableOrderingComposer,
          $$TrackLinksTableAnnotationComposer,
          $$TrackLinksTableCreateCompanionBuilder,
          $$TrackLinksTableUpdateCompanionBuilder,
          (TrackLinkRow, $$TrackLinksTableReferences),
          TrackLinkRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$TrackLinksTableTableManager(_$LibraryDatabase db, $TrackLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String?> albumExternalId = const Value.absent(),
                Value<String?> artistExternalId = const Value.absent(),
                Value<String?> artId = const Value.absent(),
                Value<DateTime> linkedAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
              }) => TrackLinksCompanion(
                id: id,
                trackId: trackId,
                sourceId: sourceId,
                externalId: externalId,
                albumExternalId: albumExternalId,
                artistExternalId: artistExternalId,
                artId: artId,
                linkedAt: linkedAt,
                lastSeenAt: lastSeenAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required String sourceId,
                required String externalId,
                Value<String?> albumExternalId = const Value.absent(),
                Value<String?> artistExternalId = const Value.absent(),
                Value<String?> artId = const Value.absent(),
                required DateTime linkedAt,
                required DateTime lastSeenAt,
              }) => TrackLinksCompanion.insert(
                id: id,
                trackId: trackId,
                sourceId: sourceId,
                externalId: externalId,
                albumExternalId: albumExternalId,
                artistExternalId: artistExternalId,
                artId: artId,
                linkedAt: linkedAt,
                lastSeenAt: lastSeenAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackLinksTable, TrackLinkRow>(table),
                  $$TrackLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$TrackLinksTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackLinksTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $TrackLinksTable,
      TrackLinkRow,
      $$TrackLinksTableFilterComposer,
      $$TrackLinksTableOrderingComposer,
      $$TrackLinksTableAnnotationComposer,
      $$TrackLinksTableCreateCompanionBuilder,
      $$TrackLinksTableUpdateCompanionBuilder,
      (TrackLinkRow, $$TrackLinksTableReferences),
      TrackLinkRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$LyricsEntriesTableCreateCompanionBuilder =
    LyricsEntriesCompanion Function({
      Value<int> trackId,
      required String lines,
      required bool synced,
      Value<String?> language,
      required String origin,
      Value<int?> remoteId,
      required DateTime fetchedAt,
    });
typedef $$LyricsEntriesTableUpdateCompanionBuilder =
    LyricsEntriesCompanion Function({
      Value<int> trackId,
      Value<String> lines,
      Value<bool> synced,
      Value<String?> language,
      Value<String> origin,
      Value<int?> remoteId,
      Value<DateTime> fetchedAt,
    });

final class $$LyricsEntriesTableReferences
    extends BaseReferences<_$LibraryDatabase, $LyricsEntriesTable, LyricsRow> {
  $$LyricsEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TracksTable _trackIdTable(_$LibraryDatabase db) =>
      db.tracks.createAlias('lyrics_entries__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LyricsEntriesTableFilterComposer
    extends Composer<_$LibraryDatabase, $LyricsEntriesTable> {
  $$LyricsEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lines => $composableBuilder(
    column: $table.lines,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsEntriesTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LyricsEntriesTable> {
  $$LyricsEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lines => $composableBuilder(
    column: $table.lines,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsEntriesTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LyricsEntriesTable> {
  $$LyricsEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lines =>
      $composableBuilder(column: $table.lines, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsEntriesTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LyricsEntriesTable,
          LyricsRow,
          $$LyricsEntriesTableFilterComposer,
          $$LyricsEntriesTableOrderingComposer,
          $$LyricsEntriesTableAnnotationComposer,
          $$LyricsEntriesTableCreateCompanionBuilder,
          $$LyricsEntriesTableUpdateCompanionBuilder,
          (LyricsRow, $$LyricsEntriesTableReferences),
          LyricsRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$LyricsEntriesTableTableManager(
    _$LibraryDatabase db,
    $LyricsEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String> lines = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<int?> remoteId = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => LyricsEntriesCompanion(
                trackId: trackId,
                lines: lines,
                synced: synced,
                language: language,
                origin: origin,
                remoteId: remoteId,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                required String lines,
                required bool synced,
                Value<String?> language = const Value.absent(),
                required String origin,
                Value<int?> remoteId = const Value.absent(),
                required DateTime fetchedAt,
              }) => LyricsEntriesCompanion.insert(
                trackId: trackId,
                lines: lines,
                synced: synced,
                language: language,
                origin: origin,
                remoteId: remoteId,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsEntriesTable, LyricsRow>(table),
                  $$LyricsEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$LyricsEntriesTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$LyricsEntriesTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LyricsEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LyricsEntriesTable,
      LyricsRow,
      $$LyricsEntriesTableFilterComposer,
      $$LyricsEntriesTableOrderingComposer,
      $$LyricsEntriesTableAnnotationComposer,
      $$LyricsEntriesTableCreateCompanionBuilder,
      $$LyricsEntriesTableUpdateCompanionBuilder,
      (LyricsRow, $$LyricsEntriesTableReferences),
      LyricsRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$PlayEventsTableCreateCompanionBuilder = PlayEventsCompanion Function({
  Value<int> id,
  required int trackId,
  required String sourceId,
  required DateTime startedAt,
  Value<int> listenedMs,
  Value<int> positionMs,
  Value<bool> completed,
});
typedef $$PlayEventsTableUpdateCompanionBuilder = PlayEventsCompanion Function({
  Value<int> id,
  Value<int> trackId,
  Value<String> sourceId,
  Value<DateTime> startedAt,
  Value<int> listenedMs,
  Value<int> positionMs,
  Value<bool> completed,
});

final class $$PlayEventsTableReferences
    extends BaseReferences<_$LibraryDatabase, $PlayEventsTable, PlayEventRow> {
  $$PlayEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$LibraryDatabase db) =>
      db.tracks.createAlias('play_events__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayEventsTableFilterComposer
    extends Composer<_$LibraryDatabase, $PlayEventsTable> {
  $$PlayEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayEventsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $PlayEventsTable> {
  $$PlayEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayEventsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $PlayEventsTable> {
  $$PlayEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayEventsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $PlayEventsTable,
          PlayEventRow,
          $$PlayEventsTableFilterComposer,
          $$PlayEventsTableOrderingComposer,
          $$PlayEventsTableAnnotationComposer,
          $$PlayEventsTableCreateCompanionBuilder,
          $$PlayEventsTableUpdateCompanionBuilder,
          (PlayEventRow, $$PlayEventsTableReferences),
          PlayEventRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$PlayEventsTableTableManager(_$LibraryDatabase db, $PlayEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> listenedMs = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlayEventsCompanion(
                id: id,
                trackId: trackId,
                sourceId: sourceId,
                startedAt: startedAt,
                listenedMs: listenedMs,
                positionMs: positionMs,
                completed: completed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required String sourceId,
                required DateTime startedAt,
                Value<int> listenedMs = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlayEventsCompanion.insert(
                id: id,
                trackId: trackId,
                sourceId: sourceId,
                startedAt: startedAt,
                listenedMs: listenedMs,
                positionMs: positionMs,
                completed: completed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayEventsTable, PlayEventRow>(table),
                  $$PlayEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlayEventsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlayEventsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlayEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $PlayEventsTable,
      PlayEventRow,
      $$PlayEventsTableFilterComposer,
      $$PlayEventsTableOrderingComposer,
      $$PlayEventsTableAnnotationComposer,
      $$PlayEventsTableCreateCompanionBuilder,
      $$PlayEventsTableUpdateCompanionBuilder,
      (PlayEventRow, $$PlayEventsTableReferences),
      PlayEventRow,
      PrefetchHooks Function({bool trackId})
    >;

class $LibraryDatabaseManager {
  final _$LibraryDatabase _db;
  $LibraryDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$TrackLinksTableTableManager get trackLinks =>
      $$TrackLinksTableTableManager(_db, _db.trackLinks);
  $$LyricsEntriesTableTableManager get lyricsEntries =>
      $$LyricsEntriesTableTableManager(_db, _db.lyricsEntries);
  $$PlayEventsTableTableManager get playEvents =>
      $$PlayEventsTableTableManager(_db, _db.playEvents);
}
