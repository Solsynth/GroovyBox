import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/screens/explore.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/pill_app_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One artist, as every source that carries them describes them.
///
/// The page is addressed by [LibraryRef]: an artist id is native to its own
/// library, so there is no merged artist — only a merged list of artists, and
/// this page reads the one the row was tapped on. What the source says the
/// person recorded is what shows here; nothing is matched across sources by
/// name, because two libraries spelling a name the same way is a guess this
/// page has no business making.
///
/// Top tracks are the first album's songs in record order, capped: a track
/// listing the source does not provide is invented rather than asked for.
@RoutePage()
class ArtistDetailScreen extends ConsumerWidget {
  /// Which library the artist belongs to; artists are only unique per source.
  final String sourceId;
  final String artistId;
  final String? artistName;

  const ArtistDetailScreen({
    super.key,
    @PathParam('sourceId') required this.sourceId,
    @PathParam('artistId') required this.artistId,
    this.artistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(
      artistAlbumsProvider((sourceId: sourceId, id: artistId)),
    );
    // One boolean, not the transport: a position tick must not rebuild a
    // page of album cards.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return albums.when(
      data: (list) => _Body(
        sourceId: sourceId,
        artistId: artistId,
        name: artistName,
        albums: list,
        bottomInset: bottomInset,
      ),
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: ContentFrame(
          child: EmptyState(
            icon: Symbols.error_rounded,
            title: 'artistsDetailLoadError'.tr(),
            message: describeServerError(error),
            iconColor: Theme.of(context).colorScheme.error,
            action: FilledButton(
              onPressed: () => ref.invalidate(
                artistAlbumsProvider((sourceId: sourceId, id: artistId)),
              ),
              child: Text('commonTryAgain'.tr()),
            ),
          ),
        ),
      ),
    );
  }
}

/// The artist page's body: hero, top tracks, albums.
class _Body extends ConsumerStatefulWidget {
  final String sourceId;
  final String artistId;
  final String? name;
  final List<LibraryAlbum> albums;
  final double bottomInset;

  const _Body({
    required this.sourceId,
    required this.artistId,
    required this.name,
    required this.albums,
    required this.bottomInset,
  });

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  /// Songs of the first album that answered, as the page's top tracks.
  ///
  /// Held once loaded: a rebuild on every hero redraw must not re-ask the
  /// network for a list it already has.
  List<LibrarySong>? _topTracks;

  @override
  Widget build(BuildContext context) {
    final albums = widget.albums;
    final fallback = widget.name ?? 'artistsDetailTitleFallback'.tr();
    final artist = albums
        .map((album) => album.artist)
        .whereType<String>()
        .firstOrNull;
    final topTracks = _topTracks ?? const <LibrarySong>[];
    if (_topTracks == null && albums.isNotEmpty) {
      ref
          .read(
            albumSongsProvider((
              sourceId: albums.first.sourceId,
              id: albums.first.id,
            )).future,
          )
          .then((songs) {
            if (mounted) setState(() => _topTracks = songs.take(5).toList());
          });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.read(libraryArtistsProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              SliverPillHeader(
                title: fallback,
                leading: HeaderBackButton(
                  onPressed: () => context.router.maybePop(),
                ),
              ),
              SliverToBoxAdapter(
                child: CollectionHero(
                  sourceId: widget.sourceId,
                  artId: albums
                      .map((a) => a.artId)
                      .whereType<String>()
                      .firstOrNull,
                  eyebrow: 'artistsEyebrow'.tr(),
                  fallbackIcon: Symbols.artist,
                  meta: artist ?? fallback,
                  actions: [
                    if (topTracks.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(playbackProvider.notifier)
                            .playQueue(topTracks),
                        icon: const Icon(Symbols.play_arrow_rounded, size: 20),
                        label: Text('artistsPlayTop'.tr()),
                      ),
                    if (topTracks.length > 1)
                      IconButton.filledTonal(
                        tooltip: 'libraryShuffle'.tr(),
                        onPressed: () {
                          final notifier = ref.read(playbackProvider.notifier);
                          notifier.playQueue(topTracks);
                          notifier.setShuffle(true);
                        },
                        icon: const Icon(Symbols.shuffle_rounded),
                      ),
                  ],
                ),
              ),
              if (albums.isEmpty && topTracks.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    compact: true,
                    icon: Symbols.artist,
                    title: 'artistsDetailEmptyTitle'.tr(),
                    message: 'artistsDetailEmptyMessage'.tr(),
                  ),
                )
              else ...[
                if (topTracks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: LibrarySectionHeader(title: 'artistsTopTracks'.tr()),
                  ),
                if (topTracks.isNotEmpty)
                  SliverList.builder(
                    itemCount: topTracks.length,
                    itemBuilder: (context, index) {
                      final song = topTracks[index];
                      return SongTrackRow(
                        song: song,
                        subtitle: song.album ?? 'commonUnknownArtist'.tr(),
                        leading: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        trailing: formatDuration(song.duration),
                        onTap: () => ref
                            .read(playbackProvider.notifier)
                            .playQueue(topTracks, startIndex: index),
                      );
                    },
                  ),
                if (albums.isNotEmpty)
                  SliverToBoxAdapter(
                    child: LibrarySectionHeader(
                      title: 'artistsAlbums'.plural(albums.length),
                    ),
                  ),
                if (albums.isNotEmpty)
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
                      itemCount: albums.length,
                      itemBuilder: (context, index) => AlbumCard(
                        album: albums[index],
                        onTap: () => context.router.push(
                          AlbumDetailRoute(
                            sourceId: albums[index].sourceId,
                            albumId: albums[index].id,
                            albumName: albums[index].name,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset)),
            ],
          ),
        ),
      ),
    );
  }
}
