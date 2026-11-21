import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/solarpass/login_dialog.dart';
import 'package:groovy_box/solarpass/models.dart';
import 'package:groovy_box/solarpass/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(listeningStatsProvider);
          ref.invalidate(pulsarTasteProvider);
          if (account.value != null) {
            ref.read(solarpassAccountProvider.notifier).refresh();
          }
        },
        child: ContentFrame(
          child: PageListView(
            children: [
              // The account block is the page's name: an avatar, a display
              // name and a handle say "this is you" better than the word
              // Profile over them. The refresh action rides at its start,
              // where a header's trailing control used to sit.
              const SizedBox(height: SolSpace.lg),
              _Identity(
                account: account,
                trailing: IconButton(
                  tooltip: 'commonRefresh'.tr(),
                  onPressed: () {
                    ref.invalidate(listeningStatsProvider);
                    ref.invalidate(pulsarTasteProvider);
                    if (account.value != null) {
                      ref.read(solarpassAccountProvider.notifier).refresh();
                    }
                  },
                  icon: const Icon(Symbols.refresh_rounded),
                ),
              ),
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
    final session = ref.watch(pulsarSessionProvider);
    // Signed out has no fleet-side taste, and saying so beats an empty title:
    // the provider answers null forever without a session, so a section that
    // waited would wait for the lifetime of the app.
    if (session.hasValue && session.value == null) return const [];
    final window = ref.watch(tasteWindowProvider);
    final taste = ref.watch(pulsarTasteProvider(window));
    return [
      SectionLabel(
        'profileTasteTitle'.tr(),
        trailing: _WindowSwitch(window: window),
      ),
      ...switch (taste) {
        AsyncValue(value: final PulsarMediaStats stats?) => [
          _TasteBody(
            stats: stats,
            scrobbling: ref.watch(
              solarpassConfigProvider.select(
                (config) => config.scrobbleEnabled,
              ),
            ),
          ),
        ],
        AsyncValue(hasError: true) => [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SolSpace.xxl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'profileTasteError'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(pulsarTasteProvider(window)),
                  child: Text('commonTryAgain'.tr()),
                ),
              ],
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
///
/// It is also the page's opening: a tab root has no bar to carry the account,
/// so the account itself is what the page starts with, and [trailing] holds
/// the one page-level action at the far end of that row.
class _Identity extends StatelessWidget {
  final AsyncValue<SolarpassAccount?> account;
  final Widget? trailing;

  const _Identity({required this.account, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.md,
        SolSpace.md,
        SolSpace.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _body(context, theme)),
          ?trailing,
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData theme) {
    return switch (account) {
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
                    maxLines: 1,
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
      // Signed out is a settled state, not a wait: the account layer answers
      // `AsyncData(null)`. `hasValue` is what separates that from a loading
      // state, whose value is also null — matching on the null alone left the
      // skeleton bar on a signed-out page forever.
      AsyncValue(hasValue: true, value: null) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: SolSpace.lg,
        children: [
          const _Avatar(name: '?'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: SolSpace.xs,
              children: [
                Text(
                  'profileSignedOutTitle'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'profileSignedOutSubtitle'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SolSpace.xs),
                FilledButton.icon(
                  onPressed: () => SolarpassLoginDialog.show(context),
                  icon: const Icon(Symbols.login_rounded, size: 18),
                  label: Text('solarpassConnectButton'.tr()),
                ),
              ],
            ),
          ),
        ],
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
                // Static skeleton bars, not progress indicators: the account
                // fetch either lands or fails, and a pulse that never stops
                // reads as a hung page.
                _SkeletonBar(width: 120, height: 18),
                _SkeletonBar(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ),
    };
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

  /// Whether this device forwards plays at all. An empty window means one of
  /// two very different things — nothing was played, or nothing was sent —
  /// and the page must not leave the reader to guess which.
  final bool scrobbling;

  const _TasteBody({required this.stats, required this.scrobbling});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stats.totalScrobbles == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: SolSpace.xxl),
        child: Text(
          scrobbling
              ? 'profileTasteEmpty'.tr()
              : 'profileTasteScrobblingOff'.tr(),
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
                    artworkUrl: stats.topItems[i].artworkUrl,
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
                    // A creator's cover, when the fleet has one: the row is a
                    // name to a person, and a portrait beats a note glyph.
                    artworkUrl: stats.topCreators[i].artworkUrl,
                    artworkFallback: Symbols.person_rounded,
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

/// One ranked row of the taste lists: rank, cover, name, optional artist under
/// it.
///
/// The cover is drawn from the fleet's own `artwork_url`, which the stats
/// aggregate now carries per row: these rows name things no connected library
/// necessarily holds — another device's Apple Music play, a store recording —
/// so there is no art handle to resolve through a source, and a row without a
/// picture is the row the reader cannot recognise. Rows with no URL (a creator,
/// an old scrobbler's play) keep the rank in the same slot, so the list stays
/// aligned instead of jumping.
class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String? subtitle;
  final String trailing;
  final String? artworkUrl;
  final IconData artworkFallback;

  const _RankRow({
    required this.rank,
    required this.name,
    this.subtitle,
    required this.trailing,
    this.artworkUrl,
    this.artworkFallback = Symbols.music_note_rounded,
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
          _RankArtwork(url: artworkUrl, fallbackIcon: artworkFallback),
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

/// The square a ranked row draws before its name.
///
/// A bare URL rather than a [LibraryArtwork]: the fleet's cover is a picture,
/// not one library's art handle, and it may name a recording no library here
/// can resolve. A row without a URL still reserves the square, so ranks and
/// names of a mixed list stay in one column instead of stepping.
class _RankArtwork extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;

  static const _size = 36.0;

  const _RankArtwork({required this.url, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final fallback = _placeholder(context);
    final cover = url;
    return SizedBox.square(
      dimension: _size,
      child: cover == null || cover.isEmpty
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(SolRadius.xs),
              // The placeholder sits under the image, so a cover that is still
              // loading (or that fails) reads as a note, not a hole; the
              // errorBuilder keeps the framework's error glyph out of the list.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fallback,
                  Image.network(
                    cover,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(SolRadius.xs),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          fallbackIcon,
          size: _size * 0.5,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
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
