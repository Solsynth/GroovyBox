import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../core/identity.dart';
import 'models.dart';

class OidcConfiguration {
  const OidcConfiguration({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.deviceAuthorizationEndpoint,
  });

  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri? deviceAuthorizationEndpoint;

  factory OidcConfiguration.fromJson(
    Map<String, dynamic> json,
    String fallbackBase,
  ) {
    final authStr =
        json['authorization_endpoint'] as String? ??
        '$fallbackBase/stargate/auth/open/authorize';
    final tokenStr =
        json['token_endpoint'] as String? ??
        '$fallbackBase/stargate/auth/open/token';
    final deviceStr =
        json['device_authorization_endpoint'] as String? ??
        '$fallbackBase/stargate/auth/open/device/code';

    return OidcConfiguration(
      authorizationEndpoint: Uri.parse(authStr),
      tokenEndpoint: Uri.parse(tokenStr),
      deviceAuthorizationEndpoint: deviceStr.isNotEmpty
          ? Uri.tryParse(deviceStr)
          : null,
    );
  }
}

class SolarpassClient {
  SolarpassClient({Dio? dio, this.config = const SolarpassConfig()})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ) {
    // Stargate records the user agent that obtained a session and Solian lists
    // it as the device name. Without this the session shows up as
    // `Dart/<sdk> (dart:io)` and cannot be recognised. Set on the instance
    // rather than the BaseOptions above so an injected Dio gets it too.
    _dio.options.headers['User-Agent'] = appUserAgent;
  }

  final Dio _dio;
  SolarpassConfig config;

  String get _issuer => config.serverUrl.replaceAll(RegExp(r'/+$'), '');
  String get _clientId => config.clientId;
  String get _callbackScheme => config.callbackScheme;
  String get _redirectUri => '$_callbackScheme://oauth/callback';

  static const _deviceCodeGrant =
      'urn:ietf:params:oauth:grant-type:device_code';

  static String _randomUrlSafe(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<OidcConfiguration> discover() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_issuer/.well-known/openid-configuration',
      );
      final data = response.data;
      if (data != null) {
        return OidcConfiguration.fromJson(data, _issuer);
      }
    } catch (e) {
      debugPrint(
        '[Solarpass] OIDC discovery failed, using fallback endpoints: $e',
      );
    }
    return OidcConfiguration(
      authorizationEndpoint: Uri.parse('$_issuer/stargate/auth/open/authorize'),
      tokenEndpoint: Uri.parse('$_issuer/stargate/auth/open/token'),
      deviceAuthorizationEndpoint: Uri.parse(
        '$_issuer/stargate/auth/open/device/code',
      ),
    );
  }

  /// Authorization code flow with PKCE using browser popup.
  Future<OAuthSession> authorizeBrowser() async {
    final conf = await discover();
    final verifier = _randomUrlSafe(64);
    final state = _randomUrlSafe(32);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');

    final authUrl = conf.authorizationEndpoint.replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': '*',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    debugPrint('[Solarpass] Launching browser auth: $authUrl');
    final callbackRaw = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final callback = Uri.parse(callbackRaw);
    if (callback.queryParameters['state'] != state) {
      throw const OAuthException(
        'State verification failed in OAuth response.',
      );
    }

    final error = callback.queryParameters['error'];
    if (error != null) {
      throw OAuthException(
        callback.queryParameters['error_description'] ?? error,
        code: error,
      );
    }

    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const OAuthException(
        'Authorization server did not provide a code.',
      );
    }

    return _exchangeCode(conf.tokenEndpoint, code: code, verifier: verifier);
  }

  Future<OAuthSession> _exchangeCode(
    Uri tokenEndpoint, {
    required String code,
    required String verifier,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        tokenEndpoint.toString(),
        data: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': verifier,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = response.data ?? {};
      return _sessionFrom(data);
    } on DioException catch (e) {
      final desc = e.response?.data is Map
          ? e.response?.data['error_description'] ?? e.response?.data['error']
          : null;
      throw OAuthException(
        desc?.toString() ?? e.message ?? 'Token exchange failed',
      );
    }
  }

  /// Authorizes using RFC 8628 device flow.
  Future<OAuthSession> authorizeDevice({
    void Function(DeviceAuthorization authorization)? onDeviceCode,
  }) async {
    final conf = await discover();
    final endpoint = conf.deviceAuthorizationEndpoint;
    if (endpoint == null) {
      throw const OAuthException(
        'Device authorization is not supported by this server.',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      endpoint.toString(),
      data: {'client_id': _clientId, 'scope': '*'},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data ?? const <String, dynamic>{};
    final deviceCode = data['device_code'] as String? ?? '';
    final userCode = data['user_code'] as String? ?? '';
    final verificationUri = Uri.tryParse(
      data['verification_uri'] as String? ?? '',
    );
    if (deviceCode.isEmpty || userCode.isEmpty || verificationUri == null) {
      throw const OAuthException('Invalid device code response from server.');
    }

    final completeUri = Uri.tryParse(
      data['verification_uri_complete'] as String? ?? '',
    );
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 600;
    final interval = (data['interval'] as num?)?.toInt() ?? 5;

    final authorization = DeviceAuthorization(
      userCode: userCode,
      verificationUri: verificationUri,
      verificationUriComplete: completeUri != null && completeUri.hasScheme
          ? completeUri
          : verificationUri,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      interval: interval,
    );

    onDeviceCode?.call(authorization);

    return _awaitDeviceApproval(
      conf.tokenEndpoint,
      deviceCode: deviceCode,
      interval: interval,
      deadline: authorization.expiresAt,
    );
  }

  Future<OAuthSession> _awaitDeviceApproval(
    Uri tokenEndpoint, {
    required String deviceCode,
    required int interval,
    required DateTime deadline,
  }) async {
    var wait = interval;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: wait));
      Map<String, dynamic>? failure;
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          tokenEndpoint.toString(),
          data: {
            'grant_type': _deviceCodeGrant,
            'device_code': deviceCode,
            'client_id': _clientId,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        return _sessionFrom(response.data ?? const <String, dynamic>{});
      } on DioException catch (error) {
        final body = error.response?.data;
        if (body is! Map) rethrow;
        failure = Map<String, dynamic>.from(body);
      }
      final err = failure['error']?.toString();
      if (err == 'authorization_pending') continue;
      if (err == 'slow_down') {
        wait += 5;
        continue;
      }
      if (err == 'expired_token') {
        throw const OAuthException(
          'Device authorization code has expired. Please try again.',
        );
      }
      if (err == 'access_denied') {
        throw const OAuthException('Authorization was rejected.');
      }
      throw OAuthException(
        failure['error_description']?.toString() ??
            err ??
            'Device authorization failed.',
      );
    }
    throw const OAuthException('Device authorization timed out.');
  }

  /// Refreshes the session using the refresh token.
  Future<OAuthSession> refresh(OAuthSession session) async {
    if (session.refreshToken == null || session.refreshToken!.isEmpty) {
      throw const OAuthException(
        'No refresh token available to refresh session.',
      );
    }
    final conf = await discover();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        conf.tokenEndpoint.toString(),
        data: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': session.refreshToken!,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = response.data ?? const <String, dynamic>{};
      return _sessionFrom(data, previous: session);
    } on DioException catch (e) {
      final desc = e.response?.data is Map
          ? e.response?.data['error_description']
          : null;
      throw OAuthException(
        desc?.toString() ?? e.message ?? 'Session refresh failed',
      );
    }
  }

  OAuthSession _sessionFrom(
    Map<String, dynamic> data, {
    OAuthSession? previous,
  }) {
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const OAuthException('Token response contained no access token.');
    }
    final refreshToken =
        (data['refresh_token'] as String?) ?? previous?.refreshToken;
    final expiresIn = (data['expires_in'] as num?)?.toInt();
    final expiresAt = expiresIn != null
        ? DateTime.now().add(Duration(seconds: expiresIn))
        : previous?.expiresAt;
    final tokenType =
        (data['token_type'] as String?) ?? previous?.tokenType ?? 'Bearer';
    final scope = (data['scope'] as String?) ?? previous?.scope;

    return OAuthSession(
      accessToken: token,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      tokenType: tokenType,
      scope: scope,
    );
  }

  /// Fetches current user profile from Stargate.
  Future<SolarpassAccount> fetchCurrentAccount(OAuthSession session) async {
    final headers = {
      'Accept': 'application/json',
      'Authorization': '${session.tokenType} ${session.accessToken}',
    };

    // Try /stargate/accounts/me first, then fallback to /api/accounts/me
    for (final path in ['/stargate/accounts/me', '/api/accounts/me']) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '$_issuer$path',
          options: Options(headers: headers),
        );
        if (response.data != null) {
          return SolarpassAccount.fromJson(response.data!, baseUrl: _issuer);
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    throw const OAuthException('Failed to fetch account info from Solarpass.');
  }

  /// Sends now playing activity to Solar Network presence (Pulsar or Stargate fallback).
  Future<void> setPresenceActivity({
    required OAuthSession session,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? position,
    String? artworkUrl,
    String? trackId,
  }) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': '${session.tokenType} ${session.accessToken}',
    };

    // 1. Try Pulsar modern playback session endpoint
    final pulsarPayload = <String, dynamic>{
      'manual_id': 'groovybox:now_playing',
      'domain': 'music',
      'title': title,
      if (artist != null && artist.isNotEmpty) 'subtitle': artist,
      if (album != null && album.isNotEmpty) 'caption': album,
      if (artworkUrl != null && artworkUrl.isNotEmpty)
        'artwork_url': artworkUrl,
      'progress_seconds': position?.inSeconds ?? 0,
      'duration_seconds': duration?.inSeconds ?? 0,
      'lease_minutes': 5,
      'provider': 'groovybox',
      if (trackId != null && trackId.isNotEmpty) 'provider_key': trackId,
      'meta': {
        'source': 'groovybox',
        'provider': 'groovybox',
        'playback_rate': 1.0,
      },
    };

    for (final path in [
      '/pulsar/sessions/now-playing',
      '/api/sessions/now-playing',
    ]) {
      try {
        await _dio.post(
          '$_issuer$path',
          data: pulsarPayload,
          options: Options(headers: headers),
        );
        debugPrint(
          '[Solarpass] Successfully reported now-playing to Pulsar ($path): $title - $artist',
        );
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          debugPrint(
            '[Solarpass] Error posting now-playing to $path: ${e.response?.statusCode} ${e.response?.data}',
          );
          rethrow;
        }
      }
    }

    // 2. Fallback to legacy Stargate activities endpoints
    final terms = <String>[
      if (title.isNotEmpty) title,
      if (artist != null && artist.isNotEmpty) artist,
      if (album != null && album.isNotEmpty) album,
      'groovybox',
      'music',
    ];

    final payload = <String, dynamic>{
      'type': 'music',
      'manual_id': 'groovybox:now_playing',
      'provider': 'groovybox',
      'reference_id': trackId ?? (artist != null ? '${artist}_$title' : title),
      'title': title,
      'subtitle': artist ?? '',
      'caption': album ?? '',
      'large_image': artworkUrl,
      'queryable_terms': terms,
      'meta': {
        'source': 'groovybox',
        'provider': 'groovybox',
        'playback_rate': 1.0,
        if (duration != null && duration.inSeconds > 0)
          'duration_seconds': duration.inSeconds,
        if (position != null) 'position_seconds': position.inSeconds,
      },
      'lease_minutes': 5,
    };

    for (final path in ['/stargate/activities', '/api/activities']) {
      try {
        await _dio.post(
          '$_issuer$path',
          data: payload,
          options: Options(headers: headers),
        );
        debugPrint(
          '[Solarpass] Successfully scrobbled activity: $title - $artist to $path',
        );
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          debugPrint(
            '[Solarpass] Error posting activity to $path: ${e.response?.statusCode} ${e.response?.data}',
          );
          rethrow;
        }
      }
    }
  }

  /// Submits completed playback scrobble to Pulsar scrobbles history.
  Future<void> submitScrobble({
    required OAuthSession session,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? listened,
    String? artworkUrl,
    String? trackId,
    DateTime? playedAt,
  }) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': '${session.tokenType} ${session.accessToken}',
    };

    final pulsarPayload = <String, dynamic>{
      'domain': 'music',
      'client_name': 'groovybox',
      'title': title,
      if (artist != null && artist.isNotEmpty) 'subtitle': artist,
      if (album != null && album.isNotEmpty) 'caption': album,
      if (artworkUrl != null && artworkUrl.isNotEmpty)
        'artwork_url': artworkUrl,
      'duration_seconds': duration?.inSeconds ?? 0,
      'listened_seconds': listened?.inSeconds ?? duration?.inSeconds ?? 0,
      if (playedAt != null) 'played_at': playedAt.toUtc().toIso8601String(),
      'provider': 'groovybox',
      if (trackId != null && trackId.isNotEmpty) 'provider_key': trackId,
      'meta': {'source': 'groovybox', 'client': 'groovybox'},
    };

    for (final path in ['/pulsar/scrobbles', '/api/scrobbles']) {
      try {
        await _dio.post(
          '$_issuer$path',
          data: pulsarPayload,
          options: Options(headers: headers),
        );
        debugPrint(
          '[Solarpass] Successfully submitted scrobble to Pulsar ($path): $title - $artist',
        );
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          debugPrint(
            '[Solarpass] Error submitting scrobble to $path: ${e.response?.statusCode} ${e.response?.data}',
          );
          rethrow;
        }
      }
    }
  }

  /// Clears active presence activity in Pulsar or Stargate.
  Future<void> clearPresenceActivity({required OAuthSession session}) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': '${session.tokenType} ${session.accessToken}',
    };

    // 1. Try Pulsar session end
    for (final path in ['/pulsar/sessions/end', '/api/sessions/end']) {
      try {
        await _dio.post(
          '$_issuer$path',
          data: {'manual_id': 'groovybox:now_playing'},
          options: Options(headers: headers),
        );
        debugPrint('[Solarpass] Ended active session on Pulsar ($path)');
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          debugPrint(
            '[Solarpass] Error ending session on $path: ${e.response?.statusCode}',
          );
        }
      }
    }

    // 2. Fallback to Stargate DELETE /activities
    for (final path in ['/stargate/activities', '/api/activities']) {
      try {
        await _dio.delete(
          '$_issuer$path',
          queryParameters: {'manualId': 'groovybox:now_playing'},
          options: Options(headers: headers),
        );
        debugPrint('[Solarpass] Cleared activity presence on $path');
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          debugPrint(
            '[Solarpass] Error clearing activity on $path: ${e.response?.statusCode}',
          );
        }
      }
    }
  }
}
