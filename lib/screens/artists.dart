import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/metadata.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/widgets/section.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/entity_metadata.dart';
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

  /// The name the fleet is asked about. A library may spell an artist one
  /// way and MusicBrainz canonically another; the fleet resolves the name and
  /// caches the answer, so the page asks with what the library gave it.
  String? get _name => widget.name ?? _artistOf(widget.albums);

  static String? _artistOf(List<LibraryAlbum> albums) =>
      albums.map((album) => album.artist).whereType<String>().firstOrNull;

  @override
  Widget build(BuildContext context) {
    final albums = widget.albums;
    final fallback = widget.name ?? 'artistsDetailTitleFallback'.tr();
    final artist = _name;
    // The fleet's record for this act. Watched by name, so a page opened for
    // a different artist asks again; a failure answers null and the page
    // keeps everything its own libraries already gave it.
    final profileState = artist == null
        ? const AsyncValue<PulsarEntityMetadata?>.data(null)
        : ref.watch(
            pulsarArtistProfileProvider(
              artist,
              language: Localizations.localeOf(context).languageCode,
            ),
          );
    final profile = profileState.value;
    final topTracks = _topTracks ?? const <LibrarySong>[];
    if (_topTracks == null && albums.isNotEmpty) {
      ref
          .read(
            // The same fallback the album page uses: a cloud account's first
            // album often answers with no tracks, and the top tracks are the
            // one part of this page that would then be missing.
            albumTracksProvider((
              album: (sourceId: albums.first.sourceId, id: albums.first.id),
              title: albums.first.name,
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
              SliverToBoxAdapter(
                child: BackButtonRow(onBack: () => context.router.maybePop()),
              ),
              SliverToBoxAdapter(
                child: CollectionHero(
                  sourceId: widget.sourceId,
                  artId: albums
                      .map((a) => a.artId)
                      .whereType<String>()
                      .firstOrNull,
                  // The fleet's portrait wins when the library has none: a
                  // source that lists an artist often has no picture of them,
                  // and an artist page that opens as a generic person is the
                  // one thing this page can plainly fix.
                  artworkUrl: profile?.artworkUrl ?? profile?.imageUrl,
                  title:
                      artist ??
                      widget.name ??
                      'artistsDetailTitleFallback'.tr(),
                  eyebrow: 'artistsEyebrow'.tr(),
                  fallbackIcon: Symbols.artist,
                  // What the act is, from the fleet: "group · United
                  // Kingdom" reads as a description, and the library's own
                  // name for the artist is already above it.
                  meta: [
                    if (profile?.subtitle != null &&
                        profile!.subtitle!.isNotEmpty)
                      profile.subtitle!
                    else
                      artist ?? fallback,
                    if (profile?.lifespan != null) profile!.lifespan!,
                  ].join('  ·  '),
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
              if (profile != null)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EntityFacts(metadata: profile),
                      EntityProse(metadata: profile),
                      // Under the prose, where the reader who wants more has
                      // just finished reading: a link row after the page's
                      // record lengths hangs off the last tile instead of
                      // belonging to anything.
                      EntityLinks(metadata: profile),
                    ],
                  ),
                )
              else if (profileState.isLoading && albums.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SolSpace.xxl,
                      SolSpace.sm,
                      SolSpace.xxl,
                      SolSpace.sm,
                    ),
                    child: Text(
                      'artistsBioLoading'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                    child: SectionHeader(title: 'artistsTopTracks'.tr()),
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
                    child: SectionHeader(
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

              if (profile != null && profile.albums.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Discography(
                    albums: profile.albums,
                    // What the artist page already lists, by title: the
                    // fleet's discography is a completion, not a second copy.
                    known: albums.map((album) => album.name).toSet(),
                    total: profile.releaseGroupCount,
                  ),
                ),
              // Last: what the account holds beyond this device's libraries
              // is a footnote to the artist, not a second discography.
              if (artist != null)
                SliverToBoxAdapter(child: _FleetSection(name: artist)),
              SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset)),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the fleet holds for this artist that this device cannot see: the
/// catalog entries the app pushed from every signed-in device.
///
/// Matched by the artist's display name in the music domain — Pulsar has no
/// id the device's libraries share, and a name is exactly what the fleet
/// dedupes on per domain. Only rows the app itself wrote are listed: the
/// fleet also stores the MusicBrainz entities it resolved (the artist record
/// credits the artist to themselves), and those are a second copy of the
/// page rather than something the account holds. Everything here is additive:
/// a miss, a sign-out or an unreachable fleet leaves the page as the device's
/// own libraries drew it, never an error row.
class _FleetSection extends ConsumerWidget {
  final String name;

  const _FleetSection({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    if (!signedIn) return const SizedBox.shrink();
    final metadata = ref.watch(pulsarArtistMetadataProvider(name));
    return metadata.when(
      data: (metadata) {
        final pushed = [
          for (final item in metadata?.catalog ?? const <CatalogItem>[])
            if (item.provider == pulsarProviderKey) item,
        ];
        if (pushed.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: SolSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'artistsFleetHeader'.tr()),
              for (final item in pushed)
                ListTile(
                  leading: item.artworkUrl == null
                      ? null
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(SolRadius.sm),
                          child: Image.network(
                            item.artworkUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 44, height: 44),
                          ),
                        ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // The album, not the artist: this page is about the artist,
                  // and the row is here to say which record the track is on.
                  subtitle: item.caption == null
                      ? null
                      : Text(
                          item.caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: item.durationSeconds == null
                      ? null
                      : Text(
                          formatDuration(
                            Duration(seconds: item.durationSeconds!),
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                ),
            ],
          ),
        );
      },
      // A fleet that is slow or down must not blank the artist page: the
      // section simply stays out, and the page keeps its own libraries' body.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// The artist's records as the fleet knows them, completed against what this
/// device's libraries already list.
///
/// The point is the gap: a server holding two of an artist's nine albums
/// leaves the page looking like the artist made two. This section says the
/// rest exist — a year, a title, a cover — without pretending any of them can
/// be played from here, which is the difference between a discography and a
/// library.
class _Discography extends StatelessWidget {
  final List<PulsarAlbumSummary> albums;
  final Set<String> known;
  final int total;

  const _Discography({
    required this.albums,
    required this.known,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = albums
        .where(
          (album) => !known.any(
            (title) => title.toLowerCase() == album.title.toLowerCase(),
          ),
        )
        .toList();
    if (missing.isEmpty) return const SizedBox.shrink();
    final count = total > albums.length ? total : albums.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'artistsDiscography'.tr(),
          trailing: Text(
            'artistsDiscographyCount'.plural(count),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
            itemCount: missing.length,
            separatorBuilder: (_, _) => const SizedBox(width: SolSpace.md),
            itemBuilder: (context, index) =>
                _DiscographyTile(album: missing[index]),
          ),
        ),
      ],
    );
  }
}

/// One fleet-only record: cover, title, year. Not tappable — this device has
/// nothing to open, and a tile that leads to an empty page is worse than one
/// that plainly says "not here".
class _DiscographyTile extends StatelessWidget {
  final PulsarAlbumSummary album;

  const _DiscographyTile({required this.album});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SolRadius.md),
                child: album.artworkUrl == null
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Symbols.album,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Image.network(
                        album.artworkUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Symbols.album,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: SolSpace.sm),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            [
              if (album.year != null) '${album.year}',
              if (album.type != null) album.type!.toLowerCase(),
            ].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
