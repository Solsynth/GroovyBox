import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The play/pause glyph, white and filled, cross-faded rather than swapped.
///
/// Both players — the dock's capsule and the full page — show this one widget,
/// so the two never disagree about which symbol or which size belongs on the
/// transport. The outgoing symbol scales down into the button while the
/// incoming one rises out of it, on the same duration, so a toggle reads as
/// one press rather than two icons trading places.
class PlayPauseIcon extends StatelessWidget {
  final bool playing;
  final double size;

  const PlayPauseIcon({super.key, required this.playing, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: playing
          ? Icon(
              Symbols.pause_rounded,
              key: const ValueKey('pause'),
              color: Colors.white,
              fill: 1,
              size: size,
            )
          : Icon(
              Symbols.play_arrow_rounded,
              key: const ValueKey('play'),
              color: Colors.white,
              fill: 1,
              size: size,
            ),
    );
  }
}
