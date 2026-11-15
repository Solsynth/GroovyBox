/// The app's voice: the colours and faces the icon already speaks.
///
/// GroovyBox's mark is flat and geometric — a white tile on a teal field with
/// an eighth note cut out of it. The identity follows from those two things
/// rather than from a generic "music app" palette: one saturated teal, paper
/// the tile's white warms into, and type with the note's squared shoulders.
///
/// Everything else (the neutral ramp, the dark scheme, the dynamic colour
/// seed) derives from [kBrandTeal] in `theme.dart`, so this file stays the
/// single place the brand is named.
library;

import 'package:flutter/material.dart';

/// The icon's teal, sampled from `assets/images/icon.jpg`. Seeds the scheme.
const Color kBrandTeal = Color(0xFF2EB0C7);

/// The note's ink: the brand hue at tone 25. Where the mark is drawn on paper
/// rather than on its white tile, and the readable deep tint of the brand
/// (9.2:1 on white) for text that must carry the accent.
const Color kBrandTealDeep = Color(0xFF0B4F5A);

/// Quietest readable tint of the brand (6.1:1 on white): rules, frames and
/// secondary marks. Not for body copy.
const Color kBrandTealSoft = Color(0xFF0E6C7C);

/// Display face: page titles, pill headers, brand lines. A geometric grotesk
/// with flat terminals that echo the note's flag; it carries the loud line
/// and gives up immediately, so the body keeps Nunito's warmth.
const String kBrandFontDisplay = 'SpaceGrotesk';

/// Body face: everything read at length.
const String kBrandFontBody = 'Nunito';

/// Data face: addresses, ports, counts, codes — anything a server said or a
/// row must line up on. Its fixed rhythm keeps `jellyfin.example.com:8096`
/// scannable where a proportional face would blur it.
const String kBrandFontData = 'SpaceMono';

/// A page title or brand line in the display face, sized and tracked for its
/// size: tighter as it grows, as the face's own metrics ask.
TextStyle brandDisplayStyle(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double height = 1.15,
}) => TextStyle(
  fontFamily: kBrandFontDisplay,
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: -0.15 - (size - 15) * 0.022,
  color: color,
);

/// Data text: a host, a count, a short code.
TextStyle brandDataStyle(
  double size,
  Color color, {
  double letterSpacing = -0.1,
}) => TextStyle(
  fontFamily: kBrandFontData,
  fontSize: size,
  letterSpacing: letterSpacing,
  color: color,
);
