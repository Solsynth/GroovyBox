import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mini_player_bridge.g.dart';

/// How eagerly the host publishes: a state change inside this window of the
/// previous one rides the trailing edge, so a burst of events sends one
/// message instead of one per event. Position ticks arrive once a second;
/// everything else is rare, so the cost of waiting is nothing and the guest's
/// repaints collapse into one.
const _kPublishInterval = Duration(milliseconds: 100);

/// Publishes the main engine's playback state to the mini player window and
/// answers its transport commands.
///
/// Started on demand — the first press of the player page's mini-player
/// button — and kept alive after that: the guest engine may outlive the
/// button's own widget, and a handler that died with it would leave a mini
/// window that renders but cannot act.
@Riverpod(keepAlive: true)
class MiniPlayerBridge extends Notifier<void> {
  ProviderSubscription<PlaybackState>? _subscription;
  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _trailing;
  PlaybackState? _pending;
  PlaybackState? _lastSent;

  /// Wires the command handler and the state watch, once.
  ///
  /// Idempotent on purpose: every button press calls this, and re-registering
  /// a handler that already exists would double-fire commands.
  void ensureStarted() {
    if (_subscription != null) return;

    final link = ref.read(miniPlayerLinkProvider);
    // Registered before the window is created, so the guest's first command
    // (it starts asking as soon as it mounts) finds a listener.
    unawaited(link.start((call) async => _onCommand(call)));

    _subscription = ref.listen(playbackProvider, (_, next) {
      _publish(next);
    });
    ref.onDispose(() {
      _trailing?.cancel();
      _subscription?.close();
      _subscription = null;
    });
  }

  @override
  void build() {
    ensureStarted();
  }

  Future<Object?> _onCommand(MethodCall call) async {
    final controller = ref.read(playbackProvider.notifier);
    switch (call.method) {
      // A window that just opened asks for the current state: the host only
      // publishes on change, so opening it between two changes would
      // otherwise leave it blank until something moved.
      case 'requestSnapshot':
        _send(ref.read(playbackProvider));
        // Answered explicitly: the guest keeps asking until a request lands,
        // and a null reply cannot be told apart from "no host yet".
        return true;
      case 'play':
        await controller.play();
      case 'pause':
        await controller.pause();
      case 'togglePlayPause':
        await controller.togglePlayPause();
      case 'next':
        await controller.next();
      case 'previous':
        await controller.previous();
      case 'seek':
        await controller.seek(Duration(milliseconds: call.arguments as int));
      case 'setShuffle':
        await controller.setShuffle(call.arguments as bool);
      case 'cycleRepeatMode':
        await controller.cycleRepeatMode();
      case 'skipToQueueIndex':
        await controller.skipToQueueIndex(call.arguments as int);
      case 'setVolume':
        await controller.setVolume((call.arguments as num).toDouble());
      case 'playQueue':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        await controller.playQueue([
          for (final song in args['songs'] as List<dynamic>)
            LibrarySong.fromJson(Map<String, dynamic>.from(song as Map)),
        ], startIndex: args['startIndex'] as int? ?? 0);
      // The guest has no database, so its lyrics pane answers from here: the
      // host owns the cache, the library credentials and the enricher.
      case 'resolveLyrics':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final resolver = await ref.read(lyricsResolverProvider.future);
        final lyrics = await resolver.resolve(
          decodeLyricsRequest(args),
          refresh: args['refresh'] as bool? ?? false,
          languageCode: args['languageCode'] as String?,
        );
        return encodeLyrics(lyrics);
      case 'forgetLyrics':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final resolver = await ref.read(lyricsResolverProvider.future);
        await resolver.forget(decodeLyricsRequest(args));
      case 'adoptLyrics':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final request = decodeLyricsRequest(
          Map<String, dynamic>.from(args['request'] as Map),
        );
        final resolver = await ref.read(lyricsResolverProvider.future);
        final stored = await resolver.adopt(
          request,
          decodeLyrics(Map<String, dynamic>.from(args['lyrics'] as Map)),
          languageCode: args['languageCode'] as String?,
        );
        // The host's own pane is showing the family entry for this track, so
        // it is the host that rebuilds it; the guest does the same locally.
        ref.invalidate(songLyricsProvider(request));
        ref.invalidate(storedLyricsProvider);
        return encodeLyrics(stored);
    }
    return null;
  }

  void _publish(PlaybackState state) {
    _trailing?.cancel();
    final now = DateTime.now();
    final elapsed = now.difference(_lastSend);
    if (elapsed < _kPublishInterval) {
      _pending = state;
      _trailing = Timer(_kPublishInterval - elapsed, () {
        final pending = _pending;
        _pending = null;
        if (pending != null) _send(pending);
      });
      return;
    }
    _send(state);
  }

  void _send(PlaybackState state) {
    _lastSend = DateTime.now();
    final last = _lastSent;
    _lastSent = state;
    if (last == null || snapshotDiffersFromTick(state, last)) {
      ref.read(miniPlayerLinkProvider).publish(state, full: true);
    } else {
      ref.read(miniPlayerLinkProvider).publish(state, full: false);
    }
  }
}

/// The mini player window's controller, kept across the presses that show and
/// hide it. Null after a failed create or a window destroyed underneath us —
/// the next call rebuilds it.
WindowController? _controller;

/// Opens (or re-shows) the always-on-top mini player window.
///
/// The window's engine starts hidden ([WindowConfiguration.hiddenAtLaunch])
/// and its first frame is drawn before `show()`, so reopening never flashes
/// an empty surface. A controller that fails to show — the window was closed
/// from the taskbar or destroyed by the OS — is discarded and rebuilt once;
/// a second failure leaves the main window alone, which is strictly better
/// than an error surfaced from a convenience button.
Future<void> openMiniPlayer(WidgetRef ref) async {
  ref.read(miniPlayerBridgeProvider.notifier).ensureStarted();

  if (_controller != null) {
    try {
      await _controller!.show();
      return;
    } catch (_) {
      _controller = null;
    }
  }
  try {
    _controller = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode({'kind': 'miniPlayer'}),
      ),
    );
    await _controller!.show();
  } catch (_) {
    // A window the platform refused to create leaves the main window alone:
    // a convenience button must never surface an error of its own.
    _controller = null;
  }
}
