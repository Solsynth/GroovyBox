import 'package:auto_route/auto_route.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The landing tab: search, a random shelf to start playing from, and the
/// newest albums.
///
/// Search is a field on this page rather than a tab of its own: the library
/// lives on a server, so the search is instant and there is nothing to keep in
/// sync — typing is the whole flow.
///
/// The whole page is one centered column ([ContentFrame]); on a wide window
/// the shelves and grid keep their comfortable size instead of stretching.
@RoutePage()
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentAlbums = ref.watch(recentAlbumsProvider);
    final randomSongs = ref.watch(randomSongsProvider);
    final search = ref.watch(searchSongsProvider(_query));
    final sources = ref.watch(librarySourcesProvider);
    // Select the identity, not the state: watching the whole transport would
    // rebuild this page on every position tick, once a second.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(recentAlbumsProvider.notifier).refresh();
          await ref.read(randomSongsProvider.notifier).refresh();
        },
        child: ContentFrame(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  showRailToggle: true,
                  title: 'Browse',
                  subtitle: sources.isEmpty
                      ? null
                      : 'Streaming from ${sources.length == 1 ? sources.single.displayName : '${sources.length} libraries'}',
                  actions: [
                    HeaderSettingsButton(
                      onPressed: () =>
                          context.router.push(const SettingsRoute()),
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
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search songs',
                    leading: const Icon(Symbols.search_rounded),
                    trailing: [
                      if (_query.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Symbols.close_rounded),
                        ),
                    ],
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
              if (_query.trim().isNotEmpty)
                // Every branch returns a list of slivers, so `when` is typed
                // to that and the whole thing spreads into the outer list.
                ...search.when<List<Widget>>(
                  data: (songs) => _songSliver(
                    songs,
                    emptyMessage: 'No songs match “$_query”.',
                  ),
                  loading: () => [const _LoadingSliver()],
                  error: (error, _) => [
                    _ErrorSliver(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(searchSongsProvider(_query)),
                    ),
                  ],
                )
              else ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Made for you',
                    trailing: TextButton.icon(
                      onPressed: () async {
                        await ref.read(randomSongsProvider.notifier).refresh();
                      },
                      icon: const Icon(Symbols.refresh_rounded, size: 18),
                      label: const Text('Shuffle'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: randomSongs.when(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : _SongShelf(songs: songs),
                    loading: () => const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _InlineError(
                      error: error,
                      onRetry: () => ref.invalidate(randomSongsProvider),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Recently added',
                    trailing: TextButton(
                      onPressed: () =>
                          context.router.navigate(const AlbumsRoute()),
                      child: const Text('See all'),
                    ),
                  ),
                ),
                ...recentAlbums.when(
                  data: (albums) => albums.isEmpty
                      ? const [SliverToBoxAdapter(child: SizedBox.shrink())]
                      : [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SolSpace.xl,
                            ),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 200,
                                    mainAxisSpacing: SolSpace.md,
                                    crossAxisSpacing: SolSpace.md,
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: albums.length,
                              itemBuilder: (context, index) => AlbumCard(
                                album: albums[index],
                                onTap: () => _openAlbum(context, albums[index]),
                              ),
                            ),
                          ),
                        ],
                  loading: () => const [_LoadingSliver()],
                  error: (error, _) => [
                    _ErrorSliver(
                      error: error,
                      onRetry: () => ref.invalidate(recentAlbumsProvider),
                    ),
                  ],
                ),
              ],
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

  /// Search results are songs: the server API returns them in one call and
  /// there is nowhere else to go for a single track.
  ///
  /// `search.when` returns widgets for a `slivers:` context in some branches,
  /// so the result is flattened into the surrounding list rather than wrapped
  /// in a single sliver.
  List<Widget> _songSliver(
    List<LibrarySong> songs, {
    required String emptyMessage,
  }) {
    if (songs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Symbols.search_rounded,
            title: 'Nothing found',
            message: emptyMessage,
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return _SongRow(
            song: song,
            onTap: () => ref
                .read(playbackProvider.notifier)
                .playQueue(songs, startIndex: index),
          );
        },
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.xl,
        SolSpace.xxl,
        SolSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Horizontal shelf of playable songs, each a cover card.
class _SongShelf extends ConsumerWidget {
  final List<LibrarySong> songs;

  const _SongShelf({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: SolSpace.md),
        itemBuilder: (context, index) {
          final song = songs[index];
          return _SongCard(
            song: song,
            onTap: () => ref
                .read(playbackProvider.notifier)
                .playQueue(songs, startIndex: index),
          );
        },
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final LibrarySong song;
  final VoidCallback onTap;

  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: onTap,
        borderRadius: SolRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(SolSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LibraryArtwork(
                sourceId: song.sourceId,
                artId: song.artId,
                size: 132,
                radius: SolRadius.md,
              ),
              const SizedBox(height: SolSpace.sm),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                song.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongRow extends ConsumerWidget {
  final LibrarySong song;
  final VoidCallback onTap;

  const _SongRow({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    return TrackRow(
      selected: playback.isCurrentSong(song),
      onTap: onTap,
      title: song.title,
      // The suffix only appears with several libraries connected, so a
      // single-server user never sees the extra noise.
      subtitle: songRowSubtitle(ref, song),
      trailing: formatDuration(song.duration),
      artwork: LibraryArtwork(
        sourceId: song.sourceId,
        artId: song.artId,
        size: 44,
        radius: SolRadius.xs,
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
  final Object error;
  final VoidCallback onRetry;

  const _ErrorSliver({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyState(
        icon: Symbols.error_rounded,
        title: 'Could not load this',
        message: describeServerError(error),
        iconColor: Theme.of(context).colorScheme.error,
        action: FilledButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _InlineError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SolSpace.xxl,
        vertical: SolSpace.sm,
      ),
      child: Row(
        children: [
          Icon(
            Symbols.error_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: SolSpace.sm),
          Expanded(
            child: Text(
              describeServerError(error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
