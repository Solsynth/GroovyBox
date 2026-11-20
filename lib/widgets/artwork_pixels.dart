import 'dart:io';

import 'package:groovy_box/library/artwork_cache.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Where a cover's pixels are: a file on disk, or a URL to paint.
///
/// One type for both engines. The main engine resolves it from its sources and
/// cover cache; the mini window has neither and asks the host over the link,
/// then rebuilds this from the answer. Everything above it — the placeholder,
/// the fade between images — stays one implementation.
sealed class ArtworkPixels {
  const ArtworkPixels();

  /// What to hand across the engine boundary: one string either side parses.
  Uri get uri;

  static ArtworkPixels? fromUri(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    return uri.isScheme('file')
        ? ArtworkFile(File(uri.toFilePath()))
        : ArtworkRemote(uri);
  }
}

final class ArtworkFile extends ArtworkPixels {
  final File file;

  const ArtworkFile(this.file);

  @override
  Uri get uri => file.uri;
}

final class ArtworkRemote extends ArtworkPixels {
  @override
  final Uri uri;

  const ArtworkRemote(this.uri);
}

/// One cover request, as a value-equal family argument.
class ArtworkHandle {
  final String sourceId;
  final String? artId;
  final int size;

  const ArtworkHandle({
    required this.sourceId,
    required this.artId,
    required this.size,
  });

  @override
  bool operator ==(Object other) =>
      other is ArtworkHandle &&
      other.sourceId == sourceId &&
      other.artId == artId &&
      other.size == size;

  @override
  int get hashCode => Object.hash(sourceId, artId, size);
}

/// This engine's answer for one cover.
///
/// The default is the main engine's: resolve the handle through its source,
/// serve it from the cover cache when there is one, and fall back to the bare
/// URL when the download failed. The mini player overrides this with a request
/// to the host, which is the only engine holding either.
/// Per-cover and auto-disposed: a grid that scrolls a thousand covers through
/// must not keep a thousand answers alive. The files themselves are the
/// cache's, so dropping the resolution costs a re-read, not a re-download.
final artworkPixelsProvider = FutureProvider.autoDispose
    .family<ArtworkPixels?, ArtworkHandle>((ref, handle) async {
      final artId = handle.artId;
      if (artId == null || artId.isEmpty) return null;
      final source = ref.watch(librarySourceByIdProvider)[handle.sourceId];
      if (source == null) return null;
      final direct = source.artworkUri(artId, size: handle.size);
      if (direct == null) return null;
      if (direct.isScheme('file')) {
        return ArtworkFile(File(direct.toFilePath()));
      }

      final cache = ref.watch(artworkCacheProvider);
      // A platform that keeps no files (the web, a test) still paints a remote
      // cover the old way: the disk cache is an improvement where it exists,
      // not a new requirement.
      if (cache == null) return ArtworkRemote(direct);
      final file = await ref.watch(
        artworkFileProvider((
          sourceId: handle.sourceId,
          artId: artId,
          size: handle.size,
        )).future,
      );
      // The cache answered nothing — the download failed — but the URL is
      // still a picture: painting it beats a placeholder.
      return file == null ? ArtworkRemote(direct) : ArtworkFile(file);
    });
