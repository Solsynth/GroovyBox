import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:groovybox/data/db.dart' as db;
import 'package:groovybox/logic/metadata_service.dart';
import 'package:groovybox/providers/audio_provider.dart';
import 'package:groovybox/providers/theme_provider.dart';
import 'package:groovybox/providers/remote_provider.dart';
import 'package:groovybox/providers/db_provider.dart';
import 'package:groovybox/providers/settings_provider.dart';

class AudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final media_kit.Player _player;
  List<MediaItem> _queue = [];
  int _queueIndex = 0;
  ProviderContainer? _container;

  AudioHandler() : _player = media_kit.Player() {
    // Configure for audio
    // _player.setPlaylistMode(PlaylistMode.loop); // Optional

    // Listen to player state changes and broadcast to audio_service
    _player.stream.playing.listen((playing) {
      _broadcastPlaybackState();
    });

    _player.stream.position.listen((position) {
      _broadcastPlaybackState();
    });

    _player.stream.duration.listen((duration) {
      _broadcastPlaybackState();
    });

    _player.stream.playlist.listen((playlist) {
      if (playlist.medias.isNotEmpty) {
        final currentIndex = playlist.index;
        if (currentIndex >= 0 && currentIndex < _queue.length) {
          _queueIndex = currentIndex;
          final currentItem = _queue[_queueIndex];
          mediaItem.add(currentItem);
          _updateThemeFromCurrentTrack(currentItem);
        }
      }
    });

    _player.stream.completed.listen((completed) async {
      if (completed && _container != null) {
        final continuePlays = _container!
            .read(settingsProvider)
            .when(
              data: (settings) => settings.continuePlays,
              loading: () => false,
              error: (_, _) => false,
            );

        if (continuePlays && _queueIndex == _queue.length - 1) {
          final oldLength = _queue.length;
          await _addRandomTracksToQueue();
          _queueIndex = oldLength; // Point to first new track
          await _updatePlaylist();
          _broadcastPlaybackState();
        }
      }
    });
  }

  // Method to set the provider container for theme updates
  void setProviderContainer(ProviderContainer container) {
    _container = container;
  }

  // Update theme color based on current track's album art and set current metadata and track
  void _updateThemeFromCurrentTrack(MediaItem mediaItem) async {
    if (_container == null) return;

    try {
      TrackMetadata? metadata;
      db.Track? track;

      // Set loading state for remote tracks
      final urlResolver = _container!.read(remoteUrlResolverProvider);
      final isRemoteTrack = urlResolver.isProtocolUrl(mediaItem.id);

      final loadingNotifier = _container!.read(
        remoteTrackLoadingProvider.notifier,
      );
      loadingNotifier.setLoading(true);

      // For remote tracks, get metadata from database
      if (isRemoteTrack) {
        final database = _container!.read(databaseProvider);
        track = await (database.select(
          database.tracks,
        )..where((t) => t.path.equals(mediaItem.id))).getSingleOrNull();

        if (track != null) {
          // Fetch album art bytes for remote tracks
          Uint8List? artBytes;
          if (track.artUri != null) {
            final imageFile = await DefaultCacheManager().getSingleFile(
              track.artUri!,
            );
            artBytes = await imageFile.readAsBytes();
          }

          metadata = TrackMetadata(
            title: track.title,
            artist: track.artist,
            album: track.album,
            artBytes: artBytes,
          );

          // Update theme from album art
          final seedColorNotifier = _container!.read(
            seedColorProvider.notifier,
          );
          seedColorNotifier.updateFromAlbumArtBytes(artBytes);
        }
      } else {
        // For local tracks, get from database and use metadata service
        final database = _container!.read(databaseProvider);
        track = await (database.select(
          database.tracks,
        )..where((t) => t.path.equals(mediaItem.id))).getSingleOrNull();

        // Use metadata service for local tracks
        final metadataService = MetadataService();
        metadata = await metadataService.getMetadata(mediaItem.id);

        // Update theme from album art
        final seedColorNotifier = _container!.read(seedColorProvider.notifier);
        seedColorNotifier.updateFromAlbumArtBytes(metadata.artBytes);
      }

      // Clear loading state
      loadingNotifier.setLoading(false);

      // Set current track
      final trackNotifier = _container!.read(currentTrackProvider.notifier);
      if (track != null) {
        trackNotifier.setTrack(CurrentTrackData.fromTrack(track));
      } else {
        trackNotifier.clear();
      }

      // Set current track metadata
      final metadataNotifier = _container!.read(
        currentTrackMetadataProvider.notifier,
      );
      if (metadata != null) {
        metadataNotifier.setMetadata(metadata);
      } else {
        metadataNotifier.clear();
      }
    } catch (e) {
      // Clear loading state on error
      final loadingNotifier = _container!.read(
        remoteTrackLoadingProvider.notifier,
      );
      loadingNotifier.setLoading(false);

      // If metadata retrieval fails, reset to default color and clear metadata/track
      final seedColorNotifier = _container!.read(seedColorProvider.notifier);
      seedColorNotifier.resetToDefault();

      final trackNotifier = _container!.read(currentTrackProvider.notifier);
      trackNotifier.clear();

      final metadataNotifier = _container!.read(
        currentTrackMetadataProvider.notifier,
      );
      metadataNotifier.clear();
    }
  }

  media_kit.Player get player => _player;

  // AudioService callbacks
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_queueIndex < _queue.length - 1) {
      _queueIndex++;
      await _player.jump(_queueIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queueIndex > 0) {
      _queueIndex--;
      await _player.jump(_queueIndex);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      _queueIndex = index;
      await _player.jump(index);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queue.add(mediaItem);
    queue.add(_queue);
    await _updatePlaylist();
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    if (index >= 0 && index <= _queue.length) {
      _queue.insert(index, mediaItem);
      queue.add(_queue);
      await _updatePlaylist();
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    _queue.remove(mediaItem);
    queue.add(_queue);
    await _updatePlaylist();
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _queue = List.from(queue);
    this.queue.add(_queue);
    await _updatePlaylist();
  }

  Future<void> _updatePlaylist() async {
    if (_container == null) {
      // Fallback if container not set
      final medias = _queue.map((item) => media_kit.Media(item.id)).toList();
      if (medias.isNotEmpty) {
        await _player.open(media_kit.Playlist(medias, index: _queueIndex));
      }
      return;
    }

    final urlResolver = _container!.read(remoteUrlResolverProvider);
    final medias = <media_kit.Media>[];

    for (final item in _queue) {
      String uri = item.id;

      // Check if this is a protocol URL that needs resolution
      if (urlResolver.isProtocolUrl(item.id)) {
        final resolvedUrl = await urlResolver.resolveUrl(item.id);
        if (resolvedUrl != null) {
          uri = resolvedUrl;
        } else {
          // If resolution fails, skip this track or use original URL
          continue;
        }
      }

      // Store the original track path in extras for queue lookup
      medias.add(media_kit.Media(uri, extras: {'trackPath': item.id}));
    }

    if (medias.isNotEmpty) {
      await _player.open(media_kit.Playlist(medias, index: _queueIndex));
    }
  }

  void _broadcastPlaybackState() {
    final playing = _player.state.playing;
    final position = _player.state.position;
    final duration = _player.state.duration;

    // Get current media item metadata if available
    MediaItem? currentMediaItem;
    if (_queueIndex >= 0 && _queueIndex < _queue.length) {
      currentMediaItem = _queue[_queueIndex];
    }

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: position,
        bufferedPosition: duration,
        speed: 1.0,
        queueIndex: _queueIndex,
      ),
    );

    // Update media item separately if we have current track info
    if (currentMediaItem != null) {
      mediaItem.add(currentMediaItem);
    }
  }

  // New methods that accept Track objects with proper metadata
  Future<void> playTrack(db.Track track) async {
    final mediaItem = await _trackToMediaItem(track);
    await updateQueue([mediaItem]);
  }

  Future<void> playTracks(List<db.Track> tracks, {int initialIndex = 0}) async {
    final mediaItems = await Future.wait(tracks.map(_trackToMediaItem));
    _queueIndex = initialIndex;
    await updateQueue(mediaItems);
  }

  Future<MediaItem> _trackToMediaItem(db.Track track) async {
    Uri? artUri;

    if (track.artUri != null) {
      // Check if it's a network URL or local file path
      if (track.artUri!.startsWith('http://') ||
          track.artUri!.startsWith('https://')) {
        // It's a network URL, cache it and get local file path
        try {
          final cachedFile = await DefaultCacheManager().getSingleFile(
            track.artUri!,
          );
          artUri = Uri.file(cachedFile.path);
        } catch (e) {
          // If caching fails, try to use the network URL directly
          artUri = Uri.parse(track.artUri!);
        }
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

  Future<void> openPlaylist(
    List<media_kit.Media> medias, {
    int initialIndex = 0,
  }) async {
    final mediaItems = medias.map((media) {
      return MediaItem(
        id: media.uri,
        album: 'Unknown Album',
        title: _extractTitleFromPath(media.uri),
        artist: 'Unknown Artist',
      );
    }).toList();

    _queueIndex = initialIndex;
    await updateQueue(mediaItems);
  }

  Future<void> _addRandomTracksToQueue() async {
    if (_container == null) return;

    try {
      final database = _container!.read(databaseProvider);

      // Get paths of tracks already in queue to avoid duplicates
      final existingPaths = _queue.map((item) => item.id).toSet();

      // Query for tracks not in current queue
      final allTracks = await (database.select(
        database.tracks,
      )..where((t) => t.path.isNotIn(existingPaths))).get();

      // Shuffle and take 10 random tracks
      allTracks.shuffle();
      final tracks = allTracks.take(10).toList();

      if (tracks.isEmpty) return;

      // Convert to MediaItems
      final newMediaItems = await Future.wait(tracks.map(_trackToMediaItem));

      // Add to queue
      _queue.addAll(newMediaItems);

      // Update the broadcasted queue
      queue.add(_queue);
    } catch (e) {
      // Silently handle errors to avoid interrupting playback
      debugPrint('Error adding random tracks to queue: $e');
    }
  }

  String _extractTitleFromPath(String path) {
    return path.split('/').last.split('.').first;
  }

  void dispose() {
    _player.dispose();
  }
}
