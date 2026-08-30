import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, HttpException;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

/// Holds the global 401 handler. When any API call returns 401, the handler
/// clears the stored token and pops the navigator back to the login screen.
typedef UnauthorizedHandler = void Function();

class RiyoApi {
  RiyoApi({UnauthorizedHandler? onUnauthorized}) : _onUnauthorized = onUnauthorized;

  final _storage = const FlutterSecureStorage();
  UnauthorizedHandler? _onUnauthorized;

  /// Allow screens to set a global 401 handler (e.g. set after MaterialApp is built).
  void setUnauthorizedHandler(UnauthorizedHandler h) => _onUnauthorized = h;

  // ---- token storage ----
  Future<String?> get token => _storage.read(key: ApiConfig.TOKEN_KEY);
  Future<void> saveToken(String t) => _storage.write(key: ApiConfig.TOKEN_KEY, value: t);
  Future<void> clearToken() async {
    await _storage.delete(key: ApiConfig.TOKEN_KEY);
  }

  // ---- low-level request ----

  /// Standard headers for every request. A real browser User-Agent bypasses the
  /// InfinityFree free-host JS-challenge for most calls, so we always send it.
  Map<String, String> _commonHeaders() => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      };

  /// True when a response body looks like JSON we can parse.
  bool _isJsonResponse(http.Response r) {
    final ct = (r.headers['content-type'] ?? '').toLowerCase();
    if (ct.contains('application/json')) return true;
    // If the body starts with '{' or '[' we treat it as JSON.
    final s = r.body.trimLeft();
    return s.startsWith('{') || s.startsWith('[');
  }

  /// Core request with timeout, retry-once on transient network errors, and
  /// typed exception translation. Throws [ApiException] on any failure.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.BASE_URL}$path').replace(queryParameters: query);

    ApiException? lastError;
    for (var attempt = 0; attempt <= ApiConfig.MAX_RETRIES; attempt++) {
      try {
        late http.Response r;
        final headers = {..._commonHeaders(), if (body != null) 'Content-Type': 'application/x-www-form-urlencoded'};
        if (method == 'GET') {
          r = await http
              .get(uri, headers: headers)
              .timeout(ApiConfig.READ_TIMEOUT);
        } else {
          r = await http
              .post(uri, headers: headers, body: body ?? {})
              .timeout(ApiConfig.READ_TIMEOUT);
        }
        return _parse(r);
      } on TimeoutException {
        lastError = const ApiException(ApiError.timeout, 'The server is taking too long to respond.');
      } on SocketException catch (e) {
        lastError = ApiException(ApiError.noNetwork, e.message);
      } on HttpException catch (e) {
        lastError = ApiException(ApiError.noNetwork, e.message);
      } on http.ClientException catch (e) {
        lastError = ApiException(ApiError.noNetwork, e.message);
      } on FormatException {
        // The server returned something we can't parse as JSON — could be the
        // InfinityFree HTML challenge or an unhandled error page.
        lastError = const ApiException(
            ApiError.invalidResponse, 'The server response was not valid JSON.');
      } catch (e) {
        lastError = ApiException(ApiError.unknown, e.toString());
      }
      // brief backoff before retry
      if (attempt < ApiConfig.MAX_RETRIES) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw lastError ?? const ApiException(ApiError.unknown, 'Unknown error');
  }

  /// Parses the HTTP response into a Map and converts known error shapes
  /// into typed [ApiException]s.
  Map<String, dynamic> _parse(http.Response r) {
    if (!_isJsonResponse(r)) {
      // Likely the InfinityFree HTML JS-challenge or an error page.
      throw ApiException(
        ApiError.invalidResponse,
        'Unexpected response (HTTP ${r.statusCode}).',
        httpStatus: r.statusCode,
      );
    }
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object.');
      }
      // jsonDecode returns Map<dynamic, dynamic>; cast to Map<String, dynamic>.
      body = Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw ApiException(
        ApiError.invalidResponse,
        'Could not parse server response.',
        httpStatus: r.statusCode,
      );
    }

    if (body['status'] == 'error') {
      final msg = (body['message'] ?? 'Request failed').toString();
      final code = _mapHttpAndMessage(r.statusCode, msg);
      // 401 / 403-unauthorized: clear token + fire global handler.
      if (code == ApiError.unauthorized) {
        clearToken();
        _onUnauthorized?.call();
      }
      throw ApiException(code, msg, httpStatus: r.statusCode);
    }
    if (r.statusCode >= 400) {
      final code = _mapHttp(r.statusCode);
      throw ApiException(code, 'HTTP ${r.statusCode}', httpStatus: r.statusCode);
    }
    return body;
  }

  ApiError _mapHttp(int s) {
    if (s == 401) return ApiError.unauthorized;
    if (s == 403) return ApiError.forbidden;
    if (s == 404) return ApiError.notFound;
    if (s == 400) return ApiError.badRequest;
    if (s >= 500) return ApiError.serverError;
    return ApiError.unknown;
  }

  ApiError _mapHttpAndMessage(int s, String msg) {
    if (s == 401 || msg.toLowerCase() == 'unauthorized') return ApiError.unauthorized;
    return _mapHttp(s);
  }

  // ---- warm-up: hit the homepage once to clear InfinityFree's JS challenge ----

  /// Loads the site root in a real browser context so the JS-challenge cookie
  /// is set. After this, subsequent JSON API calls go through normally even
  /// on the free InfinityFree host.
  ///
  /// [http.Client] is used so callers can share a cookie/UA surface. This is
  /// safe to call multiple times.
  Future<void> warmup({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      await c
          .get(Uri.parse('${ApiConfig.BASE_URL}/'), headers: _commonHeaders())
          .timeout(ApiConfig.CONNECT_TIMEOUT);
    } catch (_) {
      // warmup is best-effort; ignore failures.
    } finally {
      if (client == null) c.close();
    }
  }

  // ---- public endpoints ----

  Future<Map<String, dynamic>> login(String username, String password) async {
    final body = await _request('POST', '/riyo_api/login', body: {
      'username': username,
      'password': password,
    });
    if (body['token'] is String) await saveToken(body['token'] as String);
    return body;
  }

  Future<Map<String, dynamic>> profile() async =>
      _get('/riyo_api/profile');
  Future<Map<String, dynamic>> attendance([String? month]) async =>
      _get('/riyo_api/attendance', query: month != null ? {'month': month} : null);
  Future<Map<String, dynamic>> fees() async => _get('/riyo_api/fees');
  Future<Map<String, dynamic>> notices() async => _get('/riyo_api/notices');
  Future<Map<String, dynamic>> examResults() async => _get('/riyo_api/examresults');
  Future<Map<String, dynamic>> dashboard() async => _get('/riyo_api/dashboard');

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final tok = await token;
    if (tok == null) {
      throw const ApiException(ApiError.unauthorized, 'You are not logged in.');
    }
    final q = {'token': tok, if (query != null) ...query};
    return _request('GET', path, query: q);
  }

  // For diagnostics / "ping" UI.
  Future<Map<String, dynamic>> setup() async => _request('GET', '/riyo_api/setup');
}
