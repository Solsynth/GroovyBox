import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/subsonic_adapter.dart';

const _song = LibrarySong(
  sourceId: 'a',
  id: 's1',
  title: 'Track',
  duration: Duration(seconds: 200),
);

void main() {
  test('Subsonic stars and unstars through the API', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}?${request.uri.query}');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'subsonic-response': {
            'status': 'ok',
            'version': '1.16.1',
            'song': {
              'id': 's1',
              'title': 'Track',
              'starred': '2024-01-01T00:00:00Z',
            },
          },
        }),
      );
      await request.response.close();
    });

    final source = SubsonicSource(
      SourceConfig(
        id: 'a',
        kind: LibraryKind.subsonic,
        baseUrl: 'http://127.0.0.1:${server.port}',
        displayName: 'Home',
        auth: {'username': 'u', 'token': 't', 'salt': 's'},
      ),
    );

    await source.setFavourite(_song, value: true);
    await source.setFavourite(_song, value: false);
    expect(await source.isFavourite(_song), isTrue);

    expect(requests[0], contains('/rest/star'));
    expect(requests[1], contains('/rest/unstar'));
    expect(requests[2], contains('/rest/getSong'));
  });
}
