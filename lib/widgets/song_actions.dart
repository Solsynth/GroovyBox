import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
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
    // The device's record first, the source only when it has none: the heart
    // is the user's opinion, and it must not depend on a round trip.
    final value = await ref.read(favouritesProvider).read(widget.song);
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
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) _report(error);
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
            trackId: widget.song.id,
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
    final choice = await showModalBottomSheet<_PlaylistChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _PlaylistPicker(actions: actions),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      // The device playlist comes first: it is the one this app owns, and the
      // account's own is a write that leaves the app.
      final String name;
      switch (choice) {
        case _OwnedChoice(:final playlist):
          await ref.read(ownedPlaylistsProvider.notifier).add(playlist.id, [
            widget.song,
          ]);
          name = playlist.name;
        case _SourceChoice(:final playlist):
          await actions.addToPlaylist(playlist);
          name = playlist.name;
      }
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('playerPlaylistAdded'.tr(args: [name]))),
        );
      }
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

/// The track's actions, run from outside the action bar: the queue header's
/// more menu offers the same writes, and it must not re-implement them.
///
/// Each method reports its result the way the bar does — a snackbar for the
/// server's own words, or the account's failure — so the two surfaces answer
/// a tap identically.
abstract final class SongActionsRunner {
  /// Writes the track's favourite, flipping the account's record.
  ///
  /// Reads first: the menu does not carry the bar's cached answer, and a
  /// read is cheaper than a wrong write.
  static Future<void> toggleFavourite(
    BuildContext context,
    WidgetRef ref,
    SongActions actions,
  ) async {
    if (!actions.canFavourite) return;
    final value = await ref.read(favouritesProvider).read(actions.song);
    final error = await ref
        .read(favouritesProvider)
        .set(actions.song, value: !(value ?? false));
    // The state is the provider, not any widget's field: dropping the family
    // entry is what turns the prefix heart and the menu item together.
    ref.invalidate(favouriteStateProvider(actions.song));
    if (error != null && context.mounted) _report(context, error);
  }

  /// Opens the playlist picker and puts the track where it was chosen.
  static Future<void> pickPlaylist(
    BuildContext context,
    WidgetRef ref,
    SongActions actions,
  ) async {
    if (!actions.canAddToPlaylist) return;
    final choice = await showModalBottomSheet<_PlaylistChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _PlaylistPicker(actions: actions),
    );
    if (choice == null || !context.mounted) return;
    try {
      final String name;
      switch (choice) {
        case _OwnedChoice(:final playlist):
          await ref
              .read(ownedPlaylistsProvider.notifier)
              .add(playlist.id, [actions.song]);
          name = playlist.name;
        case _SourceChoice(:final playlist):
          await actions.addToPlaylist(playlist);
          name = playlist.name;
      }
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('playerPlaylistAdded'.tr(args: [name]))),
        );
      }
    } catch (error) {
      if (context.mounted) _report(context, error);
    }
  }

  /// Hands a public Pulsar link for the track to the OS share sheet, with
  /// [anchor] as the popover origin where the platform wants one.
  static Future<void> share(
    BuildContext context,
    WidgetRef ref,
    LibrarySong song,
  ) async {
    try {
      final session = await ref.read(pulsarSessionProvider.future);
      if (session == null) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text('playerShareNeedsAccount'.tr())),
          );
        }
        return;
      }
      final sources = ref.read(librarySourceByIdProvider);
      final artUri = sources[song.sourceId]?.artworkUri(song.artId);
      final share = await ref
          .read(pulsarClientProvider)
          .shareTrack(
            session,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artworkUrl: artUri?.toString(),
            durationSeconds: song.duration.inSeconds,
            trackId: song.id,
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

/// What the picker hands back: one of this device's playlists, or one of the
/// account's own.
sealed class _PlaylistChoice {
  const _PlaylistChoice();
}

class _OwnedChoice extends _PlaylistChoice {
  final OwnedPlaylist playlist;

  const _OwnedChoice(this.playlist);
}

class _SourceChoice extends _PlaylistChoice {
  final LibraryPlaylist playlist;

  const _SourceChoice(this.playlist);
}

/// Where a track can be put, as a sheet: this device's playlists first, then
/// the account's own when its source has any.
///
/// Device playlists are the primary list — they exist before a library does
/// and survive every one of them being swapped. The account's playlists are a
/// second section, not a replacement: adding there is a write to a service
/// the app does not own, and only the ones the service says are editable are
/// offered, because the favourites mix appears among them but silently refuses
/// an add.
class _PlaylistPicker extends ConsumerStatefulWidget {
  final SongActions actions;

  const _PlaylistPicker({required this.actions});

  @override
  ConsumerState<_PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends ConsumerState<_PlaylistPicker> {
  List<LibraryPlaylist>? _account;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    if (!widget.actions.canAddToPlaylist) {
      if (mounted) setState(() => _account = const []);
      return;
    }
    try {
      final playlists = await widget.actions.editablePlaylists();
      if (mounted) setState(() => _account = playlists);
    } catch (error) {
      if (mounted) setState(() => _error = describeServerError(error));
    }
  }

  /// Makes a playlist on this device, then adds the track to it.
  ///
  /// A name is asked for rather than invented: a playlist called "New
  /// playlist" is one the user has to rename before it means anything.
  Future<void> _create() async {
    final trimmed = await askPlaylistName(
      context,
      title: 'playlistPickerNewTitle'.tr(),
      confirmLabelKey: 'commonSave',
    );
    if (trimmed == null || !mounted) return;
    setState(() => _creating = true);
    final playlist = await ref
        .read(ownedPlaylistsProvider.notifier)
        .create(trimmed);
    if (!mounted) return;
    setState(() => _creating = false);
    if (playlist != null) {
      Navigator.of(context).pop(_OwnedChoice(playlist));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owned = ref.watch(ownedPlaylistsProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.md,
              SolSpace.xs,
              SolSpace.md,
              SolSpace.sm,
            ),
            child: Text(
              'playlistPickerTitle'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            enabled: !_creating,
            leading: SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(SolRadius.sm),
                ),
                child: const Icon(Symbols.add_rounded),
              ),
            ),
            title: Text('playlistPickerNew'.tr()),
            onTap: _creating ? null : _create,
          ),
          ...owned.when(
            data: (playlists) => [
              for (final playlist in playlists)
                ListTile(
                  leading: SizedBox.square(
                    dimension: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(SolRadius.sm),
                      ),
                      child: const Icon(Symbols.queue_music_rounded),
                    ),
                  ),
                  title: Text(playlist.name),
                  subtitle: playlist.trackCount == 0
                      ? null
                      : Text('playlistsTrackCount'.plural(playlist.trackCount)),
                  onTap: () =>
                      Navigator.of(context).pop(_OwnedChoice(playlist)),
                ),
            ],
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(SolSpace.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => const [],
          ),
          ..._accountRows(theme),
        ],
      ),
    );
  }

  List<Widget> _accountRows(ThemeData theme) {
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(SolSpace.md),
          child: Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ];
    }
    final account = _account;
    if (account == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(SolSpace.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    // No account playlists is the normal case for a server, not a failure:
    // the device's own list above is the whole answer, so the sheet simply
    // ends there.
    if (account.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          SolSpace.md,
          SolSpace.md,
          SolSpace.md,
          SolSpace.xs,
        ),
        child: Text(
          'playlistPickerAccountSection'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: account.length,
          itemBuilder: (context, index) {
            final playlist = account[index];
            return ListTile(
              leading: SizedBox.square(
                dimension: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SolRadius.sm),
                  child: LibraryArtwork(
                    sourceId: playlist.sourceId,
                    artId: playlist.artId,
                    radius: 0,
                    size: 40,
                    fallbackIcon: Symbols.queue_music_rounded,
                  ),
                ),
              ),
              title: Text(playlist.name),
              subtitle: playlist.songCount == null
                  ? null
                  : Text('${playlist.songCount}'),
              onTap: () => Navigator.of(context).pop(_SourceChoice(playlist)),
            );
          },
        ),
      ),
    ];
  }
}
