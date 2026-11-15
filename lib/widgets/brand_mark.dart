import 'package:flutter/material.dart';

/// The GroovyBox mark: the app icon itself, scaled to the slot that asked for
/// it.
///
/// The icon is one idea — a white tile on the brand teal with the note cut out
/// of it — so the app draws that artwork instead of approximating it with a
/// glyph from an icon font. At 18 px in a row it still reads as the app; at
/// 44 px in a header it carries the brand. Cropping and rounding are the
/// caller's job ([clipBehavior]); the mark never invents a tile of its own.
class BrandMark extends StatelessWidget {
  final double size;

  /// Set false inside text that already names the app; the artwork then
  /// carries no announcement of its own.
  final bool semantic;

  const BrandMark({super.key, this.size = 24, this.semantic = true});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/icon-rounded.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      // The mark is decoration in an interface that already loads instantly;
      // a fade would only make the brand blink in after the page.
      excludeFromSemantics: true,
    );
    return semantic
        ? Semantics(label: 'GroovyBox', image: true, child: image)
        : image;
  }
}
