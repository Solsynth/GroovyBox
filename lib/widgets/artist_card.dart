import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// An artist as a card: the source's art when it has one, a person-shaped
/// fallback when it does not, and the name under it.
///
/// The grid card the album half uses, at the same size: three halves of one
/// collection should not read as three designs.
class ArtistCard extends StatefulWidget {
  final LibraryArtist artist;
  final VoidCallback onTap;

  const ArtistCard({super.key, required this.artist, required this.onTap});

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: SolRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(SolSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedScale(
                    scale: _hovered ? 1.02 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SolRadius.md),
                        boxShadow: _hovered
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(SolRadius.md),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Person-shaped placeholder, always painted: the
                            // artwork covers it when the source has one, so a
                            // missing cover reads as a portrait, not a hole.
                            ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Symbols.person_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            LibraryArtwork(
                              // A borrowed cover is resolved through the
                              // library that minted its handle; the artist's
                              // own source may never have seen the picture.
                              sourceId: widget.artist.coverSourceId,
                              artId: widget.artist.artId,
                              radius: 0,
                              fallbackIcon: Symbols.person_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SolSpace.sm),
              Text(
                widget.artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.artist.albumCount != null)
                Text(
                  'artistsAlbums'.plural(widget.artist.albumCount!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
