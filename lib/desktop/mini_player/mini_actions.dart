import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/library/models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The track-level reads and writes the mini window offers, all answered by
/// the host.
///
/// The guest has no database, no library sources and no account session, so
/// every one of these is a question or a command across the link. Nothing is
/// cached here: the host's providers are the record, and each call asks again.
///
/// A null [MiniPlayerLink] is a guest with no peer — a widget test, or a host
/// that has not started yet. Every call then answers nothing rather than
/// throwing, which is the same posture the transport already takes.
class MiniActions {
  final MiniPlayerLink? _link;

  const MiniActions(this._link);

  /// Whether the host's record says this track is a favourite.
  Future<bool> favourite(LibrarySong song) async {
    final reply = await _link?.command<Object?>(
      kFavouriteStateMethod,
      song.toJson(),
    );
    return reply is bool ? reply : false;
  }

  /// Flips the favourite in the host.
  ///
  /// [error] is the host's words when a write half-landed — the device kept
  /// the heart, the account never heard about it — and null when all agreed.
  Future<({bool value, String? error})?> toggleFavourite(
    LibrarySong song,
  ) async {
    final reply = await _link?.command<Object?>(
      kToggleFavouriteMethod,
      song.toJson(),
    );
    if (reply is! Map) return null;
    final value = reply['value'];
    if (value is! bool) return null;
    return (value: value, error: reply['error'] as String?);
  }

  /// Where this device and its accounts can put the track.
  Future<List<MiniPlaylistTarget>> playlistTargets(LibrarySong song) async {
    final reply = await _link?.command<Object?>(
      kPlaylistTargetsMethod,
      song.toJson(),
    );
    if (reply is! List) return const [];
    return [for (final entry in reply) ?MiniPlaylistTarget.fromJson(entry)];
  }

  /// Makes a device playlist and returns the destination to add to.
  Future<MiniPlaylistTarget?> createPlaylist(String name) async {
    final reply = await _link?.command<Object?>(kCreatePlaylistMethod, name);
    if (reply is! Map) return null;
    return MiniPlaylistTarget.fromJson(reply);
  }

  /// Writes the track into [target]. Null on success, or the host's words on
  /// failure — the account's own message reads better than anything invented
  /// on this side of the hop.
  Future<String?> addToPlaylist(
    MiniPlaylistTarget target,
    LibrarySong song,
  ) async {
    final reply = await _link?.command<Object?>(kAddToPlaylistMethod, {
      'key': target.key,
      'song': song.toJson(),
    });
    if (reply is Map && reply['error'] is String) {
      return reply['error'] as String;
    }
    return null;
  }

  /// Shares the track from the host, which is the engine holding the account
  /// session and the artwork URL. Null on success, otherwise what to tell the
  /// user — the host has the share sheet's origin and the guest does not.
  Future<String?> share(LibrarySong song) async {
    final reply = await _link?.command<Object?>(
      kShareTrackMethod,
      song.toJson(),
    );
    if (reply is Map && reply['error'] is String) {
      return reply['error'] as String;
    }
    return null;
  }
}

/// The link-backed actions. `main()` overrides this with the guest's link; the
/// default is a peerless instance, so a widget test or a host build can draw
/// the view without one and every call simply answers nothing.
final miniActionsProvider = Provider<MiniActions>(
  (ref) => const MiniActions(null),
);

/// The favourite state of one track, asked of the host.
///
/// Family keyed by [TrackLookup], which has value equality on the source and
/// id — [LibrarySong] itself does not, and a family without it would mint a
/// new provider on every rebuild.
final miniFavouriteProvider = FutureProvider.family<bool, TrackLookup>(
  (ref, track) => ref.watch(miniActionsProvider).favourite(track.song),
);
