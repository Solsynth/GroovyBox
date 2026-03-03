import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:groovybox/data/db.dart';
import 'package:groovybox/data/playlist_repository.dart';
import 'package:groovybox/data/track_repository.dart';

import 'package:groovybox/logic/lyrics_parser.dart';
import 'package:groovybox/logic/window_helpers.dart';
import 'package:groovybox/providers/audio_provider.dart';
import 'package:groovybox/providers/watch_folder_provider.dart';
import 'package:groovybox/router.dart';
import 'package:groovybox/ui/tabs/albums_tab.dart';
import 'package:groovybox/ui/tabs/playlists_tab.dart';
import 'package:groovybox/ui/widgets/track_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:styled_widget/styled_widget.dart';

class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({super.key});

  static const List<String> audioExtensions = [
    'mp3',
    'm4a',
    'wav',
    'flac',
    'aac',
    'ogg',
    'wma',
    'm4p',
    'aiff',
    'au',
    'dss',
  ];

  static const List<String> lyricsExtensions = ['lrc', 'srt', 'txt'];

  static const List<String> allAllowedExtensions = [
    ...audioExtensions,
    ...lyricsExtensions,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We can define a stream provider locally or in repository file.
    // For now, using StreamBuilder is easiest since `watchAllTracks` returns a Stream.
    // Or better: `ref.watch(trackListStreamProvider)`.

    // Let's assume we use StreamBuilder for now to avoid creating another file/provider on the fly.
    final repo = ref.watch(trackRepositoryProvider.notifier);
    final selectedTrackIds = useState<Set<int>>({});
    final searchQuery = useState<String>('');
    final isSelectionMode = selectedTrackIds.value.isNotEmpty;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final isExtraLargeScreen = MediaQuery.of(context).size.width > 800;
    final selectedTab = isLargeScreen ? useState<int>(0) : null;

    void toggleSelection(int id) {
      final newSet = Set<int>.from(selectedTrackIds.value);
      if (newSet.contains(id)) {
        newSet.remove(id);
      } else {
        newSet.add(id);
      }
      selectedTrackIds.value = newSet;
    }

    void clearSelection() {
      selectedTrackIds.value = {};
    }

    if (isLargeScreen) {
      return Scaffold(
        appBar: isSelectionMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Symbols.close),
                  color: Theme.of(context).colorScheme.onPrimary,
                  onPressed: clearSelection,
                ),
                title: Text(
                  'selected'.tr(args: [selectedTrackIds.value.length.toString()]),
                ).textColor(Theme.of(context).colorScheme.onPrimary),
                backgroundColor: Theme.of(context).colorScheme.primary,
                actions: [
                  IconButton(
                    icon: const Icon(Symbols.playlist_add),
                    color: Theme.of(context).colorScheme.onPrimary,
                    tooltip: 'addToPlaylist'.tr(),
                    onPressed: () {
                      _batchAddToPlaylist(
                        context,
                        ref,
                        selectedTrackIds.value.toList(),
                        clearSelection,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Symbols.delete),
                    color: Theme.of(context).colorScheme.onPrimary,
                    tooltip: 'delete'.tr(),
                    onPressed: () {
                      _batchDelete(
                        context,
                        ref,
                        selectedTrackIds.value.toList(),
                        clearSelection,
                      );
                    },
                  ),
                  const Gap(8),
                ],
              )
            : (isDesktopPlatform()
                  ? null
                  : AppBar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      title: isLargeScreen
                          ? Row(
                              children: [
                                const Gap(4),
                                Image.asset(
                                  'assets/images/icon.jpg',
                                  width: 32,
                                  height: 32,
                                ).clipRRect(all: 8).padding(vertical: 16),
                                const Gap(12),
                                Text(
                                  'GroovyBox',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            )
                          : Text('library'.tr()),
                      actions: [
                        IconButton(
                          onPressed: () {
                            ref.read(routerProvider).push(AppRoutes.settings);
                          },
                          icon: const Icon(Symbols.settings),
                        ),
                        IconButton(
                          icon: const Icon(Symbols.add_circle_outline),
                          tooltip: 'importFiles'.tr(),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.any,
                              allowMultiple: true,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              final paths = result.files
                                  .map((f) => f.path)
                                  .whereType<String>()
                                  .toList();
                              if (paths.isNotEmpty) {
                                // Separate audio and lyrics files
                                final audioPaths = paths.where((path) {
                                  final ext = p
                                      .extension(path)
                                      .toLowerCase()
                                      .replaceFirst('.', '');
                                  return audioExtensions.contains(ext);
                                }).toList();
                                final lyricsPaths = paths.where((path) {
                                  final ext = p
                                      .extension(path)
                                      .toLowerCase()
                                      .replaceFirst('.', '');
                                  return lyricsExtensions.contains(ext);
                                }).toList();

                                // Import tracks if any
                                if (audioPaths.isNotEmpty) {
                                  await repo.importFiles(audioPaths);
                                }

                                // Import lyrics if any
                                if (!context.mounted) return;
                                if (lyricsPaths.isNotEmpty) {
                                  await _batchImportLyricsFromPaths(
                                    context,
                                    ref,
                                    lyricsPaths,
                                  );
                                }
                              }
                            }
                          },
                        ),
                        const Gap(8),
                      ],
                    )),
        body: Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: Colors.transparent,
                extended: isExtraLargeScreen,
                selectedIndex: selectedTab!.value,
                onDestinationSelected: (index) => selectedTab.value = index,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Symbols.audiotrack),
                    label: Text('tracks'.tr()),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Symbols.album),
                    label: Text('albums'.tr()),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Symbols.queue_music),
                    label: Text('playlists'.tr()),
                  ),
                ],
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                  ),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: _buildTabContent(
                      selectedTab.value,
                      ref,
                      repo,
                      selectedTrackIds,
                      searchQuery,
                      toggleSelection,
                      isSelectionMode,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: isSelectionMode
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Symbols.close),
                    color: Theme.of(context).colorScheme.onPrimary,
                    onPressed: clearSelection,
                  ),
                  title: Text(
                    'selected'.tr(args: [selectedTrackIds.value.length.toString()]),
                  ).textColor(Theme.of(context).colorScheme.onPrimary),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  actions: [
                    IconButton(
                      icon: const Icon(Symbols.playlist_add),
                      tooltip: 'addToPlaylist'.tr(),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () {
                        _batchAddToPlaylist(
                          context,
                          ref,
                          selectedTrackIds.value.toList(),
                          clearSelection,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Symbols.delete),
                      tooltip: 'delete'.tr(),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () {
                        _batchDelete(
                          context,
                          ref,
                          selectedTrackIds.value.toList(),
                          clearSelection,
                        );
                      },
                    ),
                    const Gap(8),
                  ],
                )
              : AppBar(
                  centerTitle: true,
                  title: Text('library'.tr()),
                  bottom: TabBar(
                    tabs: [
                      Tab(text: 'tracks'.tr(), icon: Icon(Symbols.audiotrack)),
                      Tab(text: 'albums'.tr(), icon: Icon(Symbols.album)),
                      Tab(text: 'playlists'.tr(), icon: Icon(Symbols.queue_music)),
                    ],
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        ref.read(routerProvider).push(AppRoutes.settings);
                      },
                      icon: const Icon(Symbols.settings),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.add_circle_outline),
                      tooltip: 'importFiles'.tr(),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final paths = result.files
                              .map((f) => f.path)
                              .whereType<String>()
                              .toList();
                          if (paths.isNotEmpty) {
                            // Separate audio and lyrics files
                            final audioPaths = paths.where((path) {
                              final ext = p
                                  .extension(path)
                                  .toLowerCase()
                                  .replaceFirst('.', '');
                              return audioExtensions.contains(ext);
                            }).toList();
                            final lyricsPaths = paths.where((path) {
                              final ext = p
                                  .extension(path)
                                  .toLowerCase()
                                  .replaceFirst('.', '');
                              return lyricsExtensions.contains(ext);
                            }).toList();

                            // Import tracks if any
                            if (audioPaths.isNotEmpty) {
                              await repo.importFiles(audioPaths);
                            }

                            // Import lyrics if any
                            if (!context.mounted) return;
                            if (lyricsPaths.isNotEmpty) {
                              await _batchImportLyricsFromPaths(
                                context,
                                ref,
                                lyricsPaths,
                              );
                            }
                          }
                        }
                      },
                    ),
                    const Gap(8),
                  ],
                ),
          body: TabBarView(
            children: [
              _buildTracksTab(
                ref,
                repo,
                selectedTrackIds,
                searchQuery,
                toggleSelection,
                isSelectionMode,
              ),
              const AlbumsTab(),
              const PlaylistsTab(),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTracksTab(
    WidgetRef ref,
    dynamic repo,
    ValueNotifier<Set<int>> selectedTrackIds,
    ValueNotifier<String> searchQuery,
    void Function(int) toggleSelection,
    bool isSelectionMode,
  ) {
    return StreamBuilder<List<Track>>(
      stream: repo.watchAllTracks(),
      builder: (context, snapshot) {
        // Calculate hintText
        String hintText;
        if (!snapshot.hasData || snapshot.hasError) {
          hintText = 'searchTracks'.tr();
        } else {
          final tracks = snapshot.data!;
          final totalTracks = tracks.length;
          if (searchQuery.value.isEmpty) {
            hintText = 'searchTracksWithCount'.tr(args: [totalTracks.toString()]);
          } else {
            final query = searchQuery.value.toLowerCase();
            final filteredCount = tracks.where((track) {
              if (track.title.toLowerCase().contains(query)) return true;
              if (track.artist?.toLowerCase().contains(query) ?? false) {
                return true;
              }
              if (track.album?.toLowerCase().contains(query) ?? false) {
                return true;
              }
              if (track.lyrics != null) {
                try {
                  final lyricsData = LyricsData.fromJsonString(track.lyrics!);
                  for (final line in lyricsData.lines) {
                    if (line.text.toLowerCase().contains(query)) return true;
                  }
                } catch (e) {
                  // Ignore parsing errors
                }
              }
              return false;
            }).length;
            hintText = 'searchTracksFiltered'.tr()
                .replaceAll('{}', filteredCount.toString())
                .replaceAll('{}', totalTracks.toString());
          }
        }

        // Determine main content
        Widget mainContent;
        if (snapshot.hasError) {
          mainContent = Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          mainContent = const Center(child: CircularProgressIndicator());
        } else {
          final tracks = snapshot.data!;
          if (tracks.isEmpty) {
            mainContent = Center(child: Text('noTracksYet'.tr()));
          } else {
            List<Track> filteredTracks;
            if (searchQuery.value.isEmpty) {
              filteredTracks = tracks;
            } else {
              final query = searchQuery.value.toLowerCase();
              filteredTracks = tracks.where((track) {
                if (track.title.toLowerCase().contains(query)) return true;
                if (track.artist?.toLowerCase().contains(query) ?? false) {
                  return true;
                }
                if (track.album?.toLowerCase().contains(query) ?? false) {
                  return true;
                }
                if (track.lyrics != null) {
                  try {
                    final lyricsData = LyricsData.fromJsonString(track.lyrics!);
                    for (final line in lyricsData.lines) {
                      if (line.text.toLowerCase().contains(query)) return true;
                    }
                  } catch (e) {
                    // Ignore parsing errors
                  }
                }
                return false;
              }).toList();
            }

            if (filteredTracks.isEmpty && searchQuery.value.isNotEmpty) {
              mainContent = Center(
                child: Text('noTracksMatchSearch'.tr()),
              );
            } else {
              mainContent = ListView.builder(
                padding: EdgeInsets.only(
                  bottom: 72 + MediaQuery.paddingOf(context).bottom,
                  top: 80,
                ),
                itemCount: filteredTracks.length,
                itemBuilder: (context, index) {
                  final track = filteredTracks[index];
                  final isSelected = selectedTrackIds.value.contains(track.id);

                  if (isSelectionMode) {
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.white10,
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (_) => toggleSelection(track.id),
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${track.artist ?? 'unknownArtist'.tr()} - ${_formatDuration(track.duration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => toggleSelection(track.id),
                    );
                  }

                  return Dismissible(
                    key: Key('track_${track.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Symbols.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('deleteTrack'.tr()),
                            content: Text(
                              'confirmDeleteTrack'.tr(args: [track.title]),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text('cancel'.tr()),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: Text('delete'.tr()),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) {
                      ref
                          .read(trackRepositoryProvider.notifier)
                          .deleteTrack(track.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'deletedTrack'.tr(args: [track.title]),
                          ),
                        ),
                      );
                    },
                    child: TrackTile(
                      track: track,
                      showTrailingIcon: true,
                      onTrailingPressed: () =>
                          _showTrackOptions(context, ref, track),
                      onLongPress: () => toggleSelection(track.id),
                      onTap: () {
                        final loadingNotifier = ref.read(
                          remoteTrackLoadingProvider.notifier,
                        );
                        final audio = ref.read(audioHandlerProvider);
                        loadingNotifier.setLoading(true);
                        audio.playTrack(track).then((_) {
                          loadingNotifier.setLoading(false);
                        });
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  );
                },
              );
            }
          }
        }

        return Stack(
          children: [
            mainContent,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SearchBar(
                  onChanged: (value) => searchQuery.value = value,
                  hintText: hintText,
                  leading: const Icon(Symbols.search),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabContent(
    int index,
    WidgetRef ref,
    dynamic repo,
    ValueNotifier<Set<int>> selectedTrackIds,
    ValueNotifier<String> searchQuery,
    void Function(int) toggleSelection,
    bool isSelectionMode,
  ) {
    switch (index) {
      case 0:
        return _buildTracksTab(
          ref,
          repo,
          selectedTrackIds,
          searchQuery,
          toggleSelection,
          isSelectionMode,
        );
      case 1:
        return const AlbumsTab();
      case 2:
        return const PlaylistsTab();
      default:
        return const SizedBox();
    }
  }

  void _showTrackOptions(BuildContext context, WidgetRef ref, Track track) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Symbols.playlist_add),
                title: Text('addToPlaylist'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(context, ref, track);
                },
              ),
              ListTile(
                leading: const Icon(Symbols.info),
                title: Text('viewDetails'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _showTrackDetails(context, ref, track);
                },
              ),
              ListTile(
                leading: const Icon(Symbols.edit),
                title: Text('editMetadata'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, ref, track);
                },
              ),
              ListTile(
                leading: const Icon(Symbols.lyrics),
                title: Text('importLyrics'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _importLyricsForTrack(context, ref, track);
                },
              ),
              ListTile(
                leading: const Icon(Symbols.delete, color: Colors.red),
                title: Text(
                  'deleteTrack'.tr(),
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(trackRepositoryProvider.notifier)
                      .deleteTrack(track.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) {
    final screenSize = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (context) {
        // Fetch playlists
        // Note: Using a hook/provider inside dialog builder might need a Consumer or similar if stream updates.
        // For simplicity, we'll assume the user wants to pick from *current* playlists.
        // Or we can use a Consumer widget inside the dialog.
        return AlertDialog(
          title: Text('addToPlaylist'.tr()),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.8,
              maxHeight: screenSize.height * 0.6,
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final playlistsAsync = ref
                    .watch(playlistRepositoryProvider.notifier)
                    .watchAllPlaylists();
                return StreamBuilder<List<Playlist>>(
                  stream: playlistsAsync,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final playlists = snapshot.data!;
                    if (playlists.isEmpty) {
                      return Text(
                        'noPlaylistsAvailable'.tr(),
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: playlists.map((playlist) {
                          return ListTile(
                            title: Text(playlist.name),
                            onTap: () {
                              ref
                                  .read(playlistRepositoryProvider.notifier)
                                  .addToPlaylist(playlist.id, track.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'addedToPlaylist'.tr(args: [playlist.name]),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showTrackDetails(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) async {
    // Try to get file info
    String fileSize = 'unknown'.tr();
    String libraryName = 'unknown'.tr();
    String dateAdded = 'unknown'.tr();

    try {
      final file = File(track.path);
      if (await file.exists()) {
        final stat = await file.stat();
        final sizeInMB = (stat.size / (1024 * 1024)).toStringAsFixed(2);
        fileSize = '$sizeInMB MB';
        dateAdded = stat.modified.toString().split(
          ' ',
        )[0]; // Just the date part
      }
    } catch (e) {
      // Ignore file access errors
    }

    // Try to find which library this track belongs to
    final watchFoldersAsync = ref.read(watchFoldersProvider);
    watchFoldersAsync.whenData((folders) {
      for (final folder in folders) {
        if (track.path.startsWith(folder.path)) {
          libraryName = folder.name;
          break;
        }
      }
    });

    if (!context.mounted) return;

    final screenSize = MediaQuery.sizeOf(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('trackDetails'.tr()),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenSize.width * 0.8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('title'.tr(), track.title),
                _buildDetailRow('artist'.tr(), track.artist ?? 'Unknown'),
                _buildDetailRow('album'.tr(), track.album ?? 'Unknown'),
                _buildDetailRow('duration'.tr(), _formatDuration(track.duration)),
                _buildDetailRow('fileSize'.tr(), fileSize),
                _buildDetailRow('library'.tr(), libraryName),
                _buildDetailRow('filePath'.tr(), track.path),
                _buildDetailRow('dateAdded'.tr(), dateAdded),
                if (track.artUri != null)
                  _buildDetailRow('albumArt'.tr(), 'Present'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Track track) {
    final titleController = TextEditingController(text: track.title);
    final artistController = TextEditingController(text: track.artist);
    final albumController = TextEditingController(text: track.album);
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('editTrack'.tr()),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenSize.width * 0.8),
          child: Column(
            spacing: 16,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'title'.tr()),
              ),
              TextField(
                controller: artistController,
                decoration: InputDecoration(labelText: 'artist'.tr()),
              ),
              TextField(
                controller: albumController,
                decoration: InputDecoration(labelText: 'album'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(trackRepositoryProvider.notifier)
                  .updateMetadata(
                    trackId: track.id,
                    title: titleController.text,
                    artist: artistController.text,
                    album: albumController.text,
                  );
              Navigator.pop(context);
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return '--:--';
    final d = Duration(milliseconds: durationMs);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _batchAddToPlaylist(
    BuildContext context,
    WidgetRef ref,
    List<int> trackIds,
    VoidCallback onSuccess,
  ) {
    final screenSize = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('addToPlaylist'.tr()),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.8,
              maxHeight: screenSize.height * 0.6,
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final playlistsAsync = ref
                    .watch(playlistRepositoryProvider.notifier)
                    .watchAllPlaylists();
                return StreamBuilder<List<Playlist>>(
                  stream: playlistsAsync,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final playlists = snapshot.data!;
                    if (playlists.isEmpty) {
                      return Text('noPlaylistsAvailable'.tr());
                    }

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: playlists.map((playlist) {
                          return ListTile(
                            title: Text(playlist.name),
                            onTap: () async {
                              final repo = ref.read(
                                playlistRepositoryProvider.notifier,
                              );
                              for (final id in trackIds) {
                                await repo.addToPlaylist(playlist.id, id);
                              }
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              onSuccess();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${'added'.tr()} ${trackIds.length} ${'tracks'.tr()} ${'to'.tr()} ${playlist.name}',
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _batchDelete(
    BuildContext context,
    WidgetRef ref,
    List<int> trackIds,
    VoidCallback onSuccess,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('deleteTracks'.tr()),
        content: Text(
          '${'confirmDelete'.tr()} ${trackIds.length} ${'tracks'.tr()}? '
          '${'thisWillRemoveThemFromYourDevice'.tr()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(trackRepositoryProvider.notifier);
      for (final id in trackIds) {
        await repo.deleteTrack(id);
      }
      onSuccess();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${'deleted'.tr()} ${trackIds.length} ${'tracks'.tr()}',
          ),
        ),
      );
    }
  }

  Future<void> _importLyricsForTrack(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'srt', 'txt'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final filename = result.files.first.name;

      final lyricsData = LyricsParser.parse(content, filename);
      final lyricsJson = lyricsData.toJsonString();

      await ref
          .read(trackRepositoryProvider.notifier)
          .updateLyrics(track.id, lyricsJson);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${'imported'.tr()} ${lyricsData.lines.length} ${'lyricsLines'.tr()} for "${track.title}"',
          ),
        ),
      );
    }
  }

  Future<void> _batchImportLyricsFromPaths(
    BuildContext context,
    WidgetRef ref,
    List<String> lyricsPaths,
  ) async {
    if (lyricsPaths.isEmpty) return;

    final repo = ref.read(trackRepositoryProvider.notifier);
    final tracks = await repo.getAllTracks();

    int matched = 0;
    int notMatched = 0;

    for (final path in lyricsPaths) {
      final file = File(path);
      final content = await file.readAsString();
      final filename = p.basename(path);

      // Get basename without extension for matching
      final baseName = filename
          .replaceAll(RegExp(r'\.(lrc|srt|txt)$', caseSensitive: false), '')
          .toLowerCase();

      // Try to find a matching track by title
      final matchingTrack = tracks.where((t) {
        final trackTitle = t.title.toLowerCase();
        return trackTitle == baseName ||
            trackTitle.contains(baseName) ||
            baseName.contains(trackTitle);
      }).firstOrNull;

      if (matchingTrack != null) {
        final lyricsData = LyricsParser.parse(content, filename);
        await repo.updateLyrics(matchingTrack.id, lyricsData.toJsonString());
        matched++;
      } else {
        notMatched++;
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${'batchImportComplete'.tr()} $matched ${'matched'.tr()}, $notMatched ${'notMatched'.tr()}',
        ),
      ),
    );
  }
}
