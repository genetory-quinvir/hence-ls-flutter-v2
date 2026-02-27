import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_models.dart';
import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_textfield_view.dart';
import '../sign_success/sign_success_view.dart';

class SignEmailView extends StatefulWidget {
  const SignEmailView({super.key});

  @override
  State<SignEmailView> createState() => _SignEmailViewState();
}

class _SignEmailViewState extends State<SignEmailView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _isSubmitting = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_revalidate);
    _passwordController.addListener(_revalidate);
    _revalidate();
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _revalidate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    final valid = validEmail && password.isNotEmpty;
    if (valid == _isFormValid) return;
    setState(() => _isFormValid = valid);
  }

  Future<void> _hydrateMe() async {
    try {
      final me = await ApiClient.fetchMe();
      await AuthStore.instance.setUser(me);
    } catch (_) {
      // Best-effort; login response may already include user data.
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')),
      );
      return;
    }
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 이메일 형식을 입력해주세요.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final json = await ApiClient.basicLogin(
        email: email,
        password: password,
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
          provider: 'email',
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
        SnackBar(content: Text('이메일 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: CommonNavigationView(
                left: const Icon(
                  PhosphorIconsRegular.caretLeft,
                  size: 24,
                  color: Colors.black,
                ),
                onLeftTap: () => Navigator.of(context).maybePop(),
                title: '이메일 로그인',
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CommonTextFieldView(
                      controller: _emailController,
                      focusNode: null,
                      title: '이메일',
                      hintText: '이메일을 입력해주세요',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enableSuggestions: false,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 12),
                    CommonTextFieldView(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      title: '비밀번호',
                      hintText: '비밀번호를 입력해주세요',
                      textInputAction: TextInputAction.done,
                      enableSuggestions: false,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      obscureText: true,
                      onSubmitted: (_) {
                        if (_isFormValid && !_isSubmitting) {
                          _submit();
                        }
                      },
                      enabled: !_isSubmitting,
                    ),
                    const Spacer(),
                    CommonRoundedButton(
                      title: _isSubmitting ? '로그인 중...' : '로그인',
                      onTap: (!_isSubmitting && _isFormValid) ? _submit : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
