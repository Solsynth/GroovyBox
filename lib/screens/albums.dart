import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/metadata.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_favourite.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/download_actions.dart';
import 'package:groovy_box/widgets/entity_metadata.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/section.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Shared album cover card, used by the library grid.
///
/// The cover lifts on hover instead of drawing a border: on a grid of
/// artwork, a hairline around every tile is noise, and motion is the cheapest
/// way to say "this is a target".
class AlbumCard extends StatefulWidget {
  final LibraryAlbum album;
  final VoidCallback onTap;

  const AlbumCard({super.key, required this.album, required this.onTap});

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
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
                      child: LibraryArtwork(
                        sourceId: widget.album.sourceId,
                        artId: widget.album.artId,
                        radius: SolRadius.md,
                        fallbackIcon: Symbols.album,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SolSpace.sm),
              Text(
                widget.album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.album.artist ?? 'commonUnknownArtist'.tr(),
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

/// One album's track list, with a play-all header.
///
/// On a wide window the cover and the actions sit side by side above the
/// tracks instead of stacking in the middle of the page.
@RoutePage()
class AlbumDetailScreen extends ConsumerWidget {
  /// Which library the album belongs to; albums are only unique per source.
  final String sourceId;
  final String albumId;
  final String? albumName;

  const AlbumDetailScreen({
    super.key,
    @PathParam('sourceId') required this.sourceId,
    @PathParam('albumId') required this.albumId,
    this.albumName,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref0 = (sourceId: sourceId, id: albumId);
    // The page's tracklist, from wherever it can be played: this album's own
    // source first, then any other connected library that holds the same
    // record. A cloud account that answers with a store album the user never
    // added is the case the second half exists for — the page then lists the
    // copy the device can actually play instead of saying "empty".
    final tracks = ref.watch(
      albumTracksProvider((album: ref0, title: albumName)),
    );
    // The album itself, apart from its tracks: a store album still has a
    // name, a year and a cover, and the hero needs them even when nothing in
    // the list can be played.
    final info = ref.watch(albumInfoProvider(ref0)).value;
    final firstSong = tracks.value?.firstOrNull;
    final artist = firstSong?.artist ?? info?.artist;
    final title = info?.name ?? albumName ?? firstSong?.album;
    final metadata = title == null
        ? const AsyncValue<PulsarEntityMetadata?>.data(null)
        : ref.watch(
            pulsarAlbumProfileProvider(
              title: title,
              artist: artist,
              language: Localizations.localeOf(context).languageCode,
            ),
          );
    final profile = metadata.value;
    final list = tracks.value ?? const <LibrarySong>[];
    // The fleet's tracklist describes the record; it is not a set of files.
    // It stands in only when this device holds none of the album, because
    // mixing rows that cannot play into a playable list would make "play
    // all" silently skip half the record.
    final fleetTracks = list.isEmpty ? profile?.tracks ?? const [] : const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: PageScrollView(
          slivers: [
            // The way back is the only chrome an album keeps: the hero below
            // names the record, its artist and its year, so a bar repeating
            // one of those three was the page's own name drawn twice.
            SliverToBoxAdapter(
              child: BackButtonRow(onBack: () => context.router.maybePop()),
            ),
            // One hero whether or not the source returned tracks. A record
            // the fleet knows and the library does not is still a record,
            // and a page that opened on "this album is empty" over a title
            // it already knew was saying less than it could.
            SliverToBoxAdapter(
              child: CollectionHero(
                sourceId: sourceId,
                artId: firstSong?.artId ?? info?.artId,
                // The server's own cover wins when it has one; with neither,
                // the fleet's cover, then the hero's fallback icon.
                artworkUrl: (firstSong?.artId ?? info?.artId) == null
                    ? profile?.artworkUrl
                    : null,
                title:
                    albumName ??
                    title ??
                    info?.name ??
                    'albumsDetailTitleFallback'.tr(),
                eyebrow: 'albumsEyebrow'.tr(),
                meta: [
                  artist ?? 'commonUnknownArtist'.tr(),
                  // The fleet knows the release date even when the library's
                  // tags carry no year.
                  if (firstSong?.year != null)
                    '${firstSong!.year}'
                  else if (info?.year != null)
                    '${info!.year}'
                  else if (profile?.releaseDate != null)
                    profile!.releaseDate!.split('-').first,
                  if (profile?.caption != null && profile!.caption!.isNotEmpty)
                    profile.caption!,
                  if (firstSong?.albumArtist != null &&
                      firstSong!.albumArtist != firstSong.artist)
                    firstSong.albumArtist!,
                ].join('  ·  '),
                actions: [
                  if (list.isNotEmpty) ...[
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(playbackProvider.notifier).playQueue(list),
                      icon: const Icon(Symbols.play_arrow_rounded, size: 20),
                      label: Text('albumsPlayAlbum'.tr()),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'libraryShuffle'.tr(),
                      onPressed: () {
                        final notifier = ref.read(playbackProvider.notifier);
                        notifier.playQueue(list);
                        notifier.setShuffle(true);
                      },
                      icon: const Icon(Symbols.shuffle_rounded),
                    ),
                    CollectionDownloadButton(songs: list),
                  ],
                  // The heart is outside the playable guard: a record the
                  // device cannot stream is still one the user may like, and
                  // the account is where that opinion lives.
                  CollectionFavouriteButton(
                    favourite: albumFavourite(
                      info ??
                          LibraryAlbum(
                            sourceId: sourceId,
                            id: albumId,
                            name:
                                albumName ??
                                title ??
                                'albumsDetailTitleFallback'.tr(),
                            duration: Duration.zero,
                            artist: artist,
                            artId: firstSong?.artId,
                            year: firstSong?.year ?? info?.year,
                          ),
                      artworkUrl: (firstSong?.artId ?? info?.artId) == null
                          ? profile?.artworkUrl
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            // The album's description is not part of the tracklist branch:
            // a source that answers with no tracks still has a record to
            // describe, and the page should not go blank where it could say
            // what the album is.
            if (profile != null)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EntityFacts(metadata: profile),
                    EntityProse(metadata: profile, title: 'albumsAbout'.tr()),
                    EntityLinks(metadata: profile),
                  ],
                ),
              ),
            ...tracks.when(
              // Nothing to list and nothing to describe it: the record really
              // is unavailable. When the fleet has the tracklist, that block
              // below says so instead of two contradicting messages.
              data: (_) =>
                  list.isEmpty && fleetTracks.isEmpty && profile == null
                  ? [
                      SliverToBoxAdapter(
                        child: EmptyState(
                          compact: true,
                          icon: Symbols.album,
                          title: 'albumsDetailEmptyTitle'.tr(),
                          message: 'albumsDetailEmptyMessage'.tr(),
                        ),
                      ),
                    ]
                  : [
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final song = list[index];
                          return SongTrackRow(
                            song: song,
                            // An album is a sequence: the number is the
                            // position in the record, which the title does
                            // not carry. The cover would be the same square
                            // twelve times, so the number takes its place.
                            leading: Text(
                              '${song.track ?? index + 1}',
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
                            subtitle: song.artist ?? 'commonUnknownArtist'.tr(),
                            trailing: formatDuration(song.duration),
                            onTap: () => ref
                                .read(playbackProvider.notifier)
                                .playQueue(list, startIndex: index),
                          );
                        },
                      ),
                    ],
              loading: () => const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(SolSpace.huge),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (error, _) => [
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Symbols.error_rounded,
                    title: 'albumsDetailLoadError'.tr(),
                    message: describeServerError(error),
                    iconColor: Theme.of(context).colorScheme.error,
                    action: FilledButton(
                      onPressed: () {
                        ref.invalidate(albumSongsProvider(ref0));
                        ref.invalidate(
                          albumTracksProvider((album: ref0, title: albumName)),
                        );
                      },
                      child: Text('commonTryAgain'.tr()),
                    ),
                  ),
                ),
              ],
            ),
            // What the record holds, from the fleet, when this device can
            // play none of it. Rows are not tappable: nothing here resolves
            // to a stream, and a row that does nothing is worse than one
            // that plainly says "not here".
            if (fleetTracks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(title: 'albumsTracklist'.tr()),
              ),
              SliverList.builder(
                itemCount: fleetTracks.length,
                itemBuilder: (context, index) {
                  final track = fleetTracks[index];
                  return ListTile(
                    leading: Text(
                      '${track.position == 0 ? index + 1 : track.position}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: track.artist == null
                        ? null
                        : Text(
                            track.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: track.length > Duration.zero
                        ? Text(
                            formatDuration(track.length),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          )
                        : null,
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SolSpace.xxl,
                    SolSpace.sm,
                    SolSpace.xxl,
                    SolSpace.md,
                  ),
                  child: Text(
                    'albumsTracklistNotHeld'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
