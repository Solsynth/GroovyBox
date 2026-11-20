import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/dashboard_layout.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/tab_navigation.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/dashboard.dart';
import 'package:groovy_box/widgets/friends_listening.dart';
import 'package:groovy_box/widgets/section.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The landing page: a mixed home of what is worth playing next.
///
/// It is not a collection index — that is the library tab — and not a search
/// field. It is the page a fresh window opens on, and every shelf is answered
/// by pressing a cover. The question it answers is "what do I put on".
///
/// The page is the user's, not the app's: sections fold like the library's
/// and stay folded, and a customize sheet can reorder them, remove them, and
/// pin a playlist as a section of its own. A section is remembered by what it
/// is rather than where it sits, so rearranging the page never moves a fold.
@RoutePage()
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  /// Namespaces the fold keys: the library folds its own sections under the
  /// same provider, and a fold on one page must not move a shelf on another.
  static const _page = 'dashboard';

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(dashboardLayoutProvider);

    // The catalog is shared with the customize sheet: it names each section
    // and says whether it has anything to show. The page attaches the content,
    // because only the page knows how a shelf behaves (a shuffle, a tab
    // switch, a queue).
    final available = ref.watch(
      dashboardSectionsProvider(Localizations.localeOf(context).languageCode),
    );

    // What the shelves are filled from. Watched here rather than in the
    // catalog so a section header can sit over a loading or failed read.
    final recentAlbums = ref.watch(recentAlbumsProvider);
    final randomSongs = ref.watch(randomSongsProvider);
    // Only accounts curate their own shelves; a server library contributes
    // nothing here and the shelves below carry it.
    final curated = ref.watch(landingShelvesProvider);
    final servers = ref.watch(librarySourcesProvider);
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    void refreshAll() {
      ref.read(recentAlbumsProvider.notifier).refresh();
      ref.read(randomSongsProvider.notifier).refresh();
      ref.read(landingShelvesProvider.notifier).refresh();
    }

    // The user's order first, then anything they have not seen yet — a
    // curated shelf appears when the account answers it, at the end, rather
    // than rearranging the page under them. Pins are sections too, so they
    // take their place in that one order instead of being appended below.
    final ordered = dashboardSectionOrder(layout, available);

    // Removed shelves stay removed; a pin is removed by removing the pin, not
    // by hiding its key.
    final shown = [
      for (final key in ordered)
        if (!layout.hidden.contains(key)) key,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(recentAlbumsProvider.notifier).refresh();
          await ref.read(randomSongsProvider.notifier).refresh();
          await ref.read(landingShelvesProvider.notifier).refresh();
        },
        child: ContentFrame(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageHeadline(
                  title: 'exploreTitle'.tr(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'dashboardCustomize'.tr(),
                        onPressed: () => showDashboardCustomize(context),
                        icon: const Icon(Symbols.tune_rounded),
                      ),
                      IconButton(
                        tooltip: 'shuffleTitle'.tr(),
                        onPressed: () =>
                            context.router.push(const SmartShuffleRoute()),
                        icon: const Icon(Symbols.shuffle_rounded),
                      ),
                      IconButton(
                        tooltip: 'commonRefresh'.tr(),
                        onPressed: refreshAll,
                        icon: const Icon(Symbols.refresh_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (servers.isEmpty)
                const SliverToBoxAdapter(child: AddSourceCard()),
              for (final key in shown)
                if (available[key] case final shelf?)
                  if (shelf.visible)
                    FoldableSection(
                      page: _page,
                      id: key,
                      title: shelf.title,
                      subtitle: shelf.source,
                      trailing: _trailingFor(context, key),
                      builder: () => _bodyFor(
                        key,
                        shelf,
                        randomSongs: randomSongs,
                        recentAlbums: recentAlbums,
                        curated: curated,
                      ),
                    ),
              SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
            ],
          ),
        ),
      ),
    );
  }

  /// The one action a section's header offers, when it has one.
  Widget? _trailingFor(BuildContext context, String key) => switch (key) {
    DashboardSections.smartShuffle => _shuffleActions(context),
    DashboardSections.forYou => TextButton.icon(
      onPressed: () => ref.read(randomSongsProvider.notifier).refresh(),
      icon: const Icon(Symbols.shuffle_rounded, size: 18),
      label: Text('exploreShuffle'.tr()),
    ),
    DashboardSections.recentlyAdded => TextButton(
      // The collection is the tab beside this one; selecting it is the same
      // move the bottom bar makes.
      onPressed: () => _openLibrary(context),
      child: Text('exploreSeeAll'.tr()),
    ),
    _ => null,
  };

  /// The smart shuffle's three moves: play it, draw another, or go to the page
  /// that explains it. The first two act on the one shared plan, so the shelf
  /// and the page never show two mixes.
  Widget _shuffleActions(BuildContext context) {
    final queue = ref.watch(shufflePlanProvider).value?.queue ?? const [];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'shufflePlay'.tr(),
          // The cards play from the one they touch; this is the whole mix.
          onPressed: queue.isEmpty
              ? null
              : () => ref.read(playbackProvider.notifier).playQueue(queue),
          icon: const Icon(Symbols.play_arrow_rounded),
        ),
        IconButton(
          tooltip: 'shuffleAgain'.tr(),
          onPressed: () => ref.read(shufflePlanProvider.notifier).shuffle(),
          icon: const Icon(Symbols.shuffle_rounded),
        ),
        IconButton(
          tooltip: 'shuffleOpen'.tr(),
          onPressed: () => context.router.push(const SmartShuffleRoute()),
          icon: const Icon(Symbols.chevron_right_rounded),
        ),
      ],
    );
  }

  /// A section's content, attached by key rather than carried in the catalog.
  ///
  /// A key the catalog lists but whose content vanished — a curated shelf the
  /// account stopped answering — renders its header over nothing instead of
  /// dropping the section the user arranged.
  List<Widget> _bodyFor(
    String key,
    DashboardShelf shelf, {
    required AsyncValue<List<LibrarySong>> randomSongs,
    required AsyncValue<List<LibraryAlbum>> recentAlbums,
    required AsyncValue<List<LandingShelf>> curated,
  }) {
    // A pinned playlist is the one shelf whose content is named by the
    // catalog itself; a playlist that was deleted is handled by the shelf.
    if (shelf.pin case final pin?) {
      return [SliverToBoxAdapter(child: PinnedPlaylistShelf(pin: pin))];
    }

    switch (key) {
      case DashboardSections.smartShuffle:
        return const [SliverToBoxAdapter(child: SmartShuffleShelf())];
      case DashboardSections.forYou:
        return [
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
        ];
      case DashboardSections.friends:
        return const [SliverToBoxAdapter(child: FriendsListeningRows())];
      case DashboardSections.recentlyAdded:
        return recentAlbums.when(
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
          loading: () => const [DashboardLoadingSliver()],
          error: (error, _) => [
            DashboardErrorSliver(
              error: error,
              onRetry: () => ref.invalidate(recentAlbumsProvider),
            ),
          ],
        );
    }

    // The account's own shelves: its curation is what the merged shelves
    // cannot reconstruct (a mix is not a playlist and a station is not a
    // track). The key spells the shelf it names, so a read that dropped it
    // falls through to an empty body rather than to another shelf's songs.
    for (final curatedShelf in curated.value ?? const <LandingShelf>[]) {
      final curatedKey = DashboardSections.curated(
        curatedShelf.sourceId,
        curatedShelf.title,
      );
      if (curatedKey == key) {
        return [
          SliverToBoxAdapter(child: SongShelf(songs: curatedShelf.songs)),
        ];
      }
    }
    return const [];
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
