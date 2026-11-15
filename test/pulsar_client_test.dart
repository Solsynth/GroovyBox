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

    test('the share page lives on the public site, not the API host', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(
        (options) async => _MockDioAdapter.json('{"id":"cat-1"}', 201),
      );
      // The fleet API and the share page are different hosts: the API is
      // `api.solian.app`, the public page `mu.solian.app`. Only the share
      // link moves; every API call stays on the API host.
      final client = PulsarClient(dio: dio, baseUrl: 'https://api.solian.app');

      final share = await client.shareTrack(_session, title: 'Brave Song');

      expect(share.shareUrl, 'https://mu.solian.app/m/cat-1');
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

  group('reviews', () {
    test('reviews reads the bare array without auth', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return ResponseBody.fromString(
          '[{"id":"rev-1","account_id":"acc-1","catalog_id":"cat-1",'
          '"rating":8,"body":"Held up on re-listen.",'
          '"created_at":"2026-01-02T03:04:05Z",'
          '"updated_at":"2026-01-03T03:04:05Z"},'
          '{"id":"rev-2","account_id":"acc-2","catalog_id":"cat-1",'
          '"body":"Comment only, no rating."}]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'x-total': ['2'],
          },
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final list = await client.reviews('cat-1');

      expect(recorded!.method, 'GET');
      expect(recorded!.path, contains('/reviews'));
      expect(recorded!.queryParameters['catalog_id'], 'cat-1');
      expect(recorded!.headers.containsKey('Authorization'), isFalse);
      expect(list, hasLength(2));
      expect(list.first.rating, 8);
      expect(list.first.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(list.last.rating, isNull);
      expect(list.last.body, 'Comment only, no rating.');
    });

    test('reviewStats reads average and count', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json('{"average":7.5,"count":4}', 200);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final stats = await client.reviewStats('cat-1');

      expect(recorded!.path, contains('/reviews/stats'));
      expect(stats.average, 7.5);
      expect(stats.count, 4);
    });

    test('myReview maps the 404 of a missing review to null', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(
        (options) async => _MockDioAdapter.json(
          '{"code":"REVIEW_NOT_FOUND","message":"no review"}',
          404,
        ),
      );
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final review = await client.myReview(_session, 'cat-1');

      expect(review, isNull);
    });

    test('myReview reads the own review when it exists', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        return _MockDioAdapter.json(
          '{"id":"rev-9","account_id":"acc-me","catalog_id":"cat-1",'
          '"rating":9}',
          200,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final review = await client.myReview(_session, 'cat-1');

      expect(review?.rating, 9);
    });

    test('putReview reports created on 201 and updated on 200', () async {
      var status = 201;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        return _MockDioAdapter.json('{"id":"rev-1"}', status);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');
      const payload = PulsarReviewPayload(catalogId: 'cat-1', rating: 7);

      expect(await client.putReview(_session, payload), isTrue);

      status = 200;
      expect(await client.putReview(_session, payload), isFalse);
    });

    test('putReview sends catalog_id, rating and body as given', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json('{"id":"rev-1"}', 201);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      await client.putReview(
        _session,
        const PulsarReviewPayload(catalogId: 'cat-1', body: 'Great.'),
      );

      expect(recorded!.method, 'PUT');
      expect(recorded!.path, endsWith('/reviews'));
      final data = recorded!.data as Map<String, dynamic>;
      expect(data['catalog_id'], 'cat-1');
      expect(data.containsKey('rating'), isFalse);
      expect(data['body'], 'Great.');
    });

    test('deleteReview DELETEs by review id', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return ResponseBody.fromString('', 204);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      await client.deleteReview(_session, 'rev-1');

      expect(recorded!.method, 'DELETE');
      expect(recorded!.path, endsWith('/reviews/rev-1'));
    });
  });

  group('status marking', () {
    test('patchCollectionItem PATCHes only the sent fields', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json('{"id":"item-1"}', 200);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      await client.patchCollectionItem(
        _session,
        collectionId: 'col-1',
        itemId: 'item-1',
        patch: const PulsarItemPatch(status: 'completed', rating: 9),
      );

      expect(recorded!.method, 'PATCH');
      expect(recorded!.path, contains('/collections/col-1/items/item-1'));
      final data = recorded!.data as Map<String, dynamic>;
      expect(data['status'], 'completed');
      expect(data['rating'], 9);
      expect(data.containsKey('note'), isFalse);
    });
  });

  group('creators', () {
    test('creators sends q and domain only when given', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json(
          '[{"id":"cr-1","domain":"music","name":"Aoi Tada",'
          '"item_count":12}]',
          200,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final list = await client.creators(query: 'aoi', domain: 'music');

      expect(recorded!.queryParameters['q'], 'aoi');
      expect(recorded!.queryParameters['domain'], 'music');
      expect(list, hasLength(1));
      expect(list.first.name, 'Aoi Tada');
      expect(list.first.itemCount, 12);
    });

    test('creator reads one creator by id', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json(
          '{"id":"cr-1","domain":"music","name":"Aoi Tada",'
          '"item_count":12}',
          200,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final creator = await client.creator('cr-1');

      expect(recorded!.path, endsWith('/creators/cr-1'));
      expect(creator.name, 'Aoi Tada');
    });

    test('creatorCatalog filters by creator id', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json(
          '[{"id":"cat-1","domain":"music","provider":"groovybox",'
          '"title":"Brave Song","creators":[{"name":"Aoi Tada",'
          '"role":"artist"}]}]',
          200,
        );
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      final items = await client.creatorCatalog('cr-1', domain: 'music');

      expect(recorded!.queryParameters['creator_id'], 'cr-1');
      expect(recorded!.queryParameters['domain'], 'music');
      expect(items, hasLength(1));
      expect(items.first.title, 'Brave Song');
      expect(items.first.creators.single.role, 'artist');
    });

    test('shareTrack forwards creator credits to POST /catalog', () async {
      RequestOptions? recorded;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        recorded = options;
        return _MockDioAdapter.json('{"id":"cat-1"}', 201);
      });
      final client = PulsarClient(dio: dio, baseUrl: 'https://fleet.example');

      await client.shareTrack(
        _session,
        title: 'Brave Song',
        creators: const [
          PulsarCreatorCredit(name: 'Aoi Tada', role: 'artist'),
        ],
      );

      final data = recorded!.data as Map<String, dynamic>;
      expect(data['creators'], [
        {'name': 'Aoi Tada', 'role': 'artist'},
      ]);
    });
  });
}
