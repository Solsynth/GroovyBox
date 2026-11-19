import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/dashboard_layout.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/tab_navigation.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/pulsar/providers.dart';
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
    final recentAlbums = ref.watch(recentAlbumsProvider);
    final randomSongs = ref.watch(randomSongsProvider);
    // Only accounts curate their own shelves; a server library contributes
    // nothing here and the shelves below carry it.
    final curated = ref.watch(landingShelvesProvider);
    final servers = ref.watch(librarySourcesProvider);
    final friends = ref.watch(friendListeningFeedProvider);
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    void refreshAll() {
      ref.read(recentAlbumsProvider.notifier).refresh();
      ref.read(randomSongsProvider.notifier).refresh();
      ref.read(landingShelvesProvider.notifier).refresh();
    }

    // The page's shelves before the user's arrangement is applied.
    final available = <String, DashboardShelf>{
      DashboardSections.forYou: DashboardShelf(
        title: 'exploreMadeForYou'.tr(),
        icon: Symbols.auto_awesome_rounded,
        // Empty until a read answers, so a first frame never flashes a shelf
        // that the next frame removes.
        visible:
            (randomSongs.value?.isNotEmpty ?? false) || randomSongs.hasError,
        trailing: TextButton.icon(
          onPressed: () => ref.read(randomSongsProvider.notifier).refresh(),
          icon: const Icon(Symbols.shuffle_rounded, size: 18),
          label: Text('exploreShuffle'.tr()),
        ),
        body: () => [
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
      ),
      DashboardSections.friends: DashboardShelf(
        title: 'friendsListeningTitle'.tr(),
        icon: Symbols.group_rounded,
        // Nobody is listening right now: an empty live shelf is a header over
        // nothing, and the friends it would name are the point of the shelf.
        visible: friends.value?.isNotEmpty ?? false,
        body: () => const [SliverToBoxAdapter(child: FriendsListeningRows())],
      ),
      DashboardSections.recentlyAdded: DashboardShelf(
        title: 'exploreRecentlyAdded'.tr(),
        icon: Symbols.new_releases_rounded,
        visible:
            (recentAlbums.value?.isNotEmpty ?? false) || recentAlbums.hasError,
        trailing: TextButton(
          // The collection is the tab beside this one; selecting it is the
          // same move the bottom bar makes.
          onPressed: () => _openLibrary(context),
          child: Text('exploreSeeAll'.tr()),
        ),
        body: () => recentAlbums.when(
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
        ),
      ),
      // The account's own shelves: its curation is what the merged shelves
      // cannot reconstruct (a mix is not a playlist and a station is not a
      // track).
      for (final shelf in curated.value ?? const <LandingShelf>[])
        DashboardSections.curated(shelf.sourceId, shelf.title): DashboardShelf(
          title: shelf.title,
          icon: Symbols.auto_awesome_rounded,
          body: () => [SliverToBoxAdapter(child: SongShelf(songs: shelf.songs))],
        ),
    };

    // The user's order first, then anything they have not seen yet — a
    // curated shelf appears when the account answers it, at the end, rather
    // than rearranging the page under them. Pins are sections too, so they
    // take their place in that one order instead of being appended below.
    final ordered = <String>[
      for (final key in layout.order)
        if (available.containsKey(key) || layout.pins.containsKey(key)) key,
    ];
    for (final key in available.keys) {
      if (!ordered.contains(key)) ordered.add(key);
    }

    // Removed shelves stay removed; a pin is removed by removing the pin, not
    // by hiding its key, so it is drawn from the pin map instead.
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
                        onPressed: () => showDashboardCustomize(
                          context,
                          ref,
                          available,
                        ),
                        icon: const Icon(Symbols.tune_rounded),
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
                      trailing: shelf.trailing,
                      builder: shelf.body,
                    )
                else if (layout.pins[key] case final pin?)
                  FoldableSection(
                    page: _page,
                    id: pin.key,
                    title: pin.title,
                    builder: () => [
                      SliverToBoxAdapter(child: PinnedPlaylistShelf(pin: pin)),
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

/// The customize sheet: the page's sections in the user's order, each with
/// the two moves that make a dashboard personal — take it off the page, and
/// move it up or down — plus the two ways to add one (a shelf the page offers
/// again, and a playlist pinned as a section of its own).
///
/// A sheet rather than a settings page: the changes are visible on the page
/// behind it as they are made, and closing it shows the result.
void showDashboardCustomize(
  BuildContext context,
  WidgetRef ref,
  Map<String, DashboardShelf> available,
) {
  final layout = ref.read(dashboardLayoutProvider);

  // The order the sheet starts from is the order the page shows: the user's
  // saved order, with shelves they have not seen yet at the end.
  final ordered = <String>[
    for (final key in layout.order)
      if (available.containsKey(key)) key,
  ];
  for (final key in available.keys) {
    if (!ordered.contains(key)) ordered.add(key);
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => DashboardCustomizeSheet(
      available: available,
      initialOrder: ordered,
    ),
  );
}
