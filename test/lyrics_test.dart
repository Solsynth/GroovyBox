import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/models.dart';

void main() {
  group('parseLrc', () {
    test('reads stamps, hundredths and one line with several stamps', () {
      final lyrics = parseLrc('''
[00:01.00]First line
[00:12.50][01:02.25]Repeated chorus
[01:10]Last line
''');

      expect(lyrics.synced, isTrue);
      expect(
        [for (final line in lyrics.lines) line.text],
        ['First line', 'Repeated chorus', 'Repeated chorus', 'Last line'],
      );
      expect(lyrics.lines[0].at, const Duration(seconds: 1));
      expect(lyrics.lines[1].at, const Duration(seconds: 12, milliseconds: 500));
      expect(lyrics.lines[3].at, const Duration(minutes: 1, seconds: 10));
      expect(
        lyrics.lines[2].at,
        const Duration(minutes: 1, seconds: 2, milliseconds: 250),
      );
    });

    test('applies the offset tag once and keeps the lines ordered', () {
      final lyrics = parseLrc('''
[offset:-500]
[00:02.00]Later
[00:01.00]Earlier
''');

      expect(lyrics.lines.first.text, 'Earlier');
      expect(lyrics.lines.first.at, const Duration(milliseconds: 1500));
      expect(lyrics.lines.last.at, const Duration(milliseconds: 2500));
    });

    test('plain text is unsynced and preserved', () {
      final lyrics = parseLrc('Just words\n\nAnd a stanza break\n');

      expect(lyrics.synced, isFalse);
      expect(lyrics.lines.map((line) => line.text), [
        'Just words',
        'And a stanza break',
      ]);
    });
  });

  group('lyricIndexAt', () {
    final lines = [
      const LyricLine(Duration(seconds: 5), 'one'),
      const LyricLine(Duration(seconds: 10), 'two'),
      const LyricLine(Duration(seconds: 20), 'three'),
    ];

    test('is -1 before the first line and follows the stamps', () {
      expect(lyricIndexAt(lines, const Duration(seconds: 4)), -1);
      expect(lyricIndexAt(lines, const Duration(seconds: 5)), 0);
      expect(lyricIndexAt(lines, const Duration(seconds: 9)), 0);
      expect(lyricIndexAt(lines, const Duration(seconds: 15)), 1);
      expect(lyricIndexAt(lines, const Duration(minutes: 5)), 2);
    });

    test('empty lyrics have no current line', () {
      expect(lyricIndexAt(const [], Duration.zero), -1);
    });
  });

  group('mergeLyricLayers', () {
    final main = Lyrics(
      synced: true,
      lines: const [
        LyricLine(Duration(seconds: 10), '踏みつけられた孤独とペダル'),
        LyricLine(Duration(seconds: 20), '何度も鳴り響く音色が頬に'),
      ],
    );

    test('attaches a reading and a translation to the line they time with', () {
      final merged = mergeLyricLayers(
        main: main,
        pronunciation: Lyrics(
          synced: true,
          lines: const [
            LyricLine(Duration(seconds: 10), 'fumitsukerareta kodoku'),
            LyricLine(Duration(seconds: 20), 'nandomo narihibiku neiro'),
          ],
        ),
        translation: Lyrics(
          synced: true,
          lines: const [
            LyricLine(Duration(seconds: 10), 'From the trampled loneliness'),
            LyricLine(Duration(seconds: 20), 'The repeated ringing tone'),
          ],
        ),
      );

      expect(merged.lines[0].pronunciation, 'fumitsukerareta kodoku');
      expect(merged.lines[1].translation, 'The repeated ringing tone');
      expect(merged.synced, isTrue);
    });

    test('drops a reading that has no line of its own', () {
      final merged = mergeLyricLayers(
        main: main,
        translation: Lyrics(
          synced: true,
          lines: const [
            // Five seconds off is not this line's translation.
            LyricLine(Duration(seconds: 15), 'Wrong line'),
          ],
        ),
      );

      expect(merged.lines.every((line) => line.translation == null), isTrue);
    });

    test('a main-only lyric is returned untouched', () {
      final merged = mergeLyricLayers(main: main);
      expect(identical(merged, main), isTrue);
    });
  });

  test('LyricsRequest identifies the song by value', () {
    const song = LibrarySong(
      sourceId: 'a',
      id: 's1',
      title: 'A Song',
      artist: 'An Artist',
      duration: Duration(minutes: 4),
    );

    expect(LyricsRequest.of(song), LyricsRequest.of(song));
    expect(
      LyricsRequest.of(song).hashCode,
      LyricsRequest.of(song).hashCode,
    );
    expect(
      LyricsRequest.of(song),
      isNot(LyricsRequest.of(const LibrarySong(
        sourceId: 'a',
        id: 's2',
        title: 'A Song',
        duration: Duration(minutes: 4),
      ))),
    );
  });
}
