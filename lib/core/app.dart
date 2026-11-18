import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dynamic_color.dart';
import 'theme.dart';

part 'app.g.dart';

/// Translations live in `assets/i18n/<language>-<COUNTRY>.json`, one file per
/// locale, matching the path declared under `flutter.assets` in pubspec.yaml.
///
/// Declared here rather than beside `main()`'s window setup because the mini
/// window boots its own engine and must be configured identically.
const kTranslationsPath = 'assets/i18n';
const kSupportedLocales = [Locale('en', 'US'), Locale('zh', 'CN')];
const kFallbackLocale = Locale('en', 'US');


/// The compact bar's default geometry.
///
/// A bar is one header row, the scrubber and the transport: the artwork lives
/// as a sleeve beside the title, not as a page-sized cover, which is what
/// keeps this window from being a second copy of the player page.
const kMiniPlayerBarWidth = 340.0;

/// Window height of the bar shape, chrome included.
///
/// The window is frameless and [DesktopWindowFrame] draws a 32px title band
/// inside it, so the height the user sees is band + content. Setting this to
/// the content height alone is what made the overlay column overflow by
/// exactly that band.
///
/// 196 is the stack measured in a widget test — header, scrubber, transport —
/// plus a 4px cushion; anything larger is the empty strip at the bottom of
/// the window that read as a padding bug.
const kMiniPlayerBarContentHeight = 196.0;
const kMiniPlayerBarHeight = kMiniPlayerBarContentHeight + 32.0;

/// Extra height the window takes when the queue or the lyrics open. The pane
/// fills exactly this, so a bar and a pane are one window in two shapes
/// rather than two layouts.
const kMiniPlayerPaneHeight = 300.0;

/// Floor for an open pane: enough lyrics or queue to be usable before the user
/// drags the window taller.
const kMiniPlayerPaneMinHeight = 200.0;

/// Tallest either shape can be dragged to. A floating player that can grow
/// into a full page is the player page with extra steps.
const kMiniPlayerMaxHeight = 720.0;

/// Bounds the window can be dragged to: narrow enough for a desktop corner,
/// wide enough for a queue row.
const kMiniPlayerMinWidth = 300.0;
const kMiniPlayerMaxWidth = 480.0;


/// The platform prefs store, opened in `main` and injected into the container.
///
/// Overriding it (instead of calling `getInstance` inside providers) keeps the
/// store synchronous to read, so the first frame already knows the theme and
/// whether a server is configured.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw StateError('sharedPreferences must be overridden in main()');

/// Which theme the window renders, following the OS by default.
enum AppThemeMode { system, light, dark }

const _kThemeModeKey = 'app_theme_mode';
const _kVolumeKey = 'app_volume';
const _kGlassEffectsKey = 'app_glass_effects';
const _kLyricsPronunciationKey = 'app_lyrics_pronunciation';
const _kLyricsTranslationKey = 'app_lyrics_translation';
const _kInfinitePlaybackKey = 'app_infinite_playback';
const _kDynamicColorKey = 'app_dynamic_color';

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final saved = ref
        .watch(sharedPreferencesProvider)
        .getString(_kThemeModeKey);
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> set(AppThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kThemeModeKey, mode.name);
  }
}

/// The app's palette: the user's own seed, or the playing cover's, when
/// dynamic colour is on and the track has a cover worth reading.
///
/// Theme sets are cached per seed: [createAppThemeSet] builds the whole
/// Material scheme twice, and this provider rebuilds on every track change.
@Riverpod(keepAlive: true)
ThemeSet appTheme(Ref ref) {
  final cover = ref.watch(dynamicColorEnabledProvider)
      ? ref.watch(coverSeedProvider).value
      : null;
  final seed = cover ?? kDefaultSeedColor;
  return _themeSets.putIfAbsent(seed, () => createAppThemeSet(seedColor: seed));
}

final _themeSets = <Color, ThemeSet>{};

/// Last volume, restored so the window does not startle the user.
@Riverpod(keepAlive: true)
double initialVolume(Ref ref) =>
    ref.watch(sharedPreferencesProvider).getDouble(_kVolumeKey) ?? 65;

Future<void> saveVolume(WidgetRef ref, double volume) =>
    ref.read(sharedPreferencesProvider).setDouble(_kVolumeKey, volume);

/// Whether chrome draws liquid glass. On by default: it is the app's look,
/// and the flat fallback exists for machines where the shader pass is too
/// expensive to pay on every scroll frame.
@Riverpod(keepAlive: true)
class GlassEffectsEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kGlassEffectsKey) ?? true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kGlassEffectsKey, enabled);
  }
}

/// Whether lyrics show pronunciation (Romanization / Romaji / Pinyin / Hangul).
/// On by default.
@Riverpod(keepAlive: true)
class LyricsPronunciationEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kLyricsPronunciationKey) ??
      true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kLyricsPronunciationKey, enabled);
  }
}

/// Whether lyrics show translations. On by default.
@Riverpod(keepAlive: true)
class LyricsTranslationEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kLyricsTranslationKey) ??
      true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kLyricsTranslationKey, enabled);
  }
}

/// Whether playback continues indefinitely with random library tracks when
/// the queue reaches the end. On by default.
@Riverpod(keepAlive: true)
class InfinitePlaybackEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kInfinitePlaybackKey) ??
      true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kInfinitePlaybackKey, enabled);
  }
}

/// Whether the playing track's cover colours the window.
///
/// On by default: it is what makes the player feel like it belongs to the
/// album. Off restores the app's own teal seed everywhere.
@Riverpod(keepAlive: true)
class DynamicColorEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kDynamicColorKey) ?? true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kDynamicColorKey, enabled);
  }
}
