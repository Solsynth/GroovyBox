import 'package:easy_localization/easy_localization.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gap/gap.dart';
import 'package:groovybox/data/db.dart';
import 'package:groovybox/data/playlist_repository.dart';

import 'package:groovybox/providers/audio_provider.dart';
import 'package:groovybox/ui/widgets/track_tile.dart';
import 'package:groovybox/ui/widgets/universal_image.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';

class AlbumDetailScreen extends HookConsumerWidget {
  final AlbumData album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playlistRepositoryProvider.notifier);
    final tracksAsync = repo.watchAlbumTracks(album.album);

    // Responsive breakpoints
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLargeScreen = screenWidth > 900;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Full width app bar
          SliverAppBar(pinned: true, title: Text(album.album)),
          // Album cover section (full width on large screens, constrained on mobile)
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                boxShadow: [BoxShadow(blurRadius: 4)],
              ),
              constraints: const BoxConstraints(maxWidth: 320),
              child: AspectRatio(
                aspectRatio: 1,
                child: album.artUri != null
                    ? UniversalImage(uri: album.artUri!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Symbols.album,
                          size: 120,
                          color: Colors.white54,
                        ),
                      ),
              ).clipRRect(all: 16),
            ).center().padding(top: 16),
          ),
          // Content section with constrained width
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLargeScreen ? 800 : double.infinity,
                ),
                child: StreamBuilder<List<Track>>(
                  stream: tracksAsync,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final tracks = snapshot.data!;
                    if (tracks.isEmpty) {
                      return SizedBox(
                        height: 200,
                        child: Center(child: Text('noTracksInAlbum'.tr())),
                      );
                    }

                    return Column(
                      children: [
                        // Action buttons
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              spacing: 12,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      _playAlbum(ref, tracks);
                                    },
                                    icon: const Icon(Symbols.play_arrow),
                                    label: Text('playAll'.tr()),
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _addToQueue(ref, tracks);
                                    },
                                    icon: const Icon(Symbols.queue_music),
                                    label: Text('addToQueue'.tr()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Track list
                        ...List.generate(tracks.length, (index) {
                          return _buildTrackTile(
                            ref,
                            tracks,
                            index,
                            isLargeScreen,
                          );
                        }),
                        // Gap for mini player
                        const Gap(80),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(
    WidgetRef ref,
    List<Track> tracks,
    int index,
    bool isLargeScreen,
  ) {
    final track = tracks[index];
    return TrackTile(
      track: track,
      leading: Text(
        '${index + 1}'.padLeft(2, '0'),
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ).padding(right: isLargeScreen ? 24 : 16),
      showTrailingIcon: false,
      onTap: () {
        _playAlbum(ref, tracks, initialIndex: index);
      },
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 24 : 16,
        vertical: 8,
      ),
    );
  }

  void _playAlbum(WidgetRef ref, List<Track> tracks, {int initialIndex = 0}) {
    final loadingNotifier = ref.read(remoteTrackLoadingProvider.notifier);
    final audioHandler = ref.read(audioHandlerProvider);
    loadingNotifier.setLoading(true);
    audioHandler.playTracks(tracks, initialIndex: initialIndex).then((_) {
      loadingNotifier.setLoading(false);
    });
  }

  void _addToQueue(WidgetRef ref, List<Track> tracks) async {
    final audioHandler = ref.read(audioHandlerProvider);

    // Add tracks one by one to avoid interrupting playback
    for (final track in tracks) {
      try {
        final mediaItem = await _trackToMediaItem(track);
        await audioHandler.addQueueItem(mediaItem);
      } catch (e) {
        debugPrint('Error adding track ${track.title} to queue: $e');
      }
    }
  }

  Future<MediaItem> _trackToMediaItem(Track track) async {
    Uri? artUri;

    if (track.artUri != null) {
      // Check if it's a network URL or local file path
      if (track.artUri!.startsWith('http://') ||
          track.artUri!.startsWith('https://')) {
        // For remote tracks, skip artwork to avoid authentication issues
        // The artwork will be loaded separately when the track is played
        if (!track.path.startsWith('groovybox://')) {
          // Only try to cache artwork for non-remote tracks
          try {
            final cachedFile = await DefaultCacheManager().getSingleFile(
              track.artUri!,
            );
            artUri = Uri.file(cachedFile.path);
          } catch (e) {
            // If caching fails, skip artwork
            debugPrint('Failed to cache artwork for ${track.title}: $e');
          }
        }
        // For remote tracks, don't set artUri to avoid authentication issues
      } else {
        // It's a local file path
        artUri = Uri.file(track.artUri!);
      }
    }

    return MediaItem(
      id: track.path,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: track.duration != null
          ? Duration(milliseconds: track.duration!)
          : null,
      artUri: artUri,
    );
  }
}


