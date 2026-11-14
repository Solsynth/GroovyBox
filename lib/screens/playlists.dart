import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One playlist's tracks, with a play-all button.
@RoutePage()
class PlaylistDetailScreen extends ConsumerWidget {
  /// Which library the playlist belongs to.
  final String sourceId;
  final String playlistId;
  final String? playlistName;

  const PlaylistDetailScreen({
    super.key,
    @PathParam('sourceId') required this.sourceId,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(
      playlistSongsProvider((sourceId: sourceId, id: playlistId)),
    );
    // One boolean, not the transport: rows decide their own selection.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: Column(
          children: [
            PageHeader(
              title: playlistName ?? 'playlistsDetailTitleFallback'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
              subtitle: songs.maybeWhen(
                data: (list) => list.isEmpty
                    ? 'playlistsDetailEmptyHeader'.tr()
                    : 'playlistsDetailTrackCount'.plural(
                        list.length,
                        args: [
                          '${list.length}',
                          formatDuration(
                            list.fold(Duration.zero, (sum, s) => sum + s.duration),
                          ),
                        ],
                      ),
                orElse: () => null,
              ),
              actions: [
                if (songs.hasValue && songs.value!.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(songs.value!),
                    icon: const Icon(Symbols.play_arrow_rounded, size: 20),
                    label: Text('commonPlay'.tr()),
                  ),
                const SizedBox(width: SolSpace.sm),
              ],
            ),
            Expanded(
              child: songs.when(
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Symbols.playlist_play,
                        title: 'playlistsDetailEmptyTitle'.tr(),
                        message: 'playlistsDetailEmptyMessage'.tr(),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: bottomInset),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final song = list[index];
                          return SongTrackRow(
                            song: song,
                            subtitle: songRowSubtitle(ref, song),
                            trailing: formatDuration(song.duration),
                            artwork: LibraryArtwork(
                              sourceId: song.sourceId,
                              artId: song.artId,
                              size: 44,
                              radius: SolRadius.xs,
                            ),
                            onTap: () => ref
                                .read(playbackProvider.notifier)
                                .playQueue(list, startIndex: index),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => EmptyState(
                  icon: Symbols.error_rounded,
                  title: 'playlistsDetailLoadError'.tr(),
                  message: describeServerError(error),
                  iconColor: Theme.of(context).colorScheme.error,
                  action: FilledButton(
                    onPressed: () => ref.invalidate(
                      playlistSongsProvider((
                        sourceId: sourceId,
                        id: playlistId,
                      )),
                    ),
                    child: Text('commonTryAgain'.tr()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
