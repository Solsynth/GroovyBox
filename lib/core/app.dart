import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dynamic_color.dart';
import 'theme.dart';

part 'app.g.dart';

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
  return _themeSets.putIfAbsent(
    seed,
    () => createAppThemeSet(seedColor: seed),
  );
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
/// album. Off restores the app's own violet seed everywhere.
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
