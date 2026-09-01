import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, HttpException, Cookie;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

/// Holds the global 401 handler. When any API call returns 401, the handler
/// clears the stored token and pops the navigator back to the login screen.
typedef UnauthorizedHandler = void Function();

class RiyoApi {
  RiyoApi({UnauthorizedHandler? onUnauthorized}) : _onUnauthorized = onUnauthorized;

  final _storage = const FlutterSecureStorage();
  UnauthorizedHandler? _onUnauthorized;

  // Shared HTTP client so cookies set by the warmup carry into API calls.
  // Without a persistent client, dart:io HttpClient would not send cookies
  // returned in Set-Cookie on the first response.
  final http.Client _client = http.Client();
  final Map<String, String> _cookieJar = {}; // cookie name -> value
  bool _warmed = false;

  void setUnauthorizedHandler(UnauthorizedHandler h) => _onUnauthorized = h;

  // ---- token storage ----
  Future<String?> get token => _storage.read(key: ApiConfig.TOKEN_KEY);
  Future<void> saveToken(String t) => _storage.write(key: ApiConfig.TOKEN_KEY, value: t);
  Future<void> clearToken() async {
    await _storage.delete(key: ApiConfig.TOKEN_KEY);
  }

  // ---- cookie management ----

  /// Parse `Set-Cookie` header(s) and add cookie name=value pairs to
  /// [_cookieJar]. Handles both a single comma-joined `Set-Cookie` string
  /// (the default `http` package behaviour) and multiple separate
  /// `Set-Cookie` headers (when the underlying client preserves them).
  void _absorbCookies(http.Response r) {
    final headerValue = r.headers['set-cookie'];
    if (headerValue == null || headerValue.isEmpty) return;

    // The `http` package concatenates multiple Set-Cookie headers into a
    // single comma-separated string. Each Set-Cookie entry itself uses
    // `;` as an attribute separator (e.g. `Path=/;HttpOnly`), so a plain
    // `split(',')` followed by a name=value sanity check is sufficient
    // for the cookies the InfinityFree challenge sets.
    final entries = <String>[];
    for (final raw in headerValue.split(',')) {
      final seg = raw.trim();
      if (seg.isEmpty) continue;
      // Only treat as a cookie line if it starts with `name=`.
      if (!RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+=").hasMatch(seg)) continue;
      entries.add(seg);
    }

    for (final seg in entries) {
      final eq = seg.indexOf('=');
      if (eq <= 0) continue;
      final name = seg.substring(0, eq).trim();
      var value = seg.substring(eq + 1).trim();
      final semi = value.indexOf(';');
      if (semi >= 0) value = value.substring(0, semi).trim();
      if (name.isEmpty) continue;
      _cookieJar[name] = value;
    }
  }

  /// Build the Cookie request header from the jar.
  String? _cookieHeader() {
    if (_cookieJar.isEmpty) return null;
    return _cookieJar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  // ---- low-level request ----

  /// Browser-like headers that make InfinityFree's free-host JS-challenge
  /// accept the request as browser traffic.
  Map<String, String> _commonHeaders() {
    final h = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    final ck = _cookieHeader();
    if (ck != null) h['Cookie'] = ck;
    return h;
  }

  /// True when a response body looks like JSON we can parse.
  bool _isJsonResponse(http.Response r) {
    final ct = (r.headers['content-type'] ?? '').toLowerCase();
    if (ct.contains('application/json')) return true;
    final s = r.body.trimLeft();
    return s.startsWith('{') || s.startsWith('[');
  }

  /// Core request with timeout, retry on transient + challenge errors, cookie
  /// persistence, and typed exception translation. Throws [ApiException].
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.BASE_URL}$path').replace(queryParameters: query);

    ApiException? lastError;
    // Allow one extra retry so the challenge-recovery path (re-warmup) gets
    // a chance to fix the next attempt.
    final maxRetries = ApiConfig.MAX_RETRIES + 1;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final headers = {
          ..._commonHeaders(),
          if (body != null) 'Content-Type': 'application/x-www-form-urlencoded',
        };
        late http.Response r;
        if (method == 'GET') {
          r = await _client.get(uri, headers: headers).timeout(ApiConfig.READ_TIMEOUT);
        } else {
          r = await _client
              .post(uri, headers: headers, body: body ?? {})
              .timeout(ApiConfig.READ_TIMEOUT);
        }
        _absorbCookies(r);
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
        lastError = const ApiException(
            ApiError.invalidResponse, 'The server response was not valid JSON.');
      } catch (e) {
        lastError = ApiException(ApiError.unknown, e.toString());
      }

      // On challenge (invalidResponse), re-warmup before retrying so the
      // server can set any required cookies.
      if (lastError?.code == ApiError.invalidResponse || lastError?.code == ApiError.unknown) {
        try {
          await _warmup();
        } catch (_) {}
      } else if (attempt < maxRetries) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw lastError ?? const ApiException(ApiError.unknown, 'Unknown error');
  }

  /// Parses the HTTP response into a Map and converts known error shapes
  /// into typed [ApiException]s.
  Map<String, dynamic> _parse(http.Response r) {
    if (!_isJsonResponse(r)) {
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

  // ---- warm-up ----

  /// Hit the site root with browser-like headers. Any Set-Cookie headers are
  /// captured into [_cookieJar] so subsequent API calls carry them.
  Future<void> _warmup() async {
    try {
      final r = await _client
          .get(Uri.parse('${ApiConfig.BASE_URL}/'), headers: _commonHeaders())
          .timeout(ApiConfig.CONNECT_TIMEOUT);
      _absorbCookies(r);
    } catch (_) {
      // warmup is best-effort
    }
  }

  /// Public warmup. Safe to call multiple times.
  Future<void> warmup() async {
    _warmed = true;
    await _warmup();
  }

  // ---- public endpoints ----

  Future<Map<String, dynamic>> login(String username, String password) async {
    // The InfinityFree JS challenge on the login POST is the most common
    // failure point — warm up again right before login so cookies are fresh.
    if (!_warmed) await _warmup();
    final body = await _request('POST', '/riyo_api/login', body: {
      'username': username,
      'password': password,
    });
    if (body['token'] is String) await saveToken(body['token'] as String);
    return body;
  }

  Future<Map<String, dynamic>> profile() async => _get('/riyo_api/profile');
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

  /// Diagnostics: hit the setup endpoint and return whatever JSON it returns.
  Future<Map<String, dynamic>> setup() async => _request('GET', '/riyo_api/setup');
}
