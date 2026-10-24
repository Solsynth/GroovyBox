import 'package:flutter/widgets.dart';

/// Width at which the shell swaps the bottom bar for a navigation rail.
///
/// Same threshold as Solian so both apps break at the same window sizes.
const double kWideScreenWidth = 768.0;
const double kWiderScreenWidth = 1024.0;

bool isWideScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width > kWideScreenWidth;
}

bool isWiderScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width > kWiderScreenWidth;
}
