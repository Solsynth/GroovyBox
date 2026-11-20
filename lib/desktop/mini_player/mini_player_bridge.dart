import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/client.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork_pixels.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/song_actions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:window_manager/window_manager.dart';

part 'mini_player_bridge.g.dart';

/// The two owners the guest is told about by name rather than by id: this
/// device's own playlists, and the account's cloud ones.
const _kDeviceOwner = 'device';
const _kCloudOwner = 'cloud';

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
      // The guest has no sources and no cover cache, so a cover is resolved
      // here: the cache's file when there is one, the art URL otherwise.
      case kResolveArtworkMethod:
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final pixels = await ref.read(
          artworkPixelsProvider(
            ArtworkHandle(
              sourceId: args['sourceId'] as String,
              artId: args['artId'] as String?,
              size: (args['size'] as num?)?.toInt() ?? 512,
            ),
          ).future,
        );
        return pixels == null
            ? null
            : {kArtworkUriField: pixels.uri.toString()};
      // Favourites, playlists and the share all write an account or a database
      // the guest does not hold. The host is the record for each of them.
      case kFavouriteStateMethod:
        final song = LibrarySong.fromJson(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        return await ref.read(solarFavouriteStateProvider(song).future);
      case kToggleFavouriteMethod:
        final song = LibrarySong.fromJson(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        if (!_actionsFor(song).canFavourite) return null;
        final favourite = await ref.read(
          solarFavouriteStateProvider(song).future,
        );
        final next = !favourite;
        // The device's record first, then the account's, exactly as the
        // player page's bar writes it: one order, one meaning of the heart.
        final error = await ref.read(favouritesProvider).set(song, value: next);
        Object? fleetError;
        if (ref.read(pulsarSessionProvider).value != null && !song.isRadio) {
          try {
            await ref
                .read(pulsarFavouritesProvider.notifier)
                .set(song, value: next);
          } catch (error) {
            fleetError = error;
          }
        }
        // Dropping the family entries is what turns every surface showing
        // this track — the host's own pages included — with one write.
        ref.invalidate(favouriteStateProvider(song));
        ref.invalidate(solarFavouriteStateProvider(song));
        final failure = error ?? fleetError;
        return {
          'value': next,
          if (failure != null) 'error': describeServerError(failure),
        };
      case kPlaylistTargetsMethod:
        final song = LibrarySong.fromJson(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        return [
          for (final target in await _playlistTargets(song)) target.toJson(),
        ];
      case kCreatePlaylistMethod:
        final name = call.arguments as String?;
        if (name == null || name.trim().isEmpty) return null;
        final playlist = await ref
            .read(ownedPlaylistsProvider.notifier)
            .create(name.trim());
        if (playlist == null) return null;
        return MiniPlaylistTarget(
          owner: _kDeviceOwner,
          id: '${playlist.id}',
          name: playlist.name,
          trackCount: playlist.trackCount,
        ).toJson();
      case kAddToPlaylistMethod:
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final target = decodePlaylistTargetKey(args['key']);
        final song = LibrarySong.fromJson(
          Map<String, dynamic>.from(args['song'] as Map),
        );
        if (target == null) return null;
        try {
          await _writeTo(target, song);
          return null;
        } catch (error) {
          return {'error': describeServerError(error)};
        }
      case kShareTrackMethod:
        final song = LibrarySong.fromJson(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        // Run here rather than hop back: the host holds the account session
        // and the library that resolves the artwork URL. No popover origin is
        // passed — this window is not the tap's surface — so the sheet takes
        // its own default placement.
        try {
          final session = await ref.read(pulsarSessionProvider.future);
          if (session == null) {
            return {'error': 'playerShareNeedsAccount'.tr()};
          }
          final artUri = ref
              .read(librarySourceByIdProvider)[song.sourceId]
              ?.artworkUri(song.artId);
          final share = await ref
              .read(pulsarClientProvider)
              .shareTrack(
                session,
                title: song.title,
                artist: song.artist,
                album: song.album,
                artworkUrl: artUri?.toString(),
                durationSeconds: song.duration.inSeconds,
                trackKey: pulsarTrackKey(song),
              );
          await SharePlus.instance.share(
            ShareParams(text: share.shareUrl, subject: song.title),
          );
          return null;
        } catch (error) {
          return {'error': describeServerError(error)};
        }
    }
    return null;
  }

  /// What the track's source can do with it, asked per write rather than
  /// cached: a reconnect changes the answer without changing the song.
  SongActions _actionsFor(LibrarySong song) {
    final source = ref.read(librarySourceByIdProvider)[song.sourceId];
    return SongActions(
      source is RatedSource ? source : null,
      source is ExtendableSource ? source : null,
      song,
    );
  }

  /// Every destination this device can put [song] in.
  ///
  /// The same three lists the full picker shows — this device's own playlists,
  /// the account's cloud ones, and the connected libraries' editable ones —
  /// flattened for the guest, which holds none of them. A source that only
  /// reads is absent, because offering a write it will refuse is worse than
  /// a shorter menu.
  Future<List<MiniPlaylistTarget>> _playlistTargets(LibrarySong song) async {
    final owned = await ref.read(ownedPlaylistsProvider.future);
    final cloud = ref.read(pulsarPlaylistsProvider).value ?? const [];
    final signedIn = ref.read(pulsarSessionProvider).value != null;
    final actions = _actionsFor(song);
    final targets = <MiniPlaylistTarget>[
      for (final playlist in owned)
        MiniPlaylistTarget(
          owner: _kDeviceOwner,
          id: '${playlist.id}',
          name: playlist.name,
          trackCount: playlist.trackCount,
        ),
      if (signedIn)
        for (final playlist in cloud)
          MiniPlaylistTarget(
            owner: _kCloudOwner,
            id: playlist.id,
            name: playlist.name,
            trackCount: playlist.items.length,
          ),
    ];
    if (actions.canAddToPlaylist) {
      try {
        for (final playlist in await actions.editablePlaylists()) {
          targets.add(
            MiniPlaylistTarget(
              owner: playlist.sourceId,
              id: playlist.id,
              name: playlist.name,
              trackCount: playlist.songCount ?? 0,
            ),
          );
        }
      } catch (_) {
        // A store that will not list its playlists is one that cannot take
        // this write: the device's own lists are still offered above.
      }
    }
    return targets;
  }

  /// Performs the write a [MiniPlaylistTarget] names.
  ///
  /// Each owner writes through its own notifier, exactly as the full picker
  /// does, so the guest's tap and the main window's tap land in the same
  /// place. A key the host did not issue answers nothing rather than
  /// guessing a destination.
  Future<void> _writeTo(
    ({String owner, String id}) target,
    LibrarySong song,
  ) async {
    switch (target.owner) {
      case _kDeviceOwner:
        await ref.read(ownedPlaylistsProvider.notifier).add(
          int.parse(target.id),
          [song],
        );
      case _kCloudOwner:
        final playlists = ref.read(pulsarPlaylistsProvider).value ?? const [];
        final playlist = playlists
            .where((playlist) => playlist.id == target.id)
            .firstOrNull;
        if (playlist == null) return;
        await ref
            .read(pulsarPlaylistsProvider.notifier)
            .addSong(playlist, song);
      default:
        final actions = _actionsFor(song);
        final playlists = await actions.editablePlaylists();
        final playlist = playlists
            .where((playlist) => playlist.id == target.id)
            .firstOrNull;
        if (playlist == null) return;
        await actions.addToPlaylist(playlist);
    }
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
        // The guest cannot ask nativeapi for "its own" window — that query
        // answers the app's main window inside any engine — so the host
        // names itself and the guest takes the other one.
        arguments: jsonEncode({
          'kind': 'miniPlayer',
          'mainWindowId': WindowManager.instance.getCurrent()?.id,
        }),
      ),
    );
    await _controller!.show();
  } catch (_) {
    // A window the platform refused to create leaves the main window alone:
    // a convenience button must never surface an error of its own.
    _controller = null;
  }
}
