import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/collection_hero.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/pill_app_bar.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/pulsar/links.dart';
import 'package:groovy_box/widgets/pulsar_upload.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One playlist's tracks, with a play-all button.
///
/// The playlist belongs to a server, so it is read-only here: adding to it
/// happens through the player's add-to-playlist action, which knows which
/// playlists the account can still write to.
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
            PillHeader(
              title: playlistName ?? 'playlistsDetailTitleFallback'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
              actions: [
                songs.maybeWhen(
                  data: (list) => PulsarUploadButton(
                    localKey: PulsarPlaylistLinks.sourceKey(
                      sourceId,
                      playlistId,
                    ),
                    suggestedName: playlistName ?? 'playlistsKind'.tr(),
                    songs: (_) async => list,
                  ),
                  orElse: () => const SizedBox.shrink(),
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
                        itemCount: list.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final first = list.first;
                            return CollectionHero(
                              sourceId: first.sourceId,
                              artId: first.artId,
                              eyebrow: 'playlistsKind'.tr(),
                              meta: [
                                first.artist ?? 'commonUnknownArtist'.tr(),
                                'playlistsTrackCount'.plural(list.length),
                              ].join('  ·  '),
                              fallbackIcon: Symbols.playlist_play,
                              actions: [
                                FilledButton.icon(
                                  onPressed: () => ref
                                      .read(playbackProvider.notifier)
                                      .playQueue(list),
                                  icon: const Icon(
                                    Symbols.play_arrow_rounded,
                                    size: 20,
                                  ),
                                  label: Text('commonPlay'.tr()),
                                ),
                                IconButton.filledTonal(
                                  tooltip: 'libraryShuffle'.tr(),
                                  onPressed: () {
                                    final notifier = ref.read(
                                      playbackProvider.notifier,
                                    );
                                    notifier.playQueue(list);
                                    notifier.setShuffle(true);
                                  },
                                  icon: const Icon(Symbols.shuffle_rounded),
                                ),
                              ],
                            );
                          }
                          final song = list[index - 1];
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
                                .playQueue(list, startIndex: index - 1),
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
