import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../library/providers.dart';

/// Cover art served by a library, with a tonal fallback while it loads and
/// when a track or album has no art at all.
class LibraryArtwork extends ConsumerWidget {
  /// Which library owns the item; resolves the URL scheme.
  final String? sourceId;

  /// Opaque art handle, interpreted by the source.
  final String? artId;
  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;

  const LibraryArtwork({
    super.key,
    required this.sourceId,
    required this.artId,
    this.size,
    this.width,
    this.height,
    this.radius = SolRadius.sm,
    this.fallbackIcon = Symbols.music_note_rounded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = ref.watch(librarySourceByIdProvider)[sourceId];
    final uri = source?.artworkUri(
      artId,
      size: ((size ?? width ?? 96) * 2).round(),
    );

    final placeholder = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: (size ?? width ?? 96) * 0.36,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size ?? width,
        height: size ?? height,
        child: uri == null
            ? placeholder
            : Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                // The server is local or user-hosted and the URL carries the
                // signed token; caching it on disk would keep credentials in
                // the image cache. The in-memory cache is enough for scrolling.
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );
  }
}
