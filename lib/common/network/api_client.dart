import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_models.dart';
import '../auth/auth_store.dart';

class ApiClient {
  ApiClient._();

  static const bool _isProd = bool.fromEnvironment('PROD', defaultValue: false);
  static const String baseUrl =
      _isProd ? 'https://ls-api.hence.events' : 'https://ls-api-dev.hence.events';
  static const String authBaseUrl =
      String.fromEnvironment('AUTH_BASE_URL', defaultValue: 'https://ls-api-dev.hence.events');

  static const String authRefreshPath = '/api/v1/auth/refresh';

  static Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    final token = AuthStore.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function() request, {
    Future<http.Response> Function()? retryRequest,
  }) async {
    final response = await request();
    if (response.statusCode != 401) return response;

    final refreshToken = AuthStore.instance.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return response;

    debugPrint('[API][AUTH] 401 received, attempting refresh');
    try {
      await AuthStore.instance.refreshSession(refresher: (token) => refreshSession(refreshToken: token));
    } catch (e) {
      debugPrint('[API][AUTH] refresh failed: $e');
      // Refresh failed: clear local session so UI can fall back to signed-out.
      await AuthStore.instance.clear();
      return response;
    }

    if (retryRequest == null) return response;
    return await retryRequest();
  }

  static AuthUser _parseUser(dynamic json) {
    // Accept either {data:{user:{...}}} or {data:{...}} (user object directly).
    final data = json is Map<String, dynamic> ? json['data'] : null;
    if (data is Map<String, dynamic>) {
      final user = data['user'];
      if (user is Map<String, dynamic>) return AuthUser.fromJson(user);
      return AuthUser.fromJson(data);
    }
    return const AuthUser(id: '', nickname: '');
  }

  static Future<Map<String, dynamic>> fetchConfig({
    required String platform,
    required String version,
  }) async {
    final uri = Uri.parse('$baseUrl/config').replace(queryParameters: {
      'platform': platform,
      'version': version,
    });
    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers());
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Config request failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<AuthUser> fetchMe() async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me');
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Me request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    return _parseUser(json);
  }

  static Future<Map<String, dynamic>> fetchFeeds({
    required String orderBy,
    int limit = 20,
    String dir = 'next',
    String? cursor,
  }) async {
    final query = <String, String>{
      'dir': dir,
      'limit': '$limit',
      'orderBy': orderBy,
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final uri = Uri.parse('$baseUrl/api/v1/feeds').replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feeds request failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> socialAppLogin({
    required String provider,
    required String accessToken,
    required String joinPlatform,
  }) async {
    final uri = Uri.parse('$authBaseUrl/api/v1/auth/social/app-login');
    final body = <String, dynamic>{
      'provider': provider,
      'accessToken': accessToken,
      'joinPlatform': joinPlatform,
    };

    _logJsonRequest('POST', uri, body, redactKeys: const {'accessToken'});
    final response = await http.post(uri, headers: _headers(json: true), body: jsonEncode(body));
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Social login failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> refreshSession({
    required String refreshToken,
  }) async {
    final uri = Uri.parse('$authBaseUrl$authRefreshPath');
    // Refresh endpoints typically require the refresh token (not the access token).
    // Do NOT attach the current access token here.
    final body = <String, dynamic>{'refreshToken': refreshToken};
    _logJsonRequest('POST', uri, body, redactKeys: const {'refreshToken'});
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $refreshToken',
      },
      body: jsonEncode(body),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Refresh failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static void _logJsonRequest(
    String method,
    Uri uri,
    Map<String, dynamic> body, {
    Set<String> redactKeys = const {},
  }) {
    final redacted = <String, dynamic>{};
    for (final entry in body.entries) {
      redacted[entry.key] = redactKeys.contains(entry.key) ? '<redacted>' : entry.value;
    }
    debugPrint('[API][REQ] $method $uri');
    debugPrint('[API][REQ] ${jsonEncode(redacted)}');
  }

  static void _logRequest(String method, Uri uri) {
    debugPrint('[API][REQ] $method $uri');
  }

  static void _logResponse(http.Response response) {
    final body = response.body;
    final preview = body.length > 800 ? '${body.substring(0, 800)}…' : body;
    debugPrint('[API][RES] ${response.statusCode} ${response.request?.url}');
    debugPrint('[API][RES] $preview');
  }
}
