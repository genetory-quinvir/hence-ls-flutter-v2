import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import '../auth/auth_models.dart';
import '../auth/auth_store.dart';
import '../../feed_comment/models/feed_comment_model.dart';
import '../../feed_comment/models/mention_user.dart';
import '../../profile/models/profile_display_user.dart';

class ApiClient {
  ApiClient._();

  static const String baseUrl = ApiConfig.baseUrl;
  static const String authBaseUrl = ApiConfig.baseUrl;

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

  static Future<ProfileDisplayUser> fetchUserDetail(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/detail/$userId');
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('User detail request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return ProfileDisplayUser.fromJson(data);
    }
    return ProfileDisplayUser.fromJson(json);
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

  static Future<void> registerPushToken({
    required String fcmToken,
    required String platform,
    required String deviceModel,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/push/register-token');
    final body = <String, dynamic>{
      'fcmToken': fcmToken,
      'platform': platform,
      'deviceModel': deviceModel,
    };

    _logJsonRequest('POST', uri, body);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
      retryRequest: () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Push token register failed: ${response.statusCode}');
    }
  }

  static Future<void> expirePushToken({
    required String fcmToken,
    required String platform,
    required String deviceModel,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/push/expire-token');
    final body = <String, dynamic>{
      'fcmToken': fcmToken,
      'platform': platform,
      'deviceModel': deviceModel,
    };

    _logJsonRequest('POST', uri, body);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
      retryRequest: () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Push token expire failed: ${response.statusCode}');
    }
  }

  static Future<void> likeFeed(String feedId) async {
    final uri = Uri.parse('$baseUrl/api/v1/feeds/$feedId/like');
    _logRequest('POST', uri);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers()),
      retryRequest: () => http.post(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Like feed failed: ${response.statusCode}');
    }
  }

  static Future<void> unlikeFeed(String feedId) async {
    final uri = Uri.parse('$baseUrl/api/v1/feeds/$feedId/like');
    _logRequest('DELETE', uri);
    final response = await _sendWithAuthRetry(
      () => http.delete(uri, headers: _headers()),
      retryRequest: () => http.delete(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unlike feed failed: ${response.statusCode}');
    }
  }

  static Future<List<String>> uploadFeedImages(List<File> files) async {
    if (files.isEmpty) return [];
    final uri = Uri.parse('$baseUrl/api/v1/feeds/images');
    final uploaded = <String>[];

    for (var i = 0; i < files.length; i += 1) {
      final file = files[i];
      Future<http.Response> send() async {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(_headers());
        request.fields['description'] = '';
        request.fields['displayOrder'] = '$i';
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path,
            contentType: MediaType('image', 'webp'),
            filename: 'feed_$i.webp',
          ),
        );
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      }

      _logRequest('POST', uri);
      final response = await _sendWithAuthRetry(send, retryRequest: send);
      _logResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Feed image upload failed: ${response.statusCode}');
      }
      if (response.body.isEmpty) {
        throw Exception('Feed image upload failed: empty response');
      }
      final json = jsonDecode(response.body);
      final ids = _extractFileIds(json);
      if (ids.isEmpty) {
        throw Exception('Feed image upload failed: no fileIds returned');
      }
      uploaded.add(ids.first);
    }
    return uploaded;
  }

  static Future<void> createPersonalFeed({
    required String content,
    required List<String> fileIds,
    required String placeName,
    required double longitude,
    required double latitude,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/personal-feed');
    final body = <String, dynamic>{
      'content': content,
      'fileIds': fileIds,
      'placeName': placeName,
      'longitude': longitude,
      'latitude': latitude,
    };

    _logJsonRequest('POST', uri, body);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
      retryRequest: () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Personal feed create failed: ${response.statusCode}');
    }
  }

  static Future<void> updatePersonalFeed({
    required String feedId,
    required String content,
    String? placeName,
    double? longitude,
    double? latitude,
    List<String>? fileIds,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/personal-feed/$feedId');
    final body = <String, dynamic>{
      'content': content,
    };
    if (placeName != null) {
      body['placeName'] = placeName;
    }
    if (longitude != null) {
      body['longitude'] = longitude;
    }
    if (latitude != null) {
      body['latitude'] = latitude;
    }
    if (fileIds != null) {
      body['fileIds'] = fileIds;
    }

    _logJsonRequest('PATCH', uri, body);
    final response = await _sendWithAuthRetry(
      () => http.patch(uri, headers: _headers(json: true), body: jsonEncode(body)),
      retryRequest: () => http.patch(uri, headers: _headers(json: true), body: jsonEncode(body)),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Personal feed update failed: ${response.statusCode}');
    }
  }

  static Future<void> deletePersonalFeed({
    required String feedId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/personal-feed/$feedId');
    _logRequest('DELETE', uri);
    final response = await _sendWithAuthRetry(
      () => http.delete(uri, headers: _headers()),
      retryRequest: () => http.delete(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Personal feed delete failed: ${response.statusCode}');
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

  static List<String> _extractFileIds(dynamic json) {
    if (json is! Map<String, dynamic>) return [];
    final ids = <String>[];
    void addList(dynamic list) {
      if (list is List) {
        for (final item in list) {
          if (item is String && item.isNotEmpty) ids.add(item);
        }
      }
    }

    addList(json['fileIds']);
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      addList(data['fileIds']);
      final uploadedFiles = data['uploadedFiles'];
      if (uploadedFiles is List) {
        for (final entry in uploadedFiles) {
          if (entry is Map<String, dynamic>) {
            final candidate =
                entry['fileId'] ?? entry['id'] ?? entry['fileID'] ?? entry['file_id'];
            if (candidate is String && candidate.isNotEmpty) {
              ids.add(candidate);
            }
          }
        }
      }
    }
    return ids;
  }

  static Future<Map<String, dynamic>> fetchFeeds({
    required String orderBy,
    int limit = 20,
    String dir = 'next',
    String? cursor,
    String? authorUserId,
    String? type,
  }) async {
    final query = <String, String>{
      'dir': dir,
      'limit': '$limit',
      'orderBy': orderBy,
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    if (authorUserId != null && authorUserId.isNotEmpty) {
      query['authorUserId'] = authorUserId;
    }
    if (type != null && type.isNotEmpty) {
      query['type'] = type;
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

  static Future<Map<String, dynamic>> fetchUserFeeds({
    required String userId,
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
    final uri = Uri.parse('$baseUrl/api/v1/feeds/user/$userId')
        .replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('User feeds request failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> followUser(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/follow/$userId');
    _logRequest('POST', uri);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers()),
      retryRequest: () => http.post(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Follow request failed: ${response.statusCode}');
    }
  }

  static Future<void> unfollowUser(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/follow/$userId');
    _logRequest('DELETE', uri);
    final response = await _sendWithAuthRetry(
      () => http.delete(uri, headers: _headers()),
      retryRequest: () => http.delete(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unfollow request failed: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> fetchFollowers({
    required String userId,
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
    final candidates = <Uri>[
      Uri.parse('$baseUrl/api/v1/users/followers/$userId')
          .replace(queryParameters: query),
    ];
    http.Response? lastResponse;
    for (final uri in candidates) {
      _logRequest('GET', uri);
      final response = await _sendWithAuthRetry(
        () => http.get(uri, headers: _headers()),
        retryRequest: () => http.get(uri, headers: _headers()),
      );
      _logResponse(response);
      lastResponse = response;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    }
    throw Exception('Followers request failed: ${lastResponse?.statusCode ?? 'unknown'}');
  }

  static Future<Map<String, dynamic>> fetchFollowing({
    required String userId,
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
    final candidates = <Uri>[
      Uri.parse('$baseUrl/api/v1/users/followings/$userId')
          .replace(queryParameters: query),
    ];
    http.Response? lastResponse;
    for (final uri in candidates) {
      _logRequest('GET', uri);
      final response = await _sendWithAuthRetry(
        () => http.get(uri, headers: _headers()),
        retryRequest: () => http.get(uri, headers: _headers()),
      );
      _logResponse(response);
      lastResponse = response;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    }
    throw Exception('Following request failed: ${lastResponse?.statusCode ?? 'unknown'}');
  }

  static Future<Map<String, dynamic>> fetchMySpaceParticipants({
    int limit = 20,
    String dir = 'next',
    String? cursor,
  }) async {
    final userId = AuthStore.instance.currentUser.value?.id ?? '';
    final query = <String, String>{
      'dir': dir,
      'limit': '$limit',
      'type': 'LIVESPACE',
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    if (userId.isNotEmpty) {
      query['authorUserId'] = userId;
    }
    final uri = Uri.parse('$baseUrl/api/v1/feeds')
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

  static Future<List<Map<String, dynamic>>> fetchNearbySpaces({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? date,
    int limit = 30,
    String? type,
    List<String>? tags,
  }) async {
    final query = <String, String>{
      'latitude': '$latitude',
      'longitude': '$longitude',
      'radius': '$radiusKm',
      if (date != null && date.isNotEmpty) 'date': date,
      'limit': '$limit',
    };
    if (type != null && type.trim().isNotEmpty) {
      query['type'] = type.trim();
    }
    if (tags != null && tags.isNotEmpty) {
      query['tags'] = tags.join(',');
    }
    final uri = Uri.parse('$baseUrl/api/v1/map/near').replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Nearby spaces request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final data = json is Map<String, dynamic> ? json['data'] : null;

    // Expected format:
    // {
    //   "data": {
    //     "feeds": [ ... ],
    //     "meta": { "feedCount": 0 }
    //   }
    // }
    if (data is Map<String, dynamic>) {
      final feeds = data['feeds'];
      if (feeds is List) {
        return feeds
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final next = Map<String, dynamic>.from(item);
              final type = (next['type'] as String?)?.toUpperCase();
              if (type == 'LIVESPACE') {
                next['purpose'] = 'LIVESPACE';
              } else if (type == 'FEED') {
                next['purpose'] = 'FEED';
              }
              return next;
            })
            .toList();
      }
    }

    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static Future<FeedCommentPage> fetchFeedComments({
    required String feedId,
    int limit = 20,
    String? cursor,
    String dir = 'next',
  }) async {
    final query = <String, String>{
      'entityType': 'FEED',
      'entityId': feedId,
      'limit': '$limit',
      'dir': dir,
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final uri =
        Uri.parse('$baseUrl/api/v1/comments').replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed comments request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final data = json is Map<String, dynamic> ? json['data'] : null;
    final root = data is Map<String, dynamic> ? data : json;
    final meta = root is Map<String, dynamic> ? root['meta'] : null;
    final metaMap = meta is Map<String, dynamic> ? meta : const <String, dynamic>{};
    final hasNext = (metaMap['hasNext'] as bool?) ?? false;
    final nextCursor =
        metaMap['nextCursor'] as String? ?? metaMap['cursor'] as String?;
    if (root is Map<String, dynamic>) {
      final comments = root['comments'] ?? root['items'] ?? root['list'];
      if (comments is List) {
        final items = comments
            .whereType<Map<String, dynamic>>()
            .map(FeedCommentItem.fromJson)
            .toList();
        return FeedCommentPage(
          comments: items,
          hasNext: hasNext,
          nextCursor: nextCursor,
        );
      }
    }
    return FeedCommentPage(comments: const [], hasNext: false, nextCursor: null);
  }

  static Future<List<MentionUser>> fetchSpaceParticipants({
    required String spaceId,
    int limit = 50,
    String? cursor,
  }) async {
    final query = <String, String>{
      'spaceId': spaceId,
      'limit': '$limit',
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    final uri = Uri.parse('$baseUrl/api/v1/space-participants')
        .replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Space participants request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final data = json is Map<String, dynamic> ? json['data'] : null;
    final root = data is Map<String, dynamic> ? data : json;
    if (root is Map<String, dynamic>) {
      final participants = root['participants'] ?? root['users'] ?? root['items'];
      if (participants is List) {
        return participants
            .whereType<Map<String, dynamic>>()
            .map(MentionUser.fromJson)
            .where((user) => user.displayName.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  static Future<void> createCommentReply({
    required String commentId,
    required String feedId,
    required String content,
    String? fileId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/comments');
    final userId = AuthStore.instance.currentUser.value?.id;
    final body = <String, dynamic>{
      'entityType': 'FEED',
      'entityId': feedId,
      'parentId': commentId,
      'content': content,
      'fileId': fileId,
    };
    if (userId != null && userId.isNotEmpty) {
      body['userId'] = userId;
    }
    _logJsonRequest('POST', uri, body);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
      retryRequest: () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Reply create failed: ${response.statusCode}');
    }
  }

  static Future<void> createFeedComment({
    required String feedId,
    required String content,
    String? fileId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/comments');
    final userId = AuthStore.instance.currentUser.value?.id;
    final body = <String, dynamic>{
      'entityType': 'FEED',
      'entityId': feedId,
      'parentId': null,
      'content': content,
      'fileId': fileId,
    };
    if (userId != null && userId.isNotEmpty) {
      body['userId'] = userId;
    }
    _logJsonRequest('POST', uri, body);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
      retryRequest: () => http.post(uri, headers: _headers(json: true), body: jsonEncode(body)),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Comment create failed: ${response.statusCode}');
    }
  }

  static Future<void> toggleFeedCommentLike(String feedCommentId) async {
    final uri =
        Uri.parse('$baseUrl/api/v1/feed-comment-likes/toggle/$feedCommentId');
    _logRequest('POST', uri);
    final response = await _sendWithAuthRetry(
      () => http.post(uri, headers: _headers()),
      retryRequest: () => http.post(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed comment like toggle failed: ${response.statusCode}');
    }
  }

  static Future<List<FeedCommentItem>> fetchCommentReplies({
    required String commentId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/comments/replies').replace(
      queryParameters: {
        'parentId': commentId,
        'dir': 'next',
        'limit': '20',
      },
    );
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Comment replies request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final data = json is Map<String, dynamic> ? json['data'] : null;
    final root = data is Map<String, dynamic> ? data : json;
    if (root is Map<String, dynamic>) {
      final replies = root['replies'] ?? root['comments'] ?? root['items'];
      if (replies is List) {
        return replies
            .whereType<Map<String, dynamic>>()
            .map(FeedCommentItem.fromJson)
            .toList();
      }
    }
    return [];
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
    final uri = Uri.parse('$baseUrl/api/v1/notifications')
        .replace(queryParameters: query);
    _logRequest('GET', uri);
    final response = await _sendWithAuthRetry(
      () => http.get(uri, headers: _headers()),
      retryRequest: () => http.get(uri, headers: _headers()),
    );
    _logResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Notifications request failed: ${response.statusCode}');
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
