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
    // The count belongs to the half that is showing: a heading that counted
    // both would describe a list the user cannot see.
    final count = switch (_view) {
      LibraryView.albums => albumList.isEmpty
          ? null
          : 'albumsCount'.plural(albumList.length),
      LibraryView.playlists => playlistList.isEmpty
          ? null
          : 'playlistsCount'.plural(playlistList.length),
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
                LibraryView.playlists => playlists.when(
                  data: (list) => [
                    if (list.isEmpty) const _EmptyPlaylists(),
                    if (list.isNotEmpty)
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) => PlaylistCard(
                          playlist: list[index],
                          onTap: () => _openPlaylist(context, list[index]),
                        ),
                      ),
                    const _CloudPlaylistsSection(),
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

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
  });

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
/// second switch.
class _CloudPlaylistsSection extends ConsumerWidget {
  const _CloudPlaylistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(pulsarPlaylistsProvider);
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);
    return cloud.when(
      data: (list) {
        if (list.isEmpty) {
          return SliverToBoxAdapter(child: SizedBox(height: bottomInset));
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: LibrarySectionHeader(
                title: 'libraryCloudPlaylists'.tr(),
              ),
            ),
            SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final playlist = list[index];
                return PlaylistCard(
                  playlist: LibraryPlaylist(
                    sourceId: 'pulsar',
                    id: playlist.id,
                    name: playlist.name,
                    duration: Duration.zero,
                  ),
                  onTap: () => context.router.push(
                    PulsarPlaylistDetailRoute(
                      playlistId: playlist.id,
                      playlistName: playlist.name,
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
          ],
        );
      },
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
