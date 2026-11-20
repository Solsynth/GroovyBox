import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/track_identity.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/widgets/artist_card.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/section.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The two questions a search asks, kept apart because their answers differ
/// in kind: one is music the user already has, the other is music they could
/// get.
enum _SearchTab { library, explore }

/// One field, two tabs.
///
/// The page used to answer both at once, in one list: the library's hits,
/// then the stores'. That reads as one answer, but the two are not the same
/// answer — the top half is "what you have", the bottom half is "what you
/// could add" — and a provider whose search reaches its whole catalogue made
/// the top half lie outright: a NetEase account's `/cloudsearch` returns
/// tracks the user never added, sitting under a heading promising the
/// opposite.
///
/// So the field is shared and the tabs are the split. Library asks only what
/// the connected libraries **hold**; Explore asks their stores and drops
/// everything the library already answers with, so a track cannot appear on
/// both tabs and "Explore" never offers the user their own music.
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

  _SearchTab _tab = _SearchTab.library;

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
    final sources = ref.watch(librarySourcesWithLocalProvider);
    final stores = ref.watch(extendableSourcesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        child: PageScrollView(
          slivers: [
            // The field is the page, not a control on a bar: a search page
            // whose header is its own query box should open with the box at
            // the top of the content, scrolling with the results under it.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SolSpace.xl,
                  SolSpace.xl,
                  SolSpace.xl,
                  SolSpace.sm,
                ),
                child: SearchBar(
                  controller: _controller,
                  hintText: 'searchPlaceholder'.tr(),
                  leading: const Icon(Symbols.search_rounded),
                  constraints: const BoxConstraints(minHeight: 52, maxHeight: 52),
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
            // Directly under the field, because it is a property of the
            // search rather than of the results: it stays put while the page
            // below it changes, and it is the only control that decides what
            // "search" means.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SolSpace.xl,
                  SolSpace.xs,
                  SolSpace.xl,
                  SolSpace.sm,
                ),
                child: SegmentedButton<_SearchTab>(
                  segments: [
                    ButtonSegment(
                      value: _SearchTab.library,
                      icon: const Icon(Symbols.library_music_rounded),
                      label: Text('searchTabLibrary'.tr()),
                    ),
                    ButtonSegment(
                      value: _SearchTab.explore,
                      icon: const Icon(Symbols.travel_explore_rounded),
                      label: Text('searchTabExplore'.tr()),
                    ),
                  ],
                  selected: {_tab},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() => _tab = selection.first);
                  },
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
                  icon: _tab == _SearchTab.library
                      ? Symbols.manage_search_rounded
                      : Symbols.travel_explore_rounded,
                  title: _tab == _SearchTab.library
                      ? 'searchIdleTitle'.tr()
                      : 'searchExploreIdleTitle'.tr(),
                  message: _tab == _SearchTab.library
                      ? 'searchIdleMessage'.tr()
                      : 'searchExploreIdleMessage'.tr(),
                ),
              )
            else if (_tab == _SearchTab.library)
              _LibraryResults(query: _query)
            else ...[
              if (stores.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SolSpace.xxl,
                      SolSpace.sm,
                      SolSpace.xxl,
                      SolSpace.md,
                    ),
                    child: Text(
                      'searchStoresUnavailable'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                _ExploreResults(query: _query),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the libraries hold, as three folds: artists, albums, tracks.
///
/// One query answers three kinds, and a page that stacked them in one list
/// made a search for an act open on nine of their songs. Each kind is its own
/// section — the same fold the library page uses — so a reader can put the
/// tracks away and keep the records, and a kind with nothing to say stays out
/// entirely rather than printing an empty heading.
///
/// Each kind answers with its own first page: the store's search returns
/// whatever it wants, and a search page that lists two hundred albums is a
/// page nobody scrolls to the end of. The extra results are behind a "see
/// all" that widens that one section, not the field: a search is a question,
/// and asking it again is the field's job.
class _LibraryResults extends ConsumerStatefulWidget {
  final String query;

  const _LibraryResults({required this.query});

  @override
  ConsumerState<_LibraryResults> createState() => _LibraryResultsState();
}

class _LibraryResultsState extends ConsumerState<_LibraryResults> {
  /// How many rows of each kind are on screen, before "see all" widens it.
  static const _initial = 5;
  static const _widened = 40;

  int _artists = _initial;
  int _albums = _initial;
  int _tracks = _initial;

  static const _page = 'search';
  static const _artistsId = 'artists';
  static const _albumsId = 'albums';
  static const _tracksId = 'tracks';

  @override
  void didUpdateWidget(_LibraryResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new question starts at the top of each kind again: "see all" widens
    // the answer it was tapped on, not the next one.
    if (oldWidget.query != widget.query) {
      _artists = _albums = _tracks = _initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(searchGroupsProvider(widget.query));
    final songs = ref.watch(searchSongsProvider(widget.query));
    final artists = groups.value?.artists ?? const <LibraryArtist>[];
    final albums = groups.value?.albums ?? const <LibraryAlbum>[];
    final tracks = songs.value ?? const <LibrarySong>[];
    // "Nothing here" is only honest once both questions have answered: the
    // group search can land a frame after the songs, and a note drawn on the
    // songs' empty answer would then sit above the artists it denied.
    final everythingEmpty =
        !groups.isLoading &&
        !songs.isLoading &&
        artists.isEmpty &&
        albums.isEmpty &&
        tracks.isEmpty;
    if (everythingEmpty) {
      // A source that failed says so where its results would have been; a
      // source that answered nothing is the note below. Both at once is the
      // honest reading: this query found nothing it could show.
      final failure = groups.error ?? songs.error;
      return SliverToBoxAdapter(
        child: _SectionNote(
          text: failure == null
              ? 'searchInLibrariesEmpty'.tr(args: [widget.query])
              : describeServerError(failure),
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        if (groups.isLoading || songs.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: SolSpace.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        if (artists.isNotEmpty)
          FoldableSection(
            page: _page,
            id: _artistsId,
            title: 'libraryArtists'.tr(),
            trailing: _SeeAll(
              shown: _artists,
              total: artists.length,
              onTap: () => setState(() => _artists = _widened),
            ),
            builder: () => [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
                    itemCount: artists.take(_artists).length,
                    separatorBuilder: (_, _) => const SizedBox(width: SolSpace.md),
                    itemBuilder: (context, index) => SizedBox(
                      width: 132,
                      child: ArtistCard(
                        artist: artists[index],
                        onTap: () => context.router.push(
                          ArtistDetailRoute(
                            sourceId: artists[index].sourceId,
                            artistId: artists[index].id,
                            artistName: artists[index].name,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (albums.isNotEmpty)
          FoldableSection(
            page: _page,
            id: _albumsId,
            title: 'libraryAlbums'.tr(),
            trailing: _SeeAll(
              shown: _albums,
              total: albums.length,
              onTap: () => setState(() => _albums = _widened),
            ),
            builder: () => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: SolSpace.md,
                    crossAxisSpacing: SolSpace.md,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: albums.take(_albums).length,
                  itemBuilder: (context, index) => AlbumCard(
                    album: albums[index],
                    onTap: () => context.router.push(
                      AlbumDetailRoute(
                        sourceId: albums[index].sourceId,
                        albumId: albums[index].id,
                        albumName: albums[index].name,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (tracks.isNotEmpty)
          FoldableSection(
            page: _page,
            id: _tracksId,
            title: 'libraryTracks'.tr(),
            trailing: _SeeAll(
              shown: _tracks,
              total: tracks.length,
              onTap: () => setState(() => _tracks = _widened),
            ),
            builder: () => [
              SliverList.builder(
                itemCount: tracks.take(_tracks).length,
                itemBuilder: (context, index) {
                  final song = tracks[index];
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
                        .playQueue(tracks, startIndex: index),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// "See all (12)": widens one section to the rest of its answer. Nothing to
/// do when the first page already holds everything.
class _SeeAll extends StatelessWidget {
  final int shown;
  final int total;
  final VoidCallback onTap;

  const _SeeAll({
    required this.shown,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (shown >= total) return const SizedBox.shrink();
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('searchSeeAll'.tr(args: ['$total'])),
    );
  }
}

/// What the stores have that the user does not, as the same three folds the
/// library tab uses: tracks, albums, playlists.
///
/// Grouped by kind rather than by store, because the question this tab
/// answers is "could I add this?" and a search for a record should open on
/// records, not on twenty-five of its songs. The store a row came from is
/// named on the row itself: a heading can only be as right as the map it
/// looks a source up in, and two connections sharing an id made that map
/// collapse them into one — which printed one store's hits under the other's
/// name. A row carrying its own source cannot say the wrong store.
///
/// Everything the library tab answers with is dropped here: a track on both
/// tabs would answer "do I have this?" twice, and the Explore tab's whole
/// premise is music the user does not have yet — hearts, playlist tracks and
/// subscribed albums included, which is why the holdings search is what the
/// comparison is made against.
class _ExploreResults extends ConsumerStatefulWidget {
  final String query;

  const _ExploreResults({required this.query});

  @override
  ConsumerState<_ExploreResults> createState() => _ExploreResultsState();
}

class _ExploreResultsState extends ConsumerState<_ExploreResults> {
  /// The same first page the library tab shows; "see all" widens one fold.
  static const _initial = 5;
  static const _widened = 40;

  int _tracks = _initial;
  int _albums = _initial;
  int _playlists = _initial;

  static const _page = 'search';
  static const _tracksId = 'explore-tracks';
  static const _albumsId = 'explore-albums';
  static const _playlistsId = 'explore-playlists';

  @override
  void didUpdateWidget(_ExploreResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _tracks = _albums = _playlists = _initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final held =
        ref.watch(searchSongsProvider(query)).value ?? const <LibrarySong>[];
    // The library's own fingerprints, so a store result the user already has
    // is not offered again. Album names are compared case-insensitively and
    // against the group search too: the album a song belongs to is not the
    // whole answer, and a record the library holds would otherwise be offered
    // back just because none of its tracks matched.
    final heldFingerprints = {
      for (final song in held) TrackIdentity.of(song).fingerprint,
    };
    final heldAlbums = {
      for (final album
          in ref.watch(searchGroupsProvider(query)).value?.albums ??
              const <LibraryAlbum>[])
        album.name.trim().toLowerCase(),
      for (final song in held)
        if (song.album != null) song.album!.trim().toLowerCase(),
    };
    // Playlists the account already has, by their own identity. A collected
    // playlist is in the library; offering to "add" it again is offering a
    // no-op.
    final heldPlaylists = {
      for (final playlist
          in ref.watch(playlistsProvider).value ?? const <LibraryPlaylist>[])
        '${playlist.sourceId}:${playlist.id}',
    };

    final catalog = ref.watch(catalogSearchProvider(query));
    return catalog.when(
      skipLoadingOnRefresh: true,
      data: (found) {
        // The merge in the provider pools every store's results; the seen sets
        // keep a row from appearing twice when two connections answer with the
        // same native id.
        final songs = <LibrarySong>[];
        final seenSongs = <String>{};
        for (final song in found.songs) {
          if (heldFingerprints.contains(TrackIdentity.of(song).fingerprint)) {
            continue;
          }
          final album = song.album?.trim().toLowerCase();
          if (album != null && heldAlbums.contains(album)) continue;
          if (!seenSongs.add('${song.sourceId}:${song.id}')) continue;
          songs.add(song);
        }
        final albums = <LibraryAlbum>[];
        final seenAlbums = <String>{};
        for (final album in found.albums) {
          if (heldAlbums.contains(album.name.trim().toLowerCase())) continue;
          if (!seenAlbums.add('${album.sourceId}:${album.id}')) continue;
          albums.add(album);
        }
        final playlists = <LibraryPlaylist>[];
        final seenPlaylists = <String>{};
        for (final playlist in found.playlists) {
          final key = '${playlist.sourceId}:${playlist.id}';
          if (heldPlaylists.contains(key)) continue;
          if (!seenPlaylists.add(key)) continue;
          playlists.add(playlist);
        }

        if (songs.isEmpty && albums.isEmpty && playlists.isEmpty) {
          // A store that answered entirely with things the library already
          // has is not a failed search; saying "no match" there would send
          // the user looking for a query that does not exist.
          return SliverToBoxAdapter(
            child: _SectionNote(
              text: found.isEmpty
                  ? 'searchInStoresEmpty'.tr(args: [query])
                  : 'searchExploreAllHeld'.tr(),
            ),
          );
        }

        return SliverMainAxisGroup(
          slivers: [
            if (albums.isNotEmpty)
              FoldableSection(
                page: _page,
                id: _albumsId,
                title: 'libraryAlbums'.tr(),
                trailing: _SeeAll(
                  shown: _albums,
                  total: albums.length,
                  onTap: () => setState(() => _albums = _widened),
                ),
                builder: () => [
                  SliverList.builder(
                    itemCount: albums.take(_albums).length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _StoreRow(
                        key: ValueKey('album:${album.sourceId}:${album.id}'),
                        title: album.name,
                        subtitle: album.artist ?? '',
                        store: _storeName(album.sourceId),
                        artId: album.artId,
                        sourceId: album.sourceId,
                        kind: CatalogKind.albums,
                        id: album.id,
                        onOpen: () => context.router.push(
                          AlbumDetailRoute(
                            sourceId: album.sourceId,
                            albumId: album.id,
                            albumName: album.name,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            if (playlists.isNotEmpty)
              FoldableSection(
                page: _page,
                id: _playlistsId,
                title: 'libraryPlaylists'.tr(),
                trailing: _SeeAll(
                  shown: _playlists,
                  total: playlists.length,
                  onTap: () => setState(() => _playlists = _widened),
                ),
                builder: () => [
                  SliverList.builder(
                    itemCount: playlists.take(_playlists).length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return _StoreRow(
                        key: ValueKey(
                          'playlist:${playlist.sourceId}:${playlist.id}',
                        ),
                        title: playlist.name,
                        subtitle: [
                          if (playlist.owner != null) playlist.owner!,
                          if (playlist.songCount != null)
                            queueSummary(playlist.songCount!, false),
                        ].join('  ·  '),
                        store: _storeName(playlist.sourceId),
                        artId: playlist.artId,
                        sourceId: playlist.sourceId,
                        kind: CatalogKind.playlists,
                        id: playlist.id,
                        fallbackIcon: Symbols.playlist_play,
                        onOpen: () => context.router.push(
                          PlaylistDetailRoute(
                            sourceId: playlist.sourceId,
                            playlistId: playlist.id,
                            playlistName: playlist.name,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            if (songs.isNotEmpty)
              FoldableSection(
                page: _page,
                id: _tracksId,
                title: 'libraryTracks'.tr(),
                trailing: _SeeAll(
                  shown: _tracks,
                  total: songs.length,
                  onTap: () => setState(() => _tracks = _widened),
                ),
                builder: () => [
                  SliverList.builder(
                    itemCount: songs.take(_tracks).length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return _StoreRow(
                        key: ValueKey('song:${song.sourceId}:${song.id}'),
                        title: song.title,
                        subtitle: song.subtitle,
                        store: _storeName(song.sourceId),
                        artId: song.artId,
                        sourceId: song.sourceId,
                        kind: CatalogKind.songs,
                        id: song.id,
                        playable: song,
                      );
                    },
                  ),
                ],
              ),
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: SolSpace.lg),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: _SectionNote(text: describeServerError(error)),
      ),
    );
  }

  /// The connected library that owns [sourceId], or null when it is gone.
  ///
  /// Read per row rather than per fold: a heading is one lookup for a block of
  /// rows, so one wrong answer there mislabels all of them.
  String? _storeName(String sourceId) {
    final name = ref.watch(librarySourceByIdProvider)[sourceId]?.displayName;
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// A store result: what it is, which store it would come from, and the button
/// that puts it in the library.
///
/// An album or a playlist opens its own page, because the store's page is how
/// a reader decides whether to add it — the row's subtitle cannot say what a
/// collection holds. A song is auditioned instead: tapping it plays the store
/// copy, which costs nothing and is the whole point of a search row.
class _StoreRow extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;

  /// The connected library this row would be added from. Null when the source
  /// is no longer connected — a row that outlived its connection.
  final String? store;
  final String? artId;
  final String sourceId;
  final CatalogKind kind;
  final String id;
  final IconData fallbackIcon;

  /// A song result, which can be auditioned before it is added. Null for
  /// albums and playlists, which are lists rather than something to play.
  final LibrarySong? playable;

  /// Opens a collection's own page. Null for songs, which play instead.
  final VoidCallback? onOpen;

  const _StoreRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artId,
    required this.sourceId,
    required this.kind,
    required this.id,
    this.store,
    this.fallbackIcon = Symbols.music_note_rounded,
    this.playable,
    this.onOpen,
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
    final onTap = widget.onOpen ?? (widget.playable == null ? null : _preview);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
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
                  fallbackIcon: widget.fallbackIcon,
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
                      // The store rides on the row's own line: a fold heading
                      // names a kind, and two stores can answer one query.
                      if (widget.store case final store?)
                        Text(
                          widget.subtitle.isEmpty
                              ? store
                              : '${widget.subtitle}  ·  $store',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else if (widget.subtitle.isNotEmpty)
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
                if (widget.onOpen != null)
                  Icon(
                    Symbols.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
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

/// One quiet line where a tab has nothing to show.
class _SectionNote extends StatelessWidget {
  final String text;

  const _SectionNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.sm,
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
