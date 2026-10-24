import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app.dart';
import 'core/router.dart';
import 'screens/setup.dart';
import 'shell/window_frame.dart';

/// Window size on first launch. A player is a tall column — cover, title,
/// scrubber, controls — so the default leans narrow rather than wide.
const kDefaultWindowSize = Size(420, 760);
const kMinimumWindowSize = Size(380, 620);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv has to be loaded before the first Player is constructed, which the
  // shell does as soon as it mounts.
  MediaKit.ensureInitialized();

  if (DesktopWindowFrame.isPlatformDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: kDefaultWindowSize,
      minimumSize: kMinimumWindowSize,
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
      title: 'GroovyBox',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    // Wayland ignores the hidden-title-bar hint until the window is frameless.
    if (Platform.isLinux && Platform.environment.containsKey('WAYLAND_DISPLAY')) {
      try {
        await windowManager.setAsFrameless();
      } on PlatformException catch (error) {
        debugPrint('[Window] Could not go frameless on Wayland: $error');
      }
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const GroovyBoxApp(),
    ),
  );
}

class GroovyBoxApp extends ConsumerWidget {
  const GroovyBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final connected = ref.watch(serverConnectionProvider) != null;

    return MaterialApp.router(
      title: 'GroovyBox',
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: router.config(),
      builder: (context, child) {
        // The frame is created once, around the routed content: pages never
        // draw window chrome themselves.
        return DesktopWindowFrame(
          isDesktopPlatform: DesktopWindowFrame.isPlatformDesktop,
          title: const _WindowTitle(),
          // Closing the window ends the app; a music player sitting in the
          // tray with no UI would be a surprise, not a convenience.
          onClose: () => windowManager.close(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              connected
                  ? (child ?? const SizedBox.shrink())
                  : const SetupScreen(),
            ],
          ),
        );
      },
    );
  }
}

/// Title shown in the frameless title bar. Kept as its own widget so the frame
/// can place it without the app passing a live provider read into a const
/// constructor.
class _WindowTitle extends ConsumerWidget {
  const _WindowTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'GroovyBox',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
