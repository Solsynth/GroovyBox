import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../server/subsonic.dart';
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
const _kServerKey = 'app_server';
const _kVolumeKey = 'app_volume';

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_kThemeModeKey);
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

/// The configured server, or null before the first sign-in.
///
/// The stored form holds the Subsonic token and salt rather than the password:
/// signing out simply drops the whole record.
@Riverpod(keepAlive: true)
class ServerConnection extends Notifier<ServerConfig?> {
  @override
  ServerConfig? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_kServerKey);
    if (raw == null) return null;
    try {
      final config = ServerConfig.fromJson(jsonDecode(raw));
      return config?.isAuthenticated == true ? config : null;
    } on FormatException {
      return null;
    }
  }

  /// Stores a signed-in config so the next launch starts connected.
  Future<void> save(ServerConfig config) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kServerKey, jsonEncode(config.toJson()));
    state = config;
  }

  Future<void> clear() async {
    await ref.read(sharedPreferencesProvider).remove(_kServerKey);
    state = null;
  }
}

/// The active API client, or null when not signed in.
///
/// Rebuilt whenever the connection changes, which is what makes every screen
/// follow a server switch without any manual refresh.
@Riverpod(keepAlive: true)
SubsonicClient? subsonicClient(Ref ref) {
  final config = ref.watch(serverConnectionProvider);
  return config == null ? null : SubsonicClient(config);
}

/// Last volume, restored so the window does not startle the user.
@Riverpod(keepAlive: true)
double initialVolume(Ref ref) =>
    ref.watch(sharedPreferencesProvider).getDouble(_kVolumeKey) ?? 65;

Future<void> saveVolume(WidgetRef ref, double volume) =>
    ref.read(sharedPreferencesProvider).setDouble(_kVolumeKey, volume);
