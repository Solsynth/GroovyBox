import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app.dart';

part 'links.g.dart';

/// Remembers which cloud playlist a device or server playlist was uploaded
/// into, so the next push is a sync instead of a second copy.
///
/// A link is `localKey` → Pulsar playlist id. The local key names the origin —
/// a device playlist by its row id, a server playlist by source and id — so
/// two playlists that happen to share a name never share a link.
class PulsarPlaylistLinks {
  const PulsarPlaylistLinks(this._prefs);

  final SharedPreferences _prefs;

  static String deviceKey(int playlistId) => 'device:$playlistId';

  static String sourceKey(String sourceId, String playlistId) =>
      'source:$sourceId:$playlistId';

  static String _storageKey(String localKey) => 'pulsar_link:$localKey';

  /// The cloud playlist this local key was uploaded into, or null.
  String? of(String localKey) {
    final value = _prefs.getString(_storageKey(localKey));
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Records the link after an upload.
  Future<void> set(String localKey, String pulsarPlaylistId) async {
    await _prefs.setString(_storageKey(localKey), pulsarPlaylistId);
  }

  /// Drops the link, when the cloud playlist is gone or the user starts over.
  Future<void> clear(String localKey) async {
    await _prefs.remove(_storageKey(localKey));
  }

  /// Drops every link that names [pulsarPlaylistId]. Deleting a cloud playlist
  /// must not leave a local one syncing into a 404.
  Future<void> clearForCloud(String pulsarPlaylistId) async {
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith('pulsar_link:')) continue;
      if (_prefs.getString(key) == pulsarPlaylistId) {
        await _prefs.remove(key);
      }
    }
  }
}

/// The link store, over the one preferences instance the app already owns.
@Riverpod(keepAlive: true)
PulsarPlaylistLinks pulsarPlaylistLinks(Ref ref) =>
    PulsarPlaylistLinks(ref.watch(sharedPreferencesProvider));
