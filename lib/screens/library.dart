import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/screens/explore.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The collection, as one page: recently added above, the playlist lists
/// below, artists between them.
///
/// Albums, artists and playlists used to be three tabs behind a segmented
/// switch, and the switch made the shell say something untrue — they are not
/// three kinds of thing in the user's head, they are three shapes of one
/// collection, and someone looking for "the thing I made last week" had to
/// remember which shape it was before they could look. One scroll answers
/// all three, in the order the collection is actually used: new records
/// first, the people behind them, then every list that plays.
///
/// This is the place you go when you know what you want. What to play next is
/// the explore page's job, so this page is deliberately a catalogue: covers,
/// rows, and nothing that competes with the shelves.
///
/// The remote lists are mixed rather than stacked: the server's playlists and
/// the account's Solar playlists are one scan of covers, and the Solar
/// favourites close it as the list that is tracks rather than playlists. One
/// header says the whole block is from elsewhere; a row's subtitle names
/// where it lives.
@RoutePage()
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Section ids double as the remembered fold state, so they name the shelf
  /// rather than its position: reordering the page never moves a fold.
  static const _albums = 'albums';
  static const _artists = 'artists';
  static const _owned = 'owned';
  static const _remote = 'remote';
  static const _favourites = 'favourites';

  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(recentAlbumsProvider);
    final artists = ref.watch(libraryArtistsProvider);
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

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
              // The page's name scrolls with the collection, and the refresh
              // action lives beside it: nothing floats over the shelves.
              SliverToBoxAdapter(
                child: PageHeadline(
                  title: 'tabAlbums'.tr(),
                  trailing: IconButton(
                    tooltip: 'commonRefresh'.tr(),
                    onPressed: () {
                      ref.read(recentAlbumsProvider.notifier).refresh();
                      ref.read(playlistsProvider.notifier).refresh();
                    },
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                ),
              ),
              _CollectionSection(
                id: _albums,
                title: 'exploreRecentlyAdded'.tr(),
                builder: () => albums.when(
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
              ),
              _CollectionSection(
                id: _artists,
                title: 'libraryArtists'.tr(),
                builder: () => artists.when(
                  data: (list) => list.isEmpty
                      ? const []
                      : [
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 168,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SolSpace.xl,
                                ),
                                itemCount: list.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: SolSpace.md),
                                itemBuilder: (context, index) => SizedBox(
                                  width: 132,
                                  child: ArtistCard(
                                    artist: list[index],
                                    onTap: () =>
                                        _openArtist(context, list[index]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                  loading: () => const [],
                  error: (_, _) => const [],
                ),
              ),
              _CollectionSection(
                id: _owned,
                title: 'libraryOwnedPlaylists'.tr(),
                trailing: TextButton.icon(
                  onPressed: () => _createOwnedPlaylist(context, ref),
                  icon: const Icon(Symbols.add_rounded, size: 18),
                  label: Text('libraryNewPlaylist'.tr()),
                ),
                builder: () => [_OwnedPlaylistsList()],
              ),
              _CollectionSection(
                id: _remote,
                title: 'libraryRemotePlaylists'.tr(),
                // The create action stays on the header so a folded section
                // still offers it.
                trailing: const _NewCloudPlaylistButton(),
                builder: () => const [_RemotePlaylistsList()],
              ),
              _CollectionSection(
                id: _favourites,
                title: 'libraryCloudFavourites'.tr(),
                builder: () => const [_SolinkFavouritesCard()],
              ),
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

  void _openArtist(BuildContext context, LibraryArtist artist) {
    context.router.push(
      ArtistDetailRoute(
        sourceId: artist.sourceId,
        artistId: artist.id,
        artistName: artist.name,
      ),
    );
  }
}

/// Solink favourites as a built-in playlist: one row with the account's cover
/// and its count, opening into its own page.
///
/// The library lists collections, and the account's hearts are a collection
/// like any other — embedding its tracks here made one list render unlike
/// every other row on the page and, on a large account, buried the shelves
/// under a scroll of tracks that could not be folded away.
class _SolinkFavouritesCard extends ConsumerWidget {
  const _SolinkFavouritesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    if (!signedIn) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final favourites = ref.watch(pulsarFavouritesProvider);
    return favourites.when(
      data: (list) {
        // Signed in with nothing hearted: an empty section says nothing a
        // first heart would not say better.
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final count = list.length;
        final cover = list
            .map((item) => item.catalogItem?.artworkUrl)
            .whereType<String>()
            .where((url) => url.isNotEmpty)
            .firstOrNull;
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: SolSpace.xs),
            child: CloudPlaylistCard(
              name: 'libraryCloudFavourites'.tr(),
              subtitle: 'playlistsTrackCount'.plural(count),
              artworkUrl: cover,
              icon: Symbols.favorite_rounded,
              onTap: () => context.router.push(const SolinkFavouritesRoute()),
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(SolSpace.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

/// The header action for a new Solink playlist: hidden when signed out,
/// because there is nowhere to create one.
class _NewCloudPlaylistButton extends ConsumerWidget {
  const _NewCloudPlaylistButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    if (!signedIn) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => _createCloudPlaylist(context, ref),
      icon: const Icon(Symbols.add_rounded, size: 18),
      label: Text('libraryNewCloudPlaylist'.tr()),
    );
  }
}

/// One foldable shelf of the collection.
///
/// The header is always drawn — folding is a way to move down the page, not a
/// way to lose the way back — and the body is built only while it is open, so
/// a folded section costs its header and nothing else.
class _CollectionSection extends ConsumerWidget {
  /// Stable id for the remembered fold state: the section's name, never its
  /// position.
  final String id;
  final String title;
  final Widget? trailing;

  /// The shelf's own slivers. Called only while the section is open.
  final List<Widget> Function() builder;

  const _CollectionSection({
    required this.id,
    required this.title,
    required this.builder,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(
      collapsedLibrarySectionsProvider.select((set) => set.contains(id)),
    );
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: LibrarySectionHeader(
            title: title,
            trailing: trailing,
            collapsed: collapsed,
            onToggle: () =>
                ref.read(collapsedLibrarySectionsProvider.notifier).toggle(id),
          ),
        ),
        if (!collapsed) ...builder(),
      ],
    );
  }
}

/// An artist as a card: the source's art when it has one, a person-shaped
/// fallback when it does not, and the name under it.
///
/// The grid card the album half uses, at the same size: three halves of one
/// collection should not read as three designs.
class ArtistCard extends StatefulWidget {
  final LibraryArtist artist;
  final VoidCallback onTap;

  const ArtistCard({super.key, required this.artist, required this.onTap});

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: SolRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(SolSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedScale(
                    scale: _hovered ? 1.02 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SolRadius.md),
                        boxShadow: _hovered
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(SolRadius.md),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Person-shaped placeholder, always painted: the
                            // artwork covers it when the source has one, so a
                            // missing cover reads as a portrait, not a hole.
                            ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Symbols.person_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            LibraryArtwork(
                              sourceId: widget.artist.sourceId,
                              artId: widget.artist.artId,
                              radius: 0,
                              fallbackIcon: Symbols.person_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SolSpace.sm),
              Text(
                widget.artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.artist.albumCount != null)
                Text(
                  'artistsAlbums'.plural(widget.artist.albumCount!),
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


/// An album-less library is a message, not a hole.
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


/// A playlist as a row: cover, name, and what is in it.
///
/// Same rounded hover language as [TrackRow], so the collection reads as one
/// family without a divider anywhere. [origin] names the library the list
/// lives on, which only a merged list needs: a row above it and a row below
/// it can share a name and belong to two different servers.
class PlaylistCard extends StatelessWidget {
  final LibraryPlaylist playlist;
  final VoidCallback onTap;
  final String? origin;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.origin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = [
      if (playlist.songCount != null)
        'playlistsTrackCount'.plural(playlist.songCount!),
      if (playlist.duration > Duration.zero) formatDuration(playlist.duration),
      if (playlist.owner != null) playlist.owner!,
      if (origin != null && origin != playlist.owner) origin!,
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

/// The playlists this device owns, as a bare list: the section above it draws
/// the name and the create action, so a folded section still offers "new
/// playlist".
class _OwnedPlaylistsList extends ConsumerWidget {
  const _OwnedPlaylistsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(ownedPlaylistsProvider);
    return owned.when(
      data: (list) => SliverList.builder(
        itemCount: list.isEmpty ? 1 : list.length,
        itemBuilder: (context, index) {
          if (list.isEmpty) {
            return Padding(
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
            );
          }
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
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(SolSpace.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      // A device with no catalog can still browse servers; the section simply
      // has nothing it could create.
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
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

  /// The mark drawn when there is no cover: a cloud for a Solink playlist,
  /// a heart for the account's favourites.
  final IconData icon;

  const CloudPlaylistCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.artworkUrl,
    this.icon = Symbols.cloud_rounded,
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
                              icon,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Image.network(
                            art,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colorScheme.surfaceContainerHigh,
                              child: Icon(
                                icon,
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

/// Every playlist that lives somewhere else, in one list.
///
/// The server's playlists and the account's Solink playlists were two stacked
/// sections, which made the page answer "where does this live" before it
/// could answer "what is this": the same kind of thing twice, under two
/// headers, separated by nothing the reader cared about. The question this
/// page answers is what lists exist, so they are one list — a server
/// playlist, then a Solink one, each row carrying its own cover and its own
/// count.
///
/// Ordering is by origin, not by name: the server answered first because its
/// list is the one the user curated there, and Solink's follows because it is
/// the list that follows the account. Neither group is labelled — the
/// subtitle says where a list lives when it is opened.
class _RemotePlaylistsList extends ConsumerWidget {
  const _RemotePlaylistsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(playlistsProvider);
    final cloud = ref.watch(pulsarPlaylistsProvider);
    final covers = ref.watch(pulsarPlaylistCoversProvider).value ?? const {};
    final sources = ref.watch(librarySourceByIdProvider);
    final serverList = server.value ?? const <LibraryPlaylist>[];
    final cloudList = cloud.value ?? const <PulsarPlaylist>[];
    final serverFailed = server.hasError && serverList.isEmpty;
    if (serverList.isEmpty && cloudList.isEmpty && !serverFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverList.builder(
      itemCount: serverList.length + cloudList.length + (serverFailed ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < serverList.length) {
          final playlist = serverList[index];
          return PlaylistCard(
            playlist: playlist,
            // Where it lives is the one thing a merged list cannot show by
            // its cover: two servers can hold a playlist with the same name,
            // and the row has to say which one opens.
            origin: sources[playlist.sourceId]?.displayName,
            onTap: () => context.router.push(
              PlaylistDetailRoute(
                sourceId: playlist.sourceId,
                playlistId: playlist.id,
                playlistName: playlist.name,
              ),
            ),
          );
        }
        final cloudIndex = index - serverList.length;
        if (cloudIndex >= cloudList.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.xxl,
              SolSpace.sm,
              SolSpace.xxl,
              0,
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
                    'playlistsLoadError'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(playlistsProvider.notifier).refresh(),
                  child: Text('commonRetry'.tr()),
                ),
              ],
            ),
          );
        }
        final playlist = cloudList[cloudIndex];
        final count = playlist.items.length;
        return CloudPlaylistCard(
          name: playlist.name,
          subtitle: [
            count == 0
                ? 'ownedPlaylistEmptyHeader'.tr()
                : 'playlistsTrackCount'.plural(count),
            'pulsarPlaylistKind'.tr(),
          ].join('  ·  '),
          artworkUrl: covers[playlist.id] ?? playlist.artworkUrl,
          onTap: () => context.router.push(
            PulsarPlaylistDetailRoute(
              playlistId: playlist.id,
              playlistName: playlist.name,
            ),
          ),
        );
      },
    );
  }
}
