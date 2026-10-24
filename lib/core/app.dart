import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

@Riverpod(keepAlive: true)
ThemeSet appTheme(Ref ref) => createAppThemeSet();

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
