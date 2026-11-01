import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// What the local play history adds up to: how much has been listened to,
/// what keeps coming back, and what played last.
///
/// Everything here comes from `play_events` in the on-device library, so it
/// describes *this* device and survives a library being swapped: removing a
/// source drops its links, not its plays.
///
/// The page is a summary, not a report: headline numbers, then the top ten of
/// two things and the last dozen plays. Anything longer is a list, and the
/// lists that matter already exist elsewhere.
@RoutePage()
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(listeningStatsProvider);
    // Select the identity, not the state: watching the whole transport would
    // rebuild this page on every position tick, once a second.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(listeningStatsProvider),
        child: ContentFrame(
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomInset),
            children: [
              PageHeader(
                showRailToggle: true,
                title: 'statsTitle'.tr(),
                subtitle: 'statsSubtitle'.tr(),
                actions: [
                  IconButton(
                    tooltip: 'commonRefresh'.tr(),
                    onPressed: () => ref.invalidate(listeningStatsProvider),
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                  const SizedBox(width: SolSpace.sm),
                ],
              ),
              ...switch (stats) {
                AsyncValue(:final value?) => _body(context, ref, value, theme),
                AsyncValue(hasError: true) => [
                  EmptyState(
                    icon: Symbols.bar_chart_rounded,
                    title: 'statsErrorTitle'.tr(),
                    message: 'statsErrorMessage'.tr(),
                    action: TextButton.icon(
                      onPressed: () => ref.invalidate(listeningStatsProvider),
                      icon: const Icon(Symbols.refresh_rounded),
                      label: Text('commonTryAgain'.tr()),
                    ),
                  ),
                ],
                _ => [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: SolSpace.huge),
                    child: Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    ListeningStats stats,
    ThemeData theme,
  ) {
    if (stats.isEmpty && stats.libraryTracks == 0) {
      return [
        EmptyState(
          icon: Symbols.query_stats_rounded,
          title: 'statsEmptyTitle'.tr(),
          message: 'statsEmptyMessage'.tr(),
        ),
      ];
    }

    return [
      _Totals(stats: stats),
      if (stats.topTracks.isNotEmpty) ...[
        SectionLabel('statsMostPlayed'.tr()),
        _TopTracks(tracks: stats.topTracks),
      ],
      if (stats.topArtists.isNotEmpty) ...[
        SectionLabel('statsArtists'.tr()),
        _TopArtists(artists: stats.topArtists),
      ],
      if (stats.recent.isNotEmpty) ...[
        SectionLabel('statsRecentlyPlayed'.tr()),
        _RecentPlays(plays: stats.recent),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(
          SolSpace.xxl,
          SolSpace.xl,
          SolSpace.xxl,
          SolSpace.xl,
        ),
        child: Text(
          'statsFooter'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ),
    ];
  }
}

/// The headline numbers: plays, time listened, songs, and how many of them
/// reached the end.
class _Totals extends StatelessWidget {
  final ListeningStats stats;

  const _Totals({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            // Not `stretch`: the row sits in a scrolling column, so its height
            // is unbounded and stretching would ask the tiles to fill infinity.
            // The three tiles share a shape, so their labels already line up.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TotalTile(
                  icon: Symbols.play_arrow_rounded,
                  value: '${stats.plays}',
                  label: 'statsLabelPlays'.plural(stats.plays),
                ),
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: _TotalTile(
                  icon: Symbols.timer_rounded,
                  value: formatListeningTime(stats.listened),
                  label: 'statsLabelListened'.tr(),
                ),
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: _TotalTile(
                  icon: Symbols.library_music_rounded,
                  value: '${stats.distinctTracks}',
                  label: 'statsLabelSongs'.plural(stats.distinctTracks),
                ),
              ),
            ],
          ),
          const SizedBox(height: SolSpace.md),
          _CompletionLine(stats: stats),
        ],
      ),
    );
  }
}

/// One number with its unit. No card of its own: the row of three is one
/// object, and three tonal rectangles side by side read as three objects.
class _TotalTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _TotalTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(height: SolSpace.sm),
        // Scaled down rather than wrapped: "12 h 40 min" is one number, and
        // breaking it across two lines makes the row's heights disagree.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// How many plays ran to the end, and how much of the library has been heard.
///
/// Stated as a sentence rather than a percentage: a completion rate is not a
/// score, and "you skipped 40%" is not something this page needs to say.
class _CompletionLine extends StatelessWidget {
  final ListeningStats stats;

  const _CompletionLine({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parts = <String>[
      'statsCompletionPlays'.plural(
        stats.plays,
        args: ['${stats.completedPlays}', '${stats.plays}'],
      ),
      if (stats.libraryTracks > 0)
        'statsCompletionLibrary'.plural(
          stats.libraryTracks,
          args: ['${stats.distinctTracks}', '${stats.libraryTracks}'],
        ),
      if (stats.orphaned > 0)
        'statsOrphaned'.tr(args: ['${stats.orphaned}']),
    ];

    return Text(
      parts.join('  ·  '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }
}

/// The tracks played most often, with how often and for how long.
class _TopTracks extends ConsumerWidget {
  final List<TopTrack> tracks;

  const _TopTracks({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackProvider.notifier);

    final current = ref.watch(
      playbackProvider.select((state) => state.current),
    );

    return Column(
      children: [
        for (final entry in tracks)
          TrackRow(
            title: entry.track.title,
            subtitle: entry.track.artist ?? 'commonUnknownArtist'.tr(),
            artwork: LibraryArtwork(
              sourceId: entry.link?.sourceId,
              artId: entry.link?.artId,
              size: 44,
              radius: SolRadius.xs,
            ),
            // Time as well as count: three plays of a two-minute song and
            // three of a nine-minute one are not the same habit, and a bare
            // play count cannot tell them apart.
            trailing:
                '${formatPlayCount(entry.plays)}  ·  '
                '${formatListeningTime(entry.listened)}',
            selected:
                current?.sourceId == entry.link?.sourceId &&
                current?.id == entry.link?.externalId,
            onTap: entry.song == null
                ? null
                : () => controller.playQueue([entry.song!]),
          ),
      ],
    );
  }
}

/// The artists behind the most plays.
///
/// No artwork: the library stores art for tracks, not for artists, and a row
/// of identical fallback tiles would say less than the rank does.
class _TopArtists extends StatelessWidget {
  final List<TopArtist> artists;

  const _TopArtists({required this.artists});

  @override
  Widget build(BuildContext context) {
    return IslandCard(
      margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
      padding: const EdgeInsets.symmetric(vertical: SolSpace.sm),
      child: Column(
        children: [
          for (var i = 0; i < artists.length; i++)
            _ArtistRow(rank: i + 1, artist: artists[i]),
        ],
      ),
    );
  }
}

class _ArtistRow extends StatelessWidget {
  final int rank;
  final TopArtist artist;

  const _ArtistRow({required this.rank, required this.artist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SolSpace.lg,
        vertical: SolSpace.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: SolSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${formatPlayCount(artist.plays)}  ·  '
                  '${formatListeningTime(artist.listened)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The last dozen tracks played, newest first.
class _RecentPlays extends ConsumerWidget {
  final List<RecentPlay> plays;

  const _RecentPlays({required this.plays});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackProvider.notifier);
    final current = ref.watch(
      playbackProvider.select((state) => state.current),
    );

    return Column(
      children: [
        for (final entry in plays)
          TrackRow(
            title: entry.track.title,
            subtitle: entry.track.artist ?? 'commonUnknownArtist'.tr(),
            artwork: LibraryArtwork(
              sourceId: entry.link?.sourceId,
              artId: entry.link?.artId,
              size: 44,
              radius: SolRadius.xs,
            ),
            trailing: formatRelativeTime(entry.playedAt),
            selected:
                current?.sourceId == entry.link?.sourceId &&
                current?.id == entry.link?.externalId,
            onTap: entry.song == null
                ? null
                : () => controller.playQueue([entry.song!]),
          ),
      ],
    );
  }
}
