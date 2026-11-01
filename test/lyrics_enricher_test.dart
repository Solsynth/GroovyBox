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
  });
}
