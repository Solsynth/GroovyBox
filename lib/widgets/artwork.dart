import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/widgets/artwork_pixels.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Cover art for a library item, with a tonal fallback while it loads and when
/// a track or album has no art at all.
///
/// The requested image is sized from the box the art actually paints into, in
/// device pixels. A fixed request leaves covers soft on the grid and in the
/// player, where the same tile is painted at two to five times that size.
///
/// How a handle becomes pixels — the cover cache, a bare URL, or the host
/// engine's answer inside the mini player — is [artworkPixelsProvider]. This
/// widget draws the result and owns nothing of the resolution itself, which is
/// what lets the same widget work in an engine that has no sources at all.
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

  /// Device pixels to request regardless of the layout box.
  ///
  /// For art painted over a whole window and then made unrecognisable — the
  /// player's blurred backdrop — the box says nothing about useful detail, and
  /// asking for it at window resolution downloads megabytes to throw away.
  final int? pixelSize;

  /// Used when the art fills an unbounded box, where there is no extent to
  /// scale: large enough for a desktop player cover, small enough to be safe.
  static const int _defaultPixels = 512;

  const LibraryArtwork({
    super.key,
    required this.sourceId,
    required this.artId,
    this.size,
    this.width,
    this.height,
    this.radius = SolRadius.sm,
    this.fallbackIcon = Symbols.music_note_rounded,
    this.pixelSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final longest = size ?? width ?? height;

    if (longest != null || pixelSize != null) {
      return _Art(
        sourceId: sourceId,
        artId: artId,
        pixels: _clampPixels(pixelSize ?? (longest! * dpr).round()),
        width: size ?? width,
        height: size ?? height,
        radius: radius,
        fallbackIcon: fallbackIcon,
      );
    }

    // No explicit extent: the parent decides. Measure it, so a 400 px grid
    // tile asks for 400 px instead of a thumbnail scaled up — but measure it
    // in buckets. A cover inside an animating box changes width every frame,
    // and an unquantised request would mint a new URL (and a new download) 60
    // times a second, blinking the placeholder at each one.
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = constraints.biggest.shortestSide;
        final scale = extent.isFinite && extent > 0 ? extent : null;
        return _Art(
          sourceId: sourceId,
          artId: artId,
          pixels: scale == null
              ? _defaultPixels
              : _clampPixels(_quantize((scale * dpr).round())),
          width: null,
          height: null,
          radius: radius,
          fallbackIcon: fallbackIcon,
        );
      },
    );
  }

  /// Rounds a request up to a bucket wide enough that ordinary layout changes
  /// stay inside one URL. Covers are stored in the low hundreds of pixels, so
  /// the rounding costs no visible detail.
  static int _quantize(int pixels) {
    final step = pixels < 256
        ? 64
        : pixels < 768
        ? 128
        : 256;
    return ((pixels + step - 1) ~/ step) * step;
  }

  /// Covers are stored in the low hundreds of pixels; past roughly a retina
  /// player cover there is nothing left to fetch.
  static int _clampPixels(int pixels) => pixels.clamp(64, 1600);
}

class _Art extends ConsumerWidget {
  final String? sourceId;
  final String? artId;
  final int pixels;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;

  const _Art({
    required this.sourceId,
    required this.artId,
    required this.pixels,
    required this.width,
    required this.height,
    required this.radius,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final extent = width ?? height ?? pixels.toDouble();
    final id = artId;
    final owner = sourceId;
    // No handle, no question: an item without a cover skips the resolver
    // entirely, so a list of coverless rows makes no requests at all.
    final answer = owner == null || id == null || id.isEmpty
        ? null
        : ref
              .watch(
                artworkPixelsProvider(
                  ArtworkHandle(sourceId: owner, artId: id, size: pixels),
                ),
              )
              .value;

    final placeholder = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: extent * 0.36,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );

    final image = switch (answer) {
      ArtworkFile(:final file) => Image.file(
        file,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
      ArtworkRemote(:final uri) => Image.network(
        uri.toString(),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
      null => null,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: image == null
            // Nothing to paint yet: the placeholder is the surface until the
            // resolver answers, and the widget rebuilds when it does — there
            // is no second network image in between.
            ? placeholder
            // The placeholder sits *under* the image rather than replacing it.
            // `gaplessPlayback` can only hold the previous frame while the
            // image widget is still the one painting; a `loadingBuilder` that
            // swaps in a grey box throws that frame away and flashes on every
            // reload — which is exactly what an animating box causes.
            : Stack(fit: StackFit.expand, children: [placeholder, image]),
      ),
    );
  }
}
