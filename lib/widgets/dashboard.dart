import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/dashboard_layout.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/local_import.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One section the dashboard can show: its name, its mark, and the library
/// that provided it.
///
/// The catalog is what the page and the customize sheet agree on — the page
/// attaches the content, the sheet arranges the names — so a section is
/// spelled once rather than in both places. A pinned playlist is a section
/// too; [pin] names the playlist its shelf reads.
class DashboardShelf {
  final String title;
  final IconData icon;

  /// The library that provided the content, named in a small line under the
  /// title. Null for a shelf the page assembles from every library, where a
  /// name would claim one source for another's songs.
  final String? source;

  /// False for a shelf that has nothing to show right now: the name would
  /// introduce an empty space. Still listed in the customize sheet, so the
  /// user can see it and turn it back on later.
  final bool visible;

  /// Set when this section is a playlist the user pinned.
  final DashboardPin? pin;

  const DashboardShelf({
    required this.title,
    required this.icon,
    this.source,
    this.visible = true,
    this.pin,
  });
}

/// The sections the dashboard can show right now, before the user's
/// arrangement decides where.
///
/// The content is not here: each shelf's body is the page's own action (a
/// shuffle, a see-all, a queue), and the page and the customize sheet share
/// the catalog rather than a copy of the page.
///
/// Keyed on the locale: `tr()` reads easy_localization's process-wide
/// singleton, which does not notify providers, so a map cached under one key
/// would keep the first language after a switch.
final dashboardSectionsProvider =
    Provider.family<Map<String, DashboardShelf>, String>((ref, language) {
      final randomSongs = ref.watch(randomSongsProvider);
      final recentAlbums = ref.watch(recentAlbumsProvider);
      final friends = ref.watch(friendListeningFeedProvider);
      final curated = ref.watch(landingShelvesProvider);
      final shuffle = ref.watch(shufflePlanProvider);
      final layout = ref.watch(dashboardLayoutProvider);
      final sources = ref.watch(librarySourceByIdProvider);
      final everyLibrary = 'dashboardSourceEveryLibrary'.tr();

      return {
        DashboardSections.smartShuffle: DashboardShelf(
          title: 'shuffleTitle'.tr(),
          icon: Symbols.shuffle_rounded,
          source: 'shuffleSource'.tr(),
          visible: !(shuffle.value?.isEmpty ?? true) || shuffle.hasError,
        ),
        DashboardSections.forYou: DashboardShelf(
          title: 'exploreMadeForYou'.tr(),
          icon: Symbols.auto_awesome_rounded,
          source: everyLibrary,
          visible:
              (randomSongs.value?.isNotEmpty ?? false) || randomSongs.hasError,
        ),
        DashboardSections.friends: DashboardShelf(
          title: 'friendsListeningTitle'.tr(),
          icon: Symbols.group_rounded,
          source: 'dashboardSourceSolink'.tr(),
          visible: friends.value?.isNotEmpty ?? false,
        ),
        DashboardSections.recentlyAdded: DashboardShelf(
          title: 'exploreRecentlyAdded'.tr(),
          icon: Symbols.new_releases_rounded,
          source: everyLibrary,
          visible:
              (recentAlbums.value?.isNotEmpty ?? false) ||
              recentAlbums.hasError,
        ),
        // A shelf an account-backed library curates itself: its name is the
        // shelf's, and the line under it says which account answered.
        for (final shelf in curated.value ?? const <LandingShelf>[])
          DashboardSections.curated(
            shelf.sourceId,
            shelf.title,
          ): DashboardShelf(
            title: shelf.title,
            icon: Symbols.auto_awesome_rounded,
            source: sources[shelf.sourceId]?.displayName ?? shelf.sourceId,
          ),
        for (final pin in layout.pins.values)
          pin.key: DashboardShelf(
            title: pin.title,
            icon: _pinIcon(pin.kind),
            source: switch (pin.kind) {
              DashboardPinKind.owned => LibraryKind.local.label,
              DashboardPinKind.server =>
                sources[pin.sourceId]?.displayName ?? pin.sourceId,
              DashboardPinKind.solink => 'dashboardSourceSolink'.tr(),
            },
            pin: pin,
          ),
      };
    });

IconData _pinIcon(DashboardPinKind kind) => switch (kind) {
  DashboardPinKind.owned => Symbols.queue_music_rounded,
  DashboardPinKind.server => Symbols.playlist_play,
  DashboardPinKind.solink => Symbols.cloud_rounded,
};

/// The catalog's sections in the order the user arranged them.
///
/// The saved order first, then shelves they have not seen yet at the end —
/// a curated shelf appears when the account answers it rather than
/// rearranging the page under them. Pins are sections too, so they take their
/// place in that one order.
List<String> dashboardSectionOrder(
  DashboardLayout layout,
  Map<String, DashboardShelf> available,
) {
  final ordered = [
    for (final key in layout.order)
      if (available.containsKey(key)) key,
  ];
  for (final key in available.keys) {
    if (!ordered.contains(key)) ordered.add(key);
  }
  return ordered;
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

/// The smart shuffle as a section: the planned mix's cards, in the order the
/// shuffle chose.
///
/// The plan is the page's own, not a second draw — the shelf and the page show
/// one queue, and "shuffle again" from either moves both. The section is
/// shorter than the page on purpose: the groups and the full queue live there,
/// and the header opens it.
class SmartShuffleShelf extends ConsumerWidget {
  const SmartShuffleShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(shufflePlanProvider)
        .when(
          data: (plan) => plan.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SolSpace.xxl,
                    vertical: SolSpace.sm,
                  ),
                  child: Text(
                    'shuffleEmptyMessage'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                )
              : SongShelf(songs: plan.queue),
          loading: () => const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator()),
          ),
          // A retry re-reads what the mix is drawn from; the plan follows.
          error: (error, _) => InlineError(
            error: error,
            onRetry: () => ref.read(shuffleSeedsProvider.notifier).refresh(),
          ),
        );
  }
}

class SongCard extends ConsumerWidget {
  final LibrarySong song;
  final VoidCallback onTap;

  const SongCard({super.key, required this.song, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              if (_subtitle(ref) case final subtitle?)
                Text(
                  subtitle,
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

  /// The card's second line: the artist, else the album.
  ///
  /// A station has neither — it is a run of tracks the player generates, not a
  /// recording — so it is named after the library that provides it ("Apple
  /// Music"), which is true and is what the card would otherwise lose.
  /// Anything else without an artist shows only its title.
  String? _subtitle(WidgetRef ref) {
    final artist = song.artist;
    if (artist != null && artist.isNotEmpty) return artist;
    final album = song.album;
    if (album != null && album.isNotEmpty) return album;
    if (!song.isRadio) return null;
    return ref.watch(librarySourceByIdProvider)[song.sourceId]?.displayName;
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
      DashboardPinKind.owned =>
        ref
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

/// Opens the customize sheet over the page that asked for it.
///
/// A sheet rather than a settings page of its own: the dashboard behind it
/// follows every move as it is made, so closing the sheet shows the result
/// rather than asking for a second confirmation. Both the Explore headline
/// and Settings open the same sheet.
void showDashboardCustomize(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => const DashboardCustomizeSheet(),
  );
}

/// The customize sheet: the page's sections in the user's order, each with
/// the two moves that make a dashboard personal — take it off the page, and
/// move it up or down — plus the two ways to add one (a shelf that was
/// removed, and a playlist pinned as a section of its own).
///
/// Writes are live: the page behind the sheet follows every move, so closing
/// the sheet shows the result rather than asking for a second confirmation.
class DashboardCustomizeSheet extends ConsumerStatefulWidget {
  const DashboardCustomizeSheet({super.key});

  @override
  ConsumerState<DashboardCustomizeSheet> createState() =>
      _DashboardCustomizeSheetState();
}

class _DashboardCustomizeSheetState
    extends ConsumerState<DashboardCustomizeSheet> {
  /// Null until the first build, which is also the first point the locale and
  /// the translator are readable: `initState` cannot look at inherited
  /// widgets, and the catalog is keyed by language.
  List<String>? _order;

  /// The language the rows are spelled in. `tr()` resolves against the
  /// process-wide catalog, so the sheet asks the same catalog the page did.
  /// A test that mounts the sheet without an EasyLocalization ancestor still
  /// gets the widget locale rather than a null dereference.
  String get _language {
    final easy = EasyLocalization.of(context);
    return easy?.locale.languageCode ??
        Localizations.localeOf(context).languageCode;
  }

  DashboardLayout get _layout => ref.read(dashboardLayoutProvider);

  /// The user's saved positions, then catalog entries they have not seen
  /// yet: a curated shelf answers late and must not reshuffle the list under
  /// them, so new keys are appended for display. The catalog already
  /// includes the pins, so one derived order is all the sheet needs.
  List<String> _effectiveOrder(Map<String, DashboardShelf> available) {
    final order =
        _order ??
        dashboardSectionOrder(ref.read(dashboardLayoutProvider), available);
    _order = order;
    return [
      ...order.where(available.containsKey),
      ...available.keys.where((key) => !order.contains(key)),
    ];
  }

  Future<void> _move(int oldIndex, int newIndex) async {
    final next = _effectiveOrder(
      ref.read(dashboardSectionsProvider(_language)),
    );
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
    setState(() => _order = _order?.where((k) => k != key).toList());
  }

  Future<void> _reset() async {
    await ref.read(dashboardLayoutProvider.notifier).reset();
    setState(
      () => _order = dashboardSectionOrder(
        ref.read(dashboardLayoutProvider),
        ref.read(dashboardSectionsProvider(_language)),
      ),
    );
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
      final order = _order;
      if (order != null && !order.contains(pin.key)) order.add(pin.key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = ref.watch(dashboardLayoutProvider);
    final available = ref.watch(dashboardSectionsProvider(_language));
    final effective = _effectiveOrder(available);
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
                itemCount: effective.length,
                onReorderItem: _move,
                itemBuilder: (context, index) {
                  final key = effective[index];
                  final pin = layout.pins[key];
                  final shelf = available[key];
                  final title = shelf?.title ?? pin?.title ?? key;
                  final icon = shelf?.icon ?? Symbols.widgets_rounded;
                  final source = shelf?.source;
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: removed
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              if (source != null)
                                Text(
                                  source,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (shelf?.pin != null)
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
