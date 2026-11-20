import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
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

    return albums.when(
      data: (list) => _Body(
        sourceId: sourceId,
        artistId: artistId,
        name: artistName,
        albums: list,
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

  const _Body({
    required this.sourceId,
    required this.artistId,
    required this.name,
    required this.albums,
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
    // The artist's own picture, as the library that listed them draws it on
    // its card. Read from the list the page was opened from rather than
    // asked for again: it is already in memory, and a source that carries a
    // portrait here is the one case the fleet cannot answer for.
    final artId = ref
        .watch(libraryArtistsProvider)
        .value
        ?.where(
          (candidate) =>
              candidate.sourceId == widget.sourceId &&
              candidate.id == widget.artistId,
        )
        .firstOrNull
        ?.artId;
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
          child: PageScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: BackButtonRow(onBack: () => context.router.maybePop()),
              ),
              SliverToBoxAdapter(
                child: CollectionHero(
                  sourceId: widget.sourceId,
                  // The act's own portrait, never the first album's cover:
                  // a sleeve is a record's face, and the artist page used to
                  // open showing one of theirs as if it were a likeness. The
                  // library's artist art is the fallback below, and the
                  // fleet's portrait replaces it when there is one.
                  artId: artId,
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
                    // A fleet record is looked up by title and credit; the
                    // name is what every connected library spells the act by.
                    artist: artist,
                  ),
                ),
              // Last: what the account holds beyond this device's libraries
              // is a footnote to the artist, not a second discography.
              if (artist != null)
                SliverToBoxAdapter(child: _FleetSection(name: artist)),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
/// rest exist — a year, a title, a cover — and each tile can be opened when
/// the record turns out to be reachable somewhere: another connected library
/// or a store, found by [discoveredAlbumProvider] when the tile is tapped. A
/// record nobody can play says so in place instead of opening an empty page.
class _Discography extends StatelessWidget {
  final List<PulsarAlbumSummary> albums;
  final Set<String> known;
  final int total;
  final String? artist;

  const _Discography({
    required this.albums,
    required this.known,
    required this.total,
    this.artist,
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
                _DiscographyTile(album: missing[index], artist: artist),
          ),
        ),
      ],
    );
  }
}

/// One record the fleet knows and the libraries here do not: cover, title,
/// year, and a way in when the record can be found.
///
/// Tapping asks [discoveredAlbumProvider] where the record actually lives —
/// the connected libraries first, a store second — and opens its album page
/// from the answer. The lookup is on demand rather than on build because a
/// discography is a list of records, and asking every library about all of
/// them would cost the page its first paint for a question the reader may
/// never ask.
class _DiscographyTile extends ConsumerStatefulWidget {
  final PulsarAlbumSummary album;
  final String? artist;

  const _DiscographyTile({required this.album, this.artist});

  @override
  ConsumerState<_DiscographyTile> createState() => _DiscographyTileState();
}

class _DiscographyTileState extends ConsumerState<_DiscographyTile> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final album = await ref.read(
        discoveredAlbumProvider((
          title: widget.album.title,
          artist: widget.artist,
        )).future,
      );
      if (!mounted) return;
      if (album == null) {
        messenger?.showSnackBar(
          SnackBar(content: Text('artistsRecordUnavailable'.tr())),
        );
        return;
      }
      context.router.push(
        AlbumDetailRoute(
          sourceId: album.sourceId,
          albumId: album.id,
          albumName: album.name,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final album = widget.album;
    final art = album.artworkUrl;
    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: _open,
        borderRadius: SolRadius.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SolRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (art == null)
                        ColoredBox(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Symbols.album,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Image.network(
                          art,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Icon(
                              Symbols.album,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      // The lookup is a request per tile; while it runs the
                      // cover says so instead of the row going dead.
                      if (_opening)
                        ColoredBox(
                          color: theme.colorScheme.scrim.withValues(
                            alpha: 0.35,
                          ),
                          child: const Center(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            ),
                          ),
                        ),
                    ],
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
      ),
    );
  }
}
