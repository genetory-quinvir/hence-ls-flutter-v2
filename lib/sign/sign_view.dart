import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/auth/auth_models.dart';
import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../sign_success/sign_success_view.dart';
import '../web/web_view.dart';

class SignView extends StatefulWidget {
  const SignView({super.key});

  @override
  State<SignView> createState() => _SignViewState();
}

class _SignViewState extends State<SignView> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  bool _isLoading = false;

  static const String _googleServerClientId =
      '468574374791-b6hdars6tdngeib1b87af6chjfu1f7dv.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => const WebViewPage(
              title: '서비스 이용약관',
              url: WebUrls.termsUrl,
            ),
          ),
        );
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => const WebViewPage(
              title: '개인정보처리방침',
              url: WebUrls.privacyUrl,
            ),
          ),
        );
      };
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  String _joinPlatform() {
    if (Platform.isIOS) return 'IOS';
    if (Platform.isAndroid) return 'ANDROID';
    return 'WEB';
  }

  Future<void> _hydrateMe() async {
    try {
      final me = await ApiClient.fetchMe();
      await AuthStore.instance.setUser(me);
      debugPrint('[AUTH][ME] hydrated user id=${me.id.isNotEmpty}');
    } catch (e) {
      // Social login response already contains a user object today; this is best-effort.
      debugPrint('[AUTH][ME] hydrate failed: $e');
    }
  }

  Future<void> _naverLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await NaverLoginSDK.authenticate();
      final token = await NaverLoginSDK.getAccessToken();
      if (token.isEmpty) throw Exception('Empty Naver access token');

      final json = await ApiClient.socialAppLogin(
        provider: 'NAVER',
        accessToken: token,
        joinPlatform: _joinPlatform(),
      );

      if (!mounted) return;
      final data = json['data'];
      final isNewUser = data is Map<String, dynamic> ? (data['isNewUser'] as bool?) : null;
      final accessToken = data is Map<String, dynamic> ? (data['accessToken'] as String?) : null;
      final refreshToken = data is Map<String, dynamic> ? (data['refreshToken'] as String?) : null;
      final userJson = data is Map<String, dynamic> ? data['user'] : null;
      if (accessToken != null && refreshToken != null) {
        await AuthStore.instance.setSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: userJson is Map<String, dynamic> ? AuthUser.fromJson(userJson) : null,
          provider: 'naver',
        );
        await _hydrateMe();
      }
      if (isNewUser == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignSuccessView()),
        );
      } else {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네이버 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _kakaoLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final installed = await isKakaoTalkInstalled();
      final OAuthToken token = installed
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      final json = await ApiClient.socialAppLogin(
        provider: 'KAKAO',
        accessToken: token.accessToken,
        joinPlatform: _joinPlatform(),
      );

      final data = json['data'];
      final isNewUser = data is Map<String, dynamic> ? (data['isNewUser'] as bool?) : null;
      final accessToken = data is Map<String, dynamic> ? (data['accessToken'] as String?) : null;
      final refreshToken = data is Map<String, dynamic> ? (data['refreshToken'] as String?) : null;
      final userJson = data is Map<String, dynamic> ? data['user'] : null;
      if (accessToken != null && refreshToken != null) {
        await AuthStore.instance.setSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: userJson is Map<String, dynamic> ? AuthUser.fromJson(userJson) : null,
          provider: 'kakao',
        );
        await _hydrateMe();
      }

      if (!mounted) return;
      if (isNewUser == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignSuccessView()),
        );
      } else {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _appleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final credential = Platform.isIOS
          ? await SignInWithApple.getAppleIDCredential(
              scopes: const [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
            )
          : await SignInWithApple.getAppleIDCredential(
              scopes: const [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
              webAuthenticationOptions: WebAuthenticationOptions(
                clientId: 'com.hence.ls.service',
                redirectUri: Uri.parse(
                  'https://ls-api-dev.hence.events/api/v1/auth/apple/callback',
                ),
              ),
            );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw Exception('Empty Apple identity token');
      }

      final json = await ApiClient.socialAppLogin(
        provider: 'APPLE',
        accessToken: identityToken,
        joinPlatform: _joinPlatform(),
      );

      final data = json['data'];
      final isNewUser = data is Map<String, dynamic> ? (data['isNewUser'] as bool?) : null;
      final accessToken = data is Map<String, dynamic> ? (data['accessToken'] as String?) : null;
      final refreshToken = data is Map<String, dynamic> ? (data['refreshToken'] as String?) : null;
      final userJson = data is Map<String, dynamic> ? data['user'] : null;
      if (accessToken != null && refreshToken != null) {
        await AuthStore.instance.setSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: userJson is Map<String, dynamic> ? AuthUser.fromJson(userJson) : null,
          provider: 'apple',
        );
        await _hydrateMe();
      }

      if (!mounted) return;
      if (isNewUser == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignSuccessView()),
        );
      } else {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      final s = e.toString();
      if (s.contains('canceled') ||
          s.contains('Canceled') ||
          s.contains('UserCancel') ||
          s.contains('취소')) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('애플 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _googleServerClientId,
      );

      // Make sure the native channel is initialized (best-effort).
      try {
        await googleSignIn.signInSilently();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // user canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Empty Google access token');
      }

      final json = await ApiClient.socialAppLogin(
        provider: 'GOOGLE',
        accessToken: accessToken,
        joinPlatform: _joinPlatform(),
      );

      final data = json['data'];
      final isNewUser = data is Map<String, dynamic> ? (data['isNewUser'] as bool?) : null;
      final appAccessToken = data is Map<String, dynamic> ? (data['accessToken'] as String?) : null;
      final refreshToken = data is Map<String, dynamic> ? (data['refreshToken'] as String?) : null;
      final userJson = data is Map<String, dynamic> ? data['user'] : null;
      if (appAccessToken != null && refreshToken != null) {
        await AuthStore.instance.setSession(
          accessToken: appAccessToken,
          refreshToken: refreshToken,
          user: userJson is Map<String, dynamic> ? AuthUser.fromJson(userJson) : null,
          provider: 'google',
        );
        await _hydrateMe();
      }

      if (!mounted) return;
      if (isNewUser == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignSuccessView()),
        );
      } else {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구글 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
            CommonNavigationView(
              left: const Icon(
                PhosphorIconsRegular.x,
                size: 24,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              right: Text(
                '둘러보기',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              onRightTap: () => Navigator.of(context).maybePop(),
            ),
            const Expanded(child: SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  CommonRoundedButton(
                    title: '네이버로 계속하기',
                    onTap: _isLoading ? null : _naverLogin,
                    height: 50,
                    radius: 25,
                    backgroundColor: const Color(0xFF00C443),
                    textColor: Colors.white,
                    leadingCentered: true,
                    leading: SvgPicture.asset(
                      'assets/images/icon_naver.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CommonRoundedButton(
                    title: '카카오로 계속하기',
                    onTap: _isLoading ? null : _kakaoLogin,
                    height: 50,
                    radius: 25,
                    backgroundColor: const Color(0xFFFFE431),
                    textColor: Colors.black,
                    leadingCentered: true,
                    leading: SvgPicture.asset(
                      'assets/images/icon_kakao.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CommonRoundedButton(
                    title: '구글로 계속하기',
                    onTap: _isLoading ? null : _googleLogin,
                    height: 50,
                    radius: 25,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    borderColor: const Color(0xFFE0E0E0),
                    leadingCentered: true,
                    leading: SvgPicture.asset(
                      'assets/images/icon_google.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CommonRoundedButton(
                    title: '애플로 계속하기',
                    onTap: _isLoading ? null : _appleLogin,
                    height: 50,
                    radius: 25,
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                    leadingCentered: true,
                    leading: SvgPicture.asset(
                      'assets/images/icon_apple.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text.rich(
                textAlign: TextAlign.center,
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '계속하기를 선택하면 ',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    TextSpan(
                      text: '서비스 이용약관',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A7A7A),
                      ),
                      recognizer: _termsRecognizer,
                    ),
                    const TextSpan(
                      text: ' 및',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    TextSpan(
                      text: '\n개인정보 수집 · 이용',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A7A7A),
                      ),
                      recognizer: _privacyRecognizer,
                    ),
                    const TextSpan(
                      text: '에 동의한 것으로 간주합니다.',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
