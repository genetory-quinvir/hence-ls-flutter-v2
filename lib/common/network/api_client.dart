import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
  static const String _cdnBase = 'https://d8fw6zmrtkhsn.cloudfront.net/';

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

  static Future<AuthUser> updateProfile({
    required String nickname,
    String? name,
    String? gender,
    bool? marketingConsent,
    String? introduction,
    int? age,
    String? dateOfBirth,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/profile');
    final body = <String, dynamic>{
      'nickname': nickname,
    };
    if (name != null) body['name'] = name;
    if (gender != null) body['gender'] = gender;
    if (marketingConsent != null) body['marketingConsent'] = marketingConsent;
    if (introduction != null) body['introduction'] = introduction;
    if (age != null) body['age'] = age;
    if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth;

    _logJsonRequest('PATCH', uri, body);
    final response = await _sendWithAuthRetry(
      () => http.patch(uri, headers: _headers(json: true), body: jsonEncode(body)),
      retryRequest: () => http.patch(uri, headers: _headers(json: true), body: jsonEncode(body)),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Profile update failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    return _parseUser(json);
  }

  static Future<String?> uploadProfileImage(File file) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/profile-image');
    Future<http.Response> send() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers());
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('image', 'webp'),
          filename: 'profile.webp',
        ),
      );
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    _logRequest('POST', uri);
    final response = await _sendWithAuthRetry(send, retryRequest: send);
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Profile image upload failed: ${response.statusCode}');
    }
    if (response.body.isEmpty) return null;
    final json = jsonDecode(response.body);
    final s3Key = _extractS3Key(json);
    if (s3Key != null && s3Key.isNotEmpty) {
      return '$_cdnBase$s3Key';
    }
    final user = _parseUser(json);
    return user.profileImageUrl;
  }

  static Future<void> deleteProfileImage() async {
    final uri = Uri.parse('$baseUrl/api/v1/users/profile-image');
    _logRequest('DELETE', uri);
    final response = await _sendWithAuthRetry(
      () => http.delete(uri, headers: _headers()),
      retryRequest: () => http.delete(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Profile image delete failed: ${response.statusCode}');
    }
  }

  static String? _extractS3Key(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final uploadedFiles = data['uploadedFiles'];
      if (uploadedFiles is List && uploadedFiles.isNotEmpty) {
        final first = uploadedFiles.first;
        if (first is Map<String, dynamic>) {
          final key = first['s3Key'] ?? first['s3key'] ?? first['filePath'];
          if (key is String && key.isNotEmpty) {
            if (key.endsWith('/') && first['fileName'] is String) {
              return '$key${first['fileName']}';
            }
            return key;
          }
        }
      }
      final s3Key = data['s3key'] ?? data['s3Key'] ?? data['key'];
      if (s3Key is String) return s3Key;
    }
    final s3Key = json['s3key'] ?? json['s3Key'] ?? json['key'];
    if (s3Key is String) return s3Key;
    return null;
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

  static Future<Map<String, dynamic>> fetchMyFeeds({
    int limit = 20,
    String dir = 'next',
    String? cursor,
  }) async {
    final query = <String, String>{
      'dir': dir,
      'limit': '$limit',
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final uri =
        Uri.parse('$baseUrl/api/v1/feeds/mine').replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('My feeds request failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchMySpaceParticipants({
    int limit = 20,
    String dir = 'next',
    String? cursor,
  }) async {
    final query = <String, String>{
      'dir': dir,
      'limit': '$limit',
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final uri = Uri.parse('$baseUrl/api/v1/space-participants/mine')
        .replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('My space participants request failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchMyNotifications({
    int limit = 20,
    String dir = 'next',
    String? cursor,
  }) async {
    final query = <String, String>{
      'dir': dir,
      'limit': '$limit',
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final uri = Uri.parse('$baseUrl/api/v1/notifications/mine')
        .replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('My notifications request failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> markAllNotificationsRead() async {
    final uri = Uri.parse('$baseUrl/api/v1/notifications/read-all');
    _logRequest('PATCH', uri);
    final response = await _sendWithAuthRetry(
      () => http.patch(uri, headers: _headers()),
      retryRequest: () => http.patch(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Mark all notifications read failed: ${response.statusCode}',
      );
    }
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
