import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';

LibrarySong _song(String id, {String? title, int seconds = 100}) => LibrarySong(
  sourceId: 'source',
  id: id,
  title: title ?? id,
  duration: Duration(seconds: seconds),
);

void main() {
  group('PlaybackState', () {
    test('exposes the current song and traversal flags', () {
      const empty = PlaybackState();
      expect(empty.current, isNull);
      expect(empty.hasNext, isFalse);
      expect(empty.hasPrevious, isFalse);

      final state = PlaybackState(
        queue: [_song('a'), _song('b'), _song('c')],
        currentIndex: 1,
      );
      expect(state.current!.id, 'b');
      expect(state.hasNext, isTrue);
      expect(state.hasPrevious, isTrue);

      // At the end of the queue there is nothing next — unless repeat is on,
      // which wraps.
      final atEnd = PlaybackState(
        queue: [_song('a'), _song('b')],
        currentIndex: 1,
      );
      expect(atEnd.hasNext, isFalse);

      final wrapping = PlaybackState(
        queue: [_song('a'), _song('b')],
        currentIndex: 1,
        repeatMode: PlaybackRepeatMode.all,
      );
      expect(wrapping.hasPrevious, isTrue);
    });

    test('copyWith can clear the index for an emptied queue', () {
      final state = PlaybackState(
        queue: [_song('a')],
        currentIndex: 0,
        playing: true,
      );
      final cleared = state.copyWith(clearIndex: true, playing: false);
      expect(cleared.current, isNull);
      expect(cleared.queue, hasLength(1), reason: 'copyWith keeps the queue');
      expect(cleared.playing, isFalse);
    });

    test('identifies the current song across sources', () {
      final state = PlaybackState(
        queue: [
          LibrarySong(
            sourceId: 'a',
            id: '1',
            title: 'Same id',
            duration: Duration.zero,
          ),
        ],
        currentIndex: 0,
      );
      expect(
        state.isCurrentSong(
          const LibrarySong(
            sourceId: 'a',
            id: '1',
            title: 'Same id',
            duration: Duration.zero,
          ),
        ),
        isTrue,
      );
      // Native ids repeat between libraries, so the source has to match too.
      expect(
        state.isCurrentSong(
          const LibrarySong(
            sourceId: 'b',
            id: '1',
            title: 'Same id',
            duration: Duration.zero,
          ),
        ),
        isFalse,
      );
    });

    test('repeat cycles off -> queue -> one song -> off', () {
      expect(nextRepeatMode(PlaybackRepeatMode.off), PlaybackRepeatMode.all);
      expect(
        nextRepeatMode(PlaybackRepeatMode.all),
        PlaybackRepeatMode.single,
      );
      expect(
        nextRepeatMode(PlaybackRepeatMode.single),
        PlaybackRepeatMode.off,
      );
      expect(
        const PlaybackState().repeatMode,
        PlaybackRepeatMode.off,
        reason: 'a fresh queue does not repeat',
      );
    });
  });
}
