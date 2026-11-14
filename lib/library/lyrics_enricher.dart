/// Romanizes CJK lyrics and generates translations when missing.
library;

import 'dart:convert';
import 'dart:isolate';
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

  /// A lyric line longer than this is a whole song's text that arrived
  /// without line breaks, not a line anyone sings. The romanizers are
  /// quadratic on long unbroken CJK strings — the pinyin dictionary lookup
  /// re-slices the remaining text per character, so a 4 000-character line
  /// costs about ninety seconds — and a reading under a blob of that size
  /// is unreadable anyway. Such lines get no pronunciation layer.
  static const _maxRomanizeLineLength = 500;

  /// Total text past which the romanization pass moves to a background
  /// isolate. Below it the work is dictionary hits measured in microseconds
  /// per line and stays inline; above it a page of lyrics could hold the UI
  /// isolate for frames it cannot spare. The dictionaries are rebuilt inside
  /// the spawned isolate — statics do not cross an isolate boundary.
  static const _isolateOffloadThreshold = 1200;

  /// Whether the romanization pass is heavy enough to leave the UI isolate:
  /// any single huge line, or more text than a page of short lines.
  static bool _needsIsolate(List<LyricLine> lines) {
    var total = 0;
    for (final line in lines) {
      if (line.text.length > 200) return true;
      total += line.text.length;
      if (total > _isolateOffloadThreshold) return true;
    }
    return false;
  }

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

  /// One line's romanization pass: keeps an existing reading, skips lines
  /// with no CJK text, refuses lines past the length cap, and adds a fresh
  /// reading when the romanizer produces something different.
  static LyricLine _romanize(LyricLine line, String songLang) {
    final trimmed = line.text.trim();
    final lowerText = trimmed.toLowerCase();

    // Clean existing pronunciation if it matches text exactly
    if (line.pronunciation != null) {
      if (line.pronunciation!.trim().toLowerCase() == lowerText) {
        return LyricLine(line.at, line.text, translation: line.translation);
      }
      return line;
    }

    // Do not romanize if line has no CJK characters (e.g. English lines)
    if (!hasCjk(trimmed)) return line;

    // A line past the cap is a mis-parsed text blob, not a sung line:
    // romanizing it would stall for minutes (the pinyin lookup is
    // quadratic) and the reading under a wall of text is unreadable.
    final roman = trimmed.length <= _maxRomanizeLineLength
        ? romanizeLine(trimmed, songLang)
        : '';
    final romanClean = roman.trim();
    if (romanClean.isEmpty || romanClean.toLowerCase() == lowerText) {
      return line;
    }
    return line.withLayers(pronunciation: romanClean);
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

    final songLang = lyrics.language ?? detectLanguage(lyrics.lines);
    final targetLang = targetLanguage ?? resolveTargetLanguage();

    // 1. Romanization for CJK lines only (and clean up any identical
    // pronunciations). Short workloads stay inline; heavy ones — a whole
    // page of CJK lines, or a single huge line — run on a background
    // isolate so a lyric pane loading never holds the UI isolate. The
    // dictionaries are built there because statics do not cross an isolate
    // boundary.
    Future<List<LyricLine>> romanizeAll() async {
      await ensureInitialized();
      return [for (final line in lyrics.lines) _romanize(line, songLang)];
    }

    final withPronunciation =
        _needsIsolate(lyrics.lines) ? await Isolate.run(romanizeAll) : await romanizeAll();

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
