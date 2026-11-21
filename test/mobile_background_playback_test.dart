import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/session.dart';

void main() {
  group('Mobile background playback & audio session', () {
    const testSong = LibrarySong(
      id: 'song-1',
      sourceId: 'src-1',
      title: 'Echoes',
      artist: 'Pink Floyd',
      album: 'Meddle',
      duration: Duration(minutes: 23, seconds: 31),
    );

    test('AudioSnapshot contains buffering and itemOf metadata', () {
      final item = AudioSnapshot.itemOf(testSong, artUri: Uri.parse('https://example.com/art.jpg'));
      expect(item.id, equals('src-1:song-1'));
      expect(item.title, equals('Echoes'));
      expect(item.artist, equals('Pink Floyd'));
      expect(item.album, equals('Meddle'));
      expect(item.duration, equals(const Duration(minutes: 23, seconds: 31)));
      expect(item.artUri, equals(Uri.parse('https://example.com/art.jpg')));

      final snapshot = AudioSnapshot(
        items: [item],
        index: 0,
        playing: true,
        buffering: true,
        position: const Duration(seconds: 45),
        repeatMode: AudioServiceRepeatMode.none,
        shuffle: false,
      );

      expect(snapshot.buffering, isTrue);
      expect(snapshot.playing, isTrue);
    });

    test('GroovyBoxAudioHandler reports AudioProcessingState.buffering when buffering', () {
      final handler = GroovyBoxAudioHandler();
      final item = AudioSnapshot.itemOf(testSong);

      handler.publish(AudioSnapshot(
        items: [item],
        index: 0,
        playing: true,
        buffering: true,
        position: const Duration(seconds: 10),
        repeatMode: AudioServiceRepeatMode.all,
        shuffle: true,
      ));

      expect(handler.playbackState.value.processingState, equals(AudioProcessingState.buffering));
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.playbackState.value.repeatMode, equals(AudioServiceRepeatMode.all));
      expect(handler.playbackState.value.shuffleMode, equals(AudioServiceShuffleMode.all));
      expect(
        handler.playbackState.value.systemActions,
        containsAll([
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        ]),
      );

      // Once buffering stops, it transitions to ready
      handler.publish(AudioSnapshot(
        items: [item],
        index: 0,
        playing: true,
        buffering: false,
        position: const Duration(seconds: 12),
        repeatMode: AudioServiceRepeatMode.none,
        shuffle: false,
      ));

      expect(handler.playbackState.value.processingState, equals(AudioProcessingState.ready));
    });

    test('the handler stands down while the platform player owns playback', () async {
      final handler = GroovyBoxAudioHandler();
      final item = AudioSnapshot.itemOf(testSong);

      // Start from an active app-owned session so standing down has a real
      // transition to retire.
      handler.publish(AudioSnapshot(
        items: [item],
        index: 0,
        playing: true,
        position: const Duration(seconds: 10),
        repeatMode: AudioServiceRepeatMode.none,
        shuffle: false,
      ));
      expect(handler.playbackState.value.processingState, AudioProcessingState.ready);
      expect(handler.playbackState.value.playing, isTrue);

      final states = <PlaybackState>[];
      final sub = handler.playbackState.skip(1).listen(states.add);
      addTearDown(sub.cancel);

      // The system player publishes its own now-playing entry; publishing the
      // app's as well — or leaving `playing: true` on Darwin — activates
      // MPRemoteCommandCenter / MPNowPlayingInfoCenter and shows a duplicate
      // session in macOS Control Center.
      handler.publish(AudioSnapshot(
        items: [item],
        index: 0,
        playing: true,
        position: const Duration(seconds: 10),
        repeatMode: AudioServiceRepeatMode.none,
        shuffle: false,
        platformOwned: true,
      ));
      await pumpEventQueue();

      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
        reason: 'idle retires the app entry so only MusicKit reports',
      );
      expect(handler.mediaItem.value, isNull);
      expect(handler.queue.value, isEmpty);
      expect(
        handler.playbackState.value.playing,
        isFalse,
        reason: 'playing: true wakes audio_service on macOS even when idle',
      );
      expect(states, hasLength(1));

      // Further platform-owned publishes while already stood down must be
      // no-ops so audio_service is never woken back up.
      handler.publish(AudioSnapshot(
        items: [item],
        index: 0,
        playing: true,
        position: const Duration(seconds: 20),
        repeatMode: AudioServiceRepeatMode.none,
        shuffle: false,
        platformOwned: true,
      ));
      await pumpEventQueue();
      expect(states, hasLength(1));
    });

    test('GroovyBoxAudioHandler sets idle when no song is selected', () {
      final handler = GroovyBoxAudioHandler();

      handler.publish(const AudioSnapshot(
        items: [],
        index: null,
        playing: false,
        buffering: false,
        position: Duration.zero,
        repeatMode: AudioServiceRepeatMode.none,
        shuffle: false,
      ));

      expect(handler.playbackState.value.processingState, equals(AudioProcessingState.idle));
      expect(handler.playbackState.value.controls, isEmpty);
    });
  });
}
