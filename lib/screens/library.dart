import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/screens/explore.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The collection, as an index: every album and every playlist, one switch
/// between the two shapes.
///
/// Albums and playlists used to be two tabs, which made the shell say
/// something untrue: they are not two kinds of thing in the user's head, they
/// are two shapes of one collection, and someone looking for "the thing I made
/// last week" had to remember which kind it was before they could look. One
/// page with a switch keeps that choice visible instead of hiding it behind a
/// tab.
///
/// This is the place you go when you know what you want. What to play next is
/// the explore page's job, so this page is deliberately a catalogue: a grid of
/// covers, a list of playlists, and nothing that competes with the shelves.
@RoutePage()
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// Which half of the collection is on screen.
enum LibraryView { albums, playlists }

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryView _view = LibraryView.albums;

  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(recentAlbumsProvider);
    final playlists = ref.watch(playlistsProvider);
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    final albumList = albums.value ?? const <LibraryAlbum>[];
    final playlistList = playlists.value ?? const <LibraryPlaylist>[];
    final ownedList = ref.watch(ownedPlaylistsProvider).value ?? const [];
    // The count belongs to the half that is showing: a heading that counted
    // both would describe a list the user cannot see.
    final count = switch (_view) {
      LibraryView.albums =>
        albumList.isEmpty ? null : 'albumsCount'.plural(albumList.length),
      LibraryView.playlists =>
        (playlistList.isEmpty && ownedList.isEmpty)
            ? null
            : 'playlistsCount'.plural(playlistList.length + ownedList.length),
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(recentAlbumsProvider.notifier).refresh();
          await ref.read(playlistsProvider.notifier).refresh();
        },
        child: ContentFrame(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: 'libraryTitle'.tr(),
                  subtitle: count ?? 'librarySubtitle'.tr(),
                  actions: [
                    IconButton(
                      tooltip: 'commonRefresh'.tr(),
                      onPressed: () {
                        ref.read(recentAlbumsProvider.notifier).refresh();
                        ref.read(playlistsProvider.notifier).refresh();
                      },
                      icon: const Icon(Symbols.refresh_rounded),
                    ),
                    const SizedBox(width: SolSpace.sm),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SolSpace.xxl,
                    0,
                    SolSpace.xxl,
                    SolSpace.md,
                  ),
                  child: SegmentedButton<LibraryView>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: LibraryView.albums,
                        icon: const Icon(Symbols.album_rounded, size: 18),
                        label: Text('libraryAlbums'.tr()),
                      ),
                      ButtonSegment(
                        value: LibraryView.playlists,
                        icon: const Icon(
                          Symbols.playlist_play_rounded,
                          size: 18,
                        ),
                        label: Text('libraryPlaylists'.tr()),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (selection) =>
                        setState(() => _view = selection.first),
                  ),
                ),
              ),
              ...switch (_view) {
                LibraryView.albums => albums.when(
                  data: (list) => list.isEmpty
                      ? const [_EmptyAlbums()]
                      : [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              SolSpace.xl,
                              0,
                              SolSpace.xl,
                              0,
                            ),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 200,
                                    mainAxisSpacing: SolSpace.md,
                                    crossAxisSpacing: SolSpace.md,
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: list.length,
                              itemBuilder: (context, index) => AlbumCard(
                                album: list[index],
                                onTap: () => _openAlbum(context, list[index]),
                              ),
                            ),
                          ),
                        ],
                  loading: () => const [_LoadingSliver()],
                  error: (error, _) => [
                    _ErrorSliver(
                      icon: Symbols.album,
                      title: 'albumsLoadError'.tr(),
                      error: error,
                      onRetry: () =>
                          ref.read(recentAlbumsProvider.notifier).refresh(),
                    ),
                  ],
                ),
                LibraryView.playlists => [
                  const _OwnedPlaylistsSection(),
                  ...playlists.when(
                    data: (list) => [
                      if (list.isNotEmpty)
                        SliverToBoxAdapter(
                          child: LibrarySectionHeader(
                            title: 'libraryServerPlaylists'.tr(),
                          ),
                        ),
                      if (list.isNotEmpty)
                        SliverList.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) => PlaylistCard(
                            playlist: list[index],
                            onTap: () => _openPlaylist(context, list[index]),
                          ),
                        ),
                      if (list.isEmpty) const _EmptyPlaylists(),
                    ],
                    loading: () => const [_LoadingSliver()],
                    error: (error, _) => [
                      _ErrorSliver(
                        icon: Symbols.playlist_play,
                        title: 'playlistsLoadError'.tr(),
                        error: error,
                        onRetry: () =>
                            ref.read(playlistsProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                  const _CloudPlaylistsSection(),
                ],
              },
              SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
            ],
          ),
        ),
      ),
    );
  }

  void _openAlbum(BuildContext context, LibraryAlbum album) {
    context.router.push(
      AlbumDetailRoute(
        sourceId: album.sourceId,
        albumId: album.id,
        albumName: album.name,
      ),
    );
  }

  void _openPlaylist(BuildContext context, LibraryPlaylist playlist) {
    context.router.push(
      PlaylistDetailRoute(
        sourceId: playlist.sourceId,
        playlistId: playlist.id,
        playlistName: playlist.name,
      ),
    );
  }
}

/// An empty half is an invitation, not a blank: it says which half is empty
/// and what would fill it.
class _EmptyAlbums extends StatelessWidget {
  const _EmptyAlbums();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: EmptyState(
        compact: true,
        icon: Symbols.album,
        title: 'albumsEmptyTitle'.tr(),
        message: 'albumsEmptyMessage'.tr(),
      ),
    );
  }
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: EmptyState(
        compact: true,
        icon: Symbols.playlist_play,
        title: 'playlistsEmptyTitle'.tr(),
        message: 'playlistsEmptyMessage'.tr(),
      ),
    );
  }
}

/// A playlist as a row: cover, name, and what is in it.
///
/// Same rounded hover language as [TrackRow], so the two halves of the
/// collection read as one family without a divider anywhere.
class PlaylistCard extends StatelessWidget {
  final LibraryPlaylist playlist;
  final VoidCallback onTap;

  const PlaylistCard({super.key, required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = [
      if (playlist.songCount != null)
        'playlistsTrackCount'.plural(playlist.songCount!),
      formatDuration(playlist.duration),
      if (playlist.owner != null) playlist.owner!,
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SolRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SolSpace.md,
              vertical: SolSpace.sm,
            ),
            child: Row(
              children: [
                LibraryArtwork(
                  sourceId: playlist.sourceId,
                  artId: playlist.artId,
                  size: 52,
                  radius: SolRadius.md,
                  fallbackIcon: Symbols.playlist_play,
                ),
                const SizedBox(width: SolSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Symbols.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The playlists this device owns, above every other playlist.
///
/// They are first because they are the only ones the app can create and
/// edit: a server playlist belongs to a Navidrome or Jellyfin account, a cloud
/// playlist to Pulsar. Putting the editable list under the read-only ones
/// would make the one thing the user can act on the hardest thing to find.
class _OwnedPlaylistsSection extends ConsumerWidget {
  const _OwnedPlaylistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(ownedPlaylistsProvider);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: LibrarySectionHeader(
            title: 'libraryOwnedPlaylists'.tr(),
            trailing: TextButton.icon(
              onPressed: () => _createOwnedPlaylist(context, ref),
              icon: const Icon(Symbols.add_rounded, size: 18),
              label: Text('libraryNewPlaylist'.tr()),
            ),
          ),
        ),
        ...owned.when(
          data: (list) => [
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SolSpace.xxl,
                    0,
                    SolSpace.xxl,
                    SolSpace.sm,
                  ),
                  child: Text(
                    'libraryOwnedPlaylistsEmpty'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final playlist = list[index];
                  return PlaylistCard(
                    playlist: LibraryPlaylist(
                      sourceId: kLocalSourceId,
                      id: '${playlist.id}',
                      name: playlist.name,
                      duration: Duration.zero,
                      songCount: playlist.trackCount,
                    ),
                    onTap: () => context.router.push(
                      OwnedPlaylistDetailRoute(
                        playlistId: playlist.id,
                        playlistName: playlist.name,
                      ),
                    ),
                  );
                },
              ),
          ],
          loading: () => const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(SolSpace.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          // A device with no catalog can still browse servers; the section
          // simply has nothing it could create.
          error: (_, _) => const [SliverToBoxAdapter(child: SizedBox.shrink())],
        ),
      ],
    );
  }
}

/// One row of the cloud playlist list, carrying the server's own artwork.
///
/// [PlaylistCard] resolves art through a library source, and a cloud playlist
/// has none: its cover URL is the playlist's, not a source's, so it is drawn
/// directly instead of through [LibraryArtwork].
class CloudPlaylistCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? artworkUrl;
  final VoidCallback onTap;

  const CloudPlaylistCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final art = artworkUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SolRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SolSpace.md,
              vertical: SolSpace.sm,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(SolRadius.md),
                  child: SizedBox.square(
                    dimension: 52,
                    child: art == null || art.isEmpty
                        ? ColoredBox(
                            color: colorScheme.surfaceContainerHigh,
                            child: Icon(
                              Symbols.cloud_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Image.network(
                            art,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colorScheme.surfaceContainerHigh,
                              child: Icon(
                                Symbols.cloud_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: SolSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Symbols.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Creates a device playlist and opens it.
Future<void> _createOwnedPlaylist(BuildContext context, WidgetRef ref) async {
  final name = await askPlaylistName(context, title: 'libraryNewPlaylist'.tr());
  if (name == null || !context.mounted) return;
  final created = await ref.read(ownedPlaylistsProvider.notifier).create(name);
  if (created == null || !context.mounted) return;
  context.router.push(
    OwnedPlaylistDetailRoute(
      playlistId: created.id,
      playlistName: created.name,
    ),
  );
}

/// Creates a cloud playlist and opens it. Failures are the server's own
/// words: a create that silently does nothing leaves the user naming it again.
Future<void> _createCloudPlaylist(BuildContext context, WidgetRef ref) async {
  final name = await askPlaylistName(
    context,
    title: 'libraryNewCloudPlaylist'.tr(),
  );
  if (name == null || !context.mounted) return;
  try {
    final created = await ref
        .read(pulsarPlaylistsProvider.notifier)
        .create(name);
    if (created == null || !context.mounted) return;
    context.router.push(
      PulsarPlaylistDetailRoute(
        playlistId: created.id,
        playlistName: created.name,
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(describeServerError(error))));
  }
}

class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(SolSpace.huge),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorSliver extends StatelessWidget {
  final IconData icon;
  final String title;
  final Object error;
  final VoidCallback onRetry;

  const _ErrorSliver({
    required this.icon,
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: EmptyState(
        compact: true,
        icon: icon,
        title: title,
        message: describeServerError(error),
        iconColor: Theme.of(context).colorScheme.error,
        action: FilledButton(
          onPressed: onRetry,
          child: Text('commonTryAgain'.tr()),
        ),
      ),
    );
  }
}

/// The account's cloud playlists, from Pulsar, under the device's own.
///
/// They are a different list, not a merged one: a device playlist exists
/// before any account does, and a cloud playlist follows the account across
/// devices. One section header keeps the distinction visible without a
/// second switch, and the header is where a cloud playlist is made.
class _CloudPlaylistsSection extends ConsumerWidget {
  const _CloudPlaylistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(pulsarPlaylistsProvider);
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    return cloud.when(
      data: (list) => SliverMainAxisGroup(
        slivers: [
          if (signedIn)
            SliverToBoxAdapter(
              child: LibrarySectionHeader(
                title: 'libraryCloudPlaylists'.tr(),
                trailing: TextButton.icon(
                  onPressed: () => _createCloudPlaylist(context, ref),
                  icon: const Icon(Symbols.add_rounded, size: 18),
                  label: Text('libraryNewCloudPlaylist'.tr()),
                ),
              ),
            ),
          SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final playlist = list[index];
              final count = playlist.items.length;
              return CloudPlaylistCard(
                name: playlist.name,
                subtitle: count == 0
                    ? 'ownedPlaylistEmptyHeader'.tr()
                    : 'playlistsTrackCount'.plural(count),
                artworkUrl: playlist.artworkUrl,
                onTap: () => context.router.push(
                  PulsarPlaylistDetailRoute(
                    playlistId: playlist.id,
                    playlistName: playlist.name,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(SolSpace.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      // A signed-out window has no cloud playlists: silence, not an error.
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
