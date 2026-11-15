import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/pulsar/client.dart';
import 'package:groovy_box/pulsar/favourites.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider whose account already holds favourites: the import half of
/// [RatedSource].
class _Rated extends LibrarySource implements RatedSource {
  _Rated(this.favourites);

  final List<LibrarySong> favourites;
  int imports = 0;

  @override
  String get id => 'apple';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'apple',
    kind: LibraryKind.appleMusic,
    baseUrl: '',
    displayName: 'Apple Music',
  );

  @override
  Future<List<LibrarySong>> favouriteSongs() async {
    imports++;
    return favourites;
  }

  @override
  Future<bool> isFavourite(LibrarySong song) async => false;

  @override
  Future<void> setFavourite(LibrarySong song, {required bool value}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A connected library with no account of its own, only items to serve.
class _Plain extends LibrarySource {
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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A Solar Network API that records what was written to the account and
/// answers the favourites list from [account].
class _FakeSolar {
  _FakeSolar(this.account);

  /// Source-scoped keys the account holds.
  final Set<String> account;

  final List<Map<String, dynamic>> added = [];
  final List<String> removed = [];

  late final Dio dio;

  static ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  HttpClientAdapter adapter() => _Adapter((options) async {
    final path = options.path;
    if (path.endsWith('/collections/favourites') && options.method == 'GET') {
      return _json({
        'items': [
          for (final key in account)
            {
              'id': 'item-$key',
              'catalog_id': 'cat-$key',
              'catalog_item': {
                'id': 'cat-$key',
                'domain': 'music',
                'provider': 'groovybox',
                'provider_key': key,
                'title': 'Track ${key.split(':').last}',
                'duration_seconds': 200,
              },
            },
        ],
      });
    }
    if (path.endsWith('/collections/favourites') && options.method == 'PUT') {
      final body = (options.data as Map).cast<String, dynamic>();
      added.add(body);
      final key = body['provider_key'] as String;
      account.add(key);
      return _json({'id': 'cat-$key'}, 201);
    }
    if (path.contains('/collections/favourites/') &&
        options.method == 'DELETE') {
      removed.add(path.split('/').last);
      return _json({}, 204);
    }
    return _json({}, 404);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);
}

const _songA = LibrarySong(
  sourceId: 'a',
  id: 's1',
  title: 'Brave Song',
  artist: 'Aoi Tada',
  duration: Duration(seconds: 200),
);

const _songB = LibrarySong(
  sourceId: 'a',
  id: 's2',
  title: 'Yellow',
  artist: 'Coldplay',
  duration: Duration(seconds: 266),
);

typedef _Harness = ({
  ProviderContainer container,
  LibraryDatabase db,
  _FakeSolar solar,
});

Future<_Harness> _harness({
  required Set<String> account,
  bool signedIn = true,
  List<LibrarySource> sources = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    if (signedIn)
      'solarpass_oauth_session': jsonEncode({
        'access_token': 'access-token',
        'token_type': 'Bearer',
      }),
  });
  final prefs = await SharedPreferences.getInstance();
  final db = LibraryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final solar = _FakeSolar({...account});
  solar.dio = Dio()..httpClientAdapter = solar.adapter();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      libraryDatabaseProvider.overrideWithValue(db),
      librarySourcesProvider.overrideWithValue(sources),
      pulsarClientProvider.overrideWithValue(
        PulsarClient(dio: solar.dio, baseUrl: 'https://solar.example'),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, db: db, solar: solar);
}

/// Reads one auto-disposed family entry without letting it be disposed while
/// the future is in flight — `read` alone schedules the dispose immediately.
Future<bool> _heart(ProviderContainer container, LibrarySong song) async {
  final keep = container.listen(
    solarFavouriteStateProvider(song),
    (_, _) {},
  );
  addTearDown(keep.close);
  return container.read(solarFavouriteStateProvider(song).future);
}

void main() {
  test('a heart the account holds is the heart every surface draws', () async {
    final harness = await _harness(account: {'a:s1'});
    final container = harness.container;

    // Signed in, Solar answers — even for a track this device has never
    // recorded a heart for.
    expect(await _heart(container, _songA), isTrue);
    expect(await _heart(container, _songB), isFalse);
  });

  test('signed out, the device record still answers', () async {
    final harness = await _harness(account: const {}, signedIn: false);
    await LibraryCatalog(harness.db).setFavourite(_songB, value: true);

    expect(await _heart(harness.container, _songB), isTrue);
  });

  test('a sync pulls the account favourites onto this device', () async {
    final harness = await _harness(account: {'a:s1'}, sources: [_Plain()]);
    final catalog = LibraryCatalog(harness.db);
    // The device knows the track, just not that it is liked.
    await catalog.adopt(_songA);

    final result = await harness.container
        .read(solarFavouritesSyncProvider)
        .sync();

    expect(result.error, isNull);
    expect(result.pulled, 1);
    expect(await catalog.favouriteOf(_songA), isTrue);
  });

  test('a sync pushes the hearts the account is missing', () async {
    final harness = await _harness(account: const {});
    final catalog = LibraryCatalog(harness.db);
    await catalog.adopt(_songB);
    await catalog.setFavourite(_songB, value: true);

    final result = await harness.container
        .read(solarFavouritesSyncProvider)
        .sync();

    expect(result.pushed, 1);
    expect(harness.solar.added.single['provider_key'], 'a:s2');
    expect(harness.solar.added.single['title'], 'Yellow');
  });

  test('importing a provider lands its favourites in both records', () async {
    final source = _Rated(const [_songA]);
    final harness = await _harness(account: const {}, sources: [source]);

    final result = await harness.container
        .read(solarFavouritesSyncProvider)
        .importFrom('apple');

    expect(result.error, isNull);
    expect(result.found, 1);
    expect(result.pushed, 1);
    expect(source.imports, 1);
    expect(harness.solar.added.single['provider_key'], 'a:s1');
    expect(
      await LibraryCatalog(harness.db).favouriteOf(_songA),
      isTrue,
    );
  });
}
