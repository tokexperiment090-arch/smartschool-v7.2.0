// Riyo mobile app — API client + config.
// Point BASE_URL at your Riyo server. On InfinityFree the first request hits a
// JS challenge cookie; in a real app you load the site once (WebView or http
// with cookie jar) to capture it, then API calls reuse those cookies.
class ApiConfig {
  // TODO: replace with your real domain.
  static const String BASE_URL = 'https://riyo.rf.gd';
  static const String TOKEN_KEY = 'riyo_api_token';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
