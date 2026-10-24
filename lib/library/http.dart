import 'package:dio/dio.dart';

/// Ensures a scheme, strips trailing slashes, and appends [suffix] when absent.
///
/// Some servers expose their API at the root, others under a path. Accept a
/// bare host, a host with a trailing slash, or a full API URL.
String normalizeBaseUrl(String raw, {String? suffix}) {
  var url = raw.trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (suffix != null && !url.endsWith(suffix)) url = '$url$suffix';
  return url;
}

/// Maps dio failures to user-facing text.
String describeDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.transformTimeout:
      return 'The server took too long to respond.';
    case DioExceptionType.connectionError:
      return 'Could not reach the server. Check the address and your network.';
    case DioExceptionType.badCertificate:
      return "The server's certificate is not valid.";
    case DioExceptionType.cancel:
      return 'Request cancelled.';
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode;
      return 'Server returned HTTP ${status ?? 'error'}.';
    case DioExceptionType.unknown:
      return error.message ?? 'Unknown network error.';
  }
}
