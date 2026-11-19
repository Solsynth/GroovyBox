/// Covers kept on this device, so a library that cannot be reached still has
/// its artwork.
///
/// Separate from the response cache on purpose: a cover is bytes, not JSON,
/// and it is keyed by the *art handle* rather than by the URL that served it.
/// A URL carries a signed token and a requested size, both of which change
/// between sessions and layouts while the picture does not.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/identity.dart';
import 'providers.dart';
import 'source.dart';

part 'artwork_cache.g.dart';

/// Where covers live, under the app's support directory.
const kArtworkCacheDirectory = 'art_cache';

/// One cached cover.
class CachedArtwork {
  final File file;

  /// Whether the download that produced it is still running: the widget can
  /// paint the file either way, and a caller that needs completeness awaits
  /// [ready].
  final Future<File?> ready;

  const CachedArtwork(this.file, this.ready);
}

/// The disk half of cover loading.
class ArtworkCache {
  ArtworkCache({required this.directory, Dio? dio}) : _dio = dio ?? Dio();

  /// Absolute path of the cover folder.
  final String directory;
  final Dio _dio;

  /// Fetches in flight, keyed the same way as the files: two widgets asking
  /// for one cover share one download.
  final Map<String, Future<File?>> _running = {};

  /// The file for one art handle, if it is already on disk.
  Future<File?> existing(String sourceId, String? artId, int size) async {
    if (artId == null || artId.isEmpty) return null;
    final file = File(p.join(directory, _name(sourceId, artId, size)));
    return await file.exists() ? file : null;
  }

  /// The cover's file: from disk when present, otherwise downloaded once.
  ///
  /// [uri] is what to fetch on a miss, computed by the source from the handle
  /// so the cache never learns a provider's URL vocabulary. Null when there is
  /// nothing to show.
  Future<File?> resolve(
    String sourceId,
    String? artId, {
    required int size,
    required Uri? Function() uri,
  }) async {
    if (artId == null || artId.isEmpty) return null;
    final cached = await existing(sourceId, artId, size);
    if (cached != null) return cached;
    final url = uri();
    if (url == null) return null;
    final name = _name(sourceId, artId, size);
    return _running.putIfAbsent(name, () async {
      try {
        final response = await _dio.get<List<int>>(
          url.toString(),
          options: Options(
            responseType: ResponseType.bytes,
            headers: {HttpHeaders.userAgentHeader: appUserAgent},
          ),
        );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) return null;
        final file = File(p.join(directory, name));
        await file.parent.create(recursive: true);
        // Written beside the name, then renamed: a half-written cover must
        // never be painted as a complete one.
        final partial = File('${file.path}.part');
        await partial.writeAsBytes(bytes, flush: true);
        await partial.rename(file.path);
        return file;
      } catch (error) {
        debugPrint('[Artwork] Could not read cover for $artId: $error');
        return null;
      } finally {
        _running.remove(name);
      }
    });
  }

  /// Names one handle's file. A hash because an art id is a URL or an id with
  /// slashes in it, and neither is a file name.
  static String _name(String sourceId, String artId, int size) =>
      '${md5.convert(utf8.encode('$sourceId\u0000$artId\u0000$size'))}.img';

  /// Deletes every cached cover, for Settings.
  Future<void> clear() async {
    final handle = Directory(directory);
    if (!await handle.exists()) return;
    await for (final entry in handle.list()) {
      if (entry is File) {
        try {
          await entry.delete();
        } catch (error) {
          debugPrint('[Artwork] Could not delete ${entry.path}: $error');
        }
      }
    }
  }

  /// How many covers are stored and how many bytes they take.
  Future<({int count, int bytes})> totals() async {
    final handle = Directory(directory);
    if (!await handle.exists()) return (count: 0, bytes: 0);
    var count = 0;
    var bytes = 0;
    await for (final entry in handle.list()) {
      if (entry is! File) continue;
      count++;
      try {
        bytes += await entry.length();
      } catch (_) {
        // A file deleted mid-scan contributes nothing.
      }
    }
    return (count: count, bytes: bytes);
  }
}

/// Where covers live, injected by `main` beside the other storage paths.
@Riverpod(keepAlive: true)
String? artworkCacheDirectory(Ref ref) => null;

/// The device's cover cache, or null when it cannot keep files.
@Riverpod(keepAlive: true)
ArtworkCache? artworkCache(Ref ref) {
  final directory = ref.watch(artworkCacheDirectoryProvider);
  if (directory == null) return null;
  return ArtworkCache(directory: directory);
}

/// The cover one source's handle names, for a widget that just wants a file.
///
/// Keyed by the source and handle rather than by [LibrarySource], which has no
/// value equality: the source is looked up per resolution.
@riverpod
Future<File?> artworkFile(
  Ref ref,
  ({String sourceId, String? artId, int size}) art,
) async {
  final cache = ref.watch(artworkCacheProvider);
  if (cache == null) return null;
  final source = ref.read(librarySourceByIdProvider)[art.sourceId];
  return cache.resolve(
    art.sourceId,
    art.artId,
    size: art.size,
    uri: () => source?.artworkUri(art.artId, size: art.size),
  );
}
