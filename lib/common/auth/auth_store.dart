import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';

class AuthStore {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const _kAccessTokenKey = 'auth.accessToken';
  static const _kRefreshTokenKey = 'auth.refreshToken';
  static const _kUserKey = 'auth.user';
  static const _kProviderKey = 'auth.provider';

  final ValueNotifier<bool> isSignedIn = ValueNotifier<bool>(false);
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<String?> lastProvider = ValueNotifier<String?>(null);

  String? _accessToken;
  String? _refreshToken;
  Future<void>? _refreshInFlight;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessTokenKey);
    _refreshToken = prefs.getString(_kRefreshTokenKey);
    lastProvider.value = prefs.getString(_kProviderKey)?.toLowerCase();
    final userRaw = prefs.getString(_kUserKey);
    if (userRaw != null && userRaw.isNotEmpty) {
      try {
        final map = jsonDecode(userRaw) as Map<String, dynamic>;
        currentUser.value = AuthUser.fromStoredJson(map);
      } catch (_) {
        // ignore corrupted cache
      }
    }
    // Server does not return provider today, so hydrate it from cached provider.
    final hydratedProvider = lastProvider.value;
    final user = currentUser.value;
    if (hydratedProvider != null &&
        hydratedProvider.isNotEmpty &&
        user != null &&
        (user.provider == null || user.provider!.isEmpty)) {
      currentUser.value = _withProvider(user, hydratedProvider);
    }
    isSignedIn.value = (_accessToken?.isNotEmpty ?? false);
    debugPrint(
      '[AUTH][INIT] signedIn=${isSignedIn.value} '
      'accessToken=${_accessToken?.isNotEmpty ?? false} '
      'refreshToken=${_refreshToken?.isNotEmpty ?? false} '
      'user=${currentUser.value != null}',
    );
  }

  Future<void> setSession({
    required String accessToken,
    required String refreshToken,
    AuthUser? user,
    String? provider,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    isSignedIn.value = true;
    final normalizedProvider =
        (provider != null && provider.isNotEmpty) ? provider.toLowerCase() : null;
    final effectiveProvider = normalizedProvider ??
        user?.provider?.toLowerCase() ??
        currentUser.value?.provider?.toLowerCase() ??
        lastProvider.value?.toLowerCase();
    if (user != null) {
      currentUser.value =
          effectiveProvider == null ? user : _withProvider(user, effectiveProvider);
    }
    if (effectiveProvider != null && effectiveProvider.isNotEmpty) {
      lastProvider.value = effectiveProvider;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, accessToken);
    await prefs.setString(_kRefreshTokenKey, refreshToken);
    if (user != null) {
      await prefs.setString(
        _kUserKey,
        jsonEncode(
          currentUser.value == null ? user.toJson() : currentUser.value!.toJson(),
        ),
      );
    }
    if (effectiveProvider != null && effectiveProvider.isNotEmpty) {
      await prefs.setString(_kProviderKey, effectiveProvider);
    }
    debugPrint(
      '[AUTH][SESSION] saved signedIn=true '
      'accessToken=${accessToken.isNotEmpty} '
      'refreshToken=${refreshToken.isNotEmpty} '
      'user=${currentUser.value != null} '
      'provider=${lastProvider.value}',
    );
  }

  AuthUser _withProvider(AuthUser user, String provider) {
    return AuthUser(
      id: user.id,
      nickname: user.nickname,
      introduction: user.introduction,
      email: user.email,
      provider: provider,
      profileImageUrl: user.profileImageUrl,
    );
  }

  Future<void> setUser(AuthUser user) async {
    final effectiveProvider =
        user.provider?.toLowerCase() ?? currentUser.value?.provider?.toLowerCase() ?? lastProvider.value?.toLowerCase();
    currentUser.value =
        (effectiveProvider == null || effectiveProvider.isEmpty) ? user : _withProvider(user, effectiveProvider);
    if (effectiveProvider != null && effectiveProvider.isNotEmpty) {
      lastProvider.value = effectiveProvider;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(currentUser.value!.toJson()));
    if (effectiveProvider != null && effectiveProvider.isNotEmpty) {
      await prefs.setString(_kProviderKey, effectiveProvider);
    }
    debugPrint(
      '[AUTH][USER] saved user=${currentUser.value != null} '
      'provider=${lastProvider.value}',
    );
  }

  Future<void> refreshSession({
    required Future<Map<String, dynamic>> Function(String refreshToken) refresher,
  }) async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      debugPrint('[AUTH][REFRESH] skipped (no refreshToken)');
      return;
    }
    _refreshInFlight ??= _doRefresh(refresher);
    try {
      debugPrint('[AUTH][REFRESH] start');
      await _refreshInFlight;
      debugPrint('[AUTH][REFRESH] success');
    } catch (e) {
      debugPrint('[AUTH][REFRESH] failed: $e');
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _doRefresh(
    Future<Map<String, dynamic>> Function(String refreshToken) refresher,
  ) async {
    final json = await refresher(_refreshToken!);
    final data = json['data'];
    if (data is! Map<String, dynamic>) return;

    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final userJson = data['user'];

    AuthUser? user;
    if (userJson is Map<String, dynamic>) {
      user = AuthUser.fromJson(userJson);
    }

    if (accessToken != null && refreshToken != null) {
      await setSession(accessToken: accessToken, refreshToken: refreshToken, user: user);
    } else if (user != null) {
      await setUser(user);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    isSignedIn.value = false;
    currentUser.value = null;
    lastProvider.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
    await prefs.remove(_kUserKey);
    await prefs.remove(_kProviderKey);
    debugPrint('[AUTH][CLEAR] signedIn=false');
  }
}
