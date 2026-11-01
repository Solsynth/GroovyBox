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

  static final _latinRegex = RegExp(r'[a-zA-Z]');
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
    var latin = 0;
    for (final line in lines) {
      final t = line.text.trim();
      if (t.isEmpty) continue;
      if (_kanaRegex.hasMatch(t)) kana++;
      if (_hangulRegex.hasMatch(t)) hangul++;
      if (_hanziRegex.hasMatch(t)) hanzi++;
      if (_latinRegex.hasMatch(t)) latin++;
    }

    if (kana > 0 && kana >= hanzi) return 'ja';
    if (hangul > 0) return 'ko';
    if (hanzi > 0 && hanzi >= latin) return 'zh';
    return 'en';
  }

  /// Whether the lyrics have CJK text, missing translations, or duplicate layers
  /// that can be cleaned and enriched.
  bool needsEnrichment(Lyrics lyrics) {
    if (lyrics.isEmpty) return false;
    // Check if there are dirty duplicate layers from earlier stores that need cleaning
    final hasDuplicates = lyrics.lines.any((l) {
      final t = l.text.trim().toLowerCase();
      if (t.isEmpty) return false;
      final p = l.pronunciation?.trim().toLowerCase();
      final x = l.translation?.trim().toLowerCase();
      return (p != null && p == t) || (x != null && (x == t || x == p));
    });
    if (hasDuplicates) return true;

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

  /// The language lyric translations should be written in, for an app running
  /// in [languageCode].
  ///
  /// The *app's* locale, not the device's: a user who set the interface to
  /// Chinese on an English machine wants Chinese translations.
  static String targetLanguageFor(String? languageCode) {
    final code = (languageCode ?? '').toLowerCase();
    if (code.startsWith('zh')) return 'zh-CN';
    return code.isEmpty ? 'en' : code;
  }

  /// Best guess when no caller supplied a language: the device locale.
  ///
  /// Lyrics resolve on a background provider with no widget tree, so the
  /// app's own choice is only known when a caller passes it in.
  static String resolveTargetLanguage() =>
      targetLanguageFor(_deviceLanguageCode());

  static String _deviceLanguageCode() {
    try {
      return ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    } catch (_) {
      return '';
    }
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

    // 1. Romanization for CJK lines only (and clean up any identical pronunciations)
    final withPronunciation = <LyricLine>[];
    for (final line in lyrics.lines) {
      final trimmed = line.text.trim();
      final lowerText = trimmed.toLowerCase();

      // Clean existing pronunciation if it matches text exactly
      if (line.pronunciation != null) {
        if (line.pronunciation!.trim().toLowerCase() == lowerText) {
          withPronunciation.add(
            LyricLine(line.at, line.text, translation: line.translation),
          );
        } else {
          withPronunciation.add(line);
        }
        continue;
      }

      // Do not romanize if line has no CJK characters (e.g. English lines)
      if (!hasCjk(trimmed)) {
        withPronunciation.add(line);
        continue;
      }

      final roman = romanizeLine(trimmed, songLang);
      final romanClean = roman.trim();
      if (romanClean.isEmpty || romanClean.toLowerCase() == lowerText) {
        withPronunciation.add(line);
      } else {
        withPronunciation.add(
          line.withLayers(pronunciation: romanClean),
        );
      }
    }

    // 2. Translation
    // Identify lines that actually need a translation
    final indicesToTranslate = <int>[];
    final textsToTranslate = <String>[];
    for (var i = 0; i < withPronunciation.length; i++) {
      final line = withPronunciation[i];
      final trimmed = line.text.trim();
      final lowerText = trimmed.toLowerCase();
      if (trimmed.isEmpty) continue;

      if (line.translation != null) {
        // Strip if duplicate of text or pronunciation
        final transLower = line.translation!.trim().toLowerCase();
        if (transLower == lowerText ||
            transLower == line.pronunciation?.trim().toLowerCase()) {
          withPronunciation[i] = LyricLine(
            line.at,
            line.text,
            pronunciation: line.pronunciation,
          );
        } else {
          continue;
        }
      }

      // If line is already in target language, do not translate:
      // - English line and target is English:
      if (targetLang.startsWith('en') && !hasCjk(trimmed)) {
        continue;
      }
      // - Chinese line and target is Chinese:
      if (targetLang.startsWith('zh') &&
          _hanziRegex.hasMatch(trimmed) &&
          !_kanaRegex.hasMatch(trimmed) &&
          !_hangulRegex.hasMatch(trimmed)) {
        continue;
      }

      indicesToTranslate.add(i);
      textsToTranslate.add(trimmed);
    }

    if (textsToTranslate.isEmpty) {
      return Lyrics(
        lines: withPronunciation,
        synced: lyrics.synced,
        language: songLang,
        // Nothing was generated, so the row keeps whatever translation it
        // already had (and the language that one was written in).
        translationLanguage: lyrics.translationLanguage,
      );
    }

    // Batch translate
    final translations = await _translateBatch(textsToTranslate, targetLang);
    final finalLines = List<LyricLine>.from(withPronunciation);
    for (var i = 0; i < indicesToTranslate.length; i++) {
      final index = indicesToTranslate[i];
      final original = textsToTranslate[i].trim().toLowerCase();
      final translated = translations[i]?.trim();
      if (translated != null &&
          translated.isNotEmpty &&
          translated.toLowerCase() != original &&
          translated.toLowerCase() !=
              finalLines[index].pronunciation?.trim().toLowerCase()) {
        finalLines[index] =
            finalLines[index].withLayers(translation: translated);
      }
    }

    return Lyrics(
      lines: finalLines,
      synced: lyrics.synced,
      language: songLang,
      // Only claim the language when a translation actually landed: a batch
      // that failed should not mark the row as translated.
      translationLanguage: finalLines.any((line) => line.translation != null)
          ? targetLang
          : lyrics.translationLanguage,
    );
  }
}
