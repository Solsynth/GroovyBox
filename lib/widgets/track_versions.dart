import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Every connected library's copy of one song, to pick from.
///
/// The reason it exists: the same recording is often held by several
/// libraries at once — a local file, the Subsonic server, the account's Apple
/// Music library — and each is better at something. A streamed copy plays on
/// any device, an Apple Music one carries the account's licensing, a local one
/// needs no network. The app has been able to *fall back* to an alternate
/// source since playback was written ([LibraryCatalog.linksOfSong]); this is
/// the same knowledge, asked directly, so the choice is the user's.
///
/// It is a sheet rather than a page: a lookup is a question about the track on
/// screen, and answering it should not cost the page underneath.
class TrackVersionsPanel extends ConsumerWidget {
  const TrackVersionsPanel({super.key, required this.song});

  final LibrarySong song;

  /// Opens the sheet for [song].
  static Future<void> show(BuildContext context, LibrarySong song) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: TrackVersionsPanel(song: song),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final copies = ref.watch(songCopiesProvider(TrackLookup(song)));
    final controller = ref.read(playbackProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xl,
            0,
            SolSpace.xl,
            SolSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'versionsTitle'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // What was looked up, so the sheet is unambiguous when two
                // tracks share a title.
                '${song.artist ?? 'playerUnknownArtist'.tr()}  ·  ${song.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: copies.when(
            data: (list) => list.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: Symbols.content_copy_rounded,
                    title: 'versionsEmptyTitle'.tr(),
                    message: 'versionsEmptyMessage'.tr(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: SolSpace.lg),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final copy = list[index];
                      final source = ref.watch(
                        librarySourceByIdProvider,
                      )[copy.sourceId];
                      // The copy the user opened this from is not an
                      // alternative; it is the thing they already have.
                      final isOrigin = copy.sourceId == song.sourceId;
                      return TrackRow(
                        title: copy.song.playing.title,
                        subtitle: [
                          source?.displayName ?? copy.sourceId,
                          if (copy.song.playing.album != null)
                            copy.song.playing.album!,
                          if (!copy.playable) 'versionsUnavailable'.tr(),
                        ].join('  ·  '),
                        // The length is what actually differs between two
                        // copies of "the same" recording, so it is the one
                        // number worth showing.
                        trailing: copy.song.playing.duration == Duration.zero
                            ? null
                            : formatDuration(copy.song.playing.duration),
                        selected: isOrigin,
                        artwork: LibraryArtwork(
                          sourceId: copy.sourceId,
                          artId: copy.song.playing.artId,
                          size: 44,
                          radius: SolRadius.xs,
                        ),
                        onTap: copy.playable
                            ? () {
                                // Play this copy in place, with the queue it
                                // belongs to: the user asked for this version
                                // of this song, not for a new queue.
                                controller.switchVersion(copy.song);
                                Navigator.of(context).maybePop();
                              }
                            : null,
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              compact: true,
              icon: Symbols.error_rounded,
              title: 'versionsFailedTitle'.tr(),
              message: describeServerError(error),
            ),
          ),
        ),
        if (copies.value?.any((copy) => !copy.playable) ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.xl,
              0,
              SolSpace.xl,
              SolSpace.md,
            ),
            child: Text(
              'versionsUnavailableHint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
