import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Searching a store for music the account does not hold yet.
///
/// The browse page's field searches what the libraries *have*. This sheet is
/// the other direction: what the store has, with a button per row to put it in
/// the library. It is a sheet because it is a side trip — the page underneath
/// is where the result ends up.
class CatalogSearchPanel extends ConsumerStatefulWidget {
  const CatalogSearchPanel({super.key, required this.store});

  /// Which library's store this is. A search is per store: the catalog of a
  /// Jellyfin server is its own, and one query does not mean both.
  final ExtendableSource store;

  static Future<void> show(BuildContext context, ExtendableSource store) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: CatalogSearchPanel(store: store),
          ),
        ),
      );

  @override
  ConsumerState<CatalogSearchPanel> createState() => _CatalogSearchPanelState();
}

class _CatalogSearchPanelState extends ConsumerState<CatalogSearchPanel> {
  final _controller = TextEditingController();
  String _query = '';

  /// The ids this panel has already added, so a row stops offering to add
  /// again instead of failing on the second tap.
  final _added = <String>{};
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(catalogSearchProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xl,
            0,
            SolSpace.xl,
            SolSpace.sm,
          ),
          child: Text(
            'catalogTitle'.tr(args: [widget.store.displayName]),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
          child: SearchBar(
            controller: _controller,
            hintText: 'catalogSearchPlaceholder'.tr(),
            leading: const Icon(Symbols.search_rounded),
            onChanged: (value) => setState(() => _query = value),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: 'commonClear'.tr(),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Symbols.close_rounded),
                ),
            ],
          ),
        ),
        const SizedBox(height: SolSpace.sm),
        Expanded(
          child: _query.trim().isEmpty
              ? EmptyState(
                  compact: true,
                  icon: Symbols.travel_explore_rounded,
                  title: 'catalogIdleTitle'.tr(),
                  message: 'catalogIdleMessage'.tr(),
                )
              : results.when(
                  data: (found) => found.isEmpty
                      ? EmptyState(
                          compact: true,
                          icon: Symbols.search_off_rounded,
                          title: 'catalogEmptyTitle'.tr(),
                          message: 'catalogEmptyMessage'.tr(args: [_query]),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: SolSpace.xl),
                          children: [
                            if (found.songs.isNotEmpty) ...[
                              SectionLabel('catalogSongs'.tr()),
                              for (final song in found.songs)
                                _ResultRow(
                                  title: song.title,
                                  subtitle: song.subtitle,
                                  artId: song.artId,
                                  sourceId: song.sourceId,
                                  added: _added.contains(song.id),
                                  onAdd: _adding
                                      ? null
                                      : () => _add(CatalogKind.songs, song.id),
                                  onPlay: () => ref
                                      .read(playbackProvider.notifier)
                                      .playQueue([song]),
                                ),
                            ],
                            if (found.albums.isNotEmpty) ...[
                              SectionLabel('catalogAlbums'.tr()),
                              for (final album in found.albums)
                                _ResultRow(
                                  title: album.name,
                                  subtitle: album.artist ?? '',
                                  artId: album.artId,
                                  sourceId: album.sourceId,
                                  added: _added.contains(album.id),
                                  onAdd: _adding
                                      ? null
                                      : () =>
                                            _add(CatalogKind.albums, album.id),
                                ),
                            ],
                            if (found.playlists.isNotEmpty) ...[
                              SectionLabel('catalogPlaylists'.tr()),
                              for (final playlist in found.playlists)
                                _ResultRow(
                                  title: playlist.name,
                                  subtitle: '',
                                  artId: playlist.artId,
                                  sourceId: playlist.sourceId,
                                  added: _added.contains(playlist.id),
                                  onAdd: _adding
                                      ? null
                                      : () => _add(
                                          CatalogKind.playlists,
                                          playlist.id,
                                        ),
                                ),
                            ],
                          ],
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => EmptyState(
                    compact: true,
                    icon: Symbols.error_rounded,
                    title: 'catalogFailedTitle'.tr(),
                    message: describeServerError(error),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _add(CatalogKind kind, String id) async {
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final added = await ref
          .read(libraryEditorProvider.notifier)
          .add(kind, (sourceId: widget.store.id, id: id), [id]);
      if (!mounted) return;
      setState(() {
        _adding = false;
        if (added > 0) _added.add(id);
      });
      // Invalidate so a re-search reflects the library as it now is.
      ref.invalidate(catalogSearchProvider(_query));
    } catch (error) {
      if (!mounted) return;
      setState(() => _adding = false);
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }
}

/// One store result: artwork, what it is, and what can be done with it.
class _ResultRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? artId;
  final String sourceId;
  final bool added;
  final VoidCallback? onAdd;

  /// Absent for a result that cannot be played yet — an album or a playlist.
  final VoidCallback? onPlay;

  const _ResultRow({
    required this.title,
    required this.subtitle,
    required this.artId,
    required this.sourceId,
    required this.added,
    this.onAdd,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(SolRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SolSpace.sm,
              vertical: SolSpace.xs,
            ),
            child: Row(
              children: [
                LibraryArtwork(
                  sourceId: sourceId,
                  artId: artId,
                  size: 40,
                  radius: SolRadius.xs,
                ),
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
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (added)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.md,
                    ),
                    child: Icon(
                      Symbols.check_circle_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'catalogAdd'.tr(),
                    onPressed: onAdd,
                    icon: const Icon(Symbols.library_add_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
