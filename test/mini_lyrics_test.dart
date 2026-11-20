import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/desktop/mini_player/mini_lyrics.dart';
import 'package:groovy_box/library/lyrics.dart';

const _request = LyricsRequest(
  sourceId: 'a',
  id: 's1',
  title: 'ハロ／ハワユ',
  artist: 'Kano',
  duration: Duration(seconds: 208),
);

const _guestAnswer = Lyrics(
  lines: [LyricLine(Duration(seconds: 3), 'host line')],
  synced: true,
);

void main() {
  test('resolve asks the host and decodes its answer', () async {
    final calls = <String>[];
    late Map<String, dynamic> sent;
    final resolver = HostLyricsResolver.withCommand((method, [args]) async {
      calls.add(method);
      sent = Map<String, dynamic>.from(args as Map);
      return encodeLyrics(_guestAnswer);
    });

    final lyrics = await resolver.resolve(_request);

    expect(calls, ['resolveLyrics']);
    expect(sent['id'], 's1');
    expect(sent['refresh'], false);
    expect(lyrics.lines.single.text, 'host line');
  });

  test('a host that never answers is an empty pane, not an error', () async {
    final resolver = HostLyricsResolver.withCommand((method, [args]) async => null);

    final lyrics = await resolver.resolve(_request);

    expect(lyrics.isEmpty, isTrue);
  });

  test('adopt sends the lyric and keeps what the host stored', () async {
    late Map<String, dynamic> sent;
    final resolver = HostLyricsResolver.withCommand((method, [args]) async {
      sent = Map<String, dynamic>.from(args as Map);
      return encodeLyrics(
        const Lyrics(
          lines: [LyricLine(Duration(seconds: 1), 'enriched line')],
          synced: true,
          translationLanguage: 'zh-CN',
        ),
      );
    });

    final stored = await resolver.adopt(
      _request,
      const Lyrics(
        lines: [LyricLine(Duration(seconds: 1), 'picked line')],
        synced: true,
      ),
      languageCode: 'zh-CN',
    );

    final request = Map<String, dynamic>.from(sent['request'] as Map);
    final picked = Map<String, dynamic>.from(sent['lyrics'] as Map);
    expect(request['languageCode'], 'zh-CN');
    expect((picked['lines'] as List).single['text'], 'picked line');
    // The host's enrichment is what the pane shows, not the raw pick.
    expect(stored.lines.single.text, 'enriched line');
    expect(stored.translationLanguage, 'zh-CN');
  });

  test('ask-again reaches the host cache', () async {
    final calls = <String>[];
    final resolver = HostLyricsResolver.withCommand((method, [args]) async {
      calls.add(method);
      return null;
    });

    await resolver.forget(_request);

    expect(calls, ['forgetLyrics']);
  });
}
