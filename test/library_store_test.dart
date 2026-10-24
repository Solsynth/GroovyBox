import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/store.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a container whose prefs are read fresh, the way the app does at
/// launch.
Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates the single-server record into a source list', () async {
    SharedPreferences.setMockInitialValues({
      'app_server': jsonEncode({
        'baseUrl': 'https://m.example.com/rest',
        'username': 'u',
        'token': 't',
        'salt': 's',
      }),
    });

    final container = await _container();
    final configs = container.read(sourceStoreProvider);

    expect(configs, hasLength(1));
    final config = configs.single;
    expect(config.kind, LibraryKind.subsonic);
    expect(config.baseUrl, 'https://m.example.com/rest');
    expect(config.displayName, 'm.example.com');
    expect(config.auth, {'username': 'u', 'token': 't', 'salt': 's'});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_server'), isNull, reason: 'legacy key dropped');
    final stored = jsonDecode(prefs.getString('app_sources')!) as List;
    expect(stored, hasLength(1));
    expect((stored.single as Map)['kind'], 'subsonic');
  });

  test('adds and removes sources, persisting across containers', () async {
    SharedPreferences.setMockInitialValues({});

    final jellyfin = SourceConfig(
      id: 'jellyfin-1',
      kind: LibraryKind.jellyfin,
      baseUrl: 'https://jellyfin.example.com:8096',
      displayName: 'jellyfin.example.com',
      auth: const {
        'username': 'u',
        'userId': 'u1',
        'accessToken': 'tok',
      },
    );

    final first = await _container();
    await first.read(sourceStoreProvider.notifier).add(jellyfin);
    expect(first.read(sourceStoreProvider), hasLength(1));

    final second = await _container();
    expect(second.read(sourceStoreProvider), hasLength(1));
    expect(second.read(sourceStoreProvider).single.auth['accessToken'], 'tok');

    await second.read(sourceStoreProvider.notifier).remove('jellyfin-1');
    expect(second.read(sourceStoreProvider), isEmpty);

    final third = await _container();
    expect(third.read(sourceStoreProvider), isEmpty);
  });

  test('drops a record whose kind this build does not know', () async {
    SharedPreferences.setMockInitialValues({
      'app_sources': jsonEncode([
        {'id': 'x', 'kind': 'roon', 'baseUrl': 'https://x', 'displayName': 'x'},
        {
          'id': 'y',
          'kind': 'subsonic',
          'baseUrl': 'https://y',
          'displayName': 'y',
          'auth': {'username': 'u', 'token': 't', 'salt': 's'},
        },
      ]),
    });

    final container = await _container();
    final configs = container.read(sourceStoreProvider);

    expect(configs.map((config) => config.id), ['y']);
  });
}
