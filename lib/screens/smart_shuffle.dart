import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/smart_shuffle.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/dashboard.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The smart shuffle: one mix drawn from the whole device, grouped by genre
/// and mood.
///
/// A page rather than a button because the mix has something to say: which
/// shelves it drew from and what the listener's library is made of. The
/// shuffle itself is one press — every group has its own play action, and the
/// header's plays the whole mix.
///
/// The mix is [shufflePlanProvider]'s, not this page's: the dashboard's
/// section draws the same plan, so the shelf that opens here is the queue the
/// page is about to show.
@RoutePage()
class SmartShuffleScreen extends ConsumerWidget {
  const SmartShuffleScreen({super.key});

  void _play(WidgetRef ref, List<LibrarySong> songs) {
    if (songs.isEmpty) return;
    ref.read(playbackProvider.notifier).playQueue(songs);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(shufflePlanProvider);

    return Scaffold(
      body: ContentFrame(
        child: PageScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BackButtonRow(onBack: () => context.router.maybePop()),
            ),
            ...plan.when(
              data: (plan) => plan.isEmpty
                  ? [
                      SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Symbols.shuffle_rounded,
                          title: 'shuffleEmptyTitle'.tr(),
                          message: 'shuffleEmptyMessage'.tr(),
                        ),
                      ),
                    ]
                  : [
                      SliverToBoxAdapter(
                        child: _ShuffleHero(
                          plan: plan,
                          onPlay: () => _play(ref, plan.queue),
                          onShuffle: () =>
                              ref.read(shufflePlanProvider.notifier).shuffle(),
                        ),
                      ),
                      for (final group in plan.groups)
                        SliverToBoxAdapter(
                          child: _GroupSection(
                            group: group,
                            onPlay: (index) =>
                                _play(ref, group.songs.skip(index).toList()),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _QueueList(
                          queue: plan.queue,
                          onPlay: (songs) => _play(ref, songs),
                        ),
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
                  child: InlineError(
                    error: error,
                    onRetry: () =>
                        ref.read(shuffleSeedsProvider.notifier).refresh(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The page's own title, the reason it drew what it drew, and the two actions.
class _ShuffleHero extends StatelessWidget {
  final SmartShuffle plan;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  const _ShuffleHero({
    required this.plan,
    required this.onPlay,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genres = plan.groups
        .where((group) => group.kind == ShuffleGroupKind.genre)
        .length;
    final moods = plan.groups
        .where((group) => group.kind == ShuffleGroupKind.mood)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.xl,
        SolSpace.xl,
        SolSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'shuffleTitle'.tr(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SolSpace.xs),
          Text(
            'shuffleSubtitle'.plural(
              plan.queue.length,
              args: ['${genres + moods}'],
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: SolSpace.md),
          Wrap(
            spacing: SolSpace.sm,
            runSpacing: SolSpace.sm,
            children: [
              FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Symbols.play_arrow_rounded, size: 18),
                label: Text('shufflePlay'.tr()),
              ),
              OutlinedButton.icon(
                onPressed: onShuffle,
                icon: const Icon(Symbols.shuffle_rounded, size: 18),
                label: Text('shuffleAgain'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One genre or one mood, with its own play action.
class _GroupSection extends StatelessWidget {
  final ShuffleGroup group;

  /// Plays the group from [index]: a card opens what it shows first, and the
  /// list behind it follows.
  final ValueChanged<int> onPlay;

  const _GroupSection({required this.group, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = group.kind == ShuffleGroupKind.mood;
    final title = mood
        ? 'shuffleMood${group.title[0].toUpperCase()}${group.title.substring(1)}'
              .tr()
        : group.title;
    return Padding(
      padding: const EdgeInsets.only(top: SolSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SolSpace.xxl, 0, SolSpace.lg, 0),
            child: Row(
              children: [
                Icon(
                  mood ? Symbols.mood_rounded : Symbols.category_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SolSpace.sm),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onPlay(0),
                  icon: const Icon(Symbols.play_arrow_rounded, size: 18),
                  label: Text('shuffleGroupPlay'.tr()),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              itemCount: group.songs.length,
              separatorBuilder: (_, _) => const SizedBox(width: SolSpace.md),
              itemBuilder: (context, index) {
                final song = group.songs[index];
                return SizedBox(
                  width: 132,
                  child: InkWell(
                    onTap: () => onPlay(index),
                    borderRadius: SolRadius.cardRadius,
                    child: Padding(
                      padding: const EdgeInsets.all(SolSpace.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LibraryArtwork(
                            sourceId: song.sourceId,
                            artId: song.artId,
                            size: 124,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole planned mix as a list, so the user can see the order the shuffle
/// chose rather than only its first card of each group.
class _QueueList extends StatelessWidget {
  final List<LibrarySong> queue;
  final ValueChanged<List<LibrarySong>> onPlay;

  const _QueueList({required this.queue, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SolSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.xxl,
              SolSpace.lg,
              SolSpace.xxl,
              SolSpace.sm,
            ),
            child: Text(
              'shuffleQueueTitle'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var index = 0; index < queue.length; index++)
            SongTrackRow(
              song: queue[index],
              title: queue[index].title,
              subtitle: [
                queue[index].subtitle,
                if ((queue[index].genre ?? '').isNotEmpty) queue[index].genre!,
              ].join('  ·  '),
              artwork: LibraryArtwork(
                sourceId: queue[index].sourceId,
                artId: queue[index].artId,
                size: 44,
                radius: SolRadius.sm,
              ),
              trailing: formatDuration(queue[index].duration),
              onTap: () => onPlay([for (final song in queue.skip(index)) song]),
            ),
        ],
      ),
    );
  }
}
