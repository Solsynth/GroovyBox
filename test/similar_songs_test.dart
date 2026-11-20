import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/subsonic_adapter.dart';

const _seed = LibrarySong(
  sourceId: 'a',
  id: 'seed',
  title: 'Seed',
  duration: Duration(seconds: 200),
);

/// Serves a scripted response per endpoint and records what was asked.
class _Server {
  _Server(this.answers);

  final Map<String, Object> answers;
  final requests = <String>[];

  Future<SubsonicSource> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final endpoint = request.uri.pathSegments.last;
      requests.add(endpoint);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(answers[endpoint] ?? _empty));
      await request.response.close();
    });
    return SubsonicSource(
      SourceConfig(
        id: 'a',
        kind: LibraryKind.subsonic,
        baseUrl: 'http://127.0.0.1:${server.port}',
        displayName: 'Home',
        auth: {'username': 'u', 'token': 't', 'salt': 's'},
      ),
    );
  }
}

Map<String, Object> _songs(List<String> ids) => {
  'subsonic-response': {
    'status': 'ok',
    'version': '1.16.1',
    'similarSongs2': {
      'song': [
        for (final id in ids)
          {'id': id, 'title': 'Neighbour $id', 'duration': 200},
      ],
    },
  },
};

Map<String, Object> _failed(int code) => {
  'subsonic-response': {
    'status': 'failed',
    'version': '1.16.1',
    'error': {'code': code, 'message': 'not supported'},
  },
};

const _empty = {
  'subsonic-response': {'status': 'ok', 'version': '1.16.1'},
};

void main() {
  test('Subsonic asks getSimilarSongs2 and maps the neighbours', () async {
    final source = await _Server({
      'getSimilarSongs2': _songs(['b', 'c']),
    }).start();

    final songs = await source.similarSongs(_seed, limit: 10);

    expect(songs.map((song) => song.id), ['b', 'c']);
    expect(songs.first.title, 'Neighbour b');
  });

  test(
    'a server without the extension falls back to the older endpoint',
    () async {
      final server = _Server({
        'getSimilarSongs2': _failed(10),
        'getSimilarSongs': _songs(['d']),
      });
      final source = await server.start();

      final songs = await source.similarSongs(_seed, limit: 10);

      expect(songs.map((song) => song.id), ['d']);
      expect(server.requests, ['getSimilarSongs2', 'getSimilarSongs']);
    },
  );

  test(
    'a real failure travels up rather than reading as no neighbours',
    () async {
      final source = await _Server({'getSimilarSongs2': _failed(40)}).start();

      await expectLater(
        source.similarSongs(_seed),
        throwsA(isA<LibraryException>()),
      );
    },
  );

  test('a server with no similar data answers empty, not an error', () async {
    final source = await _Server({}).start();

    final songs = await source.similarSongs(_seed);

    expect(songs, isEmpty);
  });
}
