import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_enricher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyricsEnricher', () {
    final enricher = LyricsEnricher();

    test('detects CJK characters', () {
      expect(LyricsEnricher.hasCjk('Hello world'), isFalse);
      expect(LyricsEnricher.hasCjk('こんにちは'), isTrue);
      expect(LyricsEnricher.hasCjk('你好世界'), isTrue);
      expect(LyricsEnricher.hasCjk('안녕하세요'), isTrue);
    });

    test('detects language of songs', () {
      expect(
        LyricsEnricher.detectLanguage([
          const LyricLine(Duration.zero, 'Hello world'),
        ]),
        'en',
      );
      expect(
        LyricsEnricher.detectLanguage([
          const LyricLine(Duration.zero, '静かに消えていく思い出'),
        ]),
        'ja',
      );
      expect(
        LyricsEnricher.detectLanguage([
          const LyricLine(Duration.zero, '今天我寒夜里看雪飘过'),
        ]),
        'zh',
      );
      expect(
        LyricsEnricher.detectLanguage([
          const LyricLine(Duration.zero, '안녕하세요'),
        ]),
        'ko',
      );
    });

    test('generates romanji for Japanese lyrics', () async {
      final lyrics = const Lyrics(
        lines: [
          LyricLine(Duration(seconds: 1), '静かに消えていく思い出'),
          LyricLine(Duration(seconds: 5), '冷たい風が頬をかすめる'),
        ],
        synced: true,
      );

      final enriched = await enricher.enrich(lyrics, targetLanguage: 'ja');
      expect(enriched.lines[0].pronunciation, isNotNull);
      expect(enriched.lines[0].pronunciation, contains('shizuka'));
      expect(enriched.lines[1].pronunciation, isNotNull);
      expect(enriched.lines[1].pronunciation, contains('tsumetai'));
    });

    test('generates pinyin for Chinese lyrics', () async {
      final lyrics = const Lyrics(
        lines: [
          LyricLine(Duration(seconds: 1), '海阔天空'),
        ],
        synced: true,
      );

      final enriched = await enricher.enrich(lyrics, targetLanguage: 'zh-CN');
      expect(enriched.lines[0].pronunciation, isNotNull);
      expect(enriched.lines[0].pronunciation, contains('hǎi kuò'));
    });

    test('generates romanization for Korean lyrics', () async {
      final lyrics = const Lyrics(
        lines: [
          LyricLine(Duration(seconds: 1), '사랑해요'),
        ],
        synced: true,
      );

      final enriched = await enricher.enrich(lyrics, targetLanguage: 'ko');
      expect(enriched.lines[0].pronunciation, isNotNull);
      expect(enriched.lines[0].pronunciation, contains('saranghaeyo'));
    });

    test('does not duplicate lines for English lyrics', () async {
      final lyrics = const Lyrics(
        lines: [
          LyricLine(Duration(seconds: 1), "I'm in love with the shape of you"),
          LyricLine(Duration(seconds: 4), 'We push and pull like a magnet do'),
        ],
        synced: true,
      );

      final enriched = await enricher.enrich(lyrics, targetLanguage: 'en');
      for (final line in enriched.lines) {
        // Must never have pronunciation on English lines
        expect(line.pronunciation, isNull);
        // Must never duplicate text as translation
        expect(line.translation, isNot(equals(line.text)));
      }
    });

    test('detects English song with single CJK credit line as en', () {
      final lang = LyricsEnricher.detectLanguage([
        const LyricLine(Duration.zero, "I'm in love with the shape of you"),
        const LyricLine(Duration(seconds: 2), 'We push and pull like a magnet do'),
        const LyricLine(Duration(seconds: 4), 'Although my heart is falling too'),
        const LyricLine(Duration(seconds: 6), 'I am in love with your body'),
        const LyricLine(Duration(seconds: 8), 'Every day discovering something brand new'),
        const LyricLine(Duration(seconds: 10), 'I am in love with the shape of you'),
        const LyricLine(Duration(seconds: 12), 'Written by Ed (作詞: 某某)'),
      ]);
      expect(lang, 'en');
    });

    test('cleans up duplicate layers from earlier stores', () async {
      final dirty = const Lyrics(
        lines: [
          LyricLine(
            Duration(seconds: 1),
            'Yellow',
            pronunciation: 'Yellow',
            translation: 'Yellow',
          ),
        ],
        synced: true,
      );

      final cleaned = await enricher.enrich(dirty, targetLanguage: 'en');
      expect(cleaned.lines[0].pronunciation, isNull);
      expect(cleaned.lines[0].translation, isNull);
    });
  });
}
