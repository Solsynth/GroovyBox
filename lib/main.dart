import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/desktop/mini_player/mini_lyrics.dart';
import 'package:groovy_box/desktop/mini_player/mini_playback.dart';
import 'package:groovy_box/desktop/mini_player/mini_player_app.dart';
import 'package:groovy_box/desktop/mini_player/window.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/router.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/local_import.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/library/plugins/plugin_host.dart';
import 'package:groovy_box/player/session.dart';
import 'package:groovy_box/shell/window_frame.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:window_manager/window_manager.dart' hide Window;

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

  // The mini player runs a second Flutter engine in its own window. This
  // engine boots through the same `main`, so detect it before any heavy init:
  // the guest never constructs a Player, registers no audio session, and
  // opens no media session — it renders what the host publishes and forwards
  // transport commands to it.
  if (!kIsWeb && DesktopWindowFrame.isPlatformDesktop) {
    try {
      final controller = await WindowController.fromCurrentEngine();
      final raw = controller.arguments;
      final args = raw.isEmpty ? null : jsonDecode(raw);
      if (args is Map && args['kind'] == 'miniPlayer') {
        await _runMiniPlayer(args['mainWindowId'] as int?);
        return;
      }
    } catch (_) {
      // Not a secondary engine — continue with normal startup. Any platform
      // without the plugin lands here too; the mini player is desktop-only.
    }
  }

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
    // The window exists before this engine runs — the runner created it — so
    // `getCurrent` answers immediately and the options apply to it directly.
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window
        ..title = 'GroovyBox'
        ..minimumSize = kMinimumWindowSize.toNative()
        ..titleBarStyle = TitleBarStyle.hidden
        ..isWindowControlButtonsVisible = true
        ..backgroundColor = Colors.transparent.toNative();
      window.setSize(kDefaultWindowSize.toNative(), false);
      window.center();
      window.show();
      window.focus();
    }
    // Wayland ignores the hidden-title-bar hint until the window is frameless.
    if (Platform.isLinux &&
        Platform.environment.containsKey('WAYLAND_DISPLAY')) {
      try {
        window?.setFrameless(true);
      } catch (error) {
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

  // Imported files live in the app's own support directory. Resolving it
  // before the first frame keeps the local library synchronous to read, like
  // the database; a platform that refuses it still runs, just without local
  // files.
  String? localLibraryPath;
  try {
    localLibraryPath = await localMusicDirectory();
  } catch (error) {
    debugPrint('[Library] Local music directory unavailable: $error');
  }

  // User-installed library plugins, before the first frame: a connected
  // plugin's rows are stored configs, and the sources they resolve to have to
  // exist by the time the shell reads the library list. The guest engine
  // returns from `_runMiniPlayer` long before this line, so plugins are never
  // loaded twice.
  await (PluginHost.instance ??= PluginHost()).boot();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioHandlerProvider.overrideWithValue(audioHandler),
        libraryDatabaseProvider.overrideWithValue(library),
        localLibraryPathProvider.overrideWithValue(localLibraryPath),
        // The host half of the mini player's channel: created here so the
        // command handler is registered before the second engine launches.
        miniPlayerLinkProvider.overrideWithValue(MiniPlayerLink.host()),
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


/// Boots the secondary engine that renders the mini player window.
///
/// Deliberately minimal: no MediaKit, no AudioService, no AudioSession — the
/// guest never constructs a `Player`, so loading libmpv here would only waste
/// startup time and memory. What it does read is the library database and the
/// local music directory, both with the same failure posture as the main path:
/// a machine that refuses them still shows a mini player, just without local
/// artwork or cached lyrics.
Future<void> _runMiniPlayer(int? mainWindowId) async {
  await EasyLocalization.ensureInitialized();

  // The guest engine manages its own window: small, always on top, and
  // hiding instead of closing so reopening is instant.
  //
  // `getCurrent` is not usable here: nativeapi answers it from the app's
  // window list, not from this engine, so it returns the main window and
  // every "mini player" operation would act on the app. The host passes its
  // own window id in the launch arguments, and the one that is not it is
  // this engine's window.
  setMainWindowId(mainWindowId);
  final window = miniPlayerWindow();
  if (window != null) {
    // The window is frameless like the main one, so [DesktopWindowFrame]
    // draws the title bar and the window controls for both: one chrome, one
    // place to change it. macOS keeps its traffic lights on the hidden bar.
    window
      ..title = 'GroovyBox Mini'
      // The bar shape is one fixed size: it opens at exactly the height its
      // overlay fits. Panes relax the ceiling when they open.
      ..minimumSize = const Size(
        kMiniPlayerMinWidth,
        kMiniPlayerBarHeight,
      ).toNative()
      ..maximumSize = const Size(
        kMiniPlayerMaxWidth,
        kMiniPlayerBarHeight,
      ).toNative()
      ..isAlwaysOnTop = true
      ..backgroundColor = Colors.transparent.toNative()
      ..titleBarStyle = TitleBarStyle.hidden
      ..isWindowControlButtonsVisible = true;
    window.setSize(
      const Size(kMiniPlayerBarWidth, kMiniPlayerBarHeight).toNative(),
      false,
    );
    window.center();
    window.show();
  }

  // The guest never opens the library database. Even with WAL, a second
  // engine opening the same SQLite file while the main engine holds a write
  // connection corrupted the Dart heap on macOS: two drift instances, two
  // page caches, one file. The guest renders what the host publishes; the
  // lyrics pane falls back to the network resolver when the cache is out of
  // reach.
  // The guest backs SharedPreferences with an in-memory store instead of the
  // platform plugin (see the engine-registration note in MainFlutterWindow):
  // the provider tree reads it exactly as the host does, the values are
  // defaults and last for the window's lifetime, and no native code runs twice.
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  final prefs = await SharedPreferences.getInstance();

  const libraryDatabase = null;
  const localLibraryPath = null;

  final link = MiniPlayerLink.guest();
  await link.startGuest();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(libraryDatabase),
        localLibraryPathProvider.overrideWithValue(localLibraryPath),
        miniPlayerLinkProvider.overrideWithValue(link),
        playbackProvider.overrideWith(MiniPlayback.new),
        // The guest has no database, so every lyric it shows is the host's:
        // the resolver is the link, not a local chain over an absent cache.
        lyricsResolverProvider.overrideWith(
          (ref) async => HostLyricsResolver(link),
        ),
      ],
      child: EasyLocalization(
        supportedLocales: kSupportedLocales,
        path: kTranslationsPath,
        fallbackLocale: kFallbackLocale,
        useFallbackTranslations: true,
        child: const MiniPlayerApp(),
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
              onClose: () => WindowManager.instance.getCurrent()?.close(),
              child: child ?? const SizedBox.shrink(),
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

