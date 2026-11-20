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

/// Window height of the bar shape.
///
/// The window is frameless and [DesktopWindowFrame] draws a 32px title band
/// *over* the content, so the artwork runs behind the traffic lights and the
/// view's stack opens with a 32px band spacer. The band is therefore already
/// inside this height: adding it again put 32px of empty surface under the
/// transport, which is the dead strip this constant now measures exactly.
///
/// 196 is the stack to the pixel: band 32, header 64, scrubber 44, transport
/// 56.
const kMiniPlayerBarHeight = 196.0;

/// Height of the footer — scrubber and transport — where a pane lays it over
/// itself: measured 100 (scrubber 44, transport 56), no cushion.
///
/// The bar shape lays the footer out inline instead, so this is only the
/// space a pane's last row keeps clear and the height of the scrim behind the
/// floating controls.
const kMiniPlayerFooterHeight = 100.0;

/// How far above the footer its scrim starts fading in, so the pane's words
/// run out under a gradient rather than meeting a hard edge.
const kMiniPlayerFooterFadeHeight = 24.0;

/// Extra height over the bar when the queue or the lyrics open, and the floor
/// an open pane may be dragged back to.
///
/// The pane is whatever sits below the band (32) and the compact header (56),
/// so 260 opens 368px of pane — 268 of it clear of the floating footer, which
/// is a screenful of lyrics or queue rows. The 200 this replaces opened 308
/// and then handed 132 of those to a footer that measures 100.
const kMiniPlayerPaneMinHeight = 260.0;

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
const _kLyricsLlmModelKey = 'app_lyrics_llm_model';
const _kInfinitePlaybackKey = 'app_infinite_playback';
const _kDynamicColorKey = 'app_dynamic_color';
const _kPreferredPlaybackSourceKey = 'app_preferred_playback_source';

/// Which sections the user has folded away, per page.
///
/// Pages are one long scroll of shelves, and someone who came for their
/// playlists should not have to scroll past every album to reach them. A
/// folded section keeps its header — so the way back is always visible — and
/// the set is remembered: folding once is a decision about how this user
/// reads their own dashboard, not a gesture repeated every launch.
///
/// Keys are `page:id` — see [FoldableSection] — so a fold on one page never
/// moves a section on another. The old library-only set is still read once
/// and folded in: a user's existing folds are a decision already made.
@Riverpod(keepAlive: true)
class CollapsedSections extends Notifier<Set<String>> {
  static const _key = 'app_collapsed_sections';
  static const _legacyKey = 'app_library_collapsed_sections';
  static const _legacyPage = 'library';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getStringList(_key);
    if (saved != null) return saved.toSet();
    final legacy = prefs.getStringList(_legacyKey);
    if (legacy == null) return const {};
    return {for (final section in legacy) '$_legacyPage:$section'};
  }

  Future<void> toggle(String page, String section) async {
    final key = '$page:$section';
    final next = {...state};
    if (!next.remove(key)) next.add(key);
    await _save(next);
  }

  Future<void> _save(Set<String> next) async {
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, next.toList()..sort());
  }
}

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

/// The Persona model (`provider/model-name`) that translates lyrics, or null
/// for Google Translate.
///
/// This one pref *is* the opt-in: nothing optional is sent anywhere until a
/// model is named here, and clearing it returns the device to the free engine.
/// Stored as the catalogue id rather than a display name so the same choice
/// survives a friendly rename of the agent.
@Riverpod(keepAlive: true)
class LyricsLlmModel extends Notifier<String?> {
  @override
  String? build() {
    final model = ref
        .watch(sharedPreferencesProvider)
        .getString(_kLyricsLlmModelKey)
        ?.trim();
    return model == null || model.isEmpty ? null : model;
  }

  Future<void> set(String? model) async {
    final clean = model?.trim();
    state = clean == null || clean.isEmpty ? null : clean;
    final prefs = ref.read(sharedPreferencesProvider);
    if (state == null) {
      await prefs.remove(_kLyricsLlmModelKey);
    } else {
      await prefs.setString(_kLyricsLlmModelKey, state!);
    }
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

/// The library the user always wants to hear from, or null for "the row's own".
///
/// Playback asks this before it opens a track: when the library holds the
/// recording, its copy plays and the row follows it there — so a queue mixed
/// from every source still sounds like the one the user picked, and a track
/// one library only sells as an excerpt plays in full from the favourite.
/// Null keeps the old rule, where each track plays from the library it came
/// from and alternates are only a fallback.
///
/// A stale id (its library was disconnected) simply matches no source, and
/// playback falls back to the track's own library.
@Riverpod(keepAlive: true)
class PreferredPlaybackSource extends Notifier<String?> {
  @override
  String? build() => ref
      .watch(sharedPreferencesProvider)
      .getString(_kPreferredPlaybackSourceKey);

  Future<void> set(String? sourceId) async {
    state = sourceId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (sourceId == null) {
      await prefs.remove(_kPreferredPlaybackSourceKey);
      return;
    }
    await prefs.setString(_kPreferredPlaybackSourceKey, sourceId);
  }
}
