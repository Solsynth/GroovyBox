import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app.dart';
import '../data/local/library_database.dart';
import 'providers.dart';
import 'source.dart';
import 'store.dart';

part 'backup.g.dart';

class BackupSummary {
  final int sourcesCount;
  final int tracksCount;
  final int lyricsCount;
  final int playsCount;
  final DateTime? exportedAt;
  final String? app;

  const BackupSummary({
    required this.sourcesCount,
    required this.tracksCount,
    required this.lyricsCount,
    required this.playsCount,
    this.exportedAt,
    this.app,
  });
}

class BackupResult {
  final int sourcesImported;
  final int tracksImported;
  final int linksImported;
  final int lyricsImported;
  final int playsImported;

  const BackupResult({
    required this.sourcesImported,
    required this.tracksImported,
    required this.linksImported,
    required this.lyricsImported,
    required this.playsImported,
  });
}

@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) => BackupService(ref);

class BackupService {
  final Ref _ref;

  BackupService(this._ref);

  static const currentVersion = 1;

  /// Creates a complete JSON-encodable backup map containing:
  /// - Sources (connected libraries and auth)
  /// - Settings (theme, glass, lyrics settings, infinite playback)
  /// - Local database (tracks metadata, links, cached lyrics, and play events)
  Future<Map<String, dynamic>> createBackupData() async {
    final sources = _ref.read(sourceStoreProvider);
    final prefs = _ref.read(sharedPreferencesProvider);

    final settings = <String, dynamic>{
      'themeMode': _ref.read(themeModeProvider).name,
      'volume': prefs.getDouble('app_volume') ?? 65.0,
      'glassEffects': _ref.read(glassEffectsEnabledProvider),
      'lyricsPronunciation': _ref.read(lyricsPronunciationEnabledProvider),
      'lyricsTranslation': _ref.read(lyricsTranslationEnabledProvider),
      'infinitePlayback': _ref.read(infinitePlaybackEnabledProvider),
    };

    final db = _ref.read(libraryDatabaseProvider);
    final dbData = db != null ? await db.exportData() : <String, dynamic>{};

    return {
      'version': currentVersion,
      'app': 'GroovyBox',
      'exportedAt': DateTime.now().toIso8601String(),
      'sources': [for (final s in sources) s.toJson()],
      'settings': settings,
      'database': dbData,
    };
  }

  /// Inspects a raw JSON map and returns a summary of its contents, or null if invalid.
  static BackupSummary? inspectBackup(Map<String, dynamic> data) {
    var sourcesCount = 0;
    if (data['sources'] is List) {
      sourcesCount = (data['sources'] as List).length;
    }

    var tracksCount = 0;
    var lyricsCount = 0;
    var playsCount = 0;

    final dbData = data['database'];
    if (dbData is Map) {
      if (dbData['tracks'] is List) tracksCount = (dbData['tracks'] as List).length;
      if (dbData['lyrics'] is List) lyricsCount = (dbData['lyrics'] as List).length;
      if (dbData['plays'] is List) playsCount = (dbData['plays'] as List).length;
    } else if (data['tracks'] is List) {
      // Direct database export
      tracksCount = (data['tracks'] as List).length;
      if (data['lyrics'] is List) lyricsCount = (data['lyrics'] as List).length;
      if (data['plays'] is List) playsCount = (data['plays'] as List).length;
    }

    DateTime? exportedAt;
    if (data['exportedAt'] is String) {
      exportedAt = DateTime.tryParse(data['exportedAt'] as String);
    }

    return BackupSummary(
      sourcesCount: sourcesCount,
      tracksCount: tracksCount,
      lyricsCount: lyricsCount,
      playsCount: playsCount,
      exportedAt: exportedAt,
      app: data['app'] as String?,
    );
  }

  /// Restores settings, merges sources, and imports database rows.
  Future<BackupResult> restoreBackup(Map<String, dynamic> data) async {
    // 1. Settings
    if (data['settings'] is Map) {
      final settings = data['settings'] as Map;
      final prefs = _ref.read(sharedPreferencesProvider);

      if (settings['themeMode'] is String) {
        final mode = AppThemeMode.values.firstWhere(
          (m) => m.name == settings['themeMode'],
          orElse: () => AppThemeMode.system,
        );
        await _ref.read(themeModeProvider.notifier).set(mode);
      }
      if (settings['volume'] is num) {
        final volume = (settings['volume'] as num).toDouble();
        await prefs.setDouble('app_volume', volume);
      }
      if (settings['glassEffects'] is bool) {
        await _ref
            .read(glassEffectsEnabledProvider.notifier)
            .set(settings['glassEffects'] as bool);
      }
      if (settings['lyricsPronunciation'] is bool) {
        await _ref
            .read(lyricsPronunciationEnabledProvider.notifier)
            .set(settings['lyricsPronunciation'] as bool);
      }
      if (settings['lyricsTranslation'] is bool) {
        await _ref
            .read(lyricsTranslationEnabledProvider.notifier)
            .set(settings['lyricsTranslation'] as bool);
      }
      if (settings['infinitePlayback'] is bool) {
        await _ref
            .read(infinitePlaybackEnabledProvider.notifier)
            .set(settings['infinitePlayback'] as bool);
      }
    }

    // 2. Sources
    var sourcesImported = 0;
    if (data['sources'] is List) {
      final rawSources = data['sources'] as List;
      final sources = <SourceConfig>[];
      for (final raw in rawSources) {
        final parsed = SourceConfig.fromJson(raw);
        if (parsed != null) sources.add(parsed);
      }
      if (sources.isNotEmpty) {
        sourcesImported = await _ref
            .read(sourceStoreProvider.notifier)
            .mergeSources(sources);
      }
    }

    // 3. Database (metadata, lyrics, play history)
    var dbStats = (tracks: 0, links: 0, lyrics: 0, plays: 0);
    final db = _ref.read(libraryDatabaseProvider);
    if (db != null) {
      final dbData = data['database'] is Map
          ? data['database'] as Map<String, dynamic>
          : data;
      dbStats = await db.importData(dbData);
    }

    // 4. Invalidate related providers so UI refreshes immediately
    _ref.invalidate(librarySourcesProvider);
    _ref.invalidate(librarySourceByIdProvider);
    _ref.invalidate(libraryStatsProvider);
    _ref.invalidate(storedLyricsProvider);
    _ref.invalidate(listeningStatsProvider);
    _ref.invalidate(recentAlbumsProvider);
    _ref.invalidate(randomSongsProvider);
    _ref.invalidate(playlistsProvider);

    return BackupResult(
      sourcesImported: sourcesImported,
      tracksImported: dbStats.tracks,
      linksImported: dbStats.links,
      lyricsImported: dbStats.lyrics,
      playsImported: dbStats.plays,
    );
  }

  /// Exports backup data to a file (save dialog on desktop, share sheet on mobile).
  Future<String?> exportBackupFile(BuildContext context) async {
    try {
      final backup = await createBackupData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);

      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'groovybox_backup_$timestamp.json';
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      if (!kIsWeb &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        final savedUri = await FilePicker.saveFile(
          dialogTitle: 'settingsExportBackup'.tr(),
          fileName: fileName,
          bytes: bytes,
          mimeType: 'application/json',
        );
        if (savedUri == null) return null;

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsExportSuccess'.tr())),
          );
        }
        return savedUri.toString();
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, fileName));
        await tempFile.writeAsBytes(bytes);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFile.path, mimeType: 'application/json', name: fileName)],
            subject: 'GroovyBox Backup',
          ),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsExportSuccess'.tr())),
          );
        }
        return tempFile.path;
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settingsExportFailed'.tr(args: ['$error'])),
          ),
        );
      }
      return null;
    }
  }

  /// Lets the user pick a backup JSON file, inspects it, confirms, and restores it.
  Future<void> importBackupFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'settingsImportBackup'.tr(),
      );

      if (files.isEmpty) return;
      final picked = files.first;

      final bytes = await picked.readAsBytes();
      final jsonString = utf8.decode(bytes);

      final dynamic decoded;
      try {
        decoded = jsonDecode(jsonString);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsInvalidBackupFile'.tr())),
          );
        }
        return;
      }

      if (decoded is! Map<String, dynamic>) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsInvalidBackupFile'.tr())),
          );
        }
        return;
      }

      final summary = inspectBackup(decoded);
      if (summary == null ||
          (summary.sourcesCount == 0 &&
              summary.tracksCount == 0 &&
              summary.lyricsCount == 0 &&
              summary.playsCount == 0)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsInvalidBackupFile'.tr())),
          );
        }
        return;
      }

      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('settingsImportDialogTitle'.tr()),
          content: Text(
            'settingsImportDialogMessage'.tr(
              args: [
                '${summary.sourcesCount}',
                '${summary.tracksCount}',
                '${summary.lyricsCount}',
                '${summary.playsCount}',
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('commonCancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('settingsImportConfirm'.tr()),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final restoreResult = await restoreBackup(decoded);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settingsImportSuccess'.tr(
                args: [
                  '${restoreResult.sourcesImported}',
                  '${restoreResult.tracksImported}',
                  '${restoreResult.lyricsImported}',
                  '${restoreResult.playsImported}',
                ],
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settingsImportFailed'.tr(args: ['$error'])),
          ),
        );
      }
    }
  }

  /// Exports the raw SQLite database file directly.
  static Future<void> exportRawDatabase(BuildContext context) async {
    try {
      final dbPath = await LibraryDatabase.databaseFilePath();
      if (dbPath == null || !File(dbPath).existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsDatabaseUnavailable'.tr())),
          );
        }
        return;
      }

      final bytes = await File(dbPath).readAsBytes();
      if (!kIsWeb &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        final savedUri = await FilePicker.saveFile(
          dialogTitle: 'settingsExportDatabase'.tr(),
          fileName: 'library.sqlite',
          bytes: bytes,
          mimeType: 'application/x-sqlite3',
        );
        if (savedUri == null) return;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsExportSuccess'.tr())),
          );
        }
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(dbPath, name: 'library.sqlite')],
            subject: 'GroovyBox Database',
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settingsExportSuccess'.tr())),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settingsExportFailed'.tr(args: ['$error'])),
          ),
        );
      }
    }
  }
}
