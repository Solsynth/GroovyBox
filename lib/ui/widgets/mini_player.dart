import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:groovybox/data/db.dart' as db;

import 'package:groovybox/providers/audio_provider.dart';
import 'package:groovybox/ui/screens/player_screen.dart';
import 'package:groovybox/ui/widgets/track_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:media_kit/media_kit.dart';
import 'package:styled_widget/styled_widget.dart';

class MiniPlayer extends HookConsumerWidget {
  final bool enableTapToOpen;

  const MiniPlayer({super.key, this.enableTapToOpen = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.sizeOf(context).width > 800;

    if (isDesktop) {
      return _DesktopMiniPlayer(enableTapToOpen: enableTapToOpen);
    } else {
      return _MobileMiniPlayer(enableTapToOpen: enableTapToOpen);
    }
  }
}

class _MobileMiniPlayer extends HookConsumerWidget {
  final bool enableTapToOpen;

  const _MobileMiniPlayer({required this.enableTapToOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;

    final isDragging = useState(false);
    final dragValue = useState(0.0);

    return StreamBuilder<Playlist>(
      stream: player.stream.playlist,
      initialData: player.state.playlist,
      builder: (context, snapshot) {
        final index = snapshot.data?.index ?? 0;
        final medias = snapshot.data?.medias ?? [];
        if (medias.isEmpty || index < 0 || index >= medias.length) {
          return const SizedBox.shrink();
        }
        final media = medias[index];

        final devicePadding = MediaQuery.paddingOf(context);

        final currentMetadata = ref.watch(currentTrackMetadataProvider);
        final isRemoteTrackLoading = ref.watch(remoteTrackLoadingProvider);

        Widget content = Container(
          height: 72 + devicePadding.bottom,
          padding: EdgeInsets.only(bottom: devicePadding.bottom),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress Bar
              SizedBox(
                height: 4,
                width: double.infinity,
                child: isRemoteTrackLoading
                    ? LinearProgressIndicator(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : StreamBuilder<Duration>(
                        stream: player.stream.position,
                        initialData: player.state.position,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            initialData: player.state.duration,
                            builder: (context, durationSnapshot) {
                              final total =
                                  durationSnapshot.data ?? Duration.zero;
                              final max = total.inMilliseconds.toDouble();
                              final positionValue = position.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, max > 0 ? max : 0.0);

                              final currentValue = isDragging.value
                                  ? dragValue.value
                                  : positionValue;

                              return SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  overlayShape: SliderComponentShape.noOverlay,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  trackShape:
                                      const RectangularSliderTrackShape(),
                                ),
                                child: Slider(
                                  padding: EdgeInsets.zero,
                                  value: currentValue,
                                  min: 0,
                                  max: max > 0 ? max : 1.0,
                                  onChanged: (val) {
                                    isDragging.value = true;
                                    dragValue.value = val;
                                  },
                                  onChangeEnd: (val) {
                                    isDragging.value = false;
                                    player.seek(
                                      Duration(milliseconds: val.toInt()),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              Expanded(
                child: Row(
                  children: [
                    // Cover Art
                    AspectRatio(
                      aspectRatio: 1,
                      child: currentMetadata?.artBytes != null
                          ? Image.memory(
                              currentMetadata!.artBytes!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Symbols.music_note,
                                color: Colors.white54,
                              ),
                            ),
                    ).clipRRect(all: 8).padding(left: 8, vertical: 8),
                    // Title & Artist
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentMetadata?.title ??
                                  Uri.parse(media.uri).pathSegments.last,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentMetadata?.artist ?? 'unknownArtist'.tr(),
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Next Button
                    IconButton(
                      icon: const Icon(Symbols.skip_previous),
                      onPressed: player.previous,
                      iconSize: 24,
                      visualDensity: const VisualDensity(horizontal: -4),
                      padding: EdgeInsets.all(8),
                    ),
                    // Play/Pause Button
                    StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: IconButton.filled(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 100),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                              child: Icon(
                                playing
                                    ? Symbols.pause_rounded
                                    : Symbols.play_arrow_rounded,
                                key: ValueKey<bool>(playing),
                                fill: 1,
                              ),
                            ),
                            onPressed: playing ? player.pause : player.play,
                          ),
                        );
                      },
                    ),
                    const Gap(12),
                  ],
                ),
              ),
            ],
          ),
        );

        if (enableTapToOpen) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const PlayerScreen(),
                ),
              );
            },
            child: content,
          );
        } else {
          return content;
        }
      },
    );
  }
}

class _DesktopMiniPlayer extends HookConsumerWidget {
  final bool enableTapToOpen;

  const _DesktopMiniPlayer({required this.enableTapToOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;

    final isDragging = useState(false);
    final dragValue = useState(0.0);

    return StreamBuilder<Playlist>(
      stream: player.stream.playlist,
      initialData: player.state.playlist,
      builder: (context, snapshot) {
        final index = snapshot.data?.index ?? 0;
        final medias = snapshot.data?.medias ?? [];
        if (medias.isEmpty || index < 0 || index >= medias.length) {
          return const SizedBox.shrink();
        }
        final media = medias[index];

        final devicePadding = MediaQuery.paddingOf(context);

        final currentMetadata = ref.watch(currentTrackMetadataProvider);
        final isRemoteTrackLoading = ref.watch(remoteTrackLoadingProvider);

        Widget content = Container(
          height: 72 + devicePadding.bottom,
          width: double.infinity,
          padding: EdgeInsets.only(bottom: devicePadding.bottom),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress Bar
              SizedBox(
                height: 4,
                width: double.infinity,
                child: isRemoteTrackLoading
                    ? LinearProgressIndicator(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : StreamBuilder<Duration>(
                        stream: player.stream.position,
                        initialData: player.state.position,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            initialData: player.state.duration,
                            builder: (context, durationSnapshot) {
                              final total =
                                  durationSnapshot.data ?? Duration.zero;
                              final max = total.inMilliseconds.toDouble();
                              final positionValue = position.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, max > 0 ? max : 0.0);

                              final currentValue = isDragging.value
                                  ? dragValue.value
                                  : positionValue;

                              return SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  overlayShape: SliderComponentShape.noOverlay,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  trackShape:
                                      const RectangularSliderTrackShape(),
                                ),
                                child: Slider(
                                  padding: EdgeInsets.zero,
                                  value: currentValue,
                                  min: 0,
                                  max: max > 0 ? max : 1.0,
                                  onChanged: (val) {
                                    isDragging.value = true;
                                    dragValue.value = val;
                                  },
                                  onChangeEnd: (val) {
                                    isDragging.value = false;
                                    player.seek(
                                      Duration(milliseconds: val.toInt()),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Row(
                        children: [
                          // Cover Art
                          AspectRatio(
                            aspectRatio: 1,
                            child: currentMetadata?.artBytes != null
                                ? Image.memory(
                                    currentMetadata!.artBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Symbols.music_note,
                                      color: Colors.white54,
                                    ),
                                  ),
                          ).clipRRect(all: 8).padding(left: 8, vertical: 8),
                          // Title & Artist
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentMetadata?.title ??
                                        Uri.parse(media.uri).pathSegments.last,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    currentMetadata?.artist ?? 'unknownArtist'.tr(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Playback Controls
                    Flexible(
                      flex: 7,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Loop Toggle
                          StreamBuilder<PlaylistMode>(
                            stream: player.stream.playlistMode,
                            initialData: player.state.playlistMode,
                            builder: (context, snapshot) {
                              final mode = snapshot.data ?? PlaylistMode.none;
                              IconData icon;
                              Color? color;
                              switch (mode) {
                                case PlaylistMode.none:
                                  icon = Symbols.repeat;
                                  color = Theme.of(context).disabledColor;
                                  break;
                                case PlaylistMode.single:
                                  icon = Symbols.repeat_one;
                                  color = Theme.of(context).colorScheme.primary;
                                  break;
                                case PlaylistMode.loop:
                                  icon = Symbols.repeat;
                                  color = Theme.of(context).colorScheme.primary;
                                  break;
                              }
                              return IconButton(
                                icon: Icon(icon, color: color),
                                onPressed: () {
                                  final mode = player.state.playlistMode;
                                  switch (mode) {
                                    case PlaylistMode.none:
                                      player.setPlaylistMode(
                                        PlaylistMode.single,
                                      );
                                      break;
                                    case PlaylistMode.single:
                                      player.setPlaylistMode(PlaylistMode.loop);
                                      break;
                                    case PlaylistMode.loop:
                                      player.setPlaylistMode(PlaylistMode.none);
                                      break;
                                  }
                                },
                                iconSize: 20,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Symbols.skip_previous),
                            onPressed: player.previous,
                            iconSize: 24,
                          ),
                          StreamBuilder<bool>(
                            stream: player.stream.playing,
                            initialData: player.state.playing,
                            builder: (context, snapshot) {
                              final playing = snapshot.data ?? false;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: IconButton.filled(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 100),
                                    transitionBuilder:
                                        (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          );
                                        },
                                    child: Icon(
                                      playing
                                          ? Symbols.pause_rounded
                                          : Symbols.play_arrow_rounded,
                                      fill: 1,
                                      key: ValueKey<bool>(playing),
                                    ),
                                  ),
                                  onPressed: playing
                                      ? player.pause
                                      : player.play,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Symbols.skip_next),
                            onPressed: player.next,
                            iconSize: 24,
                          ),
                          IconButton(
                            icon: const Icon(Symbols.queue_music),
                            onPressed: () =>
                                _showQueueDialog(context, ref, player),
                            iconSize: 24,
                          ),
                        ],
                      ),
                    ),
                    // Volume Slider
                    Flexible(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            Symbols.volume_up,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: StreamBuilder<double>(
                              stream: player.stream.volume,
                              builder: (context, snapshot) {
                                final volume = snapshot.data ?? 100.0;
                                return Slider(
                                  value: volume,
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  label: volume.round().toString(),
                                  onChanged: (value) {
                                    player.setVolume(value);
                                  },
                                );
                              },
                            ).padding(right: 24),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (enableTapToOpen) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const PlayerScreen(),
                ),
              );
            },
            child: content,
          );
        } else {
          return content;
        }
      },
    );
  }

  void _showQueueDialog(BuildContext context, WidgetRef ref, Player player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                children: [
                  Text('queue'.tr(), style: TextStyle(fontSize: 20)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Symbols.close),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<Playlist>(
                stream: player.stream.playlist,
                initialData: player.state.playlist,
                builder: (context, snapshot) {
                  final playlist = snapshot.data;
                  if (playlist == null || playlist.medias.isEmpty) {
                    return Center(child: Text('noTracksInQueue'.tr()));
                  }

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: playlist.medias.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      player.move(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final media = playlist.medias[index];
                      final isCurrent = index == playlist.index;
                      final trackPath = media.extras?['trackPath'] ?? media.uri;
                      final trackAsync = ref.watch(
                        trackByPathProvider(trackPath),
                      );

                      return trackAsync.when(
                        loading: () => SizedBox(
                          key: Key('loading_$index'),
                          height: 72,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (error, stack) => Dismissible(
                          key: Key('queue_item_error_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Symbols.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) => player.remove(index),
                          child: TrackTile(
                            key: Key('track_tile_error_$index'),
                            leading: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                (index + 1).toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            track: db.Track(
                              id: -1,
                              path: trackPath,
                              title: Uri.parse(media.uri).pathSegments.last,
                              artist:
                                          media.extras?['artist'] as String? ??
                                          'unknownArtist'.tr(),
                              album: media.extras?['album'] as String?,
                              duration: null,
                              artUri: null,
                              lyrics: null,
                              lyricsOffset: 0,
                              addedAt: DateTime.now(),
                            ),
                            isPlaying: isCurrent,
                            onTap: () => player.jump(index),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                        data: (track) => ClipRRect(
                          key: Key('queue_item_$index'),
                          borderRadius: BorderRadius.circular(8),
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: Dismissible(
                              key: Key('dismissible_$index'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Symbols.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (direction) => player.remove(index),
                              child: TrackTile(
                                leading: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    (index + 1).toString().padLeft(2, '0'),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                track:
                                    track ??
                                    db.Track(
                                      id: -1,
                                      path: trackPath,
                                      title: Uri.parse(
                                        media.uri,
                                      ).pathSegments.last,
                                      artist:
                                          media.extras?['artist'] as String? ??
                                          'unknownArtist'.tr(),
                                      album: media.extras?['album'] as String?,
                                      duration: null,
                                      artUri: null,
                                      lyrics: null,
                                      lyricsOffset: 0,
                                      addedAt: DateTime.now(),
                                    ),
                                isPlaying: isCurrent,
                                onTap: () => player.jump(index),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


