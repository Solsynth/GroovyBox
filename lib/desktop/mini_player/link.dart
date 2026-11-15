import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The one cross-engine channel between the main window and the mini player.
const kMiniPlayerChannelName = 'groovy_box/mini_player';

/// The player screen's state, flattened for the cross-engine hop.
///
/// The mini window runs its own engine with its own [playbackProvider]-shaped
/// state, but the transport itself stays in the main engine: a second
/// [Player] would fight the first for the audio session. These codecs are the
/// wire format between them — pure functions so they can be round-trip tested
/// without two engines.
Map<String, dynamic> encodeSnapshot(PlaybackState state) => {
  'kind': 'snapshot',
  // Position rides the snapshot too: the guest's scrubber reads it, and a
  // snapshot that omitted it would snap the thumb back to 0:00 on every
  // track change, pause, or duration update until the next tick arrived.
  'positionMs': state.position.inMilliseconds,
  'queue': [for (final song in state.queue) song.toJson()],
  'stationTracks': [for (final song in state.stationTracks) song.toJson()],
  'currentIndex': state.currentIndex,
  'stationIndex': state.stationIndex,
  'playing': state.playing,
  'buffering': state.buffering,
  'durationMs': state.duration.inMilliseconds,
  'shuffle': state.shuffle,
  'repeatMode': switch (state.repeatMode) {
    PlaybackRepeatMode.off => 'off',
    PlaybackRepeatMode.all => 'all',
    PlaybackRepeatMode.single => 'single',
  },
  'volume': state.volume,
};

/// Position-only update: one per second while playing, and everything but the
/// clock is already on the guest from the last snapshot.
Map<String, dynamic> encodeTick(PlaybackState state) => {
  'kind': 'tick',
  'positionMs': state.position.inMilliseconds,
  'durationMs': state.duration.inMilliseconds,
  'playing': state.playing,
};

/// Lines and their layers, for the cross-engine lyrics hop.
///
/// The mini window has no database (a second drift instance on the same file
/// corrupted the heap on macOS), so every lyric it shows is the host's, and
/// every lyric the user picks there is written by the host.
Map<String, dynamic> encodeLyrics(Lyrics lyrics) => {
  'synced': lyrics.synced,
  'language': lyrics.language,
  'translationLanguage': lyrics.translationLanguage,
  'lines': [
    for (final line in lyrics.lines)
      {
        'at': line.at.inMilliseconds,
        'text': line.text,
        if (line.pronunciation != null) 'pronunciation': line.pronunciation,
        if (line.translation != null) 'translation': line.translation,
      },
  ],
};

/// Rebuilds [Lyrics] from [encodeLyrics]'s output.
Lyrics decodeLyrics(Map<String, dynamic> json) => Lyrics(
  synced: json['synced'] as bool? ?? false,
  language: json['language'] as String?,
  translationLanguage: json['translationLanguage'] as String?,
  lines: [
    for (final line in (json['lines'] as List<dynamic>? ?? const []))
      LyricLine(
        Duration(milliseconds: (line as Map)['at'] as int? ?? 0),
        line['text'] as String? ?? '',
        pronunciation: line['pronunciation'] as String?,
        translation: line['translation'] as String?,
      ),
  ],
);
/// A [LyricsRequest] on the wire: the mini window has no catalog to key a
/// lookup with, so it sends the fields the host's resolver matches on.
Map<String, dynamic> encodeLyricsRequest(
  LyricsRequest song, {
  String? languageCode,
}) => {
  'sourceId': song.sourceId,
  'id': song.id,
  'title': song.title,
  'artist': ?song.artist,
  'album': ?song.album,
  'durationMs': song.duration.inMilliseconds,
  'languageCode': ?languageCode,
};

/// Rebuilds a [LyricsRequest]; see [encodeLyricsRequest].
LyricsRequest decodeLyricsRequest(Map<String, dynamic> json) => LyricsRequest(
  sourceId: json['sourceId'] as String,
  id: json['id'] as String,
  title: json['title'] as String? ?? '',
  artist: json['artist'] as String?,
  album: json['album'] as String?,
  duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
);

/// Rebuilds a [PlaybackState] from [encodeSnapshot]'s output.
///
/// Unknown or missing fields fall back to [PlaybackState]'s defaults; a
/// payload that cannot be parsed at all throws, which the receiver catches —
/// a malformed message must never take the mini window down.
PlaybackState decodeSnapshot(Map<String, dynamic> json) => PlaybackState(
  queue: [
    for (final song in (json['queue'] as List<dynamic>? ?? const []))
      LibrarySong.fromJson(Map<String, dynamic>.from(song as Map)),
  ],
  stationTracks: [
    for (final song in (json['stationTracks'] as List<dynamic>? ?? const []))
      LibrarySong.fromJson(Map<String, dynamic>.from(song as Map)),
  ],
  currentIndex: json['currentIndex'] as int?,
  stationIndex: json['stationIndex'] as int? ?? -1,
  playing: json['playing'] as bool? ?? false,
  buffering: json['buffering'] as bool? ?? false,
  position: Duration(milliseconds: json['positionMs'] as int? ?? 0),
  duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
  shuffle: json['shuffle'] as bool? ?? false,
  repeatMode: switch (json['repeatMode'] as String?) {
    'all' => PlaybackRepeatMode.all,
    'single' => PlaybackRepeatMode.single,
    'off' || null => PlaybackRepeatMode.off,
    _ => throw FormatException('Unknown repeat mode', json['repeatMode']),
  },
  volume: (json['volume'] as num?)?.toDouble() ?? 100,
);

/// Whether [a] carries anything the guest cannot derive from [b]'s snapshot.
///
/// The host sends a full snapshot only when the queue, the track, or a mode
/// changed; a position tick is cheaper by an order of magnitude. Only
/// [PlaybackState.position] rides the tick, so everything else differing
/// means a snapshot.
bool snapshotDiffersFromTick(PlaybackState a, PlaybackState b) =>
    a.queue.length != b.queue.length ||
    a.currentIndex != b.currentIndex ||
    a.stationIndex != b.stationIndex ||
    a.playing != b.playing ||
    a.buffering != b.buffering ||
    a.duration != b.duration ||
    a.shuffle != b.shuffle ||
    a.repeatMode != b.repeatMode ||
    a.volume != b.volume ||
    a.stationTracks.length != b.stationTracks.length ||
    !_sameSongs(a.queue, b.queue) ||
    !_sameSongs(a.stationTracks, b.stationTracks);

bool _sameSongs(List<LibrarySong> a, List<LibrarySong> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].sourceId != b[i].sourceId || a[i].id != b[i].id) return false;
  }
  return true;
}

/// The transport bridge between the two engines.
///
/// The host (main window) publishes state and answers transport commands; the
/// guest (mini window) renders what it receives and asks the host to act.
/// Both directions swallow [WindowChannelException]: a peer that has not come
/// up yet — or is already gone — is a stale panel, not a crash.
class MiniPlayerLink {
  MiniPlayerLink.host()
    : _channel = const WindowMethodChannel(
        kMiniPlayerChannelName,
        mode: ChannelMode.bidirectional,
      );

  MiniPlayerLink.guest()
    : _channel = const WindowMethodChannel(
        kMiniPlayerChannelName,
        mode: ChannelMode.bidirectional,
      );

  final WindowMethodChannel _channel;

  /// Guest: what to do with a full state snapshot from the host. Assigned by
  /// the guest's state notifier; cleared when it disposes.
  void Function(Map<String, dynamic> json)? onSnapshot;

  /// Guest: what to do with a position tick from the host.
  void Function(Duration position, Duration duration, bool playing)? onTick;

  /// Host: registers the command handler. Called once, before the first
  /// window is created, so the guest's opening command finds a listener.
  Future<void> start(Future<void> Function(MethodCall) onCommand) =>
      _channel.setMethodCallHandler(onCommand);

  /// Host: publishes state. Fire-and-forget — the guest engine may be gone
  /// the moment after the user closed its window, and that is not an error.
  void publish(PlaybackState state, {required bool full}) {
    unawaited(
      _channel
          .invokeMethod<void>(
            full ? 'snapshot' : 'tick',
            full ? encodeSnapshot(state) : encodeTick(state),
          )
          // A peer that is not there yet — or already gone — is a stale
          // panel, not an error worth surfacing.
          .catchError((Object _) => null),
    );
  }

  /// Guest: registers the handler for host messages and routes each one to
  /// the callbacks above. Called once, before the first frame.
  Future<void> startGuest() => _channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'snapshot':
        onSnapshot?.call(Map<String, dynamic>.from(call.arguments as Map));
      case 'tick':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        onTick?.call(
          Duration(milliseconds: args['positionMs'] as int? ?? 0),
          Duration(milliseconds: args['durationMs'] as int? ?? 0),
          args['playing'] as bool? ?? false,
        );
    }
  });

  /// Guest: asks the host to do something. Fire-and-forget for the same
  /// reason [publish] is: a missing host leaves a stale panel, never a crash.
  Future<T?> command<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on WindowChannelException {
      return null;
    }
  }
}

/// Provided once per engine by `main()`; both roles override it, so reading
/// it anywhere else is a wiring bug, not a runtime state.
final miniPlayerLinkProvider = Provider<MiniPlayerLink>(
  (ref) =>
      throw StateError('miniPlayerLinkProvider must be overridden in main()'),
);
