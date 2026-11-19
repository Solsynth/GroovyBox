import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/dashboard_layout.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/local_import.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One shelf the dashboard can draw, before the user's arrangement decides
/// where.
class DashboardShelf {
  final String title;
  final IconData icon;

  /// False for a shelf that has nothing to show right now: the name would
  /// introduce an empty space. Still listed in the customize sheet, so the
  /// user can see it and turn it back on later.
  final bool visible;
  final Widget? trailing;
  final List<Widget> Function() body;

  const DashboardShelf({
    required this.title,
    required this.icon,
    required this.body,
    this.visible = true,
    this.trailing,
  });
}

/// Horizontal shelf of playable songs, each a cover card.
class SongShelf extends ConsumerWidget {
  final List<LibrarySong> songs;

  const SongShelf({super.key, required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: SolSpace.md),
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongCard(
            song: song,
            onTap: () => ref
                .read(playbackProvider.notifier)
                .playQueue(songs, startIndex: index),
          );
        },
      ),
    );
  }
}

class SongCard extends StatelessWidget {
  final LibrarySong song;
  final VoidCallback onTap;

  const SongCard({super.key, required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: onTap,
        borderRadius: SolRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(SolSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LibraryArtwork(
                sourceId: song.sourceId,
                artId: song.artId,
                size: 132,
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
  }
}

class DashboardLoadingSliver extends StatelessWidget {
  const DashboardLoadingSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(SolSpace.huge),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class DashboardErrorSliver extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const DashboardErrorSliver({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: EmptyState(
        compact: true,
        icon: Symbols.album,
        title: 'exploreLoadError'.tr(),
        message: describeServerError(error),
        iconColor: Theme.of(context).colorScheme.error,
        action: FilledButton(
          onPressed: onRetry,
          child: Text('commonTryAgain'.tr()),
        ),
      ),
    );
  }
}

/// One quiet error line on a section that has nothing to show.
class InlineError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const InlineError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SolSpace.xxl,
        vertical: SolSpace.sm,
      ),
      child: Row(
        children: [
          Icon(
            Symbols.error_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: SolSpace.sm),
          Expanded(
            child: Text(
              describeServerError(error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: Text('commonRetry'.tr())),
        ],
      ),
    );
  }
}

/// The one nudge this page makes: with no server connected the library is
/// empty, and the way out is either connecting one or importing files already
/// on this device. It is a card in the page, not a gate — the app is usable
/// before either happens.
class AddSourceCard extends ConsumerWidget {
  const AddSourceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xl,
        SolSpace.sm,
        SolSpace.xl,
        SolSpace.sm,
      ),
      child: IslandCard(
        padding: const EdgeInsets.all(SolSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.cloud_off_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SolSpace.sm),
                Expanded(
                  child: Text(
                    'exploreNoSourceTitle'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SolSpace.sm),
            Text(
              'exploreNoSourceMessage'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: SolSpace.lg),
            Wrap(
              spacing: SolSpace.sm,
              runSpacing: SolSpace.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => context.router.push(const SetupRoute()),
                  icon: const Icon(Symbols.add_rounded, size: 18),
                  label: Text('exploreAddSource'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: () => importMusicFiles(context, ref),
                  icon: const Icon(Symbols.file_open_rounded, size: 18),
                  label: Text('exploreImportFiles'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A playlist the user pinned as a section: its own cover row, then its
/// tracks as a shelf. The reading is the source's, exactly as its detail
/// page does it — a pin is a shortcut to a playlist, not a copy of one.
class PinnedPlaylistShelf extends ConsumerWidget {
  final DashboardPin pin;

  const PinnedPlaylistShelf({super.key, required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = switch (pin.kind) {
      DashboardPinKind.owned => ref
          .watch(ownedPlaylistEntriesProvider(int.parse(pin.id)))
          .whenData((entries) => [for (final entry in entries) entry.song]),
      DashboardPinKind.server => ref.watch(
        playlistSongsProvider((sourceId: pin.sourceId, id: pin.id)),
      ),
      DashboardPinKind.solink => _solinkSongs(ref),
    };
    return songs.when(
      data: (list) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SolSpace.xxl,
                vertical: SolSpace.sm,
              ),
              child: Text(
                'dashboardPinEmpty'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            )
          : SongShelf(songs: list),
      loading: () => const SizedBox(
        height: 190,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => InlineError(
        error: error,
        // A retry re-reads the playlist the pin points at.
        onRetry: () {
          switch (pin.kind) {
            case DashboardPinKind.owned:
              ref.invalidate(ownedPlaylistEntriesProvider(int.parse(pin.id)));
            case DashboardPinKind.server:
              ref.invalidate(
                playlistSongsProvider((sourceId: pin.sourceId, id: pin.id)),
              );
            case DashboardPinKind.solink:
              ref.invalidate(pulsarPlaylistDetailProvider(pin.id));
          }
        },
      ),
    );
  }

  /// A cloud playlist names tracks the connected libraries have to match,
  /// so its shelf is the detail read resolved against them.
  AsyncValue<List<LibrarySong>> _solinkSongs(WidgetRef ref) {
    final detail = ref.watch(pulsarPlaylistDetailProvider(pin.id));
    return detail.when(
      data: (playlist) => ref
          .watch(pulsarPlaylistSongsProvider(playlist))
          .whenData((songs) => [for (final song in songs) ?song]),
      loading: () => const AsyncLoading(),
      error: (error, stack) => AsyncError(error, stack),
    );
  }
}

/// The customize sheet: the page's sections in the user's order, each with
/// the two moves that make a dashboard personal — take it off the page, and
/// move it up or down — plus the two ways to add one (a shelf that was
/// removed, and a playlist pinned as a section of its own).
///
/// Writes are live: the page behind the sheet follows every move, so closing
/// the sheet shows the result rather than asking for a second confirmation.
class DashboardCustomizeSheet extends ConsumerStatefulWidget {
  final Map<String, DashboardShelf> available;
  final List<String> initialOrder;

  const DashboardCustomizeSheet({
    super.key,
    required this.available,
    required this.initialOrder,
  });

  @override
  ConsumerState<DashboardCustomizeSheet> createState() =>
      _DashboardCustomizeSheetState();
}

class _DashboardCustomizeSheetState
    extends ConsumerState<DashboardCustomizeSheet> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    // Pins extend the built-in order: a pinned playlist can sit anywhere on
    // the page, including above the shelves the app offers.
    final pins = ref.read(dashboardLayoutProvider).pins;
    _order = [...widget.initialOrder];
    for (final key in pins.keys) {
      if (!_order.contains(key)) {
        _order.add(key);
      }
    }
  }

  DashboardLayout get _layout => ref.read(dashboardLayoutProvider);

  /// `onReorderItem` already adjusts the destination index for the item
  /// removed from its old place.
  Future<void> _move(int oldIndex, int newIndex) async {
    final next = [..._order];
    final key = next.removeAt(oldIndex);
    next.insert(newIndex, key);
    setState(() => _order = next);
    await ref.read(dashboardLayoutProvider.notifier).setOrder(next);
  }

  Future<void> _setVisible(String key, bool visible) async {
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    if (visible) {
      await notifier.show(key);
    } else {
      await notifier.hide(key);
    }
  }

  Future<void> _removePin(String key) async {
    await ref.read(dashboardLayoutProvider.notifier).removePin(key);
    setState(() => _order = _order.where((k) => k != key).toList());
  }

  Future<void> _reset() async {
    await ref.read(dashboardLayoutProvider.notifier).reset();
    setState(() => _order = [...widget.initialOrder]);
  }

  Future<void> _addPin() async {
    final pin = await showModalBottomSheet<DashboardPin>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _PinPicker(pinned: _layout.pins.keys.toSet()),
    );
    if (pin == null || !mounted) return;
    await ref.read(dashboardLayoutProvider.notifier).addPin(pin);
    if (!mounted) return;
    setState(() {
      if (!_order.contains(pin.key)) _order.add(pin.key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = ref.watch(dashboardLayoutProvider);
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.md,
                SolSpace.xs,
                SolSpace.md,
                SolSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'dashboardSections'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text('dashboardReset'.tr()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.md,
                0,
                SolSpace.md,
                SolSpace.sm,
              ),
              child: Text(
                'dashboardCustomizeHint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(bottom: SolSpace.md),
                itemCount: _order.length,
                onReorderItem: _move,
                itemBuilder: (context, index) {
                  final key = _order[index];
                  final pin = layout.pins[key];
                  final shelf = widget.available[key];
                  final title = pin?.title ?? shelf?.title ?? key;
                  final icon =
                      pin != null
                      ? _pinIcon(pin.kind)
                      : shelf?.icon ?? Symbols.widgets_rounded;
                  // A shelf the page cannot draw yet (a curated shelf that
                  // has not answered) is listed but greyed: it is still a
                  // choice, just not one with anything behind it today.
                  final removed = layout.hidden.contains(key);
                  return Padding(
                    key: ValueKey(key),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.xs,
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.all(SolSpace.md),
                            child: Icon(
                              Symbols.drag_handle_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(icon, size: 20),
                        const SizedBox(width: SolSpace.md),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: removed
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                        if (pin != null)
                          IconButton(
                            tooltip: 'dashboardRemoveSection'.tr(),
                            onPressed: () => _removePin(key),
                            icon: const Icon(Symbols.delete_outline_rounded),
                          ),
                        Switch(
                          value: !removed,
                          onChanged: (value) => _setVisible(key, value),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.md,
                SolSpace.xs,
                SolSpace.md,
                SolSpace.sm,
              ),
              child: OutlinedButton.icon(
                onPressed: _addPin,
                icon: const Icon(Symbols.playlist_add_rounded),
                label: Text('dashboardAddSection'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _pinIcon(DashboardPinKind kind) => switch (kind) {
    DashboardPinKind.owned => Symbols.queue_music_rounded,
    DashboardPinKind.server => Symbols.playlist_play,
    DashboardPinKind.solink => Symbols.cloud_rounded,
  };
}

/// The playlists a section can be made from, wherever they live. The same
/// one list as the library page: this device's, a server's, the account's.
class _PinPicker extends ConsumerWidget {
  final Set<String> pinned;

  const _PinPicker({required this.pinned});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owned = ref.watch(ownedPlaylistsProvider).value ?? const [];
    final server = ref.watch(playlistsProvider).value ?? const [];
    final cloud = ref.watch(pulsarPlaylistsProvider).value ?? const [];

    final list = <DashboardPin>[
      for (final playlist in owned)
        DashboardPin(
          kind: DashboardPinKind.owned,
          id: '${playlist.id}',
          title: playlist.name,
        ),
      for (final playlist in server)
        DashboardPin(
          kind: DashboardPinKind.server,
          sourceId: playlist.sourceId,
          id: playlist.id,
          title: playlist.name,
        ),
      for (final playlist in cloud)
        DashboardPin(
          kind: DashboardPinKind.solink,
          id: playlist.id,
          title: playlist.name,
        ),
    ].where((pin) => !pinned.contains(pin.key)).toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.md,
              SolSpace.xs,
              SolSpace.md,
              SolSpace.sm,
            ),
            child: Text(
              'dashboardPinTitle'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SolSpace.md),
              child: Text(
                'dashboardNoPlaylists'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, index) {
                final pin = list[index];
                return ListTile(
                  leading: Icon(switch (pin.kind) {
                    DashboardPinKind.owned => Symbols.queue_music_rounded,
                    DashboardPinKind.server => Symbols.playlist_play,
                    DashboardPinKind.solink => Symbols.cloud_rounded,
                  }),
                  title: Text(pin.title),
                  onTap: () => Navigator.of(context).pop(pin),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
