/// Translating lyric lines with an LLM on the user's own Solar Network
/// account, through Persona's OpenAI-compatible endpoint.
///
/// Opt-in: the resolver asks for a translator only when this device has picked
/// a model. Every word of a song then leaves the device for the account's AI
/// service, which is a different bargain from the one the app makes with Google
/// Translate for everyone.
///
/// The request is stateless on Persona's side (`/v1/chat/completions`), so a
/// lyric translation never appears in the account's conversation list, never
/// earns a run row, and never touches agent memory. The model is addressed
/// through Persona's `raw` agent — a transparent proxy with no system prompt of
/// its own — so the translator's instructions are the only ones applied.
///
/// The edge prefix is `persona`: the Solar Network gateway maps
/// `/persona/<path>` onto Persona's `/api/<path>`, which is where the
/// OpenAI-compatible routes are also mounted.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/app.dart';
import '../core/identity.dart';
import '../solarpass/models.dart';
import '../solarpass/providers.dart';

/// What the enricher needs from an LLM, so the enrichment pass can be tested
/// and used without a live account.
abstract class LineTranslator {
  /// Translates [lines] into [targetLanguage] (`'en'`, `'zh-CN'`).
  ///
  /// The result is index-aligned with [lines]: a line the model skipped is
  /// null. Throws when the service refuses or cannot be reached, so the caller
  /// can fall back to the free engine.
  Future<List<String?>> translate(List<String> lines, String targetLanguage);
}

/// A model Persona lists for this account (`GET /persona/models`).
class PersonaModel {
  const PersonaModel({
    required this.id,
    required this.provider,
    required this.name,
    this.type,
  });

  /// `provider/model-name`, the id Persona's catalogue uses.
  final String id;
  final String provider;
  final String name;
  final String? type;

  /// Whether the model can hold a conversation. Embedding models are listed
  /// in the same catalogue and would only fail the request.
  bool get isChat => (type ?? '').toLowerCase() != 'embedding';

  factory PersonaModel.fromJson(Map<String, dynamic> json) {
    final provider = json['provider']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    return PersonaModel(
      id: json['id']?.toString() ?? '$provider/$name',
      provider: provider,
      name: name,
      type: json['type']?.toString(),
    );
  }
}

/// How many lines go into one completion.
///
/// A lyric page is a few dozen lines, which one request handles with room to
/// spare. A long karaoke page is split so the model is never asked for a
/// numbered reply longer than it can count, and one failure costs a batch
/// instead of the whole song.
const _kLinesPerRequest = 60;

/// [LineTranslator] over Persona's stateless chat-completions endpoint.
class PersonaLineTranslator implements LineTranslator {
  PersonaLineTranslator({
    required this.baseUrl,
    required this.session,
    required this.model,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               // A whole page in one completion: slower than a chat turn, so
               // the receive timeout is the generous half.
               receiveTimeout: const Duration(seconds: 90),
             ),
           );

  /// The Solar Network server the account is signed in to.
  final String baseUrl;
  final OAuthSession session;

  /// `provider/model-name`, copied from [PersonaModel.id].
  final String model;

  final Dio _dio;

  String get _issuer => baseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  Future<List<String?>> translate(
    List<String> lines,
    String targetLanguage,
  ) async {
    if (lines.isEmpty) return const [];
    final results = List<String?>.filled(lines.length, null);
    var produced = 0;
    for (var start = 0; start < lines.length; start += _kLinesPerRequest) {
      final end = (start + _kLinesPerRequest).clamp(0, lines.length);
      final batch = lines.sublist(start, end);
      final reply = await _translateBatch(batch, targetLanguage);
      for (var i = 0; i < batch.length && i < reply.length; i++) {
        final text = reply[i]?.trim();
        if (text == null || text.isEmpty) continue;
        results[start + i] = text;
        produced++;
      }
    }
    if (produced == 0) throw const PersonaTranslationException('empty reply');
    return results;
  }

  Future<List<String?>> _translateBatch(
    List<String> lines,
    String targetLanguage,
  ) async {
    final language = _languageName(targetLanguage);
    final numbered = [
      for (var i = 0; i < lines.length; i++) '${i + 1}|${lines[i]}',
    ].join('\n');

    final response = await _dio.post<Map<String, dynamic>>(
      '$_issuer/persona/v1/chat/completions',
      data: {
        // No agent_id: the three-part model addresses Persona's `raw` agent
        // directly, which carries no system prompt and no server tools.
        'model': 'raw/$model',
        'stream': false,
        'messages': [
          {
            'role': 'system',
            'content':
                'You translate song lyrics into $language. '
                'The user sends lines as "<number>|<text>", one per line. '
                'Reply with the same numbers, one per line, as '
                '"<number>|<translation>". '
                'Translate every line, keeping its meaning, tone, slang and '
                'imagery; do not explain, romanize, annotate or add notes. '
                'Keep names as they are commonly written in $language. '
                'Never merge or split lines: reply with exactly one numbered '
                'line for every numbered line you were sent.',
          },
          {'role': 'user', 'content': numbered},
        ],
      },
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'User-Agent': appUserAgent,
          'Authorization': '${session.tokenType} ${session.accessToken}',
        },
      ),
    );

    final choices = response.data?['choices'];
    if (choices is! List || choices.isEmpty) return const [];
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content']?.toString() : null;
    if (content == null || content.trim().isEmpty) return const [];
    return parseNumberedLines(content, lines.length);
  }
}

/// Thrown when Persona answered but with nothing a translation could be read
/// from. Distinct from a transport failure only so the caller's log says which
/// half went wrong.
class PersonaTranslationException implements Exception {
  const PersonaTranslationException(this.message);
  final String message;

  @override
  String toString() => 'PersonaTranslationException: $message';
}

/// Reads `n|text` lines back into index order.
///
/// The number, not the position, is what places a translation: a model that
/// drops an empty line or wraps one must not shift every line after it. A bare
/// JSON array of strings is accepted too — a model that ignores the numbering
/// still said something usable.
@visibleForTesting
List<String?> parseNumberedLines(String content, int count) {
  final results = List<String?>.filled(count, null);
  final pattern = RegExp(r'^\s*(\d+)\s*[|:.)\]]\s?(.*)$');
  var matched = 0;
  for (final rawLine in content.split('\n')) {
    final match = pattern.firstMatch(rawLine.trimRight());
    if (match == null) continue;
    final index = int.tryParse(match.group(1)!) ?? 0;
    if (index < 1 || index > count) continue;
    final text = match.group(2)?.trim() ?? '';
    if (text.isEmpty) continue;
    results[index - 1] = text;
    matched++;
  }
  if (matched > 0) return results;

  final start = content.indexOf('[');
  final end = content.lastIndexOf(']');
  if (start < 0 || end <= start) return results;
  try {
    final decoded = jsonDecode(content.substring(start, end + 1));
    if (decoded is! List) return results;
    for (var i = 0; i < decoded.length && i < count; i++) {
      final text = decoded[i]?.toString().trim();
      if (text != null && text.isNotEmpty) results[i] = text;
    }
  } catch (_) {}
  return results;
}

/// Name the model is asked to write in. Codes alone work, but a name is what
/// steers register: "Simplified Chinese" reads differently from `zh-CN`.
String _languageName(String code) {
  final normalized = code.trim().toLowerCase();
  if (normalized.startsWith('zh')) {
    return normalized.endsWith('tw') || normalized.endsWith('hk')
        ? 'Traditional Chinese'
        : 'Simplified Chinese';
  }
  return switch (normalized) {
    'en' => 'English',
    'ja' => 'Japanese',
    'ko' => 'Korean',
    'fr' => 'French',
    'de' => 'German',
    'es' => 'Spanish',
    'pt' => 'Portuguese',
    'it' => 'Italian',
    'ru' => 'Russian',
    'ar' => 'Arabic',
    'hi' => 'Hindi',
    'th' => 'Thai',
    'vi' => 'Vietnamese',
    _ => code,
  };
}

/// The account's model catalogue, empty when signed out or unreachable.
final personaLyricsModelsProvider = FutureProvider<List<PersonaModel>>((
  ref,
) async {
  final session = await ref.watch(solarpassSessionProvider.future);
  if (session == null) return const [];
  final config = ref.watch(solarpassConfigProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  try {
    final response = await dio.get<List<dynamic>>(
      '${config.serverUrl.replaceAll(RegExp(r'/+$'), '')}/persona/models',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'User-Agent': appUserAgent,
          'Authorization': '${session.tokenType} ${session.accessToken}',
        },
      ),
    );
    return [
      for (final entry in response.data ?? const [])
        if (entry is Map)
          PersonaModel.fromJson(Map<String, dynamic>.from(entry)),
    ].where((model) => model.isChat && model.id.isNotEmpty).toList();
  } catch (error) {
    debugPrint('[Persona] Model catalogue unavailable: $error');
    return const [];
  }
});

/// The translator for the signed-in account and the chosen model, or null
/// when either is missing — a half-configured choice is not an engine, and
/// null simply means the Google path.
///
/// Resolved per lookup rather than once: the model may be picked mid-session,
/// and the session's token is refreshed underneath a long-lived resolver.
final personaLyricsTranslatorProvider = FutureProvider<LineTranslator?>((
  ref,
) async {
  final session = await ref.watch(solarpassSessionProvider.future);
  if (session == null) return null;
  final model = ref.watch(lyricsLlmModelProvider);
  if (model == null || model.isEmpty) return null;
  final config = ref.watch(solarpassConfigProvider);
  return PersonaLineTranslator(
    baseUrl: config.serverUrl,
    session: session,
    model: model,
  );
});
