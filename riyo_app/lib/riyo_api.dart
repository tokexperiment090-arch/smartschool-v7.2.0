import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class RiyoApi {
  final _storage = const FlutterSecureStorage();

  Future<String?> get token => _storage.read(key: ApiConfig.TOKEN_KEY);

  Future<void> saveToken(String t) => _storage.write(key: ApiConfig.TOKEN_KEY, value: t);
  Future<void> clearToken() => _storage.delete(key: ApiConfig.TOKEN_KEY);

  Future<Map<String, dynamic>> _get(String path, String tok) async {
    final r = await http.get(Uri.parse('${ApiConfig.BASE_URL}$path?token=$tok'));
    return _decode(r);
  }

  Map<String, dynamic> _decode(http.Response r) {
    final body = jsonDecode(r.body);
    if (body is Map && body['status'] == 'error') {
      throw ApiException(body['message'] ?? 'Request failed');
    }
    if (r.statusCode >= 400) throw ApiException('HTTP ${r.statusCode}');
    return body;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.BASE_URL}/riyo_api/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );
    final body = _decode(r);
    if (body['token'] != null) await saveToken(body['token']);
    return body;
  }

  Future<Map<String, dynamic>> profile() async =>
      _get('/riyo_api/profile', (await token)!);
  Future<Map<String, dynamic>> attendance([String? month]) async {
    final tok = (await token)!;
    final url = month != null
        ? '${ApiConfig.BASE_URL}/riyo_api/attendance?token=$tok&month=$month'
        : '${ApiConfig.BASE_URL}/riyo_api/attendance?token=$tok';
    final r = await http.get(Uri.parse(url));
    return _decode(r);
  }
  Future<Map<String, dynamic>> fees() async => _get('/riyo_api/fees', (await token)!);
  Future<Map<String, dynamic>> notices() async =>
      _get('/riyo_api/notices', (await token)!);
  Future<Map<String, dynamic>> examResults() async =>
      _get('/riyo_api/examresults', (await token)!);
  Future<Map<String, dynamic>> dashboard() async =>
      _get('/riyo_api/dashboard', (await token)!);
}
