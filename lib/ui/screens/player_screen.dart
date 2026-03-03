import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:gap/gap.dart';
import 'package:groovybox/data/db.dart' as db;
import 'package:groovybox/data/track_repository.dart';

import 'package:groovybox/logic/lrc_providers.dart';
import 'package:groovybox/logic/lyrics_parser.dart';
import 'package:groovybox/logic/metadata_service.dart';
import 'package:groovybox/logic/window_helpers.dart';
import 'package:groovybox/providers/audio_provider.dart';
import 'package:groovybox/providers/db_provider.dart';
import 'package:groovybox/providers/lrc_fetcher_provider.dart';
import 'package:groovybox/providers/settings_provider.dart';
import 'package:groovybox/ui/widgets/mini_player.dart';
import 'package:groovybox/ui/widgets/track_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:media_kit/media_kit.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:window_manager/window_manager.dart';

enum ViewMode { cover, lyrics, queue }

class PlayerScreen extends HookConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;

    // Use the default player screen setting from main settings provider
    final settingsAsync = ref.watch(settingsProvider);
    final defaultPlayerScreen = settingsAsync.maybeWhen(
      data: (settings) => settings.defaultPlayerScreen,
      orElse: () => null, // Return null when loading/error
    );
    final viewMode = useState<ViewMode>(ViewMode.cover); // Start with cover

    // Update viewMode when defaultPlayerScreen setting is loaded
    useEffect(() {
      if (defaultPlayerScreen != null) {
        final newViewMode = switch (defaultPlayerScreen) {
          DefaultPlayerScreen.cover => ViewMode.cover,
          DefaultPlayerScreen.lyrics => ViewMode.lyrics,
          DefaultPlayerScreen.queue => ViewMode.queue,
        };
        viewMode.value = newViewMode;
      }
      return null;
    }, [defaultPlayerScreen]);
    final isMobile = MediaQuery.sizeOf(context).width <= 800;

    return StreamBuilder<Playlist>(
      stream: player.stream.playlist,
      initialData: player.state.playlist,
      builder: (context, snapshot) {
        final index = snapshot.data?.index ?? 0;
        final medias = snapshot.data?.medias ?? [];
        if (medias.isEmpty || index < 0 || index >= medias.length) {
          return Center(child: Text('noMediaSelected'.tr()));
        }
        final media = medias[index];

        final currentMetadata = ref.watch(currentTrackMetadataProvider);

        // Build blurred background if cover art is available
        Widget? background;
        final artBytes = currentMetadata?.artBytes;
        if (artBytes != null) {
          background = Positioned.fill(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: MemoryImage(artBytes),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        } else {
          background = null;
        }

        final devicePadding = MediaQuery.paddingOf(context);

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              switch (event.logicalKey) {
                case LogicalKeyboardKey.space:
                  if (player.state.playing) {
                    player.pause();
                  } else {
                    player.play();
                  }
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.bracketLeft:
                  player.previous();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.bracketRight:
                  player.next();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.escape:
                  Navigator.of(context).pop();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowUp:
                  player.setVolume(
                    (player.state.volume + 10).clamp(0, 100),
                  ); // Increase volume
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowDown:
                  player.setVolume(
                    (player.state.volume - 10).clamp(0, 100),
                  ); // Decrease volume
                  return KeyEventResult.handled;
                default:
                  return KeyEventResult.ignored;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            body: ClipRect(
              child: Stack(
                children: [
                  ...background != null ? [background] : [],
                  // Drag area for desktop platforms
                  if (isDesktopPlatform())
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: devicePadding.top + 60,
                      child: GestureDetector(
                        onPanStart: (details) => windowManager.startDragging(),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  // Main content (StreamBuilder)
                  Builder(
                    builder: (context) {
                      if (isMobile) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top:
                                devicePadding.top +
                                40 +
                                (isDesktopPlatform() ? 28 : 0),
                          ),
                          child: _MobileLayout(
                            player: player,
                            viewMode: viewMode,
                            media: media,
                            trackPath: media.uri,
                          ),
                        );
                      } else {
                        return _DesktopLayout(
                          player: player,
                          viewMode: viewMode,
                          media: media,
                          trackPath: media.uri,
                        );
                      }
                    },
                  ),
                  // IconButton
                  Positioned(
                    top:
                        devicePadding.top + 16 + (isDesktopPlatform() ? 28 : 0),
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Symbols.keyboard_arrow_down),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      iconSize: 24,
                    ),
                  ),
                  _ViewToggleButton(viewMode: viewMode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileLayout extends HookConsumerWidget {
  final Player player;
  final ValueNotifier<ViewMode> viewMode;
  final Media media;
  final String trackPath;

  const _MobileLayout({
    required this.player,
    required this.viewMode,
    required this.media,
    required this.trackPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMetadata = ref.watch(currentTrackMetadataProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (viewMode.value) {
        ViewMode.cover => _CoverView(
          key: const ValueKey('cover'),
          player: player,
          currentMetadata: currentMetadata,
          media: media,
          trackPath: trackPath,
        ).padding(bottom: MediaQuery.paddingOf(context).bottom),
        ViewMode.lyrics => _LyricsView(
          key: const ValueKey('lyrics'),
          player: player,
        ),
        ViewMode.queue => _QueueView(
          key: const ValueKey('queue'),
          player: player,
        ),
      },
    );
  }
}

class _PlayerCoverControlsPanel extends StatelessWidget {
  final Player player;
  final TrackMetadata? currentMetadata;
  final Media media;
  final String trackPath;

  const _PlayerCoverControlsPanel({
    required this.player,
    required this.currentMetadata,
    required this.media,
    required this.trackPath,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(480, MediaQuery.sizeOf(context).width * 0.4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _PlayerCoverArt(currentMetadata: currentMetadata),
                  ),
                ),
              ),
            ),
          ),
          _PlayerControls(
            player: player,
            currentMetadata: currentMetadata,
            media: media,
            trackPath: trackPath,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DesktopLayout extends HookConsumerWidget {
  final Player player;
  final ValueNotifier<ViewMode> viewMode;
  final Media media;
  final String trackPath;

  const _DesktopLayout({
    required this.player,
    required this.viewMode,
    required this.media,
    required this.trackPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMetadata = ref.watch(currentTrackMetadataProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (viewMode.value) {
        ViewMode.cover => Center(
          key: const ValueKey('cover'),
          child: _PlayerCoverControlsPanel(
            player: player,
            currentMetadata: currentMetadata,
            media: media,
            trackPath: trackPath,
          ),
        ),
        ViewMode.lyrics => Stack(
          key: const ValueKey('lyrics'),
          children: [
            // Left Side: Cover + Controls
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _PlayerCoverControlsPanel(
                        player: player,
                        currentMetadata: currentMetadata,
                        media: media,
                        trackPath: trackPath,
                      ),
                    ),
                  ),
                  Expanded(child: const SizedBox.shrink()),
                ],
              ),
            ),
            // Overlaid Lyrics on the right
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width * 0.6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _PlayerLyrics(player: player),
              ),
            ),
          ],
        ),
        ViewMode.queue => Stack(
          key: const ValueKey('queue'),
          children: [
            // Left Side: Cover + Controls
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _PlayerCoverControlsPanel(
                        player: player,
                        currentMetadata: currentMetadata,
                        media: media,
                        trackPath: trackPath,
                      ),
                    ),
                  ),
                  Expanded(child: const SizedBox.shrink()),
                ],
              ),
            ),
            // Overlaid Queue on the right
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width * 0.5,
              child: _QueueView(player: player).padding(right: 64),
            ),
          ],
        ),
      },
    );
  }
}

class _CoverView extends StatelessWidget {
  final Player player;
  final TrackMetadata? currentMetadata;
  final Media media;
  final String trackPath;

  const _CoverView({
    super.key,
    required this.player,
    required this.currentMetadata,
    required this.media,
    required this.trackPath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: _PlayerCoverArt(currentMetadata: currentMetadata),
              ),
            ),
          ),
          _PlayerControls(
            player: player,
            currentMetadata: currentMetadata,
            media: media,
            trackPath: trackPath,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LyricsView extends StatelessWidget {
  final Player player;

  const _LyricsView({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _PlayerLyrics(player: player),
          ),
        ),
        MiniPlayer(enableTapToOpen: false),
      ],
    );
  }
}

class _PlayerCoverArt extends StatelessWidget {
  final TrackMetadata? currentMetadata;

  const _PlayerCoverArt({required this.currentMetadata});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            image: () {
              final artBytes = currentMetadata?.artBytes;
              return artBytes != null
                  ? DecorationImage(
                      image: MemoryImage(artBytes),
                      fit: BoxFit.cover,
                    )
                  : null;
            }(),
          ),
          child: currentMetadata?.artBytes == null
              ? Center(
                  child: Icon(
                    Symbols.music_note,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _PlayerLyrics extends HookConsumerWidget {
  final Player player;

  const _PlayerLyrics({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for current track data (including lyrics)
    final currentTrack = ref.watch(currentTrackProvider);

    // For now, skip metadata loading to avoid provider issues
    final AsyncValue<TrackMetadata> metadataAsync = AsyncValue.data(
      TrackMetadata(),
    );

    final lyricsFetcher = ref.watch(lyricsFetcherProvider);
    final musixmatchProviderInstance = ref.watch(musixmatchProvider);
    final neteaseProviderInstance = ref.watch(neteaseProvider);
    final lrclibProviderInstance = ref.watch(lrclibProvider);

    // Simulate async behavior for compatibility
    if (currentTrack == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Convert CurrentTrackData to db.Track for compatibility
    final track = db.Track(
      id: currentTrack.id,
      title: currentTrack.title,
      artist: currentTrack.artist,
      album: currentTrack.album,
      path: currentTrack.path,
      lyrics: currentTrack.lyrics,
      lyricsOffset: currentTrack.lyricsOffset,
      duration: null,
      artUri: null,
      addedAt: DateTime.now(),
    );

    return _buildLyricsContent(
      track,
      metadataAsync,
      ref,
      lyricsFetcher,
      musixmatchProviderInstance,
      neteaseProviderInstance,
      lrclibProviderInstance,
      context,
    );
  }

  void _showFetchLyricsDialog(
    BuildContext context,
    WidgetRef ref,
    db.Track track,
    String trackPath,
    dynamic metadataObj,
    musixmatchProvider,
    neteaseProvider,
    lrclibProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => _FetchLyricsDialog(
        track: track,
        trackPath: trackPath,
        metadataObj: metadataObj,
        ref: ref,
        musixmatchProvider: musixmatchProvider,
        neteaseProvider: neteaseProvider,
        lrclibProvider: lrclibProvider,
      ),
    );
  }

  Widget _buildLyricsContent(
    db.Track track,
    AsyncValue<TrackMetadata> metadataAsync,
    WidgetRef ref,
    dynamic lyricsFetcher,
    dynamic musixmatchProviderInstance,
    dynamic neteaseProviderInstance,
    dynamic lrclibProviderInstance,
    BuildContext context,
  ) {
    // Get lyrics mode setting
    final lyricsMode = ref.watch(lyricsModeProvider);
    final isDesktop = MediaQuery.sizeOf(context).width > 800;

    // Determine if we should use curved (desktop-style) or flat (mobile-style) lyrics
    final useCurvedStyle = switch (lyricsMode) {
      LyricsMode.curved => true,
      LyricsMode.flat => false,
      LyricsMode.auto =>
        isDesktop, // Auto mode: curved on desktop, flat on mobile
    };
    if (track.lyrics == null) {
      // Show fetch lyrics UI
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('noLyricsAvailable'.tr()),
          const SizedBox(height: 16),

          if (lyricsFetcher.isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Symbols.download),
              label: Text('fetchLyrics'.tr()),
              onPressed: () => _showFetchLyricsDialog(
                context,
                ref,
                track,
                track.path,
                metadataAsync.value,
                musixmatchProviderInstance,
                neteaseProviderInstance,
                lrclibProviderInstance,
              ),
            ),
        ],
      );
    }

    try {
      final lyricsData = LyricsData.fromJsonString(track.lyrics!);

      if (lyricsData.type == 'timed') {
        return _TimedLyricsView(
          lyrics: lyricsData,
          player: player,
          track: track,
        );
      } else {
        // Plain text lyrics
        if (useCurvedStyle) {
          return ListWheelScrollView.useDelegate(
            itemExtent: 50,
            perspective: 0.001,
            offAxisFraction: isDesktop ? 1.5 : 0,
            squeeze: 1.0,
            diameterRatio: isDesktop
                ? 2
                : RenderListWheelViewport.defaultDiameterRatio,
            physics: const FixedExtentScrollPhysics(),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: lyricsData.lines.length,
              builder: (context, index) {
                final line = lyricsData.lines[index];
                return Align(
                  alignment: isDesktop
                      ? Alignment.centerRight
                      : Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop
                          ? MediaQuery.sizeOf(context).width * 0.4
                          : MediaQuery.sizeOf(context).width * 0.8,
                    ),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        line.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lyricsData.lines.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  lyricsData.lines[index].text,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              );
            },
          );
        }
      }
    } catch (e) {
      return Center(child: Text('errorLoadingLyrics'.tr(args: [e.toString()])));
    }
  }
}

class _FetchLyricsDialog extends StatelessWidget {
  final db.Track track;
  final String trackPath;
  final dynamic metadataObj;
  final WidgetRef ref;
  final LrcProvider musixmatchProvider;
  final LrcProvider neteaseProvider;
  final LrcProvider lrclibProvider;

  const _FetchLyricsDialog({
    required this.track,
    required this.trackPath,
    required this.metadataObj,
    required this.ref,
    required this.musixmatchProvider,
    required this.neteaseProvider,
    required this.lrclibProvider,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = metadataObj as TrackMetadata?;
    final searchTerm =
        '${metadata?.title ?? track.title} ${metadata?.artist ?? track.artist}'
            .trim();

    return AlertDialog(
      title: Text('fetchLyrics'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              children: [
                TextSpan(text: 'searchLyricsWith'.tr(args: [searchTerm.split(' ').first])),
                TextSpan(
                  text: ' $searchTerm',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text('whereToSearchLyrics'.tr()),
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Symbols.library_music),
                        title: Text('musixmatch'.tr()),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref
                        .read(lyricsFetcherProvider.notifier)
                        .fetchLyricsForTrack(
                          trackId: track.id,
                          searchTerm: searchTerm,
                          provider: musixmatchProvider,
                          trackPath: trackPath,
                        );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Symbols.music_video),
                  title: Text('netease'.tr()),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref
                        .read(lyricsFetcherProvider.notifier)
                        .fetchLyricsForTrack(
                          trackId: track.id,
                          searchTerm: searchTerm,
                          provider: neteaseProvider,
                          trackPath: trackPath,
                        );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Symbols.library_books),
                  title: Text('lrclib'.tr()),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref
                        .read(lyricsFetcherProvider.notifier)
                        .fetchLyricsForTrack(
                          trackId: track.id,
                          searchTerm: searchTerm,
                          provider: lrclibProvider,
                          trackPath: trackPath,
                        );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Symbols.file_upload),
                  title: Text('manualImport'.tr()),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _importLyricsForTrack(context, ref, track, trackPath);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
      ],
    );
  }

  Future<void> _importLyricsForTrack(
    BuildContext context,
    WidgetRef ref,
    db.Track track,
    String trackPath,
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
            'Imported ${lyricsData.lines.length} lyrics lines for "${track.title}"',
          ),
        ),
      );
    }
  }
}

class _LyricsAdjustButton extends HookConsumerWidget {
  final Player player;

  const _LyricsAdjustButton({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider);

    // For now, skip metadata loading to avoid provider issues
    final AsyncValue<TrackMetadata> metadataAsync = AsyncValue.data(
      TrackMetadata(),
    );
    final musixmatchProviderInstance = ref.watch(musixmatchProvider);
    final neteaseProviderInstance = ref.watch(neteaseProvider);
    final lrclibProviderInstance = ref.watch(lrclibProvider);

    // Don't show the button if there's no current track
    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Symbols.settings_applications),
      iconSize: 24,
      tooltip: 'adjustLyricsTiming'.tr(),
      onPressed: () => _showLyricsRefreshDialog(
        context,
        ref,
        currentTrack,
        metadataAsync,
        musixmatchProviderInstance,
        neteaseProviderInstance,
        lrclibProviderInstance,
      ),
      padding: EdgeInsets.zero,
    );
  }

  void _showFetchLyricsDialog(
    BuildContext context,
    WidgetRef ref,
    db.Track track,
    String trackPath,
    dynamic metadataObj,
    musixmatchProvider,
    neteaseProvider,
    lrclibProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => _FetchLyricsDialog(
        track: track,
        trackPath: trackPath,
        metadataObj: metadataObj,
        ref: ref,
        musixmatchProvider: musixmatchProvider,
        neteaseProvider: neteaseProvider,
        lrclibProvider: lrclibProvider,
      ),
    );
  }

  void _showLyricsRefreshDialog(
    BuildContext context,
    WidgetRef ref,
    CurrentTrackData currentTrack,
    AsyncValue<TrackMetadata> metadataAsync,
    musixmatchProvider,
    neteaseProvider,
    lrclibProvider,
  ) {
    // Convert CurrentTrackData to db.Track for compatibility
    final track = db.Track(
      id: currentTrack.id,
      title: currentTrack.title,
      artist: currentTrack.artist,
      album: currentTrack.album,
      path: currentTrack.path,
      lyrics: currentTrack.lyrics,
      lyricsOffset: currentTrack.lyricsOffset,
      duration: null,
      artUri: null,
      addedAt: DateTime.now(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('lyricsOptions'.tr()),
        content: Column(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              spacing: 8,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Symbols.refresh),
                        label: Text('refetch'.tr()),
                        onPressed: () {
                          Navigator.of(context).pop();
                          final metadata = metadataAsync.value;
                          _showFetchLyricsDialog(
                            context,
                            ref,
                            track,
                            currentTrack.path,
                            metadata,
                            musixmatchProvider,
                            neteaseProvider,
                            lrclibProvider,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Symbols.clear),
                        label: Text('clear'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          debugPrint('Clearing lyrics for track ${track.id}');
                          final database = ref.read(databaseProvider);
                          await (database.update(
                            database.tracks,
                          )..where((t) => t.id.equals(track.id))).write(
                            db.TracksCompanion(
                              lyrics: const drift.Value.absent(),
                            ),
                          );
                          debugPrint('Cleared lyrics from database');

                          // Update current track provider if this is the current track
                          final currentTrackNotifier = ref.read(
                            currentTrackProvider.notifier,
                          );
                          final currentTrackState = ref.watch(
                            currentTrackProvider,
                          );
                          if (currentTrackState != null &&
                              currentTrackState.id == track.id) {
                            final updatedTrack = currentTrackState.copyWith(
                              lyrics: null,
                            );
                            currentTrackNotifier.setTrack(updatedTrack);
                            debugPrint(
                              'Updated current track provider - cleared lyrics',
                            );
                          }

                          // Invalidate the track provider to refresh the UI
                          ref.invalidate(
                            trackByPathProvider(currentTrack.path),
                          );
                          debugPrint(
                            'Invalidated track provider for ${currentTrack.path}',
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Symbols.sync),
                    label: Text('liveLyricsSync'.tr()),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showLiveLyricsSyncDialog(
                        context,
                        ref,
                        track,
                        currentTrack.path,
                        player,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Symbols.tune),
                    label: Text('manualOffset'.tr()),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showLyricsOffsetDialog(
                        context,
                        ref,
                        track,
                        currentTrack.path,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }

  void _showLyricsOffsetDialog(
    BuildContext context,
    WidgetRef ref,
    db.Track track,
    String trackPath,
  ) {
    final offsetController = TextEditingController(
      text: track.lyricsOffset.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('adjustLyricsTiming'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'enterOffsetMs'.tr(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: offsetController,
              decoration: InputDecoration(labelText: 'offsetMs'.tr()),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              final offset = int.tryParse(offsetController.text) ?? 0;
              Navigator.of(context).pop();

              final database = ref.read(databaseProvider);
              await (database.update(database.tracks)
                    ..where((t) => t.id.equals(track.id)))
                  .write(db.TracksCompanion(lyricsOffset: drift.Value(offset)));

              // Invalidate the track provider to refresh the UI
              ref.invalidate(trackByPathProvider(trackPath));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLiveLyricsSyncDialog(
    BuildContext context,
    WidgetRef ref,
    db.Track track,
    String trackPath,
    Player player,
  ) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) => _LiveLyricsSyncDialog(
        track: track,
        trackPath: trackPath,
        player: player,
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final ValueNotifier<ViewMode> viewMode;

  const _ViewToggleButton({required this.viewMode});

  @override
  Widget build(BuildContext context) {
    IconData getIcon() {
      switch (viewMode.value) {
        case ViewMode.cover:
          return Symbols.album;
        case ViewMode.lyrics:
          return Symbols.lyrics;
        case ViewMode.queue:
          return Symbols.queue_music;
      }
    }

    String getTooltip() {
      switch (viewMode.value) {
        case ViewMode.cover:
          return 'showLyrics'.tr();
        case ViewMode.lyrics:
          return 'showQueue'.tr();
        case ViewMode.queue:
          return 'showCover'.tr();
      }
    }

    return Positioned(
      top:
          MediaQuery.of(context).padding.top +
          16 +
          (isDesktopPlatform() ? 28 : 0),
      right: 16,
      child: IconButton(
        icon: Icon(getIcon()),
        iconSize: 24,
        tooltip: getTooltip(),
        onPressed: () {
          switch (viewMode.value) {
            case ViewMode.cover:
              viewMode.value = ViewMode.lyrics;
              break;
            case ViewMode.lyrics:
              viewMode.value = ViewMode.queue;
              break;
            case ViewMode.queue:
              viewMode.value = ViewMode.cover;
              break;
          }
        },
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _QueueView extends HookConsumerWidget {
  final Player player;

  const _QueueView({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width <= 800;

    return Column(
      children: [
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
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
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
                  final trackAsync = ref.watch(trackByPathProvider(trackPath));

                  return trackAsync.when(
                    loading: () => SizedBox(
                      key: Key('loading_$index'),
                      height: 72,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => Dismissible(
                      key: Key('queue_item_error_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Symbols.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) => player.remove(index),
                      child: TrackTile(
                        leading: Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: TextStyle(fontSize: 14),
                        ).padding(right: 8),
                        track: db.Track(
                          id: -1,
                          path: trackPath,
                          title: Uri.parse(media.uri).pathSegments.last,
                          artist:
                              media.extras?['artist'] as String? ??
                              'Unknown Artist',
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
                    data: (track) =>
                        ReorderableDelayedDragStartListener(
                          index: index,
                          child: Dismissible(
                            key: Key('queue_item_$index'),
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
                              leading: Text(
                                (index + 1).toString().padLeft(2, '0'),
                                style: TextStyle(fontSize: 14),
                              ).padding(right: 8),
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
                                        'Unknown Artist',
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
                        ).clipRRect(
                          all: 8,
                          key: Key('queue_item_error_${index}_rect'),
                        ),
                  );
                },
              );
            },
          ),
        ),
        if (isMobile) MiniPlayer(enableTapToOpen: false),
      ],
    );
  }
}

class _TimedLyricsView extends HookConsumerWidget {
  final LyricsData lyrics;
  final Player player;
  final db.Track track;

  const _TimedLyricsView({
    required this.lyrics,
    required this.player,
    required this.track,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get lyrics mode setting
    final lyricsMode = ref.watch(lyricsModeProvider);
    final isDesktop = MediaQuery.sizeOf(context).width > 800;

    // Determine if we should use curved (desktop-style) or flat (mobile-style) lyrics
    final useCurvedStyle = switch (lyricsMode) {
      LyricsMode.curved => true,
      LyricsMode.flat => false,
      LyricsMode.auto =>
        isDesktop, // Auto mode: curved on desktop, flat on mobile
    };

    final listController = useMemoized(() => ListController(), []);
    final scrollController = useScrollController();
    final wheelScrollController = useMemoized(
      () => FixedExtentScrollController(),
      [],
    );
    final previousIndex = useState(-1);

    // Use track directly to access lyrics offset
    final lyricsOffset = track.lyricsOffset;

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final positionMs = position.inMilliseconds + lyricsOffset;

        // Find current line index
        int currentIndex = 0;
        for (int i = 0; i < lyrics.lines.length; i++) {
          if ((lyrics.lines[i].timeMs ?? 0) <= positionMs) {
            currentIndex = i;
          } else {
            break;
          }
        }

        // Auto-scroll when current line changes
        if (currentIndex != previousIndex.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            previousIndex.value = currentIndex;
            if (useCurvedStyle) {
              if (wheelScrollController.hasClients) {
                wheelScrollController.animateToItem(
                  currentIndex,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              }
            } else {
              listController.animateToItem(
                index: currentIndex,
                scrollController: scrollController,
                alignment: 0.5,
                duration: (_) => const Duration(milliseconds: 300),
                curve: (_) => Curves.easeOutCubic,
              );
            }
          });
        }

        final totalDurationMs = player.state.duration.inMilliseconds;

        if (useCurvedStyle) {
          return ListWheelScrollView.useDelegate(
            controller: wheelScrollController,
            itemExtent: 50,
            perspective: 0.001,
            offAxisFraction: isDesktop ? 1.5 : 0,
            squeeze: 1.0,
            diameterRatio: isDesktop
                ? 2
                : RenderListWheelViewport.defaultDiameterRatio,
            physics: const FixedExtentScrollPhysics(),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: lyrics.lines.length,
              builder: (context, index) {
                final line = lyrics.lines[index];
                final isActive = index == currentIndex;

                // Calculate progress within the current line for fill effect
                double progress = 0.0;
                if (isActive) {
                  final startTime = line.timeMs ?? 0;
                  final endTime = index < lyrics.lines.length - 1
                      ? (lyrics.lines[index + 1].timeMs ?? startTime)
                      : totalDurationMs;
                  if (endTime > startTime) {
                    progress =
                        ((positionMs - startTime) / (endTime - startTime))
                            .clamp(0.0, 1.0);
                  }
                }

                return Align(
                  alignment: isDesktop
                      ? Alignment.centerRight
                      : Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop
                          ? MediaQuery.sizeOf(context).width * 0.4
                          : MediaQuery.sizeOf(context).width * 0.8,
                    ),
                    child: InkWell(
                      onTap: () {
                        if (line.timeMs != null) {
                          player.seek(Duration(milliseconds: line.timeMs!));
                        }
                      },
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(
                                fontSize: isActive ? 18 : 16,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                              ),
                          textAlign: TextAlign.left,
                          child: () {
                            final displayText = line.text;

                            return isActive && progress > 0.0 && progress < 1.0
                                ? ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ],
                                      stops: [progress, progress],
                                    ).createShader(bounds),
                                    child: Text(
                                      displayText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                : Text(
                                    displayText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                          }(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }

        return SuperListView.builder(
          padding: EdgeInsets.only(
            top: 0.25 * MediaQuery.sizeOf(context).height,
            bottom: 0.25 * MediaQuery.sizeOf(context).height,
          ),
          listController: listController,
          controller: scrollController,
          itemCount: lyrics.lines.length,
          itemBuilder: (context, index) {
            final line = lyrics.lines[index];
            final isActive = index == currentIndex;

            // Calculate progress within the current line for fill effect
            double progress = 0.0;
            if (isActive) {
              final startTime = line.timeMs ?? 0;
              final endTime = index < lyrics.lines.length - 1
                  ? (lyrics.lines[index + 1].timeMs ?? startTime)
                  : totalDurationMs;
              if (endTime > startTime) {
                progress = ((positionMs - startTime) / (endTime - startTime))
                    .clamp(0.0, 1.0);
              }
            }

            return InkWell(
              onTap: () {
                if (line.timeMs != null) {
                  player.seek(Duration(milliseconds: line.timeMs!));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: isActive ? 20 : 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                  child: () {
                    final displayText = line.text;

                    return isActive && progress > 0.0 && progress < 1.0
                        ? ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ],
                              stops: [progress, progress],
                            ).createShader(bounds),
                            child: Text(displayText),
                          )
                        : Text(displayText);
                  }(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlayerControls extends HookWidget {
  final Player player;
  final TrackMetadata? currentMetadata;
  final Media media;
  final String trackPath;

  const _PlayerControls({
    required this.player,
    required this.currentMetadata,
    required this.media,
    required this.trackPath,
  });

  @override
  Widget build(BuildContext context) {
    final isDragging = useState(false);
    final dragValue = useState(0.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title & Artist
        Column(
          children: [
            Text(
              currentMetadata?.title ?? Uri.parse(media.uri).pathSegments.last,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              currentMetadata?.artist ?? 'Unknown Artist',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Progress Bar
        StreamBuilder<Duration>(
          stream: player.stream.position,
          initialData: player.state.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;

            return StreamBuilder<Duration>(
              stream: player.stream.duration,
              initialData: player.state.duration,
              builder: (context, durationSnapshot) {
                final totalDuration = durationSnapshot.data ?? Duration.zero;
                final max = totalDuration.inMilliseconds.toDouble();
                final positionValue = position.inMilliseconds.toDouble().clamp(
                  0.0,
                  max > 0 ? max : 0.0,
                );

                final currentValue = isDragging.value
                    ? dragValue.value
                    : positionValue;

                return Column(
                  children: [
                    Slider(
                      value: currentValue,
                      min: 0,
                      max: max > 0 ? max : 1.0,
                      onChanged: (val) {
                        isDragging.value = true;
                        dragValue.value = val;
                      },
                      onChangeEnd: (val) {
                        isDragging.value = false;
                        player.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(
                              Duration(milliseconds: currentValue.toInt()),
                            ),
                          ),
                          Text(formatDuration(totalDuration)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 16),

        // Media Controls
        Row(
          spacing: 8,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shuffle
            IconButton(
              icon: StreamBuilder<bool>(
                stream: player.stream.shuffle,
                initialData: player.state.shuffle,
                builder: (context, snapshot) {
                  final shuffle = snapshot.data ?? false;
                  return Icon(
                    Symbols.shuffle,
                    color: shuffle
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  );
                },
              ),
              onPressed: () {
                player.setShuffle(!player.state.shuffle);
              },
            ),
            // Previous
            IconButton(
              icon: const Icon(Symbols.skip_previous, size: 32),
              onPressed: player.previous,
            ),
            // Play/Pause
            StreamBuilder<bool>(
              stream: player.stream.playing,
              initialData: player.state.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return IconButton.filled(
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
                      fill: 1,
                      key: ValueKey<bool>(playing),
                      size: 48,
                    ),
                  ),
                  onPressed: playing ? player.pause : player.play,
                  iconSize: 48,
                );
              },
            ),
            // Next
            IconButton(
              icon: const Icon(Symbols.skip_next, size: 32),
              onPressed: player.next,
            ),
            // Loop Mode
            IconButton(
              icon: StreamBuilder<PlaylistMode>(
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
                  return Icon(icon, color: color);
                },
              ),
              onPressed: () {
                final mode = player.state.playlistMode;
                switch (mode) {
                  case PlaylistMode.none:
                    player.setPlaylistMode(PlaylistMode.single);
                    break;
                  case PlaylistMode.single:
                    player.setPlaylistMode(PlaylistMode.loop);
                    break;
                  case PlaylistMode.loop:
                    player.setPlaylistMode(PlaylistMode.none);
                    break;
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Volume Slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            spacing: 16,
            children: [
              _LyricsAdjustButton(player: player),
              Expanded(
                child: StreamBuilder<double>(
                  stream: player.stream.volume,
                  builder: (context, snapshot) {
                    final volume = snapshot.data ?? 100.0;
                    return Row(
                      children: [
                        Icon(
                          volume == 0
                              ? Symbols.volume_off
                              : volume < 50
                              ? Symbols.volume_down
                              : Symbols.volume_up,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Slider(
                            value: volume,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: volume.round().toString(),
                            onChanged: (value) {
                              player.setVolume(value);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Provider to fetch a single track by path
final trackByPathProvider = FutureProvider.family<db.Track?, String>((
  ref,
  trackPath,
) async {
  final database = ref.watch(databaseProvider);
  return (database.select(
    database.tracks,
  )..where((t) => t.path.equals(trackPath))).getSingleOrNull();
});

// Dialog for live lyrics synchronization
class _LiveLyricsSyncDialog extends HookConsumerWidget {
  final db.Track track;
  final String trackPath;
  final Player player;

  const _LiveLyricsSyncDialog({
    required this.track,
    required this.trackPath,
    required this.player,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tempOffset = useState(track.lyricsOffset);

    return Scaffold(
      appBar: AppBar(
        title: Text('liveLyricsSync'.tr()),
        leading: IconButton(
          icon: const Icon(Symbols.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.check),
            onPressed: () async {
              // Store context before async operation
              final navigator = Navigator.of(context);

              // Save the adjusted offset
              final database = ref.read(databaseProvider);
              await (database.update(
                database.tracks,
              )..where((t) => t.id.equals(track.id))).write(
                db.TracksCompanion(lyricsOffset: drift.Value(tempOffset.value)),
              );

              // Update current track provider if this is the current track
              final currentTrackNotifier = ref.read(
                currentTrackProvider.notifier,
              );
              final currentTrack = ref.watch(currentTrackProvider);
              if (currentTrack != null && currentTrack.id == track.id) {
                final updatedTrack = currentTrack.copyWith(
                  lyricsOffset: tempOffset.value,
                );
                currentTrackNotifier.setTrack(updatedTrack);
                debugPrint(
                  'Updated current track provider with new lyrics offset',
                );
              }

              // Invalidate the track provider to refresh the UI
              ref.invalidate(trackByPathProvider(trackPath));

              navigator.pop();
            },
            tooltip: 'Save',
          ),
          const Gap(8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.max(480, MediaQuery.sizeOf(context).width * 0.4),
          ),
          child: Column(
            children: [
              // Current offset display
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('offset'.tr(args: [tempOffset.value.toString()])),
                  ],
                ),
              ),

              // Offset adjustment buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Symbols.fast_rewind),
                      label: Text('minus100ms'.tr()),
                      onPressed: () =>
                          tempOffset.value = (tempOffset.value - 100),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Symbols.skip_previous),
                      label: Text('plus10ms'.tr()),
                      onPressed: () =>
                          tempOffset.value = (tempOffset.value - 10),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Symbols.refresh),
                      label: Text('reset'.tr()),
                      onPressed: () => tempOffset.value = 0,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Symbols.skip_next),
                      label: Text('plus10ms'.tr()),
                      onPressed: () =>
                          tempOffset.value = (tempOffset.value + 10),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Symbols.fast_forward),
                      label: Text('plus100ms'.tr()),
                      onPressed: () =>
                          tempOffset.value = (tempOffset.value + 100),
                    ),
                  ],
                ),
              ),

              // Fine adjustment slider
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('fineAdjustment'.tr()),
                    Slider(
                      value: tempOffset.value.toDouble().clamp(-5000.0, 5000.0),
                      min: -5000,
                      max: 5000,
                      divisions: 100,
                      label: '${tempOffset.value}ms',
                      onChanged: (value) => tempOffset.value = value.toInt(),
                    ),
                  ],
                ),
              ),

              // Player controls
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Symbols.skip_previous, size: 32),
                      onPressed: player.previous,
                    ),
                    const SizedBox(width: 16),
                    StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return IconButton.filled(
                          icon: Icon(
                            playing ? Symbols.pause : Symbols.play_arrow,
                            size: 48,
                          ),
                          onPressed: playing ? player.pause : player.play,
                          iconSize: 48,
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Symbols.skip_next, size: 32),
                      onPressed: player.next,
                    ),
                  ],
                ),
              ),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: StreamBuilder<Duration>(
                  stream: player.stream.position,
                  initialData: player.state.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    return StreamBuilder<Duration>(
                      stream: player.stream.duration,
                      initialData: player.state.duration,
                      builder: (context, durationSnapshot) {
                        final totalDuration =
                            durationSnapshot.data ?? Duration.zero;
                        final max = totalDuration.inMilliseconds.toDouble();
                        final positionValue = position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, max > 0 ? max : 0.0);

                        return Column(
                          children: [
                            Slider(
                              value: positionValue,
                              min: 0,
                              max: max > 0 ? max : 1.0,
                              onChanged: (val) => player.seek(
                                Duration(milliseconds: val.toInt()),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(
                                      Duration(
                                        milliseconds: positionValue.toInt(),
                                      ),
                                    ),
                                  ),
                                  Text(_formatDuration(totalDuration)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Lyrics preview with live offset
              Expanded(
                child: _LiveLyricsPreview(
                  track: track,
                  player: player,
                  tempOffset: tempOffset.value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Widget for live lyrics preview with temporary offset
class _LiveLyricsPreview extends HookConsumerWidget {
  final db.Track track;
  final Player player;
  final int tempOffset;

  const _LiveLyricsPreview({
    required this.track,
    required this.player,
    required this.tempOffset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final lyricsData = LyricsData.fromJsonString(track.lyrics!);

      if (lyricsData.type != 'timed') {
        return Center(child: Text('onlyTimedLyricsCanBeSynced'.tr()));
      }

      return StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final positionMs = position.inMilliseconds + tempOffset;

          // Find current line index
          int currentIndex = 0;
          for (int i = 0; i < lyricsData.lines.length; i++) {
            if ((lyricsData.lines[i].timeMs ?? 0) <= positionMs) {
              currentIndex = i;
            } else {
              break;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lyricsData.lines.length,
            itemBuilder: (context, index) {
              final line = lyricsData.lines[index];
              final isActive = index == currentIndex;

              // Calculate progress within the current line for fill effect
              double progress = 0.0;
              if (isActive) {
                final startTime = line.timeMs ?? 0;
                final endTime = index < lyricsData.lines.length - 1
                    ? (lyricsData.lines[index + 1].timeMs ?? startTime)
                    : player.state.duration.inMilliseconds;
                if (endTime > startTime) {
                  progress = ((positionMs - startTime) / (endTime - startTime))
                      .clamp(0.0, 1.0);
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: isActive ? 18 : 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                  child: () {
                    final displayText = kDebugMode
                        ? '[${_formatTimestamp(line.timeMs ?? 0)}] ${line.text}'
                        : line.text;

                    return isActive && progress > 0.0 && progress < 1.0
                        ? ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ],
                              stops: [progress, progress],
                            ).createShader(bounds),
                            child: Text(displayText),
                          )
                        : Text(displayText);
                  }(),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      return Center(child: Text('errorLoadingLyrics'.tr(args: [e.toString()])));
    }
  }
}

// Helper function to format milliseconds as timestamp
String _formatTimestamp(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  final millisecondsPart =
      (duration.inMilliseconds % 1000) ~/ 10; // Show centiseconds
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millisecondsPart.toString().padLeft(2, '0')}';
}
