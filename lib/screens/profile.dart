import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/solarpass/models.dart';
import 'package:groovy_box/solarpass/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/pill_app_bar.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The account, as the fleet sees it and as this device records it.
///
/// Modeled on Solian's profile screen: the identity block up top (avatar,
/// handle, bio, from Solarpass), then taste — what the account keeps coming
/// back to, aggregated by Pulsar across every device — then the on-device
/// listening story the old stats page carried, which survives a server
/// change and answers to no account.
///
/// Signed out, the identity block is a sign-in prompt and the taste section
/// is silent; the local stats still fill the page.
@RoutePage()
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(solarpassAccountProvider);
    // Select the identity, not the state: watching the whole transport would
    // rebuild this page on every position tick, once a second.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(listeningStatsProvider);
          ref.invalidate(pulsarTasteProvider);
          if (account.value != null) {
            ref.read(solarpassAccountProvider.notifier).refresh();
          }
        },
        child: ContentFrame(
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomInset),
            children: [
              PillHeader(
                title: 'profileTitle'.tr(),
                subtitle: 'profileSubtitle'.tr(),
                actions: [
                  IconButton(
                    tooltip: 'commonRefresh'.tr(),
                    onPressed: () {
                      ref.invalidate(listeningStatsProvider);
                      ref.invalidate(pulsarTasteProvider);
                    },
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                ],
              ),
              _Identity(account: account),
              // Taste is account-scoped, so it sits under the identity: the
              // windows switch together, and a signed-out page has neither.
              ..._taste(context, ref),
              _DeviceStory(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _taste(BuildContext context, WidgetRef ref) {
    // A signed-out account has no fleet-side taste: the section folds away
    // entirely rather than showing a spinner that can never resolve, since
    // the provider stays empty without a session.
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    if (!signedIn) return const [];
    final window = ref.watch(tasteWindowProvider);
    final taste = ref.watch(pulsarTasteProvider(window));
    return [
      SectionLabel(
        'profileTasteTitle'.tr(),
        trailing: _WindowSwitch(window: window),
      ),
      ...switch (taste) {
        AsyncValue(value: final PulsarMediaStats stats?) => [
          _TasteBody(stats: stats),
        ],
        AsyncValue(hasError: true) => [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SolSpace.xxl),
            child: Text(
              'profileTasteError'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        _ => const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: SolSpace.lg),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ],
      },
    ];
  }
}

/// Which stretch of time the taste summary covers. Tab-local taste: nothing
/// else reads it, and it resets when the page is rebuilt fresh.
class TasteWindowState extends Notifier<TasteWindow> {
  @override
  TasteWindow build() => TasteWindow.all;

  void set(TasteWindow value) => state = value;
}

final tasteWindowProvider = NotifierProvider<TasteWindowState, TasteWindow>(
  TasteWindowState.new,
);

/// How far back the taste summary reaches, as chips: all time, a year, a
/// month. Short spans make the ranking answer "what have I been into lately"
/// instead of repeating the all-time answer.
class _WindowSwitch extends ConsumerWidget {
  final TasteWindow window;

  const _WindowSwitch({required this.window});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<TasteWindow>(
      segments: [
        ButtonSegment(
          value: TasteWindow.all,
          label: Text('tasteWindowAll'.tr()),
        ),
        ButtonSegment(
          value: TasteWindow.year,
          label: Text('tasteWindowYear'.tr()),
        ),
        ButtonSegment(
          value: TasteWindow.month,
          label: Text('tasteWindowMonth'.tr()),
        ),
      ],
      selected: {window},
      onSelectionChanged: (selection) {
        ref.read(tasteWindowProvider.notifier).set(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// The identity block: avatar, handle, bio. Solian leads with the same three,
/// minus the header image this app has no use for.
class _Identity extends StatelessWidget {
  final AsyncValue<SolarpassAccount?> account;

  const _Identity({required this.account});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.md,
        SolSpace.xxl,
        SolSpace.sm,
      ),
      child: switch (account) {
        AsyncValue(:final value?) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: SolSpace.lg,
          children: [
            _Avatar(avatarUrl: value.avatarUrl, name: value.displayName),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${value.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (value.bio != null && value.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: SolSpace.xs),
                    Text(
                      value.bio!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        AsyncValue(hasError: true) => Text(
          'profileAccountError'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        _ => const Row(
          spacing: SolSpace.lg,
          children: [
            _Avatar(name: '?'),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: SolSpace.xs,
                children: [
                  // Static skeleton bars, not progress indicators: the
                  // account fetch either lands or fails, and a pulse that
                  // never stops reads as a hung page.
                  _SkeletonBar(width: 120, height: 18),
                  _SkeletonBar(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
      },
    );
  }
}

/// A static placeholder bar for the identity block while the account loads.
class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;

  const _Avatar({this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return ClipOval(
      child: Container(
        width: 64,
        height: 64,
        color: scheme.primaryContainer,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The taste summary: headline numbers, then top tracks and top creators as
/// the server ranked them. This is the fleet-wide answer; the device's own
/// story follows below.
class _TasteBody extends StatelessWidget {
  final PulsarMediaStats stats;

  const _TasteBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stats.totalScrobbles == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: SolSpace.xxl),
        child: Text(
          'profileTasteEmpty'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TasteTile(
                  icon: Symbols.play_arrow_rounded,
                  value: '${stats.totalScrobbles}',
                  label: 'statsLabelPlays'.plural(stats.totalScrobbles),
                ),
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: _TasteTile(
                  icon: Symbols.timer_rounded,
                  value: formatListeningTime(
                    Duration(seconds: stats.totalSeconds),
                  ),
                  label: 'statsLabelListened'.tr(),
                ),
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: _TasteTile(
                  icon: Symbols.event_available_rounded,
                  value: '${stats.daysActive}',
                  label: 'profileDaysActive'.plural(stats.daysActive),
                ),
              ),
            ],
          ),
        ),
        if (stats.topItems.isNotEmpty) ...[
          const SizedBox(height: SolSpace.md),
          IslandCard(
            margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
            padding: const EdgeInsets.symmetric(vertical: SolSpace.sm),
            child: Column(
              children: [
                for (var i = 0; i < stats.topItems.length; i++)
                  _RankRow(
                    rank: i + 1,
                    name: stats.topItems[i].name,
                    subtitle: stats.topItems[i].subtitle,
                    trailing:
                        '${formatPlayCount(stats.topItems[i].count)}  ·  '
                        '${formatListeningTime(Duration(seconds: stats.topItems[i].seconds))}',
                  ),
              ],
            ),
          ),
        ],
        if (stats.topCreators.isNotEmpty) ...[
          const SizedBox(height: SolSpace.sm),
          IslandCard(
            margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
            padding: const EdgeInsets.symmetric(vertical: SolSpace.sm),
            child: Column(
              children: [
                for (var i = 0; i < stats.topCreators.length; i++)
                  _RankRow(
                    rank: i + 1,
                    name: stats.topCreators[i].name,
                    trailing: formatPlayCount(stats.topCreators[i].count),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TasteTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _TasteTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: SolSpace.sm),
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
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One ranked row of the taste lists: rank, name, optional artist under it.
class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String? subtitle;
  final String trailing;

  const _RankRow({
    required this.rank,
    required this.name,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                color: theme.colorScheme.onSurfaceVariant,
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            trailing,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The device's own listening story — the old stats page, folded in under
/// the account sections. It keeps the local-first guarantees: counted from
/// this device's play history, surviving a server change.
class _DeviceStory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(listeningStatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.from(switch (stats) {
        AsyncValue(:final value?) => _deviceBody(context, ref, value),
        AsyncValue(hasError: true) => [
          SectionLabel('profileDeviceTitle'.tr()),
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
        _ => const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: SolSpace.huge),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ],
      }),
    );
  }

  List<Widget> _deviceBody(
    BuildContext context,
    WidgetRef ref,
    ListeningStats stats,
  ) {
    if (stats.isEmpty && stats.libraryTracks == 0) {
      return [
        SectionLabel('profileDeviceTitle'.tr()),
        EmptyState(
          icon: Symbols.query_stats_rounded,
          title: 'statsEmptyTitle'.tr(),
          message: 'statsEmptyMessage'.tr(),
        ),
      ];
    }
    return [
      SectionLabel('profileDeviceTitle'.tr()),
      _DeviceTotals(stats: stats),
      if (stats.topTracks.isNotEmpty) ...[
        SectionLabel('statsMostPlayed'.tr()),
        _DeviceTopTracks(tracks: stats.topTracks),
      ],
      if (stats.recent.isNotEmpty) ...[
        SectionLabel('statsRecentlyPlayed'.tr()),
        _DeviceRecent(plays: stats.recent),
      ],
    ];
  }
}

/// The headline numbers of the device's own history: plays, time listened,
/// distinct songs.
class _DeviceTotals extends StatelessWidget {
  final ListeningStats stats;

  const _DeviceTotals({required this.stats});

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TasteTile(
                  icon: Symbols.play_arrow_rounded,
                  value: '${stats.plays}',
                  label: 'statsLabelPlays'.plural(stats.plays),
                ),
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: _TasteTile(
                  icon: Symbols.timer_rounded,
                  value: formatListeningTime(stats.listened),
                  label: 'statsLabelListened'.tr(),
                ),
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: _TasteTile(
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

/// How many plays ran to the end, and how much of the library has been heard.
class _CompletionLine extends StatelessWidget {
  final ListeningStats stats;

  const _CompletionLine({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      if (stats.orphaned > 0) 'statsOrphaned'.tr(args: ['${stats.orphaned}']),
    ];
    return Text(
      parts.join('  ·  '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }
}

/// The tracks played most often on this device, with how often and for how
/// long.
class _DeviceTopTracks extends ConsumerWidget {
  final List<TopTrack> tracks;

  const _DeviceTopTracks({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackProvider.notifier);
    final currentKey = ref.watch(
      playbackProvider.select((state) {
        final song = state.current;
        return song == null ? null : (song.sourceId, song.id);
      }),
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
            trailing:
                '${formatPlayCount(entry.plays)}  ·  '
                '${formatListeningTime(entry.listened)}',
            selected:
                currentKey != null &&
                currentKey.$1 == entry.link?.sourceId &&
                currentKey.$2 == entry.link?.externalId,
            onTap: entry.song == null
                ? null
                : () => controller.playQueue([entry.song!]),
          ),
      ],
    );
  }
}

/// The last tracks played on this device, newest first.
class _DeviceRecent extends ConsumerWidget {
  final List<RecentPlay> plays;

  const _DeviceRecent({required this.plays});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackProvider.notifier);
    final currentKey = ref.watch(
      playbackProvider.select((state) {
        final song = state.current;
        return song == null ? null : (song.sourceId, song.id);
      }),
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
                currentKey != null &&
                currentKey.$1 == entry.link?.sourceId &&
                currentKey.$2 == entry.link?.externalId,
            onTap: entry.song == null
                ? null
                : () => controller.playQueue([entry.song!]),
          ),
      ],
    );
  }
}
