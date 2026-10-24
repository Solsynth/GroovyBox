import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/server/models.dart';

SubsonicSong _song(String id, {String? title, int seconds = 100}) =>
    SubsonicSong(id: id, title: title ?? id, duration: Duration(seconds: seconds));

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

  group('SubsonicSong', () {
    test('falls back when tags are missing', () {
      final song = SubsonicSong.fromJson({
        'id': 's1',
        'title': 'Song',
        'duration': 60,
        'album': 'An Album',
      });
      expect(song.subtitle, 'An Album', reason: 'album substitutes for artist');

      final bare = SubsonicSong.fromJson({'id': 's2'});
      expect(bare.title, 'Untitled');
      expect(bare.duration, Duration.zero);
      expect(bare.subtitle, 'Unknown artist');
    });

    test('reads OpenSubsonic wire names', () {
      final song = SubsonicSong.fromJson({
        'id': 's3',
        'title': 'Song',
        'artist': 'Artist',
        'artistId': 'ar1',
        'album': 'Album',
        'albumId': 'al1',
        'coverArt': 'cover-3',
        'duration': 200,
        'track': 4,
        'discNumber': 2,
        'year': 2019,
        'genre': 'Jazz',
      });
      expect(song.coverArt, 'cover-3');
      expect(song.track, 4);
      expect(song.discNumber, 2);
      expect(song.year, 2019);
      expect(song.artistId, 'ar1');
      expect(song.albumId, 'al1');
    });
  });
}
