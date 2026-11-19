/// The controls that put a library's tracks on this device, in the shapes the
/// pages already use.
///
/// One place rather than three: the player's menu, an album's hero and a
/// playlist's hero all ask the same question ("is this on the device, and can
/// I put it there?"), and three answers that disagreed would read as a bug.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/library/downloads.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One track's download state as the player's menu shows it.
class TrackDownloadMenuItem extends ConsumerWidget {
  final LibrarySong song;

  /// The context of the menu's anchor, never a menu item's own: the item's
  /// element is gone by the time its handler runs.
  final BuildContext hostContext;

  const TrackDownloadMenuItem({
    super.key,
    required this.song,
    required this.hostContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (song.isRadio) return const SizedBox.shrink();
    final key = (sourceId: song.sourceId, id: song.id);
    final downloaded = ref.watch(isDownloadedProvider(key)).value ?? false;
    final progress = ref.watch(
      downloadsControllerProvider.select(
        (state) => state[DownloadsController.keyOf(song)],
      ),
    );
    if (progress?.active ?? false) {
      final percent = (progress!.fraction * 100).round();
      return MenuItemButton(
        leadingIcon: const Icon(Symbols.downloading_rounded),
        onPressed: null,
        child: Text(
          percent > 0
              ? 'downloadsProgress'.tr(args: ['$percent'])
              : 'downloadsStarting'.tr(),
        ),
      );
    }
    return MenuItemButton(
      leadingIcon: Icon(
        downloaded
            ? Symbols.download_done_rounded
            : Symbols.download_rounded,
      ),
      onPressed: () => _run(context, ref, downloaded),
      child: Text(
        downloaded ? 'downloadsRemoveTrack'.tr() : 'downloadsDownloadTrack'.tr(),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, bool downloaded) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final controller = container.read(downloadsControllerProvider.notifier);
    if (downloaded) {
      await controller.remove(song);
    } else {
      await controller.downloadAll([song]);
      final failure = container.read(downloadsControllerProvider)[
          DownloadsController.keyOf(song)];
      if (failure?.phase == DownloadPhase.failed) {
        messenger?.showSnackBar(
          SnackBar(content: Text(failure?.error ?? 'downloadsFailed'.tr())),
        );
      }
    }
  }
}

/// The hero action that downloads a whole collection.
///
/// Sits beside Play and Shuffle because it is the third way into the same
/// collection, and reports progress in place: a modal would hide the list the
/// user is watching fill up.
class CollectionDownloadButton extends ConsumerWidget {
  final List<LibrarySong> songs;

  const CollectionDownloadButton({super.key, required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadable = [
      for (final song in songs)
        if (!song.isRadio) song,
    ];
    if (downloadable.isEmpty) return const SizedBox.shrink();

    final running = ref.watch(
      downloadsControllerProvider.select(
        (state) => state.values.where((entry) => entry.active).length,
      ),
    );

    return IconButton.filledTonal(
      tooltip: running > 0
          ? 'downloadsRunning'.plural(running)
          : 'downloadsDownloadAll'.tr(),
      onPressed: () async {
        final container = ProviderScope.containerOf(context, listen: false);
        final messenger = ScaffoldMessenger.maybeOf(context);
        final added = await container
            .read(downloadsControllerProvider.notifier)
            .downloadAll(downloadable);
        if (!context.mounted) return;
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              added == 0
                  ? 'downloadsNothingNew'.tr()
                  : 'downloadsAdded'.plural(added),
            ),
          ),
        );
      },
      icon: running > 0
          ? const Icon(Symbols.downloading_rounded)
          : const Icon(Symbols.download_rounded),
    );
  }
}

/// The size a downloaded track takes, for the downloads page.
String downloadSizeLine(DownloadedTrack track) =>
    formatBytes(track.row.sizeBytes);
