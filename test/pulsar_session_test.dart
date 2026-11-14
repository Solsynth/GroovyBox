import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/solarpass/client.dart';
import 'package:groovy_box/solarpass/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Solarpass session is what every Pulsar surface gates on — the share
/// button, the cloud playlist writes, the favourites sync.
///
/// The session lives in an async notifier whose first state is `AsyncLoading`.
/// The Pulsar layer used to reach for its *notifier* and read `state.value`
/// from inside a `keepAlive` provider: a notifier never changes identity, so
/// that provider never rebuilt, and the `null` captured at startup was the
/// answer for the rest of the process. Signing in afterwards still left every
/// Pulsar surface asking for an account.
const _sessionStore = 'solarpass_oauth_session';

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
  ) => handler(options);
}

ResponseBody _json(Map<String, dynamic> body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ProviderContainer _container(SharedPreferences prefs, {Dio? dio}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (dio != null)
        solarpassClientProvider.overrideWithValue(SolarpassClient(dio: dio)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a session stored at startup is what the Pulsar layer sees', () async {
    SharedPreferences.setMockInitialValues({
      _sessionStore: jsonEncode({
        'access_token': 'access-token',
        'refresh_token': 'refresh-token',
        'token_type': 'Bearer',
      }),
    });
    final container = _container(await SharedPreferences.getInstance());

    final session = await container.read(pulsarSessionProvider.future);

    expect(session, isNotNull);
    expect(session!.accessToken, 'access-token');
  });

  test(
    'asking for the session before the notifier built still finds it',
    () async {
      SharedPreferences.setMockInitialValues({
        _sessionStore: jsonEncode({
          'access_token': 'access-token',
          'refresh_token': 'refresh-token',
          'token_type': 'Bearer',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = _container(prefs);

      // `validSession` is what the sync panel and the Pulsar layer ask. Called
      // on the first frame it can beat the notifier's own `build`; the state is
      // `AsyncLoading` then, and "not loaded" used to be answered as "signed
      // out".
      final session = await container
          .read(solarpassSessionProvider.notifier)
          .validSession();

      expect(session, isNotNull);
      expect(container.read(solarpassSessionProvider).isLoading, isFalse);
    },
  );

  test('no stored session is still a signed-out layer', () async {
    SharedPreferences.setMockInitialValues({});
    final container = _container(await SharedPreferences.getInstance());

    expect(await container.read(pulsarSessionProvider.future), isNull);
  });

  test('signing in after the app started reaches the Pulsar layer', () async {
    SharedPreferences.setMockInitialValues({});
    final dio = Dio();
    dio.httpClientAdapter = _MockDioAdapter((options) async {
      if (options.path.endsWith('/.well-known/openid-configuration')) {
        return _json({
          'device_authorization_endpoint':
              'https://auth.example.com/device/code',
          'token_endpoint': 'https://auth.example.com/token',
        });
      }
      if (options.path.endsWith('/device/code')) {
        return _json({
          'device_code': 'device-code-1',
          'user_code': 'ABCD-EFGH',
          'verification_uri': 'https://auth.example.com/device',
          'expires_in': 600,
          'interval': 0,
        });
      }
      if (options.path.endsWith('/token')) {
        return _json({
          'access_token': 'fresh-access-token',
          'refresh_token': 'fresh-refresh-token',
          'expires_in': 3600,
          'token_type': 'Bearer',
        });
      }
      return _json({}, 404);
    });
    final container = _container(
      await SharedPreferences.getInstance(),
      dio: dio,
    );

    // Asked before sign-in, which is what the app does on its first build: the
    // answer must not be latched.
    expect(await container.read(pulsarSessionProvider.future), isNull);

    await container
        .read(solarpassSessionProvider.notifier)
        .signInDevice(onDeviceCode: (_) {});

    final session = await container.read(pulsarSessionProvider.future);
    expect(
      session,
      isNotNull,
      reason: 'a login that just happened must not read as signed out',
    );
    expect(session!.accessToken, 'fresh-access-token');
  });
}
