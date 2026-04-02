import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _baseUrl = '/api/auth';
  static const Duration _timeout = Duration(seconds: 30);

  // ── Token storage ──────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Auth headers helper ────────────────────────────────────────────────────

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String company,
    required String title,
    required String email,
    required String password,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'first_name': firstName,
              'last_name': lastName,
              'company': company,
              'title': title,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_timeout);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 201) {
        await saveToken(data['token'] as String);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'error': data['error'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200) {
        await saveToken(data['token'] as String);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'error': data['error'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<User?> fetchProfile() async {
    try {
      final headers = await authHeaders();
      final resp = await http
          .get(Uri.parse('$_baseUrl/me'), headers: headers)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return User.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchProfile error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> saveApiKey(String provider, String apiKey) async {
    try {
      final headers = await authHeaders();
      final resp = await http
          .post(
            Uri.parse('/api/keys'),
            headers: headers,
            body: jsonEncode({'provider': provider, 'api_key': apiKey}),
          )
          .timeout(_timeout);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return {'success': resp.statusCode == 200, ...data};
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> getProviders() async {
    try {
      final headers = await authHeaders();
      final resp = await http
          .get(Uri.parse('/api/keys/providers'), headers: headers)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }
}
