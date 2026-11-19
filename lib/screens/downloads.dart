import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/download_actions.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Every track this device keeps, and the way to remove one.
///
/// A page rather than a sheet: downloads are a collection the user manages —
/// what is here, what it costs, what to delete — and a list that scrolls past
/// a phone window needs a page of its own. Removing one is a long press, the
/// gesture every other removable row in the app uses.
@RoutePage()
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadedTracksProvider);
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BackButtonRow(onBack: () => context.router.maybePop()),
            ),
            ...downloads.when(
              data: (list) => list.isEmpty
                  ? [
                      SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Symbols.download_rounded,
                          title: 'downloadsEmptyTitle'.tr(),
                          message: 'downloadsEmptyMessage'.tr(),
                        ),
                      ),
                    ]
                  : [
                      SliverToBoxAdapter(
                        child: _DownloadsHeader(tracks: list),
                      ),
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final track = list[index];
                          return SongTrackRow(
                            song: track.song,
                            title: track.song.title,
                            subtitle: [
                              track.song.artist ?? 'commonUnknownArtist'.tr(),
                              downloadSizeLine(track),
                            ].join('  ·  '),
                            artwork: _DownloadArtwork(track: track),
                            trailing: formatDuration(
                              Duration(milliseconds: track.row.durationMs),
                            ),
                            onTap: () => ref
                                .read(playbackProvider.notifier)
                                .playQueue(
                                  [for (final row in list) row.song],
                                  startIndex: index,
                                ),
                            onLongPress: () =>
                                _confirmRemove(context, ref, track.song),
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
                    title: 'downloadsLoadError'.tr(),
                    message: describeServerError(error),
                    iconColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    LibrarySong song,
  ) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('downloadsRemoveTitle'.tr()),
        content: Text('downloadsRemoveMessage'.tr(args: [song.title])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('commonCancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('commonRemove'.tr()),
          ),
        ],
      ),
    );
    if (agreed != true) return;
    await ref.read(downloadsControllerProvider.notifier).remove(song);
  }
}

/// The page's own headline: what is kept and what it costs.
class _DownloadsHeader extends StatelessWidget {
  final List<DownloadedTrack> tracks;

  const _DownloadsHeader({required this.tracks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = tracks.fold<int>(0, (sum, track) => sum + track.row.sizeBytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.sm,
        SolSpace.xxl,
        SolSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'downloadsTitle'.tr(),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SolSpace.xs),
          Text(
            [
              'downloadsCount'.plural(tracks.length),
              formatBytes(bytes),
            ].join('  ·  '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A download's cover, painted from the copy beside it rather than from the
/// library that served it: the page must work with no server at all.
class _DownloadArtwork extends StatelessWidget {
  final DownloadedTrack track;

  const _DownloadArtwork({required this.track});

  @override
  Widget build(BuildContext context) {
    final artPath = track.artPath;
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Symbols.music_note_rounded,
        size: 20,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(SolRadius.xs),
      child: SizedBox.square(
        dimension: 44,
        child: artPath == null
            ? placeholder
            : Image.file(
                File(artPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
