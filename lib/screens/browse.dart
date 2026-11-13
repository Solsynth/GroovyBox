import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/tab_navigation.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/local_import.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/catalog_search.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/track_versions.dart';
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
    // Only accounts bring their own curation and their own numbers; a server
    // library contributes nothing here and the shelves below carry it.
    final digests = ref.watch(libraryDigestsProvider);
    final curated = ref.watch(landingShelvesProvider);
    // A library with a store behind it can be searched for what it does not
    // hold yet; the field below only asks what it already holds.
    final extendable = ref.watch(extendableSourcesProvider);
    final search = ref.watch(searchSongsProvider(_query));
    // The local library is always present, so "no library yet" means "no
    // server yet": the page nudges instead of blocking.
    final servers = ref.watch(librarySourcesProvider);
    // Select the identity, not the state: watching the whole transport would
    // rebuild this page on every position tick, once a second.
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
                  showRailToggle: true,
                  title: 'browseTitle'.tr(),
                  subtitle: servers.isEmpty
                      ? null
                      : servers.length == 1
                      ? 'browseStreamingFrom'.tr(
                          args: [servers.single.displayName],
                        )
                      : 'browseStreamingFromLibraries'.tr(
                          args: ['${servers.length}'],
                        ),
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
                    hintText: 'browseSearchPlaceholder'.tr(),
                    leading: const Icon(Symbols.search_rounded),
                    trailing: [
                      if (_query.isNotEmpty)
                        IconButton(
                          tooltip: 'commonClear'.tr(),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Symbols.close_rounded),
                        ),
                      // The other direction from this field: the library
                      // searches what is held, this searches what the store
                      // has and can add.
                      if (extendable.isNotEmpty)
                        IconButton(
                          tooltip: 'catalogOpen'.tr(),
                          onPressed: () => CatalogSearchPanel.show(
                            context,
                            extendable.first,
                          ),
                          icon: const Icon(Symbols.travel_explore_rounded),
                        ),
                    ],
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
              if (servers.isEmpty)
                const SliverToBoxAdapter(child: _AddSourceCard()),
              if (_query.trim().isNotEmpty)
                // Every branch returns a list of slivers, so `when` is typed
                // to that and the whole thing spreads into the outer list.
                ...search.when<List<Widget>>(
                  data: (songs) => _songSliver(
                    songs,
                    emptyMessage: 'browseSearchEmpty'.tr(args: [_query]),
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
              else if (!hasMusic)
                // Nothing to shelve yet: the card above is the whole page.
                // Two empty headings would say the same thing twice.
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else ...[
                // The account's own shelves come first: they are the
                // provider's curation, which the merged shelves below cannot
                // reconstruct (a mix is not a playlist and a station is not a
                // track).
                ...digests.when(
                  data: (list) => [
                    for (final digest in list)
                      SliverToBoxAdapter(
                        child: _DigestCard(
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
                  SliverToBoxAdapter(child: _SectionHeader(title: shelf.title)),
                  SliverToBoxAdapter(child: _SongShelf(songs: shelf.songs)),
                ],
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'browseMadeForYou'.tr(),
                    trailing: TextButton.icon(
                      onPressed: () async {
                        await ref.read(randomSongsProvider.notifier).refresh();
                      },
                      icon: const Icon(Symbols.refresh_rounded, size: 18),
                      label: Text('browseShuffle'.tr()),
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
                    title: 'browseRecentlyAdded'.tr(),
                    trailing: TextButton(
                      // Albums is another tab, not a page above this one:
                      // selecting it is the same move the bottom bar makes.
                      onPressed: () => activateTab(context, 'albums'),
                      child: Text('browseSeeAll'.tr()),
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
            title: 'browseSearchNotFoundTitle'.tr(),
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

/// What a connected account says about itself, as the page's first card.
///
/// It is a dashboard line rather than a shelf: the numbers are the point
/// ("this account has 842 tracks, 10 mixes, 3 stations"), and they are the
/// only place the app reports a cloud library's own size — a server's rows
/// are the app's business, but Apple Music's curation is not reconstructible
/// from what the app can see.
class _DigestCard extends ConsumerWidget {
  final LibraryDigest digest;

  /// The shelves the page is showing for this account. Counted here rather
  /// than read again, so the card can never disagree with what is under it.
  final List<LandingShelf> shelves;

  const _DigestCard({required this.digest, required this.shelves});

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
        'browseDigestTracks'.tr(args: ['${digest.libraryTracks}']),
      if (shelves.isNotEmpty)
        'browseDigestMixes'.tr(args: ['${shelves.length}']),
      if (stationCount > 0) 'browseDigestStations'.tr(args: ['$stationCount']),
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
                    digest.subtitle ?? 'browseAppleMusicDashboard'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ['browseAppleMusicAccount'.tr(), ...stats].join('  ·  '),
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
class _AddSourceCard extends ConsumerWidget {
  const _AddSourceCard();

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
                    'browseNoSourceTitle'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SolSpace.sm),
            Text(
              'browseNoSourceMessage'.tr(),
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
                  label: Text('browseAddSource'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: () => importMusicFiles(context, ref),
                  icon: const Icon(Symbols.file_open_rounded, size: 18),
                  label: Text('browseImportFiles'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      // A long-press asks the question this row cannot: does another library
      // have a better copy of this?
      onLongPress: () => TrackVersionsPanel.show(context, song),
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
        title: 'browseLoadError'.tr(),
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
          TextButton(onPressed: onRetry, child: Text('commonRetry'.tr())),
        ],
      ),
    );
  }
}
