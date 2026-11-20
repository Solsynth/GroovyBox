import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lyrics_enricher.dart';
import 'package:groovy_box/library/lyrics_resolver.dart';
import 'package:groovy_box/library/lyrics_store.dart';
import 'package:groovy_box/library/lyrics_translator.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/solarpass/models.dart';
import 'package:groovy_box/library/source.dart';

/// A library with nothing: every lookup here is about what the cache holds.
class _EmptyLibrary extends LibrarySource {
  @override
  String get id => 'a';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'a',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Home',
  );

  @override
  Future<Lyrics> lyrics(LibrarySong song) async => Lyrics.empty;

  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records the request and answers from a handler.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

/// Google's response envelope, answered without a network.
class _GoogleAdapter implements HttpClientAdapter {
  _GoogleAdapter(this.answer);

  final String answer;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode([
      [
        [answer, '', null, null],
      ],
    ]),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// The enricher with a fake Google behind it, so a fallback test never leaves
/// the machine and can assert what the fallback actually answered.
LyricsEnricher _enricherWithGoogle(LineTranslator? translator, String answer) {
  final dio = Dio();
  dio.httpClientAdapter = _GoogleAdapter(answer);
  return LyricsEnricher(dio: dio, translator: translator);
}

/// Answers with a fixed, numbered translation and records what it was asked.
class _FakeModel implements LineTranslator {
  _FakeModel(this.answer);

  final String answer;
  final List<List<String>> calls = [];
  bool fail = false;

  @override
  Future<List<String?>> translate(
    List<String> lines,
    String targetLanguage,
  ) async {
    calls.add(List<String>.from(lines));
    if (fail) throw const PersonaTranslationException('refused');
    final parsed = parseNumberedLines(answer, lines.length);
    return parsed;
  }
}

const _song = LyricsRequest(
  sourceId: 'a',
  id: 's1',
  title: '静かに',
  artist: 'Someone',
);

({LibraryDatabase db, LyricsStore store}) _open() {
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return (db: db, store: LyricsStore(db));
}

LyricsResolver _resolver(
  LibraryDatabase db,
  LyricsStore store, {
  LyricsEnricher? enricher,
}) => LyricsResolver(
  catalog: LibraryCatalog(db),
  store: store,
  queries: () => const [],
  sourceFor: (_) => _EmptyLibrary(),
  enricher: enricher ?? LyricsEnricher(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseNumberedLines', () {
    test('places each line by its number, not its position', () {
      final parsed = parseNumberedLines('2|second\n1|first', 2);
      expect(parsed, ['first', 'second']);
    });

    test('accepts a bare JSON array when the model ignores numbering', () {
      final parsed = parseNumberedLines('["first", "second"]', 2);
      expect(parsed, ['first', 'second']);
    });

    test('leaves a dropped line null instead of shifting the rest', () {
      final parsed = parseNumberedLines('1|first\n3|third', 3);
      expect(parsed, ['first', null, 'third']);
    });
  });

  group('LyricsEnricher with a model', () {
    test('labels a model translation as llm', () async {
      final model = _FakeModel('1|quietly');
      final enricher = LyricsEnricher(translator: model);

      final enriched = await enricher.enrich(
        const Lyrics(
          lines: [LyricLine(Duration.zero, '静かに')],
          synced: true,
        ),
        targetLanguage: 'en',
      );

      expect(enriched.lines.single.translation, 'quietly');
      expect(enriched.translationLanguage, 'en');
      expect(enriched.translationEngine, 'llm');
      expect(model.calls.single, ['静かに']);
    });

    test('falls back to Google, and says so, when the model refuses', () async {
      final model = _FakeModel('1|quietly')..fail = true;
      final enricher = _enricherWithGoogle(model, 'silently');

      final enriched = await enricher.enrich(
        const Lyrics(
          lines: [LyricLine(Duration.zero, '静かに')],
          synced: true,
        ),
        targetLanguage: 'en',
      );

      // The model was asked first and refused; the free engine answered, and
      // the layer carries the free engine's name so the model is asked again
      // on the next play.
      expect(model.calls, isNotEmpty);
      expect(enriched.lines.single.translation, 'silently');
      expect(enriched.translationEngine, 'google');
    });

    test('retranslate keeps the stored layer when nothing answers', () async {
      final model = _FakeModel('1|quietly')..fail = true;
      // Google is unreachable too: a bad connection, not a refusal.
      final dio = Dio();
      dio.httpClientAdapter = _RecordingAdapter(
        (options) async => ResponseBody.fromString('', 503),
      );
      final enricher = LyricsEnricher(dio: dio, translator: model);

      final kept = await enricher.retranslate(
        const Lyrics(
          lines: [
            LyricLine(
              Duration.zero,
              '静かに',
              pronunciation: 'shizuka ni',
              translation: 'silently',
            ),
          ],
          synced: true,
          translationLanguage: 'en',
          translationEngine: 'google',
        ),
        targetLanguage: 'en',
      );

      expect(kept.lines.single.translation, 'silently');
      expect(kept.translationEngine, 'google');
    });

    test('retranslate keeps readings and replaces only the layer', () async {
      final model = _FakeModel('1|quietly');
      final enricher = LyricsEnricher(translator: model);

      final retranslated = await enricher.retranslate(
        const Lyrics(
          lines: [
            LyricLine(
              Duration.zero,
              '静かに',
              pronunciation: 'shizuka ni',
              translation: 'silently',
            ),
          ],
          synced: true,
          translationLanguage: 'en',
          translationEngine: 'google',
        ),
        targetLanguage: 'en',
      );

      expect(retranslated.lines.single.pronunciation, 'shizuka ni');
      expect(retranslated.lines.single.translation, 'quietly');
      expect(retranslated.translationEngine, 'llm');
      // Only the words were sent: the reading is not a thing to translate.
      expect(model.calls.single, ['静かに']);
    });
  });

  group('PersonaLineTranslator', () {
    test('sends the raw model and reads the numbered reply back', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _RecordingAdapter((options) async {
        recorded = options;
        return ResponseBody.fromString(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': '1|quietly\n2|and'},
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final translator = PersonaLineTranslator(
        baseUrl: 'https://api.solian.app/',
        session: const OAuthSession(accessToken: 'token'),
        model: 'openai/gpt-4.1-mini',
        dio: dio,
      );

      final translated = await translator.translate(['静かに', 'そして'], 'en');

      expect(translated, ['quietly', 'and']);
      expect(recorded!.path, 'https://api.solian.app/persona/v1/chat/completions');
      expect(
        recorded!.headers['Authorization'],
        'Bearer token',
      );
      final body = recorded!.data as Map<String, dynamic>;
      expect(body['model'], 'raw/openai/gpt-4.1-mini');
      expect(body['stream'], isFalse);
      final messages = body['messages'] as List;
      expect((messages.last as Map)['content'], '1|静かに\n2|そして');
    });

    test('splits a long page into batches and keeps line numbering', () async {
      var requests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _RecordingAdapter((options) async {
        requests++;
        final content =
            (options.data as Map)['messages'].last['content'] as String;
        final lines = content.split('\n');
        final reply = [
          for (var i = 0; i < lines.length; i++) '${i + 1}|line ${i + 1}',
        ].join('\n');
        return ResponseBody.fromString(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': reply},
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final translator = PersonaLineTranslator(
        baseUrl: 'https://api.solian.app',
        session: const OAuthSession(accessToken: 't'),
        model: 'openai/gpt-4.1-mini',
        dio: dio,
      );

      final translated = await translator.translate(
        [for (var i = 1; i <= 130; i++) '原文$i'],
        'en',
      );

      expect(requests, 3);
      expect(translated, hasLength(130));
      expect(translated[59], 'line 60');
      expect(translated[60], 'line 1');
      expect(translated[129], 'line 10');
    });

    test('throws an empty completion so the caller can fall back', () async {
      final dio = Dio();
      dio.httpClientAdapter = _RecordingAdapter(
        (options) async => ResponseBody.fromString(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': ''},
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      final translator = PersonaLineTranslator(
        baseUrl: 'https://api.solian.app',
        session: const OAuthSession(accessToken: 't'),
        model: 'openai/gpt-4.1-mini',
        dio: dio,
      );

      expect(
        () => translator.translate(['静かに'], 'en'),
        throwsA(isA<PersonaTranslationException>()),
      );
    });
  });

  group('cached translation layers', () {
    test('a layer from the other engine is re-translated, not re-fetched', () async {
      final (:db, :store) = _open();
      final model = _FakeModel('1|quietly');
      final resolver = _resolver(
        db,
        store,
        enricher: LyricsEnricher(translator: model),
      );

      // The first play stores a Google layer.
      await store.write(
        await LibraryCatalog(db).requestTrackId(_song),
        const Lyrics(
          lines: [LyricLine(Duration.zero, '静かに', translation: 'silently')],
          synced: true,
          language: 'ja',
          translationLanguage: 'en',
          translationEngine: 'google',
        ),
        origin: LyricsOrigin.lrclib,
      );

      final lyrics = await resolver.resolve(_song, languageCode: 'en');

      expect(lyrics.lines.single.translation, 'quietly');
      expect(lyrics.translationEngine, 'llm');
      expect(model.calls, hasLength(1));
    });

    test('a layer in another language is still a miss', () async {
      final (:db, :store) = _open();
      final model = _FakeModel('1|quietly');
      final resolver = _resolver(
        db,
        store,
        enricher: LyricsEnricher(translator: model),
      );

      await store.write(
        await LibraryCatalog(db).requestTrackId(_song),
        const Lyrics(
          lines: [LyricLine(Duration.zero, '静かに', translation: '静けさ')],
          synced: true,
          language: 'ja',
          translationLanguage: 'zh-CN',
          translationEngine: 'llm',
        ),
        origin: LyricsOrigin.lrclib,
      );

      final lyrics = await resolver.resolve(_song, languageCode: 'en');

      // The stored words cannot answer an English request, and the library
      // has none: the resolver reports the miss rather than the Chinese layer.
      expect(lyrics.lines, isEmpty);
    });
  });
}
