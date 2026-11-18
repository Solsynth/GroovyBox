import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
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
              ...albums.when(
                data: (list) => list.isEmpty
                    ? const [_EmptyAlbums()]
                    : [
                        SliverToBoxAdapter(
                          child: LibrarySectionHeader(
                            title: 'exploreRecentlyAdded'.tr(),
                          ),
                        ),
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
              ...artists.when(
                data: (list) => list.isEmpty
                    ? const []
                    : [
                        SliverToBoxAdapter(
                          child: LibrarySectionHeader(
                            title: 'libraryArtists'.tr(),
                          ),
                        ),
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
              const _OwnedPlaylistsSection(),
              const _RemotePlaylistsSection(),
              const _CloudFavouritesSection(),
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

/// Every playlist that lives somewhere else, in one list.
///
/// The server's playlists and the account's Solar playlists were two stacked
/// sections, which made the page answer "where does this live" before it
/// could answer "what is this": the same kind of thing twice, under two
/// headers, separated by nothing the reader cared about. The question this
/// page answers is what lists exist, so they are one list — a server
/// playlist, then a Solar one, each row carrying its own cover and its own
/// count, and the section header saying only that this block is remote and
/// where a new Solar playlist is made.
///
/// Ordering is by origin, not by name: the server answered first because its
/// list is the one the user curated there, and Solar's follows because it is
/// the list that follows the account. Neither group is labelled — the
/// subtitle says where a list lives when it is opened.
class _RemotePlaylistsSection extends ConsumerWidget {
  const _RemotePlaylistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(playlistsProvider);
    final cloud = ref.watch(pulsarPlaylistsProvider);
    final covers = ref.watch(pulsarPlaylistCoversProvider).value ?? const {};
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    final sources = ref.watch(librarySourceByIdProvider);
    final serverList = server.value ?? const <LibraryPlaylist>[];
    final cloudList = cloud.value ?? const <PulsarPlaylist>[];
    final serverFailed = server.hasError && serverList.isEmpty;
    if (serverList.isEmpty &&
        (!signedIn || cloudList.isEmpty) &&
        !serverFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: LibrarySectionHeader(
            title: 'libraryRemotePlaylists'.tr(),
            trailing: signedIn
                ? TextButton.icon(
                    onPressed: () => _createCloudPlaylist(context, ref),
                    icon: const Icon(Symbols.add_rounded, size: 18),
                    label: Text('libraryNewCloudPlaylist'.tr()),
                  )
                : null,
          ),
        ),
        SliverList.builder(
          itemCount: serverList.length + cloudList.length,
          itemBuilder: (context, index) {
            if (index < serverList.length) {
              final playlist = serverList[index];
              return PlaylistCard(
                playlist: playlist,
                // Where it lives is the one thing a merged list cannot show
                // by its cover: two servers can hold a playlist with the same
                // name, and the row has to say which one opens.
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
            final playlist = cloudList[index - serverList.length];
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
        ),
        if (serverFailed)
          SliverToBoxAdapter(
            child: Padding(
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
            ),
          ),
      ],
    );
  }
}

/// The account's favourites, as Solar Network holds them.
///
/// Solar is the record: this is the list every device writes to and every
/// import lands in, so it is shown as a playable list, not a mirror of
/// labels. A recording this device can play is matched to its own copy and
/// played from there; one it cannot play yet stays visible, because its
/// presence is what the next import or library connection fills in.
class _CloudFavouritesSection extends ConsumerWidget {
  const _CloudFavouritesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    if (!signedIn) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final favourites = ref.watch(pulsarFavouritesProvider);
    final songs = ref.watch(solarFavouriteSongsProvider);
    return favourites.when(
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final resolved = songs.value ?? const <LibrarySong?>[];
        final playable = [
          for (final song in resolved) ?song,
        ];
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: LibrarySectionHeader(
                title: 'libraryCloudFavourites'.tr(),
                trailing: TextButton.icon(
                  onPressed: playable.isEmpty
                      ? null
                      : () => ref
                            .read(playbackProvider.notifier)
                            .playQueue(playable),
                  icon: const Icon(Symbols.play_arrow_rounded, size: 18),
                  label: Text('commonPlay'.tr()),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final track = item.catalogItem;
                final catalogId = item.catalogId;
                if (track == null || catalogId == null) {
                  return const SizedBox.shrink();
                }
                final song = index < resolved.length ? resolved[index] : null;
                return _CloudFavouriteRow(
                  track: track,
                  song: song,
                  onPlay: song == null || playable.isEmpty
                      ? null
                      : () => ref
                            .read(playbackProvider.notifier)
                            .playQueue(playable, startIndex: playable.indexOf(song)),
                  onRemove: () =>
                      _remove(context, ref, catalogId, track, song),
                );
              },
            ),
          ],
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

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String catalogId,
    CatalogItem track,
    LibrarySong? song,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(pulsarFavouritesProvider.notifier).clear(catalogId);
      // The device's own heart goes with it: the sync pushes every local heart
      // the account is missing, so leaving it behind would put this one back
      // on the next run.
      if (song != null) {
        await ref.read(favouritesProvider).set(song, value: false);
        ref.invalidate(favouriteStateProvider(song));
      }
      // The account's key set is what the hearts read, so one removal turns
      // every surface that asked.
      ref.invalidate(solarFavouriteKeysProvider);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('libraryCloudFavouriteRemoved'.tr(args: [track.title])),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }
}

/// One row of the account's favourites: the track, playable when this device
/// holds it, and the heart that takes it back out of the account.
class _CloudFavouriteRow extends ConsumerWidget {
  final CatalogItem track;
  final LibrarySong? song;
  final VoidCallback? onPlay;
  final VoidCallback onRemove;

  const _CloudFavouriteRow({
    required this.track,
    required this.song,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = song;
    if (local != null) {
      return SongTrackRow(
        song: local,
        subtitle: songRowSubtitle(ref, local),
        trailing: local.duration == Duration.zero
            ? null
            : formatDuration(local.duration),
        artwork: LibraryArtwork(
          sourceId: local.sourceId,
          artId: local.artId,
          size: 48,
          radius: SolRadius.xs,
        ),
        onTap: onPlay,
        onLongPress: onRemove,
      );
    }
    final art = track.artworkUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(SolRadius.md),
            child: SizedBox.square(
              dimension: 48,
              child: art == null || art.isEmpty
                  ? ColoredBox(
                      color: scheme.surfaceContainerHigh,
                      child: Icon(
                        Symbols.favorite_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Image.network(
                      art,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: Icon(
                          Symbols.favorite_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: SolSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  track.subtitle ?? 'pulsarPlaylistUnmatched'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'libraryCloudFavouriteRemove'.tr(),
            icon: const Icon(Symbols.favorite_rounded),
            color: scheme.error,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
