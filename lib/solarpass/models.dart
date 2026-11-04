/// Data models for Solarpass authentication and Solar Network presence scrobbler.
library;

class OAuthSession {
  const OAuthSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.tokenType = 'Bearer',
    this.scope,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String tokenType;
  final String? scope;

  bool get needsRefresh =>
      expiresAt != null &&
      DateTime.now().isAfter(expiresAt!.subtract(const Duration(seconds: 45)));

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'token_type': tokenType,
    'scope': scope,
  };

  static OAuthSession? fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) return null;
    return OAuthSession(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal(),
      tokenType: (json['token_type'] as String?) ?? 'Bearer',
      scope: json['scope'] as String?,
    );
  }
}

/// Authorization payload returned during RFC 8628 device flow.
class DeviceAuthorization {
  const DeviceAuthorization({
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresAt,
    this.interval = 5,
  });

  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final DateTime expiresAt;
  final int interval;
}

/// Solarpass Account profile details.
class SolarpassAccount {
  const SolarpassAccount({
    required this.id,
    required this.name,
    this.nick,
    this.email,
    this.avatarUrl,
    this.bio,
  });

  final String id;
  final String name;
  final String? nick;
  final String? email;
  final String? avatarUrl;
  final String? bio;

  String get displayName => (nick != null && nick!.trim().isNotEmpty) ? nick!.trim() : name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nick': nick,
    'email': email,
    'avatar_url': avatarUrl,
    'bio': bio,
  };

  factory SolarpassAccount.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final name = json['name'] as String? ?? '';
    String? avatar = profile?['picture']?['url'] as String?;
    if (avatar == null || avatar.isEmpty) {
      if (baseUrl != null && baseUrl.isNotEmpty && name.isNotEmpty) {
        final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
        avatar = '$cleanBase/stargate/accounts/$name/picture';
      }
    }
    return SolarpassAccount(
      id: json['id']?.toString() ?? '',
      name: name,
      nick: json['nick'] as String?,
      email: json['email'] as String?,
      avatarUrl: avatar,
      bio: profile?['bio'] as String?,
    );
  }
}

/// User configurable settings for Solarpass integration.
class SolarpassConfig {
  const SolarpassConfig({
    this.serverUrl = defaultServerUrl,
    this.clientId = defaultClientId,
    this.callbackScheme = defaultCallbackScheme,
    this.scrobbleEnabled = true,
  });

  static const defaultServerUrl = 'https://api.solian.app';
  static const defaultClientId = 'groovybox';
  static const defaultCallbackScheme = 'groovybox';

  final String serverUrl;
  final String clientId;
  final String callbackScheme;
  final bool scrobbleEnabled;

  SolarpassConfig copyWith({
    String? serverUrl,
    String? clientId,
    String? callbackScheme,
    bool? scrobbleEnabled,
  }) => SolarpassConfig(
    serverUrl: serverUrl ?? this.serverUrl,
    clientId: clientId ?? this.clientId,
    callbackScheme: callbackScheme ?? this.callbackScheme,
    scrobbleEnabled: scrobbleEnabled ?? this.scrobbleEnabled,
  );

  Map<String, dynamic> toJson() => {
    'server_url': serverUrl,
    'client_id': clientId,
    'callback_scheme': callbackScheme,
    'scrobble_enabled': scrobbleEnabled,
  };

  factory SolarpassConfig.fromJson(Map<String, dynamic> json) => SolarpassConfig(
    serverUrl: (json['server_url'] as String?)?.trim().isNotEmpty == true
        ? json['server_url'] as String
        : defaultServerUrl,
    clientId: (json['client_id'] as String?)?.trim().isNotEmpty == true
        ? json['client_id'] as String
        : defaultClientId,
    callbackScheme: (json['callback_scheme'] as String?)?.trim().isNotEmpty == true
        ? json['callback_scheme'] as String
        : defaultCallbackScheme,
    scrobbleEnabled: json['scrobble_enabled'] as bool? ?? true,
  );
}

class OAuthException implements Exception {
  const OAuthException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => code != null ? 'OAuthException ($code): $message' : 'OAuthException: $message';
}
