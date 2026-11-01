import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/session.dart';
import 'package:groovy_box/screens/setup.dart';
import 'package:groovy_box/shell/window_frame.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Translations live in `assets/i18n/<language>-<COUNTRY>.json`, one file per
/// locale, matching the path declared under `flutter.assets` in pubspec.yaml.
const kTranslationsPath = 'assets/i18n';
const kSupportedLocales = [Locale('en', 'US'), Locale('zh', 'CN')];
const kFallbackLocale = Locale('en', 'US');

/// Window size on first launch. A player is a tall column — cover, title,
/// scrubber, controls — so the default leans narrow rather than wide.
const kDefaultWindowSize = Size(420, 760);
const kMinimumWindowSize = Size(380, 620);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads the saved locale and the device locale from prefs before the first
  // frame, so the first frame is already in the user's language.
  await EasyLocalization.ensureInitialized();

  // libmpv has to be loaded before the first Player is constructed, which the
  // shell does as soon as it mounts.
  MediaKit.ensureInitialized();

  // Configure mobile/desktop audio session category for background playback
  // and system media focus before initializing AudioService.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (error) {
      debugPrint('[AudioSession] Pre-init error: $error');
    }
  }

  // The media session comes up before the UI: the platform can hand a media
  // button to an app whose first frame has not been drawn, and the handler has
  // to exist to take it. Playback attaches itself once the shell mounts.
  final audioHandler = await AudioService.init(
    builder: GroovyBoxAudioHandler.new,
    config: AudioServiceConfig(
      androidNotificationChannelId: 'dev.solsynth.rhythmBox.channel.audio',
      // The channel name is what the OS settings screen shows. It is resolved
      // before the widget tree exists, so the singleton translator is used;
      // Android keeps the name from the first run anyway.
      androidNotificationChannelName: 'notificationChannelName'.tr(),
      androidNotificationOngoing: true,
      // Covers are served by the library at whatever size is asked for; the
      // notification never needs more than a thumbnail.
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );

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
    if (Platform.isLinux &&
        Platform.environment.containsKey('WAYLAND_DISPLAY')) {
      try {
        await windowManager.setAsFrameless();
      } on PlatformException catch (error) {
        debugPrint('[Window] Could not go frameless on Wayland: $error');
      }
    }
  }

  // The local library is opened before the first frame for the same reason
  // prefs are: the player records a play as soon as a track starts, and a
  // database still opening would surface as a stutter on the first song. The
  // first query runs here on purpose — drift opens lazily, so a file the
  // platform refuses would otherwise only surface as a failed write mid-song.
  // A machine that refuses the file still plays: it just keeps no history and
  // asks the network for lyrics every time.
  LibraryDatabase? library;
  try {
    library = LibraryDatabase();
    await library.customSelect('SELECT 1').getSingle();
  } catch (error) {
    debugPrint('[Library] Database unavailable: $error');
    library = null;
  }
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioHandlerProvider.overrideWithValue(audioHandler),
        libraryDatabaseProvider.overrideWithValue(library),
      ],
      child: EasyLocalization(
        supportedLocales: kSupportedLocales,
        path: kTranslationsPath,
        fallbackLocale: kFallbackLocale,
        useFallbackTranslations: true,
        child: const GroovyBoxApp(),
      ),
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
    final connected = ref.watch(librarySourcesProvider).isNotEmpty;
    final glass = ref.watch(glassEffectsEnabledProvider);

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
      // The app's own strings come from easy_localization; Material, Cupertino
      // and the widgets layer need their own delegates for zh-CN dates, dialog
      // labels and text direction.
      supportedLocales: kSupportedLocales,
      locale: context.locale,
      localizationsDelegates: [
        ...context.localizationDelegates,
        // material_ui's group carries the Material, Cupertino and widgets
        // delegates, so zh-CN dialog labels and dates come from one import.
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: router.config(),
      builder: (context, child) {
        // A plain `'key'.tr()` reads easy_localization's process-wide
        // singleton and does not subscribe to it, so a locale change only
        // rebuilds the widgets above the delegate. Keying the frame on the
        // locale remounts the routed content, which is what makes every
        // label on screen change language the moment the user picks one.
        return KeyedSubtree(
          key: ValueKey(context.locale),
          // The frame is created once, around the routed content: pages never
          // draw window chrome themselves.
          // The glass scope wraps the frame, so every floating surface shares
          // one setting and one paint switch.
          child: GlassEffects(
            enabled: glass,
            child: DesktopWindowFrame(
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
            ),
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
