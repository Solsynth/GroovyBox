/// The app's colours, taken from the mark.
///
/// GroovyBox's icon is flat and geometric — a white tile on a teal field with
/// an eighth note cut out of it. The identity follows from that rather than
/// from a generic "music app" palette: one saturated teal seeds the whole
/// scheme, and the neutrals tint toward its hue.
///
/// The app keeps its own typeface (Nunito, set in `theme.dart`); this file
/// names colour only.
library;

import 'package:flutter/material.dart';

/// The icon's teal, sampled from `assets/images/icon.jpg`. Seeds the scheme.
const Color kBrandTeal = Color(0xFF2EB0C7);
