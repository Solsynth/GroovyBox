import 'package:dio/dio.dart';

import 'models.dart';

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

/// Maps dio failures onto a [LibraryException] the UI can render.
///
/// Each case carries the English text *and* its `messageKey`, so the UI can
/// show the same failure in the current locale; a transport's own words are
/// passed through untranslated because they are not ours to rewrite.
LibraryException describeDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.transformTimeout:
      return const LibraryException(
        'The server took too long to respond.',
        messageKey: 'libraryTimeout',
      );
    case DioExceptionType.connectionError:
      return const LibraryException(
        'Could not reach the server. Check the address and your network.',
        messageKey: 'libraryUnreachableNetwork',
      );
    case DioExceptionType.badCertificate:
      return const LibraryException(
        "The server's certificate is not valid.",
        messageKey: 'libraryBadCertificate',
      );
    case DioExceptionType.cancel:
      return const LibraryException(
        'Request cancelled.',
        messageKey: 'libraryRequestCancelled',
      );
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode;
      return LibraryException(
        'Server returned HTTP ${status ?? 'error'}.',
        messageKey: 'libraryServerHttp',
        messageArgs: [status?.toString() ?? 'error'],
      );
    case DioExceptionType.unknown:
      final message = error.message;
      return message == null
          ? const LibraryException(
              'Unknown network error.',
              messageKey: 'libraryUnknownNetwork',
            )
          : LibraryException(message);
  }
}
