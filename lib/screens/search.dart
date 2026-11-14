import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/track_identity.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/pill_app_bar.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// One search, over everything at once: what the libraries hold and what
/// their stores could add.
///
/// A page rather than a field inside Browse. The field there searched one
/// direction — the libraries' own rows — and the store was a sheet behind a
/// separate button, so answering "do I have this, and could I?" took two
/// searches in two places. Here both are asked at once and answered in one
/// list: a row that is already playable sits beside the same track offered by
/// a store.
///
/// The library hits come first because they cost nothing to play. A store
/// result whose track the library already holds is dropped rather than
/// repeated: the answer to "do I have this?" is the row above it.
@RoutePage()
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  /// What the field holds, and what the page has actually asked for.
  ///
  /// The field must never lag a keystroke; the query may, because every
  /// change is a provider key and a store request.
  String _draft = '';
  String _query = '';
  Timer? _debounce;

  /// Long enough to swallow the gaps inside a typed word.
  static const _searchDelay = Duration(milliseconds: 260);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _draft = value);
    final term = value.trim();
    if (term.isEmpty) {
      _debounce?.cancel();
      if (_query.isNotEmpty) setState(() => _query = '');
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      if (!mounted || _query == term) return;
      setState(() => _query = term);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);
    final sources = ref.watch(librarySourcesWithLocalProvider);
    final stores = ref.watch(extendableSourcesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            SliverPillHeader(
              title: 'searchTitle'.tr(),
              subtitle: 'searchSubtitle'.tr(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SolSpace.xxl,
                  0,
                  SolSpace.xxl,
                  SolSpace.md,
                ),
                child: SearchBar(
                  controller: _controller,
                  hintText: 'searchPlaceholder'.tr(),
                  leading: const Icon(Symbols.search_rounded),
                  trailing: [
                    if (_draft.isNotEmpty)
                      IconButton(
                        tooltip: 'commonClear'.tr(),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                        icon: const Icon(Symbols.close_rounded),
                      ),
                  ],
                  onChanged: _onChanged,
                ),
              ),
            ),
            if (sources.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Symbols.library_music_rounded,
                  title: 'searchNoLibrariesTitle'.tr(),
                  message: 'searchNoLibraries'.tr(),
                  action: FilledButton.icon(
                    onPressed: () => context.router.push(const SetupRoute()),
                    icon: const Icon(Symbols.add_rounded, size: 18),
                    label: Text('searchConnect').tr(),
                  ),
                ),
              )
            else if (_query.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Symbols.travel_explore_rounded,
                  title: 'searchIdleTitle'.tr(),
                  message: 'searchIdleMessage'.tr(),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: _ResultSection(
                  title: 'searchInLibraries'.tr(),
                  query: _query,
                  // Both directions are asked with the same term; each section
                  // draws its own three states rather than one spinner over a
                  // page that is already useful.
                  child: _LibraryResults(query: _query),
                ),
              ),
              SliverToBoxAdapter(
                child: _ResultSection(
                  title: 'searchInStores'.tr(),
                  query: _query,
                  child: stores.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SolSpace.xxl,
                            SolSpace.xs,
                            SolSpace.xxl,
                            SolSpace.md,
                          ),
                          child: Text(
                            'searchStoresUnavailable'.tr(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      : _StoreResults(query: _query),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
          ],
        ),
      ),
    );
  }
}

/// A labelled block of results: the section's name and its own load state.
class _ResultSection extends StatelessWidget {
  final String title;
  final String query;
  final Widget child;

  const _ResultSection({
    required this.title,
    required this.query,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // A section with nothing in it still says so, in one quiet line: a
    // heading with no body under it reads as a broken page.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        child,
        const SizedBox(height: SolSpace.sm),
      ],
    );
  }
}

/// Songs the libraries already hold, playable now.
class _LibraryResults extends ConsumerWidget {
  final String query;

  const _LibraryResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchSongsProvider(query));
    return results.when(
      skipLoadingOnRefresh: true,
      data: (songs) => songs.isEmpty
          ? _SectionNote(text: 'searchInLibrariesEmpty'.tr(args: [query]))
          : Column(
              children: [
                for (var i = 0; i < songs.length; i++)
                  SongTrackRow(
                    song: songs[i],
                    subtitle: songRowSubtitle(ref, songs[i]),
                    trailing: formatDuration(songs[i].duration),
                    artwork: LibraryArtwork(
                      sourceId: songs[i].sourceId,
                      artId: songs[i].artId,
                      size: 44,
                      radius: SolRadius.xs,
                    ),
                    onTap: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(songs, startIndex: i),
                  ),
              ],
            ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: SolSpace.lg),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, _) => _SectionNote(text: describeServerError(error)),
    );
  }
}

/// What the stores have that the libraries do not, grouped by store.
///
/// Mixed into the same page as the library hits, so one scan of the list
/// answers both questions; the rows are kept in a store's own block because
/// adding is a per-store write and the store has to be named before a button
/// can mean anything.
class _StoreResults extends ConsumerWidget {
  final String query;

  const _StoreResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held =
        ref.watch(searchSongsProvider(query)).value ?? const <LibrarySong>[];
    // The library's own fingerprints, so a store result the user already has
    // is not offered again. Album names are compared case-insensitively:
    // there is no id to join on across two different services.
    final heldFingerprints = {
      for (final song in held) TrackIdentity.of(song).fingerprint,
    };
    final heldAlbums = {
      for (final song in held)
        if (song.album != null) song.album!.trim().toLowerCase(),
    };

    final catalog = ref.watch(catalogSearchProvider(query));
    return catalog.when(
      skipLoadingOnRefresh: true,
      data: (found) {
        final byStore = <String, CatalogSearch>{};
        // The merge in the provider pools every store's results; grouping
        // them back by source is what lets each block name its store and
        // route its own add.
        for (final song in found.songs) {
          if (heldFingerprints.contains(TrackIdentity.of(song).fingerprint)) {
            continue;
          }
          final album = song.album?.trim().toLowerCase();
          if (album != null && heldAlbums.contains(album)) continue;
          byStore.putIfAbsent(song.sourceId, CatalogSearch.new);
          byStore[song.sourceId] = byStore[song.sourceId]!.merge(
            CatalogSearch(songs: [song]),
          );
        }
        for (final album in found.albums) {
          if (heldAlbums.contains(album.name.trim().toLowerCase())) continue;
          byStore.putIfAbsent(album.sourceId, CatalogSearch.new);
          byStore[album.sourceId] = byStore[album.sourceId]!.merge(
            CatalogSearch(albums: [album]),
          );
        }
        for (final playlist in found.playlists) {
          byStore.putIfAbsent(playlist.sourceId, CatalogSearch.new);
          byStore[playlist.sourceId] = byStore[playlist.sourceId]!.merge(
            CatalogSearch(playlists: [playlist]),
          );
        }

        if (byStore.isEmpty) {
          return _SectionNote(text: 'searchInStoresEmpty'.tr(args: [query]));
        }

        final sources = ref.watch(librarySourceByIdProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in byStore.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SolSpace.xxl,
                  SolSpace.sm,
                  SolSpace.xxl,
                  SolSpace.xs,
                ),
                child: Text(
                  'searchStoreSection'.tr(
                    args: [sources[entry.key]?.displayName ?? ''],
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ..._storeRows(found: entry.value),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: SolSpace.lg),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, _) => _SectionNote(text: describeServerError(error)),
    );
  }

  List<Widget> _storeRows({required CatalogSearch found}) {
    final rows = <Widget>[
      for (final song in found.songs)
        _StoreRow(
          title: song.title,
          subtitle: song.subtitle,
          artId: song.artId,
          sourceId: song.sourceId,
          kind: CatalogKind.songs,
          id: song.id,
          playable: song,
        ),
      for (final album in found.albums)
        _StoreRow(
          title: album.name,
          subtitle: album.artist ?? '',
          artId: album.artId,
          sourceId: album.sourceId,
          kind: CatalogKind.albums,
          id: album.id,
        ),
      for (final playlist in found.playlists)
        _StoreRow(
          title: playlist.name,
          subtitle: queueSummary(playlist.songCount ?? 0, false),
          artId: playlist.artId,
          sourceId: playlist.sourceId,
          kind: CatalogKind.playlists,
          id: playlist.id,
        ),
    ];
    return rows;
  }
}

/// A store result: what it is, a preview where it can be played, and the
/// button that puts it in the library.
class _StoreRow extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final String? artId;
  final String sourceId;
  final CatalogKind kind;
  final String id;

  /// A song result, which can be auditioned before it is added. Null for
  /// albums and playlists, which are lists rather than something to play.
  final LibrarySong? playable;

  const _StoreRow({
    required this.title,
    required this.subtitle,
    required this.artId,
    required this.sourceId,
    required this.kind,
    required this.id,
    this.playable,
  });

  @override
  ConsumerState<_StoreRow> createState() => _StoreRowState();
}

class _StoreRowState extends ConsumerState<_StoreRow> {
  bool _adding = false;
  bool _added = false;

  Future<void> _add() async {
    if (_adding || _added) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final added = await ref
          .read(libraryEditorProvider.notifier)
          .add(
            widget.kind,
            (sourceId: widget.sourceId, id: widget.id),
            [widget.id],
          );
      if (!mounted) return;
      setState(() => _added = added > 0);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.playable == null ? null : _preview,
          borderRadius: BorderRadius.circular(SolRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SolSpace.md,
              vertical: SolSpace.sm,
            ),
            child: Row(
              children: [
                LibraryArtwork(
                  sourceId: widget.sourceId,
                  artId: widget.artId,
                  size: 44,
                  radius: SolRadius.xs,
                ),
                const SizedBox(width: SolSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.subtitle.isNotEmpty)
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: SolSpace.sm),
                if (widget.playable != null)
                  IconButton(
                    tooltip: 'searchPlay'.tr(),
                    onPressed: _preview,
                    icon: const Icon(Symbols.play_arrow_rounded),
                  ),
                if (_added)
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
                    onPressed: _adding ? null : _add,
                    icon: const Icon(Symbols.library_add_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _preview() {
    final song = widget.playable;
    if (song == null) return;
    ref.read(playbackProvider.notifier).playQueue([song]);
  }
}

/// One quiet line where a section has nothing to show.
class _SectionNote extends StatelessWidget {
  final String text;

  const _SectionNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.xs,
        SolSpace.xxl,
        SolSpace.md,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }
}
