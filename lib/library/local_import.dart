/// Bringing files the user already owns into the library.
///
/// Import is a *copy*: the picked file is streamed into the app's own support
/// directory, so the song keeps playing when the original folder is moved,
/// renamed, unmounted or deleted. Tags are read from the copy, a cover is
/// extracted next to it, and the song is adopted under the same canonical track
/// a server's copy of it would get — so lyrics and play history survive a
/// switch of where a song comes from.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:groovy_box/data/local/library_database.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'catalog.dart';
import 'local_library.dart';
import 'lyrics.dart';
import 'lyrics_store.dart';
import 'models.dart';
import 'providers.dart';

part 'local_import.g.dart';

/// Where imports and their covers live, under the app's support directory.
const kLocalMusicDirectory = 'local_music';
const kLocalArtDirectory = 'art';

/// Holds picked files that arrive without a path until they are copied in.
const kLocalStagingDirectory = 'staging';

/// The audio files the picker offers, without leading dots.
final List<String> kImportableExtensions = [
  for (final extension in supportedFileExtensions)
    extension.replaceFirst('.', ''),
];

/// What one import run did, in the words the UI reports.
class LocalImportResult {
  final int imported;
  final int skipped;

  /// One message per file that could not be imported, already naming it.
  final List<String> failures;

  const LocalImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.failures = const [],
  });
}

/// Copies picked audio files into the app, reads their tags and adopts them.
class LocalImportService {
  LocalImportService({
    required this.database,
    required this.directory,
    required this.lyrics,
    required this.onImported,
  });

  /// Null when the local database could not be opened: importing would copy
  /// files nothing could remember, so the caller refuses first.
  final LibraryDatabase? database;

  /// The catalog over [database]; null exactly when [database] is.
  late final LibraryCatalog? catalog = database == null
      ? null
      : LibraryCatalog(database!);

  /// Absolute path of the import directory; song ids are relative to it.
  final String directory;

  final LyricsStore? lyrics;

  /// Called once after a run that added anything, so cached reads rebuild.
  final void Function() onImported;

  /// Opens the picker and imports whatever the user chose.
  ///
  /// Picked files arrive as bytes or as a temporary copy, depending on the
  /// platform; both are read into a local path here, because the copy into the
  /// library is the same either way.
  Future<LocalImportResult> pickAndImport() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'localImportPickTitle'.tr(),
      type: FileType.custom,
      allowedExtensions: kImportableExtensions,
    );
    if (picked.isEmpty) return const LocalImportResult();

    final staging = await Directory(
      p.join(directory, kLocalStagingDirectory),
    ).create(recursive: true);
    final sources = <File>[];
    try {
      for (final file in picked) {
        final path = file.path;
        if (path != null) {
          sources.add(File(path));
          continue;
        }
        // A platform that hands over bytes without a path (web, some Android
        // providers): keep them just long enough to copy them in.
        final staged = File(p.join(staging.path, _safeFileName(file.name)));
        await staged.writeAsBytes(await file.readAsBytes(), flush: true);
        sources.add(staged);
      }
      return await importFiles(sources);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Copies and adopts [files]. One bad file does not stop the rest.
  Future<LocalImportResult> importFiles(Iterable<File> files) async {
    if (catalog == null) {
      return LocalImportResult(failures: ['localImportUnavailable'.tr()]);
    }
    await Directory(directory).create(recursive: true);

    var imported = 0;
    var skipped = 0;
    final failures = <String>[];

    for (final source in files) {
      try {
        if (await _importOne(source)) {
          imported++;
        } else {
          skipped++;
        }
      } catch (error) {
        debugPrint('[Import] ${source.path}: $error');
        failures.add(
          'localImportFailedFile'.tr(
            args: [p.basename(source.path), '$error'],
          ),
        );
      }
    }

    if (imported > 0) onImported();
    return LocalImportResult(
      imported: imported,
      skipped: skipped,
      failures: failures,
    );
  }

  /// Copies one file and adopts it. Returns false when an identical copy had
  /// already been imported, in which case its existing row is refreshed.
  Future<bool> _importOne(File source) async {
    final (target, isNew) = await _destinationFor(source);
    if (isNew) await _copyInto(source, target);

    final metadata = await _readTags(target);
    final artPath = await _writeCover(target, metadata);
    final tags = _TaggedFile.of(
      fallbackTitle: p.basenameWithoutExtension(target.path),
      metadata: metadata,
      artPath: artPath,
    );
    final songId = p.relative(target.path, from: directory);

    final trackId = await catalog!.adopt(tags.song(songId));

    // The source answers from this row, not from the canonical track: a file
    // is playable exactly as long as its own copy exists.
    await database!.upsertLocalFile(
      tags.fileRow(
        path: songId,
        sizeBytes: await target.length(),
        addedAt: DateTime.now(),
      ),
    );

    final lyricSheet = tags.lyrics;
    if (lyricSheet != null && !lyricSheet.isEmpty) {
      await lyrics?.write(trackId, lyricSheet, origin: LyricsOrigin.file);
    }
    return isNew;
  }

  /// The file's place in the import directory, and whether it still has to be
  /// copied there.
  Future<(File, bool)> _destinationFor(File source) async {
    final name = _safeFileName(p.basename(source.path));
    final direct = File(p.join(directory, name));
    final size = await source.length();
    if (!await direct.exists()) return (direct, true);

    // The source *is* the copy: the user picked a file already imported (its
    // own path is inside the library, or a staging copy of it). Nothing to do.
    if (source.absolute.path == direct.absolute.path) return (direct, false);

    // Same name and same length: this file was imported before. Re-reading
    // its tags is enough; copying it again would only duplicate bytes.
    if (await direct.length() == size) return (direct, false);

    // A different file that happens to share a name: keep both, never
    // overwrite one song with another.
    final base = p.basenameWithoutExtension(name);
    final extension = p.extension(name);
    for (var index = 2; index < 1000; index++) {
      final candidate = File(p.join(directory, '$base ($index)$extension'));
      if (!await candidate.exists()) return (candidate, true);
    }
    final stamped = DateTime.now().millisecondsSinceEpoch;
    return (File(p.join(directory, '$base-$stamped$extension')), true);
  }

  /// Streams the picked bytes into the app's own directory.
  Future<void> _copyInto(File source, File target) async {
    final sink = target.openWrite();
    try {
      await sink.addStream(source.openRead());
      await sink.flush();
    } catch (error) {
      if (await target.exists()) await target.delete();
      rethrow;
    } finally {
      await sink.close();
    }
  }

  /// Tag reading is file-format work with a real allocation cost, so it runs
  /// off the UI isolate. A file with no readable tags is not an error: its
  /// file name is used instead.
  Future<AudioMetadata?> _readTags(File file) async {
    try {
      return await Isolate.run(() => readMetadata(file, getImage: true));
    } catch (error) {
      debugPrint('[Import] No tags in ${file.path}: $error');
      return null;
    }
  }

  /// Writes the embedded cover beside the imports. Tracks sharing a cover
  /// reuse one file, so an album stores one image.
  Future<String?> _writeCover(File file, AudioMetadata? metadata) async {
    final pictures = metadata?.pictures ?? const <Picture>[];
    if (pictures.isEmpty || pictures.first.bytes.isEmpty) return null;
    final picture = pictures.first;

    final artDirectory = Directory(p.join(directory, kLocalArtDirectory));
    await artDirectory.create(recursive: true);
    final extension = switch (picture.mimetype) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
    final name = '${p.basenameWithoutExtension(file.path)}.$extension';
    final target = File(p.join(artDirectory.path, name));
    if (!await target.exists()) {
      await target.writeAsBytes(picture.bytes, flush: true);
    }
    return p.relative(target.path, from: directory);
  }
}

/// One service for the session, so concurrent imports share one directory.
@Riverpod(keepAlive: true)
Future<LocalImportService> localImportService(Ref ref) async {
  final directory = await localMusicDirectory();
  return LocalImportService(
    database: ref.watch(libraryDatabaseProvider),
    directory: directory,
    lyrics: ref.watch(lyricsStoreProvider),
    onImported: () {
      ref.invalidate(recentAlbumsProvider);
      ref.invalidate(randomSongsProvider);
      ref.invalidate(playlistsProvider);
      ref.invalidate(libraryStatsProvider);
    },
  );
}

/// Runs an import and reports the outcome in a snack bar.
///
/// One entry point for both places that offer it — the browse page's nudge and
/// the settings row — so the copy the user reads and the busy state they see
/// cannot drift between them.
Future<void> importMusicFiles(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('localImportBusy'.tr())),
          ],
        ),
      ),
    );

  LocalImportResult result;
  try {
    final service = await ref.read(localImportServiceProvider.future);
    result = await service.pickAndImport();
  } catch (error) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('localImportFailed'.tr(args: ['$error']))),
      );
    return;
  }

  messenger?.hideCurrentSnackBar();
  final message = switch (result) {
    LocalImportResult(imported: final imported, skipped: final skipped)
        when imported == 0 && skipped > 0 =>
      'localImportNothingNew'.plural(skipped),
    LocalImportResult(imported: final imported, skipped: final skipped)
        when imported > 0 && skipped > 0 =>
      'localImportPartial'.plural(imported, args: [
        '$imported',
        '$skipped',
        ...result.failures,
      ]),
    LocalImportResult(imported: final imported) when imported > 0 =>
      'localImportDone'.plural(imported),
    _ => null,
  };

  if (result.failures.isNotEmpty && message == null) {
    messenger?.showSnackBar(
      SnackBar(content: Text(result.failures.first)),
    );
    return;
  }
  if (message == null) return;
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      action: result.failures.isEmpty
          ? null
          : SnackBarAction(
              label: 'localImportShowErrors'.tr(),
              onPressed: () => _showFailures(context, result.failures),
            ),
    ),
  );
}

void _showFailures(BuildContext context, List<String> failures) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('localImportFailuresTitle'.tr()),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [for (final failure in failures) Text(failure)],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('commonClose'.tr()),
        ),
      ],
    ),
  );
}

/// What one file's tags say, normalized into the library's own vocabulary.
class _TaggedFile {
  _TaggedFile({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.genre,
    required this.year,
    required this.track,
    required this.discNumber,
    required this.duration,
    required this.albumKey,
    required this.artPath,
    required this.lyrics,
  });

  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? track;
  final int? discNumber;
  final Duration duration;
  final String? albumKey;
  final String? artPath;
  final Lyrics? lyrics;

  /// [fallbackTitle] is used when the file carries no title tag; it comes from
  /// the file name, which is the only name the user is likely to recognise.
  static _TaggedFile of({
    required String fallbackTitle,
    required AudioMetadata? metadata,
    required String? artPath,
  }) {
    final title = _clean(metadata?.title) ?? fallbackTitle;
    final artist = _clean(metadata?.artist);
    final album = _clean(metadata?.album);
    final albumArtist = _clean(metadata?.albumArtist) ?? artist;
    final year = metadata?.year;
    final rawLyrics = _clean(metadata?.lyrics);
    final genres = metadata?.genres ?? const <String>[];

    return _TaggedFile(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genres.isEmpty ? null : _clean(genres.first),
      year: year == null || year.year <= 0 ? null : year.year,
      track: metadata?.trackNumber,
      discNumber: metadata?.discNumber,
      duration: metadata?.duration ?? Duration.zero,
      albumKey: album == null
          ? null
          : localAlbumKey(album: album, albumArtist: albumArtist),
      artPath: artPath,
      lyrics: rawLyrics == null
          ? null
          : _lyricsOf(rawLyrics, metadata?.language),
    );
  }

  /// The source's own row for this file. [path] is relative to the import
  /// directory, which is what the route and the stream URI both use.
  LocalFilesCompanion fileRow({
    required String path,
    required int sizeBytes,
    required DateTime addedAt,
  }) => LocalFilesCompanion.insert(
    path: path,
    fileName: p.basename(path),
    sizeBytes: sizeBytes,
    title: title,
    addedAt: addedAt,
    artist: Value.absentIfNull(artist),
    albumArtist: Value.absentIfNull(albumArtist),
    album: Value.absentIfNull(album),
    genre: Value.absentIfNull(genre),
    year: Value.absentIfNull(year),
    albumKey: Value.absentIfNull(albumKey),
    trackNumber: Value.absentIfNull(track),
    discNumber: Value.absentIfNull(discNumber),
    durationMs: Value(duration.inMilliseconds),
    artPath: Value.absentIfNull(artPath),
  );

  LibrarySong song(String id) => LibrarySong(
    sourceId: kLocalSourceId,
    id: id,
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    albumId: albumKey,
    artId: artPath,
    duration: duration,
    track: track,
    discNumber: discNumber,
    year: year,
    genre: genre,
  );

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Tags carry plain text and LRC alike; the parser tells them apart by the
  /// timestamps it finds.
  static Lyrics _lyricsOf(String raw, String? language) {
    final parsed = parseLrc(raw);
    if (parsed.lines.isNotEmpty) {
      return Lyrics(
        lines: parsed.lines,
        synced: parsed.synced,
        language: language,
      );
    }
    return Lyrics(
      lines: [
        for (final line in const LineSplitter().convert(raw))
          if (line.trim().isNotEmpty) LyricLine(Duration.zero, line.trim()),
      ],
      synced: false,
      language: language,
    );
  }
}

/// A file name that is safe on every platform the app runs on.
String _safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '_');
  return cleaned.trim().isEmpty ? 'track' : cleaned;
}

/// The import directory, created on first use.
Future<String> localMusicDirectory() async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory(p.join(support.path, kLocalMusicDirectory));
  await dir.create(recursive: true);
  return dir.path;
}
