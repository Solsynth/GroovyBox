import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artist_card.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:groovy_box/widgets/section.dart';
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
/// Every playlist is one list rather than three: this device's, a server's
/// and the account's Solink lists are the same kind of thing, so they share
/// one header and one scan. Where a list lives is said on its detail page
/// (and in its row's subtitle when two servers could be confused), not by
/// which section it is filed under.
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
  static const _playlists = 'playlists';

  /// Namespaces the fold keys: the dashboard folds its own sections, and a
  /// fold on one page must not move a shelf on the other.
  static const _page = 'library';

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
              FoldableSection(
                page: _page,
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
              FoldableSection(
                page: _page,
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
              // One list of every playlist, wherever it lives: a device
              // playlist, a server's and the account's cloud lists are the
              // same kind of thing, and a reader asking "what lists do I
              // have" should not have to look under three headers first.
              FoldableSection(
                page: _page,
                id: _playlists,
                title: 'libraryPlaylists'.tr(),
                trailing: const _NewPlaylistButton(),
                builder: () => const [_PlaylistRows()],
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


/// Where a playlist lives, in one row's terms.
///
/// The list on the library page is one list: this device's playlists, a
/// server's and the account's Solink lists are the same kind of thing, and a
/// reader asking "what lists do I have" should not have to know which drawer
/// each one lives in. The source is said in the subtitle, where it
/// disambiguates (two servers can hold a playlist with the same name), and on
/// the detail page itself.
sealed class PlaylistEntry {
  const PlaylistEntry();

  String get name;
  String get subtitle;

  /// A cover that is a URL rather than a library handle: a cloud playlist's
  /// own artwork, which no library can resolve.
  String? get artworkUrl;

  /// A cover that is a library handle, and which source spells it. A device
  /// playlist borrows its first track's; a server playlist has its own.
  String? get artId;
  String? get artSourceId;

  IconData get icon;
  void open(BuildContext context);
}

class OwnedPlaylistEntry extends PlaylistEntry {
  final OwnedPlaylist playlist;

  const OwnedPlaylistEntry(this.playlist);

  @override
  String get name => playlist.name;

  @override
  String get subtitle => playlist.trackCount == 0
      ? 'ownedPlaylistEmptyHeader'.tr()
      : 'playlistsTrackCount'.plural(playlist.trackCount);

  @override
  String? get artworkUrl => null;

  @override
  String? get artId => playlist.artId?.artId;

  @override
  String? get artSourceId => playlist.artId?.sourceId;

  @override
  IconData get icon => Symbols.queue_music_rounded;

  @override
  void open(BuildContext context) => context.router.push(
    OwnedPlaylistDetailRoute(
      playlistId: playlist.id,
      playlistName: playlist.name,
    ),
  );
}

class ServerPlaylistEntry extends PlaylistEntry {
  final LibraryPlaylist playlist;

  /// The library's name, for the row that has to say which server it is.
  final String? origin;

  const ServerPlaylistEntry(this.playlist, {this.origin});

  @override
  String get name => playlist.name;

  @override
  String get subtitle => [
    if (playlist.songCount != null)
      'playlistsTrackCount'.plural(playlist.songCount!),
    if (playlist.duration > Duration.zero) formatDuration(playlist.duration),
    if (playlist.owner != null) playlist.owner!,
    if (origin != null && origin != playlist.owner) origin!,
  ].join('  ·  ');

  @override
  String? get artworkUrl => null;

  @override
  String? get artId => playlist.artId;

  @override
  String? get artSourceId => playlist.sourceId;

  @override
  IconData get icon => Symbols.playlist_play;

  @override
  void open(BuildContext context) => context.router.push(
    PlaylistDetailRoute(
      sourceId: playlist.sourceId,
      playlistId: playlist.id,
      playlistName: playlist.name,
    ),
  );
}

class CloudPlaylistEntry extends PlaylistEntry {
  final PulsarPlaylist playlist;
  final String? cover;

  const CloudPlaylistEntry(this.playlist, {this.cover});

  @override
  String get name => playlist.name;

  @override
  String get subtitle => [
    playlist.items.isEmpty
        ? 'ownedPlaylistEmptyHeader'.tr()
        : 'playlistsTrackCount'.plural(playlist.items.length),
    'pulsarPlaylistKind'.tr(),
  ].join('  ·  ');

  @override
  String? get artworkUrl => cover ?? playlist.artworkUrl;

  @override
  String? get artId => null;

  @override
  String? get artSourceId => null;

  @override
  IconData get icon => Symbols.cloud_rounded;

  @override
  void open(BuildContext context) => context.router.push(
    PulsarPlaylistDetailRoute(
      playlistId: playlist.id,
      playlistName: playlist.name,
    ),
  );
}

/// The account's hearts, drawn as a playlist row like the lists beside it.
///
/// Solink is the record of what the account likes, so it belongs in the one
/// list of playlists rather than in a section of its own: it is a collection
/// with a cover and a count, and it opens into its tracks.
class CloudFavouritesEntry extends PlaylistEntry {
  final int count;
  final String? cover;

  const CloudFavouritesEntry({required this.count, this.cover});

  @override
  String get name => 'libraryCloudFavourites'.tr();

  @override
  String get subtitle => 'playlistsTrackCount'.plural(count);

  @override
  String? get artworkUrl => cover;

  @override
  String? get artId => null;

  @override
  String? get artSourceId => null;

  @override
  IconData get icon => Symbols.favorite_rounded;

  @override
  void open(BuildContext context) => context.router.push(
    const SolinkFavouritesRoute(),
  );
}

/// One playlist, as a row: cover, name, and what is in it.
///
/// Same rounded hover language as [TrackRow], so the collection reads as one
/// family without a divider anywhere. A cloud playlist carries a cover URL of
/// its own, which is drawn directly instead of through [LibraryArtwork]: its
/// record has no library to resolve an art handle through.
class PlaylistCard extends StatelessWidget {
  final PlaylistEntry entry;

  const PlaylistCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final art = entry.artworkUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => entry.open(context),
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
                    child: switch (entry) {
                      // A handle is resolved through the library that spells
                      // it: a device playlist's cover comes from a connected
                      // source, and a server's from its own.
                      _ when entry.artId != null => LibraryArtwork(
                        sourceId: entry.artSourceId,
                        artId: entry.artId,
                        size: 52,
                        radius: SolRadius.md,
                        fallbackIcon: entry.icon,
                      ),
                      _ when art != null && art.isNotEmpty => Image.network(
                        art,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _coverFallback(colorScheme, entry.icon),
                      ),
                      _ => _coverFallback(colorScheme, entry.icon),
                    },
                  ),
                ),
                const SizedBox(width: SolSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.subtitle.isNotEmpty)
                        Text(
                          entry.subtitle,
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

  Widget _coverFallback(ColorScheme colorScheme, IconData icon) => ColoredBox(
    color: colorScheme.surfaceContainerHigh,
    child: Icon(icon, color: colorScheme.onSurfaceVariant),
  );
}

/// Every playlist, wherever it lives, as one list.
///
/// Ordering is by origin, not by name: this device's own playlists come first
/// because they are the ones the app owns and the ones that play without a
/// server; a server's follow in source order, and the account's Solink lists
/// close it because they are the lists that follow the account.
class _PlaylistRows extends ConsumerWidget {
  const _PlaylistRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(ownedPlaylistsProvider);
    final server = ref.watch(playlistsProvider);
    final cloud = ref.watch(pulsarPlaylistsProvider);
    final covers = ref.watch(pulsarPlaylistCoversProvider).value ?? const {};
    final favourites = ref.watch(pulsarFavouritesProvider);
    final sources = ref.watch(librarySourceByIdProvider);

    final ownedList = owned.value ?? const <OwnedPlaylist>[];
    final serverList = server.value ?? const <LibraryPlaylist>[];
    final cloudList = cloud.value ?? const <PulsarPlaylist>[];
    final loadError = server.hasError && serverList.isEmpty;

    final entries = <PlaylistEntry>[
      for (final playlist in ownedList) OwnedPlaylistEntry(playlist),
      for (final playlist in serverList)
        ServerPlaylistEntry(
          playlist,
          // Where it lives is the one thing a merged list cannot show by its
          // cover: two servers can hold a playlist with the same name, and
          // the row has to say which one opens.
          origin: sources[playlist.sourceId]?.displayName,
        ),
      for (final playlist in cloudList)
        CloudPlaylistEntry(playlist, cover: covers[playlist.id]),
      // The account's hearts close the list: they follow the account rather
      // than a library, and they are one collection, not a drawer.
      if (favourites.value case final list?)
        if (list.isNotEmpty)
          CloudFavouritesEntry(
            count: list.length,
            cover: list
                .map((item) => item.catalogItem?.artworkUrl)
                .whereType<String>()
                .where((url) => url.isNotEmpty)
                .firstOrNull,
          ),
    ];

    // Every list is still loading: a spinner says more than an empty page
    final loading =
        (owned.isLoading && ownedList.isEmpty) &&
        (server.isLoading && serverList.isEmpty) &&
        (cloud.isLoading && cloudList.isEmpty);
    if (loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(SolSpace.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SliverList.builder(
      itemCount:
          entries.length + (loadError ? 1 : 0) + (entries.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < entries.length) {
          return PlaylistCard(entry: entries[index]);
        }
        if (loadError) {
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
        // No playlists anywhere: an invitation, not a hole. The action is in
        // the section header so a folded section still offers it.
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xxl,
            0,
            SolSpace.xxl,
            SolSpace.sm,
          ),
          child: Text(
            'libraryPlaylistsEmpty'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }
}

/// The header action for a new playlist.
///
/// A device playlist is the one the app owns and the one that plays without a
/// server, so it is the default; the account's cloud list is offered beside
/// it only when signed in, because signed out there is nowhere to write one.
class _NewPlaylistButton extends ConsumerWidget {
  const _NewPlaylistButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    if (!signedIn) {
      return TextButton.icon(
        onPressed: () => _createOwnedPlaylist(context, ref),
        icon: const Icon(Symbols.add_rounded, size: 18),
        label: Text('libraryNewPlaylist'.tr()),
      );
    }
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Symbols.queue_music_rounded, size: 18),
          onPressed: () => _createOwnedPlaylist(context, ref),
          child: Text('libraryNewPlaylist'.tr()),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.cloud_rounded, size: 18),
          onPressed: () => _createCloudPlaylist(context, ref),
          child: Text('libraryNewCloudPlaylist'.tr()),
        ),
      ],
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Symbols.add_rounded, size: 18),
        label: Text('libraryNewPlaylist'.tr()),
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
