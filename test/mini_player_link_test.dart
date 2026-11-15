import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';

const _song = LibrarySong(
  sourceId: 'a',
  id: 's1',
  title: 'Sunset Overdrive',
  artist: 'The Paper Kites',
  album: 'On the Corner Where You Live',
  duration: Duration(seconds: 240),
);

const _other = LibrarySong(
  sourceId: 'a',
  id: 's2',
  title: 'Bloom',
  artist: 'The Paper Kites',
  duration: Duration(seconds: 200),
);

const _station = LibrarySong(
  sourceId: 'a',
  id: 'radio-1',
  title: 'Late Night Radio',
  duration: Duration.zero,
  isRadio: true,
  radioTrack: LibrarySong(
    sourceId: 'a',
    id: 'r1',
    title: 'Neon Lights',
    artist: 'Someone',
    duration: Duration(seconds: 180),
  ),
);

void main() {
  final state = PlaybackState(
    queue: const [_song, _other],
    stationTracks: const [_station],
    currentIndex: 1,
    stationIndex: 0,
    playing: true,
    buffering: false,
    position: const Duration(seconds: 42),
    duration: const Duration(seconds: 200),
    shuffle: true,
    repeatMode: PlaybackRepeatMode.all,
    volume: 68,
  );

  test('a snapshot round-trips a queue, a station and the modes', () {
    final decoded = decodeSnapshot(encodeSnapshot(state));

    expect(decoded.queue.map((song) => song.id), ['s1', 's2']);
    expect(decoded.queue.first.title, 'Sunset Overdrive');
    expect(decoded.queue.first.artist, 'The Paper Kites');
    expect(decoded.stationTracks.single.radioTrack?.title, 'Neon Lights');
    expect(decoded.currentIndex, 1);
    expect(decoded.stationIndex, 0);
    expect(decoded.playing, isTrue);
    expect(decoded.duration, const Duration(seconds: 200));
    expect(decoded.shuffle, isTrue);
    expect(decoded.repeatMode, PlaybackRepeatMode.all);
    expect(decoded.volume, 68);
  });

  test('a tick carries the clock and nothing else', () {
    final tick = encodeTick(state);

    expect(tick['kind'], 'tick');
    expect(tick['positionMs'], 42000);
    expect(tick['durationMs'], 200000);
    expect(tick['playing'], isTrue);
    expect(tick.containsKey('queue'), isFalse);
  });

  test('a snapshot is only needed when more than the clock moved', () {
    expect(
      snapshotDiffersFromTick(
        state.copyWith(position: const Duration(seconds: 43)),
        state,
      ),
      isFalse,
    );
    expect(
      snapshotDiffersFromTick(state.copyWith(playing: false), state),
      isTrue,
    );
    expect(
      snapshotDiffersFromTick(
        state.copyWith(repeatMode: PlaybackRepeatMode.single),
        state,
      ),
      isTrue,
    );
  });

  test('a lyric and its layers survive the hop', () {
    const lyrics = Lyrics(
      lines: [
        LyricLine(
          Duration(milliseconds: 3200),
          'ハロ',
          pronunciation: 'haro',
          translation: 'hello',
        ),
        LyricLine(Duration(milliseconds: 9100), 'plain'),
      ],
      synced: true,
      language: 'jpn',
      translationLanguage: 'en-US',
    );

    final decoded = decodeLyrics(encodeLyrics(lyrics));

    expect(decoded.synced, isTrue);
    expect(decoded.language, 'jpn');
    expect(decoded.translationLanguage, 'en-US');
    expect(decoded.lines.first.at, const Duration(milliseconds: 3200));
    expect(decoded.lines.first.text, 'ハロ');
    expect(decoded.lines.first.pronunciation, 'haro');
    expect(decoded.lines.first.translation, 'hello');
    expect(decoded.lines.last.pronunciation, isNull);
  });

  test('a lyrics request round-trips the identity the cache keys on', () {
    const request = LyricsRequest(
      sourceId: 'a',
      id: 's1',
      title: 'ハロ／ハワユ',
      artist: 'Kano',
      album: 'rye',
      duration: Duration(seconds: 208),
    );

    final decoded = decodeLyricsRequest(
      encodeLyricsRequest(request, languageCode: 'zh-CN'),
    );

    expect(decoded, request);
    expect(
      encodeLyricsRequest(request, languageCode: 'zh-CN')['languageCode'],
      'zh-CN',
    );
  });

  test('an unreadable payload throws instead of guessing', () {
    expect(
      () => decodeSnapshot({'repeatMode': 'sideways'}),
      throwsFormatException,
    );
  });
}
