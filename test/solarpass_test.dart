import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/solarpass/client.dart';
import 'package:groovy_box/solarpass/models.dart';
import 'package:groovy_box/solarpass/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDioAdapter implements HttpClientAdapter {
  _MockDioAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

void main() {
  group('Solarpass Models', () {
    test('OAuthSession json roundtrip and expiration', () {
      final now = DateTime.now();
      final session = OAuthSession(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        expiresAt: now.add(const Duration(minutes: 60)),
        tokenType: 'Bearer',
        scope: '*',
      );

      final json = session.toJson();
      final restored = OAuthSession.fromJson(json);

      expect(restored, isNotNull);
      expect(restored!.accessToken, 'access_123');
      expect(restored.refreshToken, 'refresh_456');
      expect(restored.tokenType, 'Bearer');
      expect(restored.needsRefresh, isFalse);
      expect(restored.isExpired, isFalse);

      final expiringSession = OAuthSession(
        accessToken: 'abc',
        expiresAt: now.add(const Duration(seconds: 20)),
      );
      expect(expiringSession.needsRefresh, isTrue);

      final expiredSession = OAuthSession(
        accessToken: 'abc',
        expiresAt: now.subtract(const Duration(seconds: 10)),
      );
      expect(expiredSession.isExpired, isTrue);
    });

    test('SolarpassAccount json parsing and displayName resolution', () {
      final json = {
        'id': 'user-uuid-1',
        'name': 'littlesheep',
        'nick': 'Little Sheep',
        'email': 'sheep@solian.app',
        'profile': {
          'bio': 'Music lover',
          'picture': {'url': 'https://example.com/avatar.jpg'},
        },
      };

      final account = SolarpassAccount.fromJson(json, baseUrl: 'https://api.solian.app');
      expect(account.id, 'user-uuid-1');
      expect(account.name, 'littlesheep');
      expect(account.nick, 'Little Sheep');
      expect(account.displayName, 'Little Sheep');
      expect(account.avatarUrl, 'https://example.com/avatar.jpg');
      expect(account.bio, 'Music lover');

      // Test fallback avatar when picture is omitted
      final noPicJson = {
        'id': 'user-uuid-2',
        'name': 'solian_fan',
      };
      final fallbackAccount = SolarpassAccount.fromJson(noPicJson, baseUrl: 'https://api.solian.app');
      expect(fallbackAccount.avatarUrl, 'https://api.solian.app/stargate/accounts/solian_fan/picture');
      expect(fallbackAccount.displayName, 'solian_fan');
    });

    test('SolarpassConfig defaults and mutations', () {
      const config = SolarpassConfig();
      expect(config.serverUrl, 'https://api.solian.app');
      expect(config.clientId, 'groovybox');
      expect(config.callbackScheme, 'groovybox');
      expect(config.scrobbleEnabled, isTrue);

      final updated = config.copyWith(serverUrl: 'http://localhost:8080', scrobbleEnabled: false);
      expect(updated.serverUrl, 'http://localhost:8080');
      expect(updated.clientId, 'groovybox');
      expect(updated.scrobbleEnabled, isFalse);
    });
  });

  group('SolarpassClient', () {
    test('discover loads openid configuration or falls back', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.endsWith('/.well-known/openid-configuration')) {
          return ResponseBody.fromString(
            jsonEncode({
              'authorization_endpoint': 'https://auth.example.com/authorize',
              'token_endpoint': 'https://auth.example.com/token',
              'device_authorization_endpoint': 'https://auth.example.com/device',
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final client = SolarpassClient(
        dio: dio,
        config: const SolarpassConfig(serverUrl: 'https://auth.example.com'),
      );

      final conf = await client.discover();
      expect(conf.authorizationEndpoint.toString(), 'https://auth.example.com/authorize');
      expect(conf.tokenEndpoint.toString(), 'https://auth.example.com/token');
      expect(conf.deviceAuthorizationEndpoint.toString(), 'https://auth.example.com/device');
    });

    test('refresh exchanges refresh_token for a new session', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.contains('/auth/open/token')) {
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
              'expires_in': 3600,
              'token_type': 'Bearer',
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 200);
      });

      final client = SolarpassClient(dio: dio);
      final refreshed = await client.refresh(
        const OAuthSession(
          accessToken: 'old_access',
          refreshToken: 'old_refresh',
        ),
      );

      expect(refreshed.accessToken, 'new_access_token');
      expect(refreshed.refreshToken, 'new_refresh_token');
    });

    test('fetchCurrentAccount retrieves profile information', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.contains('/accounts/me')) {
          return ResponseBody.fromString(
            jsonEncode({
              'id': '1111-2222',
              'name': 'testuser',
              'nick': 'Tester',
              'profile': {'bio': 'Testing GroovyBox'},
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final client = SolarpassClient(dio: dio);
      final account = await client.fetchCurrentAccount(
        const OAuthSession(accessToken: 'mock_token'),
      );

      expect(account.id, '1111-2222');
      expect(account.name, 'testuser');
      expect(account.displayName, 'Tester');
      expect(account.bio, 'Testing GroovyBox');
    });

    test('setPresenceActivity sends properly formatted music activity', () async {
      final dio = Dio();
      RequestOptions? recordedRequest;
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.contains('/activities')) {
          recordedRequest = options;
          return ResponseBody.fromString('{"id":"activity-123"}', 200);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final client = SolarpassClient(dio: dio);
      await client.setPresenceActivity(
        session: const OAuthSession(accessToken: 'valid_token'),
        title: 'Brave Song',
        artist: 'Aoi Tada',
        album: 'Angel Beats! OST',
        duration: const Duration(minutes: 5, seconds: 25),
        position: const Duration(minutes: 1, seconds: 15),
        trackId: 'track_99',
      );

      expect(recordedRequest, isNotNull);
      final data = recordedRequest!.data as Map<String, dynamic>;
      expect(data['type'], 'music');
      expect(data['manual_id'], 'groovybox:now_playing');
      expect(data['provider'], 'groovybox');
      expect(data['title'], 'Brave Song');
      expect(data['subtitle'], 'Aoi Tada');
      expect(data['caption'], 'Angel Beats! OST');
      expect(data['reference_id'], 'track_99');
      expect(data['lease_minutes'], 5);
      expect(data['meta']['duration_seconds'], 325);
      expect(data['meta']['position_seconds'], 75);
    });

    test('clearPresenceActivity sends DELETE request with manualId', () async {
      final dio = Dio();
      RequestOptions? deleteRequest;
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.contains('/activities') && options.method == 'DELETE') {
          deleteRequest = options;
          return ResponseBody.fromString('', 204);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final client = SolarpassClient(dio: dio);
      await client.clearPresenceActivity(
        session: const OAuthSession(accessToken: 'valid_token'),
      );

      expect(deleteRequest, isNotNull);
      expect(deleteRequest!.queryParameters['manualId'], 'groovybox:now_playing');
    });

    test('setPresenceActivity prioritizes Pulsar now-playing endpoint', () async {
      final dio = Dio();
      RequestOptions? recordedRequest;
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.contains('/pulsar/sessions/now-playing')) {
          recordedRequest = options;
          return ResponseBody.fromString('{"status":"ok"}', 200);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final client = SolarpassClient(dio: dio);
      await client.setPresenceActivity(
        session: const OAuthSession(accessToken: 'valid_token'),
        title: 'Brave Song',
        artist: 'Aoi Tada',
        album: 'Angel Beats! OST',
        duration: const Duration(minutes: 5, seconds: 25),
        position: const Duration(minutes: 1, seconds: 15),
        trackId: 'track_99',
      );

      expect(recordedRequest, isNotNull);
      final data = recordedRequest!.data as Map<String, dynamic>;
      expect(data['domain'], 'music');
      expect(data['manual_id'], 'groovybox:now_playing');
      expect(data['provider'], 'groovybox');
      expect(data['provider_key'], 'track_99');
      expect(data['title'], 'Brave Song');
      expect(data['subtitle'], 'Aoi Tada');
      expect(data['caption'], 'Angel Beats! OST');
      expect(data['progress_seconds'], 75);
      expect(data['duration_seconds'], 325);
    });

    test('submitScrobble posts to Pulsar scrobbles endpoint', () async {
      final dio = Dio();
      RequestOptions? recordedRequest;
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.contains('/pulsar/scrobbles')) {
          recordedRequest = options;
          return ResponseBody.fromString('{"id":"scrobble_1"}', 200);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final client = SolarpassClient(dio: dio);
      await client.submitScrobble(
        session: const OAuthSession(accessToken: 'valid_token'),
        title: 'Brave Song',
        artist: 'Aoi Tada',
        album: 'Angel Beats! OST',
        duration: const Duration(minutes: 5, seconds: 25),
        listened: const Duration(minutes: 4),
        trackId: 'track_99',
      );

      expect(recordedRequest, isNotNull);
      final data = recordedRequest!.data as Map<String, dynamic>;
      expect(data['domain'], 'music');
      expect(data['client_name'], 'groovybox');
      expect(data['title'], 'Brave Song');
      expect(data['subtitle'], 'Aoi Tada');
      expect(data['duration_seconds'], 325);
      expect(data['listened_seconds'], 240);
      expect(data['provider'], 'groovybox');
      expect(data['provider_key'], 'track_99');
    });

    test('clearPresenceActivity prioritizes Pulsar sessions end endpoint', () async {
      final dio = Dio();
      RequestOptions? recordedRequest;
      dio.httpClientAdapter = _MockDioAdapter((options) async {
        if (options.path.contains('/pulsar/sessions/end')) {
          recordedRequest = options;
          return ResponseBody.fromString('{"status":"ended"}', 200);
        }
        return ResponseBody.fromString('Not Found', 404);
      });

      final client = SolarpassClient(dio: dio);
      await client.clearPresenceActivity(
        session: const OAuthSession(accessToken: 'valid_token'),
      );

      expect(recordedRequest, isNotNull);
      final data = recordedRequest!.data as Map<String, dynamic>;
      expect(data['manual_id'], 'groovybox:now_playing');
    });
  });

  group('Solarpass Providers and Scrobbler', () {
    test('SolarpassSessionNotifier restore, save, signOut flow', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(solarpassSessionProvider.notifier);
      expect(container.read(solarpassSessionProvider).value, isNull);

      await prefs.setString(
        'solarpass_oauth_session',
        jsonEncode(const OAuthSession(accessToken: 'restored_token').toJson()),
      );

      container.invalidate(solarpassSessionProvider);
      final session = await container.read(solarpassSessionProvider.future);
      expect(session?.accessToken, 'restored_token');

      await notifier.signOut();
      expect(container.read(solarpassSessionProvider).value, isNull);
      expect(prefs.getString('solarpass_oauth_session'), isNull);
    });
  });
}
