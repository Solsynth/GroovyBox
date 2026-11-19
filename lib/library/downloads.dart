/// Streaming tracks kept on this device, so a library you have heard keeps
/// playing when nobody can serve it.
///
/// A download is *not* an import. The import path (`local_import.dart`) takes a
/// file the user owns and adopts it as device-local music; this path takes a
/// library's own stream, writes it into the app's storage, and remembers the
/// link it came from. The canonical track, its lyrics and its history are
/// untouched, so removing a download removes bytes and nothing else.
///
/// Playback asks this first: a downloaded track opens from disk even when the
/// server is reachable, which is what makes it a download rather than a cache.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/identity.dart';
import '../data/local/library_database.dart';
import 'models.dart';
import 'providers.dart';
import 'source.dart';

part 'downloads.g.dart';

/// Where downloads live, under the app's support directory.
const kDownloadDirectory = 'downloads';

/// Holds files being written, so a half-finished download is never mistaken
/// for a playable one and a crash leaves no audio outside the sweep.
const kDownloadStagingDirectory = 'staging';

/// One track kept on this device, as the downloads page lists it.
class DownloadedTrack {
  final DownloadRow row;

  /// The library item it was copied from. The metadata is the row's, so a
  /// source that is gone still names the track it downloaded.
  final LibrarySong song;

  /// Absolute path of the audio file.
  final String filePath;

  /// Absolute path of the cover written beside it, or null when the library
  /// had none.
  final String? artPath;

  const DownloadedTrack({
    required this.row,
    required this.song,
    required this.filePath,
    this.artPath,
  });
}

/// One track's download state, in the words a row shows.
enum DownloadPhase { queued, running, done, failed }

/// What is happening to one item right now.
class DownloadProgress {
  final DownloadPhase phase;
  final double fraction;
  final String? error;

  const DownloadProgress(this.phase, {this.fraction = 0, this.error});

  bool get active =>
      phase == DownloadPhase.queued || phase == DownloadPhase.running;

  static const idle = DownloadProgress(DownloadPhase.done);
}

/// Copies a library's stream into the app's own storage and records it.
///
/// The service owns the files; the database owns the rows. Both live behind
/// [DownloadsController], which is what the UI and the transport read.
class DownloadService {
  DownloadService({
    required this.database,
    required this.directory,
    required this.sources,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final LibraryDatabase database;

  /// Absolute path of the download directory; row paths are relative to it.
  final String directory;

  /// The connected sources, read per download rather than captured: a library
  /// connected mid-session can download without the service being rebuilt.
  final Map<String, LibrarySource> Function() sources;

  final Dio _dio;

  File fileOf(DownloadRow row) => File(p.join(directory, row.path));

  /// The audio file of one library item, or null when it is not downloaded.
  ///
  /// Also answers null when the row outlived its bytes (a file deleted behind
  /// the app's back): a download that cannot play is not a download.
  Future<String?> downloadedFile(LibrarySong song) async {
    final row = await database.downloadOf(song.sourceId, song.id);
    if (row == null) return null;
    final file = fileOf(row);
    return await file.exists() ? file.path : null;
  }

  /// Every download, newest first, as rows a page can draw.
  Future<List<DownloadedTrack>> all() async {
    final rows = await database.allDownloads();
    return [
      for (final row in rows)
        DownloadedTrack(
          row: row,
          song: songOf(row),
          filePath: fileOf(row).path,
          artPath: row.artPath == null
              ? null
              : p.join(directory, row.artPath!),
        ),
    ];
  }

  /// The song a row describes, for the downloads page.
  LibrarySong songOf(DownloadRow row) => LibrarySong(
    sourceId: row.sourceId,
    id: row.externalId,
    title: row.title,
    artist: row.artist,
    album: row.album,
    duration: Duration(milliseconds: row.durationMs),
    artId: row.artPath,
  );

  /// Whether [song] is already on this device.
  Future<bool> isDownloaded(LibrarySong song) async =>
      await downloadedFile(song) != null;

  /// Downloads one track, reporting progress as the bytes arrive.
  ///
  /// A track with no stream (a radio station, an Apple Music item) is refused
  /// before any request: those are not files a library can hand out.
  Future<void> download(
    LibrarySong song, {
    void Function(double fraction)? onProgress,
  }) async {
    if (song.isRadio) {
      throw const LibraryException(
        'A radio station cannot be downloaded.',
        messageKey: 'downloadsRadioUnsupported',
      );
    }
    final source = sources()[song.sourceId];
    if (source == null) {
      throw const LibraryException(
        'The library this track lives in is not connected.',
        messageKey: 'downloadsSourceMissing',
      );
    }
    if (source is PlatformPlayedSource) {
      throw const LibraryException(
        'This library is played by the system and cannot be copied.',
        messageKey: 'downloadsPlatformUnsupported',
      );
    }

    final existing = await downloadedFile(song);
    if (existing != null) return;

    await Directory(directory).create(recursive: true);
    final staging = await Directory(
      p.join(directory, kDownloadStagingDirectory),
    ).create(recursive: true);

    final uri = source is ResolvedStreamSource
        ? await source.resolveStreamUri(song)
        : source.streamUri(song);
    final headers = source.streamHeaders(song);

    final partial = File(
      p.join(staging.path, '${DateTime.now().microsecondsSinceEpoch}.part'),
    );
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            HttpHeaders.userAgentHeader: appUserAgent,
            ...headers,
          },
          // A server that refuses is an answer: the status is checked below
          // so its own code reaches the caller instead of a bare exception.
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status ~/ 100 != 2) {
        throw LibraryException(
          'The server refused the download (HTTP $status).',
          code: status,
          messageKey: 'downloadsHttpError',
          messageArgs: ['$status'],
        );
      }
      await _writeStream(response, partial, onProgress);
    } catch (_) {
      // A half-written file is not a copy: it is deleted before the failure
      // reaches the caller, and the rename below only ever sees a complete
      // answer.
      if (await partial.exists()) await partial.delete();
      rethrow;
    }

    final extension = _extensionOf(response, uri);
    final name = '${_slug('${song.artist ?? ''} ${song.title}')}-'
        '${_hash('${song.sourceId}:${song.id}')}$extension';
    final target = File(p.join(directory, name));
    await partial.rename(target.path);

    final artPath = await _downloadArtwork(source, song);
    final size = await target.length();
    await database.upsertDownload(
      DownloadsCompanion.insert(
        sourceId: song.sourceId,
        externalId: song.id,
        path: name,
        sizeBytes: size,
        title: song.title,
        durationMs: Value(song.duration.inMilliseconds),
        downloadedAt: DateTime.now(),
        artist: Value.absentIfNull(song.artist),
        album: Value.absentIfNull(song.album),
        artPath: Value.absentIfNull(artPath),
      ),
    );
  }

  /// Removes one track's bytes and its row.
  Future<void> remove(LibrarySong song) async {
    final row = await database.downloadOf(song.sourceId, song.id);
    if (row == null) return;
    await _deleteIfPresent(fileOf(row));
    final art = row.artPath;
    if (art != null) await _deleteIfPresent(File(p.join(directory, art)));
    await database.removeDownload(song.sourceId, song.id);
  }

  /// Removes every download, and sweeps files no row claims.
  Future<void> removeAll() async {
    for (final row in await database.allDownloads()) {
      await _deleteIfPresent(fileOf(row));
      final art = row.artPath;
      if (art != null) await _deleteIfPresent(File(p.join(directory, art)));
    }
    await database.clearDownloads();
    await sweep();
  }

  /// Deletes files left behind by an interrupted download or a removed row.
  Future<void> sweep() async {
    final directoryHandle = Directory(directory);
    if (!await directoryHandle.exists()) return;
    final claimed = {
      for (final row in await database.allDownloads()) row.path,
      for (final row in await database.allDownloads())
        if (row.artPath != null) row.artPath!,
    };
    await for (final entry in directoryHandle.list(recursive: true)) {
      if (entry is! File) continue;
      final relative = p.relative(entry.path, from: directory);
      if (relative.startsWith('$kDownloadStagingDirectory${p.separator}')) {
        await _deleteIfPresent(entry);
        continue;
      }
      if (claimed.contains(relative)) continue;
      await _deleteIfPresent(entry);
    }
    final staging = Directory(p.join(directory, kDownloadStagingDirectory));
    if (await staging.exists()) await staging.delete(recursive: true);
  }

  Future<void> _writeStream(
    Response<dynamic> response,
    File target,
    void Function(double fraction)? onProgress,
  ) async {
    final stream = (response.data as ResponseBody).stream;
    final header = response.headers.value(Headers.contentLengthHeader);
    final expected = int.tryParse(header ?? '') ?? 0;
    final sink = target.openWrite();
    var written = 0;
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
        written += chunk.length;
        if (expected > 0) onProgress?.call(written / expected);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// A cover next to the track, so a downloaded album draws its art offline.
  ///
  /// Best effort: a library with no cover, or a cover that fails, still leaves
  /// a playable download.
  Future<String?> _downloadArtwork(LibrarySource source, LibrarySong song) async {
    final uri = source.artworkUri(song.artId, size: 600);
    if (uri == null) return null;
    final extension = switch (uri.path.toLowerCase()) {
      final path when path.endsWith('.png') => '.png',
      final path when path.endsWith('.webp') => '.webp',
      _ => '.jpg',
    };
    final relative = p.join(
      'art',
      '${_hash('${song.sourceId}:${song.artId}')}$extension',
    );
    final file = File(p.join(directory, relative));
    if (await file.exists()) return relative;
    try {
      final response = await _dio.get<List<int>>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {HttpHeaders.userAgentHeader: appUserAgent},
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return relative;
    } catch (error) {
      debugPrint('[Downloads] Could not fetch cover for ${song.id}: $error');
      return null;
    }
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('[Downloads] Could not delete ${file.path}: $error');
    }
  }

  /// A file extension from the answer, falling back to the URL's own.
  static String _extensionOf(Response<dynamic> response, Uri uri) {
    final type = response.headers.value(Headers.contentTypeHeader) ?? '';
    final fromType = switch (type) {
      'audio/mpeg' || 'audio/mp3' => '.mp3',
      'audio/flac' || 'audio/x-flac' => '.flac',
      'audio/mp4' || 'audio/x-m4a' || 'audio/aac' => '.m4a',
      'audio/ogg' || 'audio/vorbis' => '.ogg',
      'audio/opus' => '.opus',
      'audio/wav' || 'audio/x-wav' => '.wav',
      _ => null,
    };
    if (fromType != null) return fromType;
    final fromPath = p.extension(uri.path).toLowerCase();
    const known = {'.mp3', '.flac', '.m4a', '.aac', '.ogg', '.opus', '.wav'};
    return known.contains(fromPath) ? fromPath : '.mp3';
  }

  static String _slug(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'track' : normalized;
  }

  /// `hashCode` is per-process; a name that changed on restart would orphan
  /// the file it named.
  static String _hash(String value) =>
      md5.convert(utf8.encode(value)).toString().substring(0, 12);
}

/// What every download is doing right now, keyed `'sourceId:externalId'`.
@Riverpod(keepAlive: true)
class DownloadsController extends Notifier<Map<String, DownloadProgress>> {
  @override
  Map<String, DownloadProgress> build() => const {};

  static String keyOf(LibrarySong song) => '${song.sourceId}:${song.id}';

  /// Downloads [songs] one at a time.
  ///
  /// Sequential rather than parallel on purpose: a queue that opens a dozen
  /// connections at once competes with playback for bandwidth, and a library
  /// server is usually someone's home machine.
  Future<int> downloadAll(List<LibrarySong> songs) async {
    final service = await ref.read(downloadServiceProvider.future);
    if (service == null) return 0;
    var done = 0;
    for (final song in songs) {
      final key = keyOf(song);
      if (state[key]?.active ?? false) continue;
      if (await service.isDownloaded(song)) continue;
      _update(key, const DownloadProgress(DownloadPhase.queued));
      try {
        _update(key, const DownloadProgress(DownloadPhase.running));
        await service.download(
          song,
          onProgress: (fraction) => _update(
            key,
            DownloadProgress(DownloadPhase.running, fraction: fraction),
          ),
        );
        _update(key, const DownloadProgress(DownloadPhase.done));
        done++;
      } catch (error) {
        debugPrint('[Downloads] ${song.title}: $error');
        _update(
          key,
          DownloadProgress(
            DownloadPhase.failed,
            error: describeDownloadError(error),
          ),
        );
      }
    }

    return done;
  }

  /// Removes one downloaded track.
  Future<void> remove(LibrarySong song) async {
    final service = await ref.read(downloadServiceProvider.future);
    if (service == null) return;
    await service.remove(song);
    state = {
      for (final entry in state.entries)
        if (entry.key != keyOf(song)) entry.key: entry.value,
    };
    _refreshReads();
  }

  /// Empties the device of downloads.
  Future<void> removeAll() async {
    final service = await ref.read(downloadServiceProvider.future);
    if (service == null) return;
    await service.removeAll();
    state = const {};
    _refreshReads();
  }

  /// Drops finished entries, so a page does not keep a stale tick forever.
  void dismiss(String key) {
    final entry = state[key];
    if (entry == null || entry.active) return;
    state = {
      for (final other in state.entries)
        if (other.key != key) other.key: other.value,
    };
  }

  void _update(String key, DownloadProgress progress) =>
      state = {...state, key: progress};

  void _refreshReads() {
    ref.invalidate(downloadedTracksProvider);
    ref.invalidate(downloadTotalsProvider);
    ref.invalidate(libraryStatsProvider);
    // Whether one track is on the device is a family: dropping the whole
    // family is one read per open menu, and a stale "Download" on a track
    // that is already here is the one wrong answer this control can give.
    ref.invalidate(isDownloadedProvider);
  }
}

/// A readable failure for one download: the server's own words when it gave
/// any, resolved through its message key, and a generic line otherwise.
String describeDownloadError(Object error) {
  if (error is LibraryException) {
    final key = error.messageKey;
    return key == null ? error.message : key.tr(args: error.messageArgs);
  }
  return 'downloadsFailed'.tr();
}

/// Whether one library item is on this device.
///
/// Keyed by the source's own id pair rather than by [LibrarySong], which has
/// no value equality: a family keyed by the song would mint a new entry per
/// rebuild.
@riverpod
Future<bool> isDownloaded(Ref ref, ({String sourceId, String id}) item) async {
  final database = ref.watch(libraryDatabaseProvider);
  if (database == null) return false;
  return await database.downloadOf(item.sourceId, item.id) != null;
}

/// The download service, or null when the device cannot keep files.
///
/// Null in tests and on a platform without a support directory: downloads are
/// then simply not offered, and playback streams as it always did.
@Riverpod(keepAlive: true)
Future<DownloadService?> downloadService(Ref ref) async {
  final database = ref.watch(libraryDatabaseProvider);
  final directory = ref.watch(downloadDirectoryProvider);
  if (database == null || directory == null) return null;
  return DownloadService(
    database: database,
    directory: directory,
    sources: () => ref.read(librarySourceByIdProvider),
  );
}

/// Where downloads live, injected by `main` beside the local music directory.
@Riverpod(keepAlive: true)
String? downloadDirectory(Ref ref) => null;

/// Every downloaded track, newest first.
@Riverpod(keepAlive: true)
class DownloadedTracks extends AsyncNotifier<List<DownloadedTrack>> {
  @override
  Future<List<DownloadedTrack>> build() async {
    final service = await ref.watch(downloadServiceProvider.future);
    if (service == null) return const [];
    return service.all();
  }
}

/// How many tracks are kept and how much room they take, for Settings.
@Riverpod(keepAlive: true)
Future<({int count, int bytes})> downloadTotals(Ref ref) async {
  final database = ref.watch(libraryDatabaseProvider);
  if (database == null) return (count: 0, bytes: 0);
  return database.downloadTotals();
}
