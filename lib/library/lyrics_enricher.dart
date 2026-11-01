/// Romanizes CJK lyrics and generates translations when missing.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:kuromoji/kuromoji.dart';
// ignore: implementation_imports
import 'package:kuromoji/src/tokenizer.dart';
import 'package:romanize/romanize.dart';

import 'lyrics.dart';

/// Detects CJK text, generates Romanization (Romaji for Japanese, Pinyin for
/// Chinese, Hangul Romanization for Korean), and fetches translations.
class LyricsEnricher {
  LyricsEnricher({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 5),
              ),
            );

  final Dio _dio;

  static Tokenizer? _tokenizer;
  static bool _initialized = false;
  static const _kanaKit = KanaKit();

  static final _kanaRegex = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]');
  static final _hangulRegex = RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]');
  static final _hanziRegex = RegExp(r'[\u4E00-\u9FFF]');
  static final _cjkRegex = RegExp(
    r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF\u1100-\u11FF]',
  );

  /// Initializes Kuromoji and TextRomanizer dictionaries once.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      _tokenizer = await TokenizerBuilder().build();
      await TextRomanizer.ensureInitialized();
    } catch (_) {}
    _initialized = true;
  }

  static bool hasCjk(String text) => _cjkRegex.hasMatch(text);

  /// Guesses the predominant language of the lyrics: 'ja', 'ko', 'zh', or 'en'.
  static String detectLanguage(List<LyricLine> lines) {
    var kana = 0;
    var hangul = 0;
    var hanzi = 0;
    for (final line in lines) {
      final t = line.text;
      if (_kanaRegex.hasMatch(t)) kana++;
      if (_hangulRegex.hasMatch(t)) hangul++;
      if (_hanziRegex.hasMatch(t)) hanzi++;
    }
    if (kana > 0) return 'ja';
    if (hangul > 0) return 'ko';
    if (hanzi > 0) return 'zh';
    return 'en';
  }

  /// Whether the lyrics have CJK text or missing translations that can be enriched.
  bool needsEnrichment(Lyrics lyrics) {
    if (lyrics.isEmpty) return false;
    final hasCjkLines = lyrics.lines.any((l) => hasCjk(l.text));
    final needsPronunciation =
        hasCjkLines && lyrics.lines.any((l) => l.pronunciation == null && hasCjk(l.text));
    final needsTranslation = lyrics.lines.any(
      (l) => l.translation == null && l.text.trim().isNotEmpty,
    );
    return needsPronunciation || needsTranslation;
  }

  /// Romanizes Japanese text into naturally spaced Romaji using Kuromoji
  /// tokenization + KanaKit.
  static String romanizeJapanese(String input) {
    if (input.trim().isEmpty) return input;
    if (_tokenizer != null) {
      try {
        final tokens = _tokenizer!.tokenize(input.replaceAll('。', '.'));
        final buffer = StringBuffer();
        for (var i = 0; i < tokens.length; i++) {
          final t = tokens[i];
          final reading = (t['reading'] != null && t['reading'] != '*')
              ? t['reading'] as String
              : t['surface_form'] as String;
          final romaji = _kanaKit.toRomaji(reading);
          final pos = t['pos'] as String?;
          if (i > 0) {
            final prevPos = tokens[i - 1]['pos'] as String?;
            if (pos == '助動詞' ||
                pos == '接尾' ||
                (prevPos == '動詞' && pos == '助詞')) {
              // Attach auxiliary verbs and suffixes without space
            } else {
              buffer.write(' ');
            }
          }
          buffer.write(romaji);
        }
        final result = buffer.toString().trim();
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    return JapaneseRomanizer().romanize(input);
  }

  /// Generates Romaji / Pinyin / Hangul romanization for one line.
  static String romanizeLine(String text, String language) {
    if (!hasCjk(text)) return text;
    try {
      if (language == 'ja' || _kanaRegex.hasMatch(text)) {
        return romanizeJapanese(text);
      }
      if (language == 'ko' || _hangulRegex.hasMatch(text)) {
        return HangulRomanizer().romanize(text);
      }
      if (language == 'zh' || _hanziRegex.hasMatch(text)) {
        return ChineseRomanizer().romanize(text);
      }
      return TextRomanizer.romanize(text);
    } catch (_) {
      return text;
    }
  }

  /// Determines the best target translation language based on user locale.
  static String resolveTargetLanguage() {
    try {
      final code =
          ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      if (code.startsWith('zh')) return 'zh-CN';
      if (code.isNotEmpty) return code;
    } catch (_) {}
    return 'en';
  }

  /// Translates a batch of lyric lines via Google Translate Web endpoint.
  Future<List<String?>> _translateBatch(
    List<String> lines,
    String targetLang,
  ) async {
    if (lines.isEmpty) return const [];
    try {
      final response = await _dio.get(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': targetLang,
          'dt': 't',
          'q': lines.join('\n'),
        },
        options: Options(responseType: ResponseType.plain),
      );
      final decoded = jsonDecode(response.data as String);
      if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
        final text = (decoded[0] as List)
            .map((item) => item is List && item.isNotEmpty ? item[0] : '')
            .join();
        final split = text.split('\n');
        if (split.length == lines.length) {
          return split.map((s) => s.trim().isEmpty ? null : s.trim()).toList();
        }
      }
    } catch (_) {}
    return List<String?>.filled(lines.length, null);
  }

  /// Enriches [lyrics] by generating Romanization for CJK lines and translating
  /// lines into the user's preferred language.
  Future<Lyrics> enrich(Lyrics lyrics, {String? targetLanguage}) async {
    if (lyrics.isEmpty) return lyrics;
    await ensureInitialized();

    final songLang = lyrics.language ?? detectLanguage(lyrics.lines);
    final targetLang = targetLanguage ?? resolveTargetLanguage();

    // 1. Romanization for CJK lines
    final withPronunciation = <LyricLine>[];
    for (final line in lyrics.lines) {
      if (line.pronunciation != null || !hasCjk(line.text)) {
        withPronunciation.add(line);
      } else {
        final roman = romanizeLine(line.text, songLang);
        withPronunciation.add(
          line.withLayers(
            pronunciation: roman.trim().isEmpty ? null : roman.trim(),
          ),
        );
      }
    }

    // 2. Translation (if target language is different from song language)
    final shouldTranslate = !songLang.startsWith(targetLang.split('-').first);
    if (!shouldTranslate) {
      return Lyrics(
        lines: withPronunciation,
        synced: lyrics.synced,
        language: songLang,
      );
    }

    // Identify non-empty lines that still need a translation
    final indicesToTranslate = <int>[];
    final textsToTranslate = <String>[];
    for (var i = 0; i < withPronunciation.length; i++) {
      final line = withPronunciation[i];
      if (line.translation == null && line.text.trim().isNotEmpty) {
        indicesToTranslate.add(i);
        textsToTranslate.add(line.text);
      }
    }

    if (textsToTranslate.isEmpty) {
      return Lyrics(
        lines: withPronunciation,
        synced: lyrics.synced,
        language: songLang,
      );
    }

    // Batch translate
    final translations = await _translateBatch(textsToTranslate, targetLang);
    final finalLines = List<LyricLine>.from(withPronunciation);
    for (var i = 0; i < indicesToTranslate.length; i++) {
      final index = indicesToTranslate[i];
      final translated = translations[i];
      if (translated != null && translated.isNotEmpty) {
        finalLines[index] = finalLines[index].withLayers(translation: translated);
      }
    }

    return Lyrics(
      lines: finalLines,
      synced: lyrics.synced,
      language: songLang,
    );
  }
}
