import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

/// The frameless desktop chrome: a draggable title bar plus window controls.
///
/// Ported from Solian's `DesktopWindowFrame`. macOS keeps the native traffic
/// lights (the window is created with `TitleBarStyle.hidden` and
/// `windowButtonVisibility: true`), so there the bar is only a drag strip and
/// a title slot. Linux and Windows get our own minimize/maximize/close row,
/// because those platforms have no traffic-light equivalent to keep.
///
/// Wrap the routed application once, in `MaterialApp.router`'s builder. Pages
/// never recreate window chrome.
class DesktopWindowFrame extends HookWidget {
  final Widget child;
  final Widget? title;
  final List<Widget> overlays;
  final VoidCallback? onClose;
  final bool isDesktopPlatform;

  const DesktopWindowFrame({
    super.key,
    required this.child,
    this.title,
    this.overlays = const [],
    this.onClose,
    this.isDesktopPlatform = false,
  });

  static bool get isPlatformDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  /// Height of the title bar band.
  ///
  /// 32 is what macOS uses to clear the traffic lights; the same band keeps the
  /// three platforms consistent when running side by side.
  static const double titleBarHeight = 32;

  @override
  Widget build(BuildContext context) {
    final isMaximized = useState(false);
    final keyboardFocusNode = useFocusNode();

    useEffect(() {
      keyboardFocusNode.requestFocus();
      return null;
    }, []);

    useEffect(() {
      if (!isDesktopPlatform) return null;

      final maximizeListener = _WindowMaximizeListener(isMaximized);
      windowManager.addListener(maximizeListener);
      windowManager.isMaximized().then((max) => isMaximized.value = max);

      return () => windowManager.removeListener(maximizeListener);
    }, [isDesktopPlatform]);

    final framedChild = isDesktopPlatform
        ? Material(
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    DragToMoveArea(
                      child: Material(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: _buildTitleBar(context, isMaximized),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
                ...overlays,
              ],
            ),
          )
        : Stack(fit: StackFit.expand, children: [child, ...overlays]);

    return Focus(
      focusNode: keyboardFocusNode,
      // Ignore Shift+Tab bleeding into window management: the palette opens on
      // it in Solian, and keeping the frame from claiming it leaves that
      // shortcut free for the app layer.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.physicalKey == PhysicalKeyboardKey.tab &&
            HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: framedChild,
    );
  }

  Widget _buildTitleBar(BuildContext context, ValueNotifier<bool> isMaximized) {
    final bar = SizedBox(
      height: titleBarHeight,
      child: Stack(alignment: Alignment.center, children: [?title]),
    );

    if (Platform.isMacOS) return bar;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(children: [if (title != null) Expanded(child: title!)]),
          ),
        ),
        _WindowButton(
          icon: Symbols.minimize,
          onPressed: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: isMaximized.value
              ? Symbols.fullscreen_exit
              : Symbols.fullscreen,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.restore();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          icon: Symbols.close,
          onPressed: onClose ?? () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _WindowButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      iconSize: 16,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      color: Theme.of(context).iconTheme.color,
    );
  }
}

class _WindowMaximizeListener with WindowListener {
  final ValueNotifier<bool> isMaximized;

  _WindowMaximizeListener(this.isMaximized);

  @override
  void onWindowMaximize() => isMaximized.value = true;

  @override
  void onWindowUnmaximize() => isMaximized.value = false;
}
