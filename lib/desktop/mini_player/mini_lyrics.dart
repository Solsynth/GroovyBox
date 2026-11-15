import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/library/lrclib.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_resolver.dart';

/// The mini window's lyrics: every answer comes from the host engine.
///
/// A second drift instance on the same SQLite file corrupted the Dart heap on
/// macOS, so the guest opens no database at all. That leaves its resolver with
/// nothing to read or write — every lyric, and every hand-picked one, has to
/// be asked of the host, which owns the cache and the library credentials.
///
/// The guest still uses the ordinary [LyricsResolver] interface, so the pane
/// and the rescue sheet need no guest-only branches: they call the provider
/// they always did, and the hop happens underneath.
class HostLyricsResolver extends LyricsResolver {
  HostLyricsResolver(MiniPlayerLink link)
    : this.withCommand(link.command<Object?>);

  /// [command] is the link's request/response call; injectable so the codec
  /// hops can be tested without two engines.
  HostLyricsResolver.withCommand(this._command)
    : super(catalog: null, store: null, lrclib: Lrclib());

  final Future<Object?> Function(String method, [Object? arguments]) _command;

  @override
  Future<Lyrics> resolve(
    LyricsRequest song, {
    bool refresh = false,
    String? languageCode,
  }) async {
    final reply = await _command('resolveLyrics', {
      ...encodeLyricsRequest(song, languageCode: languageCode),
      'refresh': refresh,
    });
    // A host that is not there yet answers nothing: an empty pane is a
    // normal state, and the next rebuild asks again.
    if (reply is! Map) return Lyrics.empty;
    return decodeLyrics(Map<String, dynamic>.from(reply));
  }

  /// Writes a hand-picked lyric in the host's cache and returns what it
  /// stored, enriched the same way a play-time fetch would be.
  @override
  Future<Lyrics> adopt(
    LyricsRequest song,
    Lyrics lyrics, {
    String? languageCode,
  }) async {
    final reply = await _command('adoptLyrics', {
      'request': encodeLyricsRequest(song, languageCode: languageCode),
      'lyrics': encodeLyrics(lyrics),
    });
    if (reply is! Map) return lyrics;
    return decodeLyrics(Map<String, dynamic>.from(reply));
  }

  /// Drops the host's cached answer for the track.
  ///
  /// The "ask again" button is `forget` + invalidate: the guest's own cache
  /// does not exist, so without this hop the invalidated pane would ask the
  /// host and be handed the very lyric the user rejected.
  @override
  Future<void> forget(LyricsRequest song) async {
    await _command('forgetLyrics', encodeLyricsRequest(song));
  }
}
