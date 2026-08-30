// Riyo mobile app configuration.
// BASE_URL points at the Riyo backend. On InfinityFree the first request hits a
// JS challenge cookie; the app warms up the challenge on startup (see main.dart)
// so subsequent API calls work normally.
class ApiConfig {
  static const String BASE_URL = 'https://riyo.rf.gd';

  // Secure storage key for the API bearer token.
  static const String TOKEN_KEY = 'riyo_api_token';

  // HTTP timeouts.
  static const Duration CONNECT_TIMEOUT = Duration(seconds: 10);
  static const Duration READ_TIMEOUT = Duration(seconds: 20);

  // Retry once on transient network/5xx errors.
  static const int MAX_RETRIES = 1;
}

/// Typed exception thrown by [RiyoApi]. The [code] lets the UI branch on
/// the kind of failure (network vs auth vs server vs parse) and the [message]
/// is a human-friendly, already-translated string suitable for showing in a
/// SnackBar or an error widget.
class ApiException implements Exception {
  final ApiError code;
  final String message;
  final int? httpStatus;
  const ApiException(this.code, this.message, {this.httpStatus});

  @override
  String toString() => 'ApiException($code, $message)';
}

enum ApiError {
  // network / connectivity
  noNetwork,        // SocketException, no internet
  timeout,          // request timed out
  // auth
  unauthorized,     // 401 — token missing/expired
  forbidden,        // 403 — e.g. teacher tried to use student app
  notFound,         // 404
  // server
  serverError,      // 5xx
  badRequest,       // 400 with a message
  // parsing
  invalidResponse,  // non-JSON body (e.g. InfinityFree JS challenge HTML)
  // unknown
  unknown,
}

/// Map a low-level error or HTTP response to a user-friendly message.
String friendlyError(Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case ApiError.noNetwork:
        return 'No internet connection. Check your Wi-Fi or mobile data and try again.';
      case ApiError.timeout:
        return 'The server is taking too long to respond. Please try again.';
      case ApiError.unauthorized:
        return 'Your session has expired. Please log in again.';
      case ApiError.forbidden:
        return e.message.isNotEmpty ? e.message : 'You are not allowed to do that.';
      case ApiError.notFound:
        return e.message.isNotEmpty ? e.message : 'The requested information was not found.';
      case ApiError.badRequest:
        return e.message.isNotEmpty ? e.message : 'The request was invalid.';
      case ApiError.serverError:
        return 'The school server returned an error. Please try again later.';
      case ApiError.invalidResponse:
        return 'The server response was not valid. Please try again in a moment.';
      case ApiError.unknown:
        return e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
