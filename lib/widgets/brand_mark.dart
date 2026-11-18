import 'package:flutter/material.dart';

/// The app's mark, drawn from the icon itself.
///
/// `assets/images/icon-rounded.png` is the identity: a white tile on the brand
/// teal with the eighth note cut out of it. The app shows that artwork wherever
/// it needs to say who it is, instead of a glyph borrowed from an icon font —
/// a music-note symbol from a general-purpose set says "music", not
/// "GroovyBox".
///
/// The image is cropped by the caller ([ClipRRect] or a size that matches the
/// slot); the mark never re-rounds the tile, because the tile is the artwork.
class BrandMark extends StatelessWidget {
  final double size;

  /// Set false inside a line that already names the app, so assistive
  /// technology does not hear the name twice.
  final bool semantic;

  const BrandMark({super.key, this.size = 24, this.semantic = true});

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/images/icon-rounded.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
    if (!semantic) return mark;
    return Semantics(label: 'GroovyBox', image: true, child: mark);
  }
}
