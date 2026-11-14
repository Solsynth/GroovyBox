import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/pulsar/client.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/solarpass/models.dart';

class _MockDioAdapter implements HttpClientAdapter {
  _MockDioAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  static ResponseBody json(String body, int status) => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

const _session = OAuthSession(accessToken: 'token');

void main() {
  group('pulsarTrackKey', () {
    test('scopes the song id to its source', () {
      final song = LibrarySong(
        sourceId: 'subsonic:home',
        id: 'tr-77',
        title: 'Brave Song',
        duration: const Duration(minutes: 3),
      );
      expect(pulsarTrackKey(song), 'subsonic:home:tr-77');
    });
  });

  group('PulsarClient', () {
    test('shareTrack sends the source-scoped provider key', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json(
          '{"id":"cat-1","domain":"music","provider":"groovybox",'
          '"provider_key":"subsonic:home:tr-77","title":"Brave Song"}',
          201,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final share = await client.shareTrack(
        _session,
        title: 'Brave Song',
        artist: 'Aoi Tada',
        trackKey: 'subsonic:home:tr-77',
      );

      final data = recorded!.data as Map<String, dynamic>;
      expect(data['provider'], 'groovybox');
      expect(data['provider_key'], 'subsonic:home:tr-77');
      expect(share.shareUrl, 'https://fleet.example/m/cat-1');
    });

    test('addTrack carries the provider key the server now honors', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json('{"id":"item-1"}', 201);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      await client.addTrack(
        _session,
        playlistId: 'pl-1',
        title: 'Brave Song',
        artist: 'Aoi Tada',
        durationSeconds: 185,
        trackKey: 'subsonic:home:tr-77',
      );

      expect(recorded!.path, contains('/collections/pl-1/items'));
      final data = recorded!.data as Map<String, dynamic>;
      expect(data['provider'], 'groovybox');
      expect(data['provider_key'], 'subsonic:home:tr-77');
      expect(data['duration_seconds'], 185);
    });

    test('renamePlaylist puts the new name on the collection', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json(
          '{"id":"pl-1","name":"Sunday","is_public":true}',
          200,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final renamed = await client.renamePlaylist(
        _session,
        'pl-1',
        name: 'Sunday',
      );

      expect(recorded!.method, 'PUT');
      expect(recorded!.path, contains('/collections/pl-1'));
      expect((recorded!.data as Map<String, dynamic>)['name'], 'Sunday');
      expect(renamed.name, 'Sunday');
    });

    test('getPlaylist reads the one collection with its items', () async {
      final dio = Dio();
      RequestOptions? recorded;
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json(
          '{"id":"pl-1","name":"Sunday","is_public":true,'
          '"items":[{"id":"it-1","catalog_id":"cat-1",'
          '"catalog_item":{"id":"cat-1","domain":"music",'
          '"provider":"groovybox","title":"Brave Song",'
          '"subtitle":"Aoi Tada","duration_seconds":185}}]}',
          200,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final playlist = await client.getPlaylist(_session, 'pl-1');

      expect(recorded!.path, contains('/collections/pl-1'));
      expect(playlist.items, hasLength(1));
      expect(playlist.items.first.catalogItem?.title, 'Brave Song');
    });
  });

  group('upload and favourites', () {
    test('replacePlaylistTracks PUTs the whole list in order', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json('{"count":2}', 200);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final count = await client.replacePlaylistTracks(
        _session,
        playlistId: 'pl-1',
        tracks: const [
          PulsarTrackPayload(
            title: 'Brave Song',
            artist: 'Aoi Tada',
            providerKey: 'subsonic:home:tr-77',
          ),
          PulsarTrackPayload(
            title: 'Cheerleader',
            artist: 'Porter Robinson',
            providerKey: 'subsonic:home:tr-78',
          ),
        ],
      );

      expect(recorded!.method, 'PUT');
      expect(recorded!.path, contains('/collections/pl-1/items'));
      final items = (recorded!.data as Map<String, dynamic>)['items'] as List;
      expect(items, hasLength(2));
      expect(items.first['title'], 'Brave Song');
      expect(items.first['provider_key'], 'subsonic:home:tr-77');
      expect(items[1]['subtitle'], 'Porter Robinson');
      expect(count, 2);
    });

    test('favourites reads the account list, one entry per recording', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json(
          '{"id":"fav-1","kind":"favorites","total":1,"items":[{"id":"it-1",'
          '"catalog_id":"cat-1","catalog_item":{"id":"cat-1","domain":"music",'
          '"provider":"groovybox","provider_key":"subsonic:home:tr-77",'
          '"title":"Brave Song","subtitle":"Aoi Tada"}}]}',
          200,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final list = await client.favourites(_session);

      expect(recorded!.path, contains('/collections/favourites'));
      expect(list, hasLength(1));
      expect(list.first.catalogItem?.providerKey, 'subsonic:home:tr-77');
      expect(list.first.catalogId, 'cat-1');
    });

    test('addFavourite PUTs the track payload', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json('{}', 201);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      await client.addFavourite(
        _session,
        const PulsarTrackPayload(
          title: 'Brave Song',
          artist: 'Aoi Tada',
          durationSeconds: 185,
          providerKey: 'subsonic:home:tr-77',
        ),
      );

      expect(recorded!.method, 'PUT');
      final data = recorded!.data as Map<String, dynamic>;
      expect(data['provider'], 'groovybox');
      expect(data['provider_key'], 'subsonic:home:tr-77');
      expect(data['duration_seconds'], 185);
    });

    test('removeFavourite DELETEs by catalog id', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return ResponseBody.fromString('', 204);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      await client.removeFavourite(_session, 'cat-1');

      expect(recorded!.method, 'DELETE');
      expect(recorded!.path, endsWith('/collections/favourites/cat-1'));
    });
  });
}
