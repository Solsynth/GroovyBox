/// The Library Sync HTTP client, over the same Dio conventions as
/// [SolarpassClient].
library;

import 'package:dio/dio.dart';

import '../core/identity.dart';
import '../solarpass/models.dart';
import 'models.dart';

/// A fleet [ApiError] surfaced as a typed exception.
class LibrarySyncException implements Exception {
  LibrarySyncException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.detail,
    this.traceId,
  });

  final int statusCode;
  final String code;
  final String message;
  final String? detail;
  final String? traceId;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'LibrarySyncException($statusCode $code): $message';
}

/// A 401: the session must be refreshed once and the call retried.
class LibrarySyncUnauthorized extends LibrarySyncException {
  LibrarySyncUnauthorized({
    required super.code,
    required super.message,
    super.detail,
    super.traceId,
  }) : super(statusCode: 401);
}

/// Pushes local changes and pulls remote ones for one account.
class LibrarySyncClient {
  LibrarySyncClient({required this.dio, required String baseUrl})
    : _basePath = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/pulsar/library';

  // Blade maps `/pulsar/library/*` to Pulsar's `/api/library/*`, so the client
  // only ever names the gateway prefix. The library mirror is a Pulsar module,
  // not a service of its own.
  final Dio dio;
  final String _basePath;
  String get baseUrl => _basePath;

  Map<String, String> _headers(OAuthSession session) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': appUserAgent,
    'Authorization': '${session.tokenType} ${session.accessToken}',
  };

  /// One batch of local changes, at most the server's maxBatch.
  Future<SyncPushResult> push(
    OAuthSession session,
    String deviceId,
    List<SyncChange> changes,
  ) async {
    final response = await _send<Map<String, dynamic>>(
      () => dio.post<Map<String, dynamic>>(
        '$_basePath/push',
        data: {
          'device_id': deviceId,
          'changes': [for (final change in changes) change.toJson()],
        },
        options: Options(headers: _headers(session)),
      ),
    );
    return SyncPushResult.fromJson(response ?? const {});
  }

  /// One page of the account's mirror after [since].
  Future<PullPage> pull(
    OAuthSession session, {
    required int since,
    required int limit,
  }) async {
    final response = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/pull',
        queryParameters: {'since': since, 'limit': limit},
        options: Options(headers: _headers(session)),
      ),
    );
    return PullPage.fromJson(response ?? const {});
  }

  /// The account's mirror summary, for the Settings row.
  Future<LibrarySyncStatus> status(OAuthSession session) async {
    final response = await _send<Map<String, dynamic>>(
      () => dio.get<Map<String, dynamic>>(
        '$_basePath/status',
        options: Options(headers: _headers(session)),
      ),
    );
    return LibrarySyncStatus.fromJson(response ?? const {});
  }

  /// Runs one request and maps a fleet ApiError onto a typed exception.
  Future<T?> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (error) {
      throw _exceptionOf(error);
    }
  }

  LibrarySyncException _exceptionOf(DioException error) {
    final status = error.response?.statusCode ?? 0;
    final body = error.response?.data;
    var code = 'RHYTHM_SYNC_REQUEST_FAILED';
    var message = error.message ?? 'The sync request failed.';
    String? detail;
    String? traceId;
    if (body is Map) {
      code = body['code'] as String? ?? code;
      message = body['message'] as String? ?? message;
      detail = body['detail'] as String?;
      traceId = body['traceId'] as String?;
    }
    if (status == 401) {
      return LibrarySyncUnauthorized(
        code: code,
        message: message,
        detail: detail,
        traceId: traceId,
      );
    }
    return LibrarySyncException(
      statusCode: status,
      code: code,
      message: message,
      detail: detail,
      traceId: traceId,
    );
  }
}
