import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One cloud playlist's tracks, with a play-all button.
///
/// The playlist lives on Pulsar; the tracks it names are matched against the
/// connected library sources, so what plays is the user's own copy of the
/// recording. A track no source holds is skipped rather than shown as a
/// blank: a playlist is not a graveyard, here either.
@RoutePage()
class PulsarPlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;
  final String? playlistName;

  const PulsarPlaylistDetailScreen({
    super.key,
    @PathParam('playlistId') required this.playlistId,
    this.playlistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(pulsarPlaylistsProvider);
    final playlist = playlists.value
        ?.where((p) => p.id == playlistId)
        .firstOrNull;
    final songs = ref.watch(
      pulsarPlaylistSongsProvider(
        playlist ??
            PulsarPlaylist(id: playlistId, name: playlistName ?? '', isPublic: true),
      ),
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
              title: playlist?.name ?? playlistName ?? 'playlistsDetailTitleFallback'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
              subtitle: songs.maybeWhen(
                data: (list) => list.isEmpty
                    ? 'pulsarPlaylistEmptyHeader'.tr()
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
                        icon: Symbols.cloud_rounded,
                        title: 'pulsarPlaylistEmptyTitle'.tr(),
                        message: 'pulsarPlaylistEmptyMessage'.tr(),
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
                    onPressed: () => ref.invalidate(pulsarPlaylistsProvider),
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
