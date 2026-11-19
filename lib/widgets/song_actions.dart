import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/pulsar/client.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/playlist_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// What the account can remember about a track: whether it is a favourite,
/// and which of its own playlists it can still be put into.
///
/// Both are *writes* to an account, so this class only ever acts on a tap and
/// never as a side effect of drawing the page. A source that cannot write at
/// all is not offered either control, which is why every member here is
/// nullable rather than throwing.
///
/// Favourites are the device's own record: the heart is drawn from the local
/// library, written there first, and only then forwarded to a connected source
/// that can remember it. A server being offline, swapped or refusing the write
/// therefore does not lose the answer — it just has not been told yet.
///
/// Adding to a playlist is the other side of the same coin: the picker offers
/// this device's own playlists (which exist before any library does) and, when
/// the account has editable playlists of its own, those too.
///
/// The bar also watches the source's identity, not just the track: a route
/// that swaps the whole library (a new server, a removed one) changes what
/// the buttons can do without changing the song.
class SongActions {
  final RatedSource? _rated;
  final ExtendableSource? _extendable;
  final LibrarySong _song;

  const SongActions(this._rated, this._extendable, this._song);

  /// The track these actions act on, for callers outside the bar that only
  /// hold the actions object.
  LibrarySong get song => _song;

  /// Whether this track can be favourited at all.
  ///
  /// A station is a standing request, not a track: a favourite of one would
  /// mean nothing, and the platform player is still resolving what it will
  /// play next. A source that cannot forward is still offered the heart: the
  /// record is the device's, and forwarding is best effort.
  bool get canFavourite => !_song.isRadio;

  /// Whether this track can be put into one of the account's playlists.
  bool get canAddToPlaylist => !_song.isRadio;

  /// Whether the account behind this source can remember a favourite too.
  bool get forwards => _rated != null;

  /// The account's own editable playlists, if its source has any.
  Future<List<LibraryPlaylist>> editablePlaylists() async {
    final source = _extendable;
    if (source == null) return const [];
    return source.editablePlaylists();
  }

  Future<void> addToPlaylist(LibraryPlaylist playlist) async {
    final source = _extendable;
    if (source == null) return;
    await source.addToPlaylist(playlist, _song);
  }
}

/// The two controls the player page adds for a track: a heart that writes the
/// account's own rating, and a button that puts the track in a playlist of the
/// account's.
///
/// They sit with the transport rather than in the corner, because both are
/// about the track that is playing now — the corner controls are about the
/// page. The heart reads the account rather than a local flag, so it shows the
/// same value the stock Music app does, and it stays in step when the count
/// changes elsewhere.
class SongActionBar extends ConsumerStatefulWidget {
  final LibrarySong song;

  const SongActionBar({super.key, required this.song});

  @override
  ConsumerState<SongActionBar> createState() => _SongActionBarState();
}

class _SongActionBarState extends ConsumerState<SongActionBar> {
  /// Null until the account has answered, so the heart does not flash
  /// "not set" on a track that is in fact a favourite.
  bool? _favourite;

  /// The track whose favourite [_favourite] describes. A station reports a new
  /// track under the same row, so the row's identity is not enough to know
  /// whether the answer still applies.
  String? _key;

  bool _busy = false;

  /// Anchors the share popover on iPad. The share used to be reported broken
  /// partly because it opened with no origin, which fails outright there.
  final _shareKey = GlobalKey();

  /// Whether the Pulsar session that actually serves the share link is
  /// present. It was reading Solarpass, which can be signed in while Pulsar
  /// is not — the button then appeared and did nothing.
  bool get _signedIn =>
      ref.watch(pulsarSessionProvider.select((s) => s.value != null));

  /// What the account can do with this track, or a no-op when its source has
  /// no write capability: a server reads and plays but has no account of its
  /// own to save anything to. A cast would fail on that source, and this is a
  /// capability question rather than a kind one.
  SongActions get _actions {
    final source = ref.watch(
      librarySourceByIdProvider.select(
        (sources) => sources[widget.song.sourceId],
      ),
    );
    return SongActions(
      source is RatedSource ? source : null,
      source is ExtendableSource ? source : null,
      widget.song,
    );
  }

  // No load in `initState`: [didChangeDependencies] runs straight after it
  // and already asks once, so loading here would fetch the same favourite
  // twice on every page build.

  @override
  void didUpdateWidget(SongActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keyOf(widget.song) != _key) _load();
  }

  /// The capability can change under a fixed song: a source reconnecting
  /// changes what the heart is allowed to do without renaming the track, so
  /// the answer is asked again whenever the source's identity changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rated = ref.read(
      librarySourceByIdProvider.select(
        (sources) => sources[widget.song.sourceId],
      ),
    );
    final capability = rated is RatedSource ? '${rated.id}:rated' : 'none';
    if (capability != _capability) {
      _capability = capability;
      _load();
    }
  }

  String? _capability;

  String _keyOf(LibrarySong song) => '${song.sourceId}:${song.id}';

  Future<void> _load() async {
    _key = _keyOf(widget.song);
    if (!_actions.canFavourite) {
      if (mounted) setState(() => _favourite = null);
      return;
    }
    // The account's record first: Solar Network is where a heart set on any
    // device — or imported from another provider — is visible, so that is the
    // answer this surface draws. Signed out it falls back to the device's own
    // row, which is why the provider answers instead of a local read here.
    final value = await ref.read(
      solarFavouriteStateProvider(widget.song).future,
    );
    if (!mounted || _key != _keyOf(widget.song)) return;
    setState(() => _favourite = value);
  }

  Future<void> _toggle() async {
    if (_busy || !_actions.canFavourite) return;
    final next = !(_favourite ?? false);
    setState(() {
      _busy = true;
      // Optimistic, and unlike before it is not undone on a network failure:
      // the local library is the record now, so the heart stays where the user
      // put it and the forward is what is reported.
      _favourite = next;
    });
    final error = await ref
        .read(favouritesProvider)
        .set(widget.song, value: next);
    // The fleet copy is pushed here, not in the device's record: this is the
    // layer that may know about Pulsar. A failure is reported once and never
    // undoes the tap — the device already agrees with the user.
    final fleetError = await _pushFavouriteToFleet(widget.song, next);
    if (!mounted) return;
    // The account's key set changed by one entry: dropping the family entries
    // is what turns the player page's prefix heart with this bar's.
    ref.invalidate(favouriteStateProvider(widget.song));
    ref.invalidate(solarFavouriteStateProvider(widget.song));
    setState(() => _busy = false);
    if (error != null) _report(error);
    if (fleetError != null) _report(fleetError);
  }

  /// Mirrors the heart into the account's Pulsar favourites, when signed in.
  /// Signed out is not a failure: the device keeps the opinion and the fleet
  /// learns it on the next sync.
  Future<Object?> _pushFavouriteToFleet(LibrarySong song, bool value) async {
    if (!_signedIn || song.isRadio) return null;
    try {
      await ref.read(pulsarFavouritesProvider.notifier).set(song, value: value);
      return null;
    } catch (error) {
      return error;
    }
  }

  /// Shares the track: hands a public Pulsar link to the OS share sheet.
  ///
  /// The link resolves to an OpenGraph page any chat app unfurls, so the
  /// recipient sees the track without opening GroovyBox first.
  ///
  /// Two things used to make this look broken. The button was shown for a
  /// Solarpass session but the share needed a Pulsar one, which can be absent
  /// or expired while Solarpass is fine; the call then returned silently and
  /// the tap did nothing. And the sheet was opened without an origin rect,
  /// which iPad needs — without it the share fails or lands as a popover in
  /// the wrong place. Both are fixed here: one session decides both the
  /// button and the call, and a failure says what happened instead of
  /// swallowing it.
  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await ref.read(pulsarSessionProvider.future);
      if (session == null) {
        if (mounted) _say('playerShareNeedsAccount'.tr());
        return;
      }
      final sources = ref.read(librarySourceByIdProvider);
      final artUri = sources[widget.song.sourceId]?.artworkUri(
        widget.song.artId,
      );
      final share = await ref
          .read(pulsarClientProvider)
          .shareTrack(
            session,
            title: widget.song.title,
            artist: widget.song.artist,
            album: widget.song.album,
            artworkUrl: artUri?.toString(),
            durationSeconds: widget.song.duration.inSeconds,
            trackKey: pulsarTrackKey(widget.song),
          );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          text: share.shareUrl,
          subject: widget.song.title,
          sharePositionOrigin: _shareOrigin(),
        ),
      );
    } catch (error) {
      if (mounted) _report(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The rect the share popover anchors to on iPad and macOS.
  ///
  /// The button's own box, so the sheet appears next to what was tapped
  /// rather than at the top-left of the window.
  Rect? _shareOrigin() {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _say(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPlaylist() async {
    final actions = _actions;
    if (_busy || !actions.canAddToPlaylist) return;
    setState(() => _busy = true);
    try {
      final result = await addTracksToPlaylist(context, songs: [widget.song]);
      if (!mounted || result == null) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('playerPlaylistAdded'.tr(args: [result.name]))),
      );
    } catch (error) {
      if (mounted) _report(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Says what the account said. [LibraryException] carries the store's own
  /// words, which are more useful than anything the app could invent.
  void _report(Object error) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(describeServerError(error))));
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    if (!actions.canFavourite && !actions.canAddToPlaylist) {
      return const SizedBox.shrink();
    }
    final favourited = _favourite ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SolSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (actions.canFavourite)
            IconButton(
              tooltip: favourited
                  ? 'playerFavourited'.tr()
                  : 'playerFavourite'.tr(),
              isSelected: favourited,
              onPressed: _busy ? null : _toggle,
              icon: Icon(
                favourited
                    ? Symbols.favorite_rounded
                    : Symbols.favorite_border_rounded,
              ),
            ),
          if (actions.canAddToPlaylist)
            IconButton(
              tooltip: 'playerAddToPlaylist'.tr(),
              onPressed: _busy ? null : _pickPlaylist,
              icon: const Icon(Symbols.playlist_add_rounded),
            ),
          if (_signedIn)
            IconButton(
              key: _shareKey,
              tooltip: 'playerShare'.tr(),
              onPressed: _busy ? null : _share,
              icon: const Icon(Symbols.ios_share_rounded),
            ),
        ],
      ),
    );
  }
}

/// The track's actions, run from outside the action bar: the more menu offers
/// the same writes, and it must not re-implement them.
///
/// Each method reports its result the way the bar does — a snackbar for the
/// server's own words, or the account's failure — so the two surfaces answer
/// a tap identically.
///
/// [context] must be the menu anchor's, never a menu item's: material_ui
/// closes the menu before running [MenuItemButton.onPressed] post-frame, and
/// the item's own element is deactivated by then — its [WidgetRef] throws the
/// moment it is read. The anchor stays mounted across the close, and the
/// container is captured from it once before any await, so the writes survive
/// the caller being torn down mid-flight.
abstract final class SongActionsRunner {
  /// Writes the track's favourite, flipping the account's record.
  ///
  /// Reads first: the menu does not carry the bar's cached answer, and a
  /// read is cheaper than a wrong write.
  static Future<void> toggleFavourite(
    BuildContext context,
    SongActions actions,
  ) async {
    if (!actions.canFavourite || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final favourites = container.read(favouritesProvider);
    // Solar Network answers first, exactly as the bar reads it: the menu and
    // the bar must never disagree about a heart.
    final value = await container.read(
      solarFavouriteStateProvider(actions.song).future,
    );
    final next = !value;
    final error = await favourites.set(actions.song, value: next);
    // The fleet copy, same as the bar's: the two surfaces answer a tap
    // identically, so neither may be the one that forgets the account.
    Object? fleetError;
    if (container.read(pulsarSessionProvider).value != null &&
        !actions.song.isRadio) {
      try {
        await container
            .read(pulsarFavouritesProvider.notifier)
            .set(actions.song, value: next);
      } catch (error) {
        fleetError = error;
      }
    }
    if (!context.mounted) return;
    // The state is the provider, not any widget's field: dropping the family
    // entry is what turns the prefix heart and the menu item together.
    container.invalidate(favouriteStateProvider(actions.song));
    container.invalidate(solarFavouriteStateProvider(actions.song));
    if (error != null) _report(context, error);
    if (fleetError != null) _report(context, fleetError);
  }

  /// Opens the playlist picker and puts the track where it was chosen.
  static Future<void> pickPlaylist(
    BuildContext context,
    SongActions actions,
  ) async {
    if (!actions.canAddToPlaylist || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result = await addTracksToPlaylist(context, songs: [actions.song]);
      if (result == null || !context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('playerPlaylistAdded'.tr(args: [result.name]))),
      );
    } catch (error) {
      if (context.mounted) _report(context, error);
    }
  }

  /// Hands a public Pulsar link for the track to the OS share sheet, with
  /// [anchor] as the popover origin where the platform wants one.
  static Future<void> share(
    BuildContext context,
    LibrarySong song,
  ) async {
    if (!context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final sources = container.read(librarySourceByIdProvider);
      final pulsarClient = container.read(pulsarClientProvider);
      final session = await container.read(pulsarSessionProvider.future);
      if (session == null) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text('playerShareNeedsAccount'.tr())),
          );
        }
        return;
      }
      final artUri = sources[song.sourceId]?.artworkUri(song.artId);
      final share = await pulsarClient.shareTrack(
        session,
        title: song.title,
        artist: song.artist,
        album: song.album,
        artworkUrl: artUri?.toString(),
        durationSeconds: song.duration.inSeconds,
        trackKey: pulsarTrackKey(song),
      );
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(text: share.shareUrl, subject: song.title),
      );
    } catch (error) {
      if (context.mounted) _report(context, error);
    }
  }

  static void _report(BuildContext context, Object error) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(describeServerError(error))));
  }
}
