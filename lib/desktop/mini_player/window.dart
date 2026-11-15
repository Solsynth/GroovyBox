import 'package:window_manager/window_manager.dart';

/// Which native window this engine may act on.
///
/// `WindowManager.instance.getCurrent()` is not per-engine: nativeapi answers
/// it from the app's window list (on macOS, `NSApplication.mainWindow` with a
/// first-window fallback), so inside the mini player's engine it returns the
/// *main* window. That is why the mini player's close button hid the app, and
/// why its pane resizes were applied to the app's window.
///
/// The host names its own window in the launch arguments; every other window
/// in the process is this engine's, and it is resolved lazily because the
/// guest's window may not be listed yet at boot.
int? _mainWindowId;
int? _ownWindowId;

/// Guest: records the main window's id so this engine can exclude it.
void setMainWindowId(int? id) => _mainWindowId = id;

/// This engine's own window, or null while it does not exist (or is gone).
///
/// Deliberately no `getCurrent()` fallback: guessing hands back the main
/// window, which is the bug this exists to prevent.
Window? miniPlayerWindow() {
  final cached = _ownWindowId;
  if (cached != null) {
    final window = WindowManager.instance.get(cached);
    if (window != null) return window;
    _ownWindowId = null;
  }
  final main = _mainWindowId;
  if (main == null) return null;
  for (final window in WindowManager.instance.getAll()) {
    if (window.id != main) {
      _ownWindowId = window.id;
      return window;
    }
  }
  return null;
}
