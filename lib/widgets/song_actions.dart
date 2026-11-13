import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// What the account can remember about a track: whether it is a favourite,
/// and which of its own playlists it can still be put into.
///
/// Both are *writes* to an account, so this class only ever acts on a tap and
/// never as a side effect of drawing the page. A source that cannot write at
/// all is not offered either control, which is why every member here is
/// nullable rather than throwing.
class SongActions {
  final ExtendableSource? _source;
  final LibrarySong _song;

  const SongActions(this._source, this._song);

  /// Whether this track can be saved to the account at all.
  ///
  /// A station is a standing request, not a track: a favourite of one would
  /// mean nothing, and the platform player is still resolving what it will
  /// play next.
  bool get canAct => _source != null && !_song.isRadio;

  Future<bool> isFavourite() async {
    final source = _source;
    if (source == null || !canAct) return false;
    try {
      return await source.isFavourite(_song);
    } on LibraryException {
      // A favourite that cannot be read is drawn as not set; the tap is what
      // reports the failure.
      return false;
    }
  }

  Future<void> setFavourite(bool value) async {
    final source = _source;
    if (source == null) return;
    await source.setFavourite(_song, value: value);
  }

  Future<List<LibraryPlaylist>> editablePlaylists() async {
    final source = _source;
    if (source == null) return const [];
    return source.editablePlaylists();
  }

  Future<void> addToPlaylist(LibraryPlaylist playlist) async {
    final source = _source;
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

  /// What the account can do with this track, or a no-op when its source has
  /// no write capability: a server reads and plays but has no account of its
  /// own to save anything to. A cast would fail on that source, and this is a
  /// capability question rather than a kind one.
  SongActions get _actions {
    final source = ref.watch(librarySourceByIdProvider)[widget.song.sourceId];
    return SongActions(source is ExtendableSource ? source : null, widget.song);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SongActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _keyOf(widget.song);
    if (next != _key) _load();
  }

  String _keyOf(LibrarySong song) => '${song.sourceId}:${song.id}';

  Future<void> _load() async {
    _key = _keyOf(widget.song);
    final actions = _actions;
    if (!actions.canAct) {
      if (mounted) setState(() => _favourite = null);
      return;
    }
    final value = await actions.isFavourite();
    if (!mounted || _key != _keyOf(widget.song)) return;
    setState(() => _favourite = value);
  }

  Future<void> _toggle() async {
    final actions = _actions;
    if (_busy || !actions.canAct) return;
    final next = !(_favourite ?? false);
    setState(() {
      _busy = true;
      // Optimistic: a heart that waits for the network reads as broken. A
      // failure puts it back where the account still says it is.
      _favourite = next;
    });
    try {
      await actions.setFavourite(next);
    } catch (error) {
      if (mounted) {
        setState(() => _favourite = !next);
        _report(error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPlaylist() async {
    final actions = _actions;
    if (_busy || !actions.canAct) return;
    final playlist = await showModalBottomSheet<LibraryPlaylist>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _PlaylistPicker(actions: actions),
    );
    if (playlist == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await actions.addToPlaylist(playlist);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('playerPlaylistAdded'.tr(args: [playlist.name])),
          ),
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
    if (!actions.canAct) return const SizedBox.shrink();
    final favourited = _favourite ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SolSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
          IconButton(
            tooltip: 'playerAddToPlaylist'.tr(),
            onPressed: _busy ? null : _pickPlaylist,
            icon: const Icon(Symbols.playlist_add_rounded),
          ),
        ],
      ),
    );
  }
}

/// The account's own editable playlists, as a sheet.
///
/// Only the playlists the service says can be edited are listed: the
/// favourites mix appears among an account's playlists but silently refuses
/// an add, so offering it would be a button that does nothing.
class _PlaylistPicker extends ConsumerStatefulWidget {
  final SongActions actions;

  const _PlaylistPicker({required this.actions});

  @override
  ConsumerState<_PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends ConsumerState<_PlaylistPicker> {
  List<LibraryPlaylist>? _playlists;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final playlists = await widget.actions.editablePlaylists();
      if (mounted) setState(() => _playlists = playlists);
    } catch (error) {
      if (mounted) {
        setState(() => _error = describeServerError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlists = _playlists;
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(SolSpace.md),
              child: Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else if (playlists == null)
            const Padding(
              padding: EdgeInsets.all(SolSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SolSpace.md),
              child: Text(
                'playlistPickerEmpty'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
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
                    onTap: () => Navigator.of(context).pop(playlist),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
