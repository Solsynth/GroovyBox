import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The shared opening block of every collection page: album, playlist, cloud
/// playlist, and the device's own.
///
/// One shape for all four is the point. These pages used to open four
/// different ways — a header, a hero, a header with buttons — and the
/// difference carried no meaning; it was just four authors. Here the subject
/// is always the same: a cover, what it is, and the two ways in.
///
/// The signature is the *sleeve*: the cover sits on a wide surface tinted
/// from the artwork's own palette, and that tint is the only saturated area
/// on the page. Everything below stays on the app's paper, so the list reads
/// as the thing the sleeve announces rather than as another card.
class CollectionHero extends StatelessWidget {
  /// Artwork, when the collection has any of its own.
  final String? sourceId;
  final String? artId;

  /// What the collection is, in one small word above the meta line: "ALBUM",
  /// "PLAYLIST", "ON THIS DEVICE". Not a number — a collection is not step
  /// three of anything.
  final String? eyebrow;

  /// Who made it, when, and what it is called. The caller decides which of
  /// those it has; missing pieces are simply absent from the line.
  final String meta;

  /// The way in: play, shuffle, and anything page-specific.
  final List<Widget> actions;
  final IconData fallbackIcon;

  const CollectionHero({
    super.key,
    required this.meta,
    required this.actions,
    this.eyebrow,
    this.sourceId,
    this.artId,
    this.fallbackIcon = Symbols.album,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wide = isWideScreen(context);
    final coverSize = wide ? 176.0 : 124.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.sm,
        SolSpace.xxl,
        SolSpace.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Sleeve(
            sourceId: sourceId,
            artId: artId,
            size: coverSize,
            fallbackIcon: fallbackIcon,
          ),
          const SizedBox(width: SolSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: SolSpace.xs),
                ],
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: SolSpace.md),
                Wrap(
                  spacing: SolSpace.sm,
                  runSpacing: SolSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The cover, on a tinted mat that lifts it off the paper.
///
/// The mat is a tone, not a glow: a soft radial wash behind the artwork,
/// wide enough that the square reads as something laid on a surface instead
/// of a sticker. No blur and no sampled artwork colour — the app's palette is
/// the seed's, and a hero that invented a second palette per album would make
/// every page a different app.
class _Sleeve extends StatelessWidget {
  final String? sourceId;
  final String? artId;
  final double size;
  final IconData fallbackIcon;

  const _Sleeve({
    required this.size,
    required this.fallbackIcon,
    this.sourceId,
    this.artId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mat = size * 0.13;
    return Container(
      padding: EdgeInsets.fromLTRB(mat * 1.25, mat, mat, mat),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SolRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.55),
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The fold of the sleeve: the one drawn detail, at the edge the
          // cover is hinged on. Without it the mat is a rounded rectangle;
          // with it the cover reads as something a record came in.
          Positioned(
            left: -mat * 0.62,
            top: mat * 0.35,
            bottom: mat * 0.35,
            width: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.05),
                    colorScheme.primary.withValues(alpha: 0.38),
                    colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(SolRadius.pill),
              ),
            ),
          ),
          _cover(colorScheme),
        ],
      ),
    );
  }

  Widget _cover(ColorScheme colorScheme) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(SolRadius.lg),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: 0.22),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: LibraryArtwork(
      sourceId: sourceId,
      artId: artId,
      size: size,
      radius: SolRadius.lg,
      fallbackIcon: fallbackIcon,
    ),
  );
}
