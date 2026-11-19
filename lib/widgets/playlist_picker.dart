import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Where a batch of tracks can be put.
///
/// The three cases are three different owners of the list — this device, the
/// account's cloud, and a connected store — and each write goes through a
/// different notifier. Naming them here is what lets one picker serve a single
/// track (the player) and many (a playlist's batch).
sealed class PlaylistTarget {
  const PlaylistTarget();

  /// The destination's name, for the confirmation line.
  String get name;
}

class OwnedPlaylistTarget extends PlaylistTarget {
  final OwnedPlaylist playlist;

  const OwnedPlaylistTarget(this.playlist);

  @override
  String get name => playlist.name;
}

class CloudPlaylistTarget extends PlaylistTarget {
  final PulsarPlaylist playlist;

  const CloudPlaylistTarget(this.playlist);

  @override
  String get name => playlist.name;
}

class SourcePlaylistTarget extends PlaylistTarget {
  final LibraryPlaylist playlist;
  final ExtendableSource source;

  const SourcePlaylistTarget(this.source, this.playlist);

  @override
  String get name => playlist.name;
}

/// What a batch write actually did.
///
/// [added] is not always the number of tracks asked for: a store's playlist
/// can only hold tracks from its own library, so a batch that mixes sources
/// lands part of itself. Reporting the count is what keeps the confirmation
/// true.
class PlaylistAddResult {
  final String name;
  final int added;

  const PlaylistAddResult(this.name, this.added);
}

/// Asks where the tracks go, then writes them there.
///
/// Returns null when the sheet was dismissed. A store that refuses a write
/// throws [LibraryException], which the caller reports: a batch that
/// half-landed is the store's answer, not something this layer can undo.
Future<PlaylistAddResult?> addTracksToPlaylist(
  BuildContext context, {
  required List<LibrarySong> songs,
}) async {
  final tracks = [
    for (final song in songs)
      if (!song.isRadio) song,
  ];
  if (tracks.isEmpty || !context.mounted) return null;
  final container = ProviderScope.containerOf(context, listen: false);
  final target = await showModalBottomSheet<PlaylistTarget>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _PlaylistPicker(songs: tracks),
  );
  if (target == null) return null;
  switch (target) {
    case OwnedPlaylistTarget(:final playlist):
      await container
          .read(ownedPlaylistsProvider.notifier)
          .add(playlist.id, tracks);
      return PlaylistAddResult(playlist.name, tracks.length);
    case CloudPlaylistTarget(:final playlist):
      // A cloud playlist is a list of names, not a library's rows: any track
      // can be written to it, whether or not this device holds a copy.
      final notifier = container.read(pulsarPlaylistsProvider.notifier);
      for (final song in tracks) {
        await notifier.addSong(playlist, song);
      }
      return PlaylistAddResult(playlist.name, tracks.length);
    case SourcePlaylistTarget(:final playlist, :final source):
      // A store's playlist is a list of that store's own items, so only the
      // tracks it can name are written. The rest are left out rather than
      // refused one by one, and the count says so.
      final own = [
        for (final song in tracks)
          if (song.sourceId == source.id) song,
      ];
      for (final song in own) {
        await source.addToPlaylist(playlist, song);
      }
      return PlaylistAddResult(playlist.name, own.length);
  }
}

/// The sheet: this device's playlists first, then the account's cloud
/// playlists when it is signed in, then the ones the connected sources hold.
///
/// Device playlists are the primary list — they exist before a library does
/// and survive every one of them being swapped. The other sections are
/// writes that leave the app, so they follow, not replace: a cloud playlist
/// needs a Pulsar session, and a source playlist only appears when the
/// source says it is editable, because the favourites mix appears among them
/// but silently refuses an add.
class _PlaylistPicker extends ConsumerStatefulWidget {
  /// The tracks being placed. Their sources are what the account section
  /// asks: a batch can mix libraries, and each store keeps its own lists.
  final List<LibrarySong> songs;

  const _PlaylistPicker({required this.songs});

  @override
  ConsumerState<_PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends ConsumerState<_PlaylistPicker> {
  List<SourcePlaylistTarget>? _account;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final sources = ref.read(librarySourceByIdProvider);
      final targets = <(String, SourcePlaylistTarget)>[];
      final seen = <String>{};
      for (final song in widget.songs) {
        final source = sources[song.sourceId];
        if (source is! ExtendableSource) continue;
        if (!seen.add(source.id)) continue;
        for (final playlist in await source.editablePlaylists()) {
          targets.add((
            '${playlist.sourceId}:${playlist.id}',
            SourcePlaylistTarget(source, playlist),
          ));
        }
      }
      if (mounted) {
        setState(() => _account = [for (final (_, target) in targets) target]);
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeServerError(error));
    }
  }

  /// Makes a playlist on this device, then hands it back as the destination.
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
      Navigator.of(context).pop(OwnedPlaylistTarget(playlist));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owned = ref.watch(ownedPlaylistsProvider);
    final cloud = ref.watch(pulsarPlaylistsProvider);
    final cloudSession = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
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
            leading: _ListIcon(icon: Symbols.add_rounded, theme: theme),
            title: Text('playlistPickerNew'.tr()),
            onTap: _creating ? null : _create,
          ),
          ...owned.when(
            data: (playlists) => [
              for (final playlist in playlists)
                ListTile(
                  leading: _ListIcon(
                    icon: Symbols.queue_music_rounded,
                    theme: theme,
                  ),
                  title: Text(playlist.name),
                  subtitle: playlist.trackCount == 0
                      ? null
                      : Text('playlistsTrackCount'.plural(playlist.trackCount)),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(OwnedPlaylistTarget(playlist)),
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
          ..._cloudRows(theme, cloud, cloudSession),
          ..._accountRows(theme),
        ],
      ),
    );
  }

  /// The account's cloud playlists, between the device's own and a server's.
  /// Signed out is the normal state for half the app's windows, so the
  /// section is silence rather than an empty-state row.
  List<Widget> _cloudRows(
    ThemeData theme,
    AsyncValue<List<PulsarPlaylist>> cloud,
    bool signedIn,
  ) {
    if (!signedIn) return const [];
    final list = cloud.value;
    if (list == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(SolSpace.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (list.isEmpty) return const [];
    return [
      _SectionLabel(text: 'playlistPickerCloudSection'.tr(), theme: theme),
      Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: list.length,
          itemBuilder: (context, index) {
            final playlist = list[index];
            return ListTile(
              leading: _ListIcon(icon: Symbols.cloud_rounded, theme: theme),
              title: Text(playlist.name),
              subtitle: playlist.items.isEmpty
                  ? null
                  : Text('playlistsTrackCount'.plural(playlist.items.length)),
              onTap: () =>
                  Navigator.of(context).pop(CloudPlaylistTarget(playlist)),
            );
          },
        ),
      ),
    ];
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
      _SectionLabel(text: 'playlistPickerAccountSection'.tr(), theme: theme),
      Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: account.length,
          itemBuilder: (context, index) {
            final target = account[index];
            final playlist = target.playlist;
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
              onTap: () => Navigator.of(context).pop(target),
            );
          },
        ),
      ),
    ];
  }
}

/// A 40 px tone block holding the row's icon, so the device and cloud rows
/// line up with the account rows' covers.
class _ListIcon extends StatelessWidget {
  final IconData icon;
  final ThemeData theme;

  const _ListIcon({required this.icon, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(SolRadius.sm),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _SectionLabel({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.md,
        SolSpace.md,
        SolSpace.md,
        SolSpace.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
