import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/tab_navigation.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/local_import.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The landing page: a mixed home of what is worth playing next.
///
/// It is not a collection index — that is the library tab — and not a search
/// field. It is the page a fresh window opens on: the account's own curation,
/// a shelf drawn at random from everything the libraries hold, and the newest
/// records, each a single tap from playing. The question it answers is "what
/// do I put on", and every shelf is answered by pressing a cover.
@RoutePage()
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    final recentAlbums = ref.watch(recentAlbumsProvider);
    final randomSongs = ref.watch(randomSongsProvider);
    // Only accounts bring their own curation and their own numbers; a server
    // library contributes nothing here and the shelves below carry it.
    final digests = ref.watch(libraryDigestsProvider);
    final curated = ref.watch(landingShelvesProvider);
    final servers = ref.watch(librarySourcesProvider);
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);
    // Empty until a read answers, so a first frame never flashes a shelf that
    // the next frame removes.
    final hasMusic =
        (randomSongs.value?.isNotEmpty ?? false) ||
        (recentAlbums.value?.isNotEmpty ?? false) ||
        (curated.value?.isNotEmpty ?? false);

    void refreshAll() {
      ref.read(recentAlbumsProvider.notifier).refresh();
      ref.read(randomSongsProvider.notifier).refresh();
      ref.read(libraryDigestsProvider.notifier).refresh();
      ref.read(landingShelvesProvider.notifier).refresh();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(recentAlbumsProvider.notifier).refresh();
          await ref.read(randomSongsProvider.notifier).refresh();
          await ref.read(libraryDigestsProvider.notifier).refresh();
          await ref.read(landingShelvesProvider.notifier).refresh();
        },
        child: ContentFrame(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: 'exploreTitle'.tr(),
                  subtitle: servers.isEmpty
                      ? null
                      : servers.length == 1
                      ? 'exploreStreamingFrom'.tr(
                          args: [servers.single.displayName],
                        )
                      : 'exploreStreamingFromLibraries'.tr(
                          args: ['${servers.length}'],
                        ),
                  actions: [
                    IconButton(
                      tooltip: 'commonRefresh'.tr(),
                      onPressed: refreshAll,
                      icon: const Icon(Symbols.refresh_rounded),
                    ),
                    const SizedBox(width: SolSpace.sm),
                  ],
                ),
              ),
              if (servers.isEmpty)
                const SliverToBoxAdapter(child: AddSourceCard()),
              // The account's own shelves come first when there are any: they
              // are the source's curation, which the merged shelves below
              // cannot reconstruct (a mix is not a playlist and a station is
              // not a track).
              ...digests.when(
                data: (list) => [
                  for (final digest in list)
                    SliverToBoxAdapter(
                      child: LibraryDigestCard(
                        digest: digest,
                        shelves: [
                          for (final shelf
                              in curated.value ?? const <LandingShelf>[])
                            if (shelf.sourceId == digest.sourceId) shelf,
                        ],
                      ),
                    ),
                ],
                loading: () => const <Widget>[],
                error: (_, _) => const <Widget>[],
              ),
              for (final shelf
                  in curated.value ?? const <LandingShelf>[]) ...[
                SliverToBoxAdapter(
                  child: LibrarySectionHeader(title: shelf.title),
                ),
                SliverToBoxAdapter(child: SongShelf(songs: shelf.songs)),
              ],
              if (hasMusic) ...[
                SliverToBoxAdapter(
                  child: LibrarySectionHeader(
                    title: 'exploreMadeForYou'.tr(),
                    trailing: TextButton.icon(
                      onPressed: () => ref
                          .read(randomSongsProvider.notifier)
                          .refresh(),
                      icon: const Icon(Symbols.refresh_rounded, size: 18),
                      label: Text('exploreShuffle'.tr()),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: randomSongs.when(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : SongShelf(songs: songs),
                    loading: () => const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => InlineError(
                      error: error,
                      onRetry: () => ref.invalidate(randomSongsProvider),
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: LibrarySectionHeader(
                  title: 'exploreRecentlyAdded'.tr(),
                  trailing: TextButton(
                    // The collection is the tab beside this one; selecting it
                    // is the same move the bottom bar makes.
                    onPressed: () => _openLibrary(context),
                    child: Text('exploreSeeAll'.tr()),
                  ),
                ),
              ),
              ...recentAlbums.when(
                data: (list) => list.isEmpty
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
                    error: error,
                    onRetry: () => ref.invalidate(recentAlbumsProvider),
                  ),
                ],
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

  /// Switches to the collection tab.
  ///
  /// A tab's landing page belongs to another tab's collection, so it cannot
  /// be pushed: selecting the tab is the same move the rail and the bottom
  /// bar make.
  void _openLibrary(BuildContext context) => activateTab(context, 'library');
}

/// What a connected account says about itself, at the top of the page.
///
/// It is a dashboard line rather than a shelf: the numbers are the point
/// ("this account has 842 tracks, 10 mixes, 3 stations"), and they are the
/// only place the app reports a cloud library's own size — a server's rows are
/// the app's business, but Apple Music's curation is not reconstructible from
/// what the app can see.
class LibraryDigestCard extends ConsumerWidget {
  final LibraryDigest digest;

  /// The shelves the page is showing for this account. Counted here rather
  /// than read again, so the card can never disagree with what is under it.
  final List<LandingShelf> shelves;

  const LibraryDigestCard({
    super.key,
    required this.digest,
    required this.shelves,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stationCount = shelves
        .expand((shelf) => shelf.songs)
        .where((song) => song.isRadio)
        .length;
    final stats = [
      if (digest.libraryTracks != null)
        'libraryDigestTracks'.tr(args: ['${digest.libraryTracks}']),
      if (shelves.isNotEmpty)
        'libraryDigestMixes'.tr(args: ['${shelves.length}']),
      if (stationCount > 0) 'libraryDigestStations'.tr(args: ['$stationCount']),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xl,
        SolSpace.md,
        SolSpace.xl,
        0,
      ),
      child: IslandCard(
        padding: const EdgeInsets.all(SolSpace.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: SolRadius.cardRadius,
              ),
              child: Icon(
                Symbols.music_note_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: SolSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    digest.subtitle ?? 'libraryAccountDashboard'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ['libraryAccountLabel'.tr(), ...stats].join('  ·  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SolSpace.sm),
            IconButton(
              tooltip: 'commonRefresh'.tr(),
              // The numbers and the recipes behind them are one read each, so
              // the card refreshes both rather than leaving a stale count over
              // freshly-read shelves.
              onPressed: () {
                ref.read(libraryDigestsProvider.notifier).refresh();
                ref.read(landingShelvesProvider.notifier).refresh();
              },
              icon: const Icon(Symbols.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one nudge this page makes: with no server connected the library is
/// empty, and the way out is either connecting one or importing files already
/// on this device. It is a card in the page, not a gate — the app is usable
/// before either happens.
class AddSourceCard extends ConsumerWidget {
  const AddSourceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xl,
        SolSpace.sm,
        SolSpace.xl,
        SolSpace.sm,
      ),
      child: IslandCard(
        padding: const EdgeInsets.all(SolSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.cloud_off_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SolSpace.sm),
                Expanded(
                  child: Text(
                    'exploreNoSourceTitle'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SolSpace.sm),
            Text(
              'exploreNoSourceMessage'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: SolSpace.lg),
            Wrap(
              spacing: SolSpace.sm,
              runSpacing: SolSpace.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => context.router.push(const SetupRoute()),
                  icon: const Icon(Symbols.add_rounded, size: 18),
                  label: Text('exploreAddSource'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: () => importMusicFiles(context, ref),
                  icon: const Icon(Symbols.file_open_rounded, size: 18),
                  label: Text('exploreImportFiles'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A section's name, above the shelf it introduces.
class LibrarySectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const LibrarySectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Horizontal shelf of playable songs, each a cover card.
class SongShelf extends ConsumerWidget {
  final List<LibrarySong> songs;

  const SongShelf({super.key, required this.songs});

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
          return SongCard(
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

class SongCard extends StatelessWidget {
  final LibrarySong song;
  final VoidCallback onTap;

  const SongCard({super.key, required this.song, required this.onTap});

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
    return SliverToBoxAdapter(
      child: EmptyState(
        compact: true,
        icon: Symbols.album,
        title: 'exploreLoadError'.tr(),
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

/// One quiet error line on a section that has nothing to show.
class InlineError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const InlineError({super.key, required this.error, required this.onRetry});

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
          TextButton(onPressed: onRetry, child: Text('commonRetry'.tr())),
        ],
      ),
    );
  }
}
