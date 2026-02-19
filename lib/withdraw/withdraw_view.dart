import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../common/notifications/fcm_service.dart';
import '../common/widgets/common_alert_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_navigation_view.dart';

class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  static const List<String> _reasons = <String>[
    '콘텐츠가 부족해요',
    '앱 사용이 어려워요',
    '오류가 자주 발생해요',
    '개인정보가 걱정돼요',
    '직접입력',
  ];

  final PageController _pageController = PageController();
  final TextEditingController _reasonController = TextEditingController();

  int _currentIndex = 0;
  bool _isAgree = false;
  String? _selectedReason;
  bool _isSubmitting = false;

  bool get _isDirectInput => _selectedReason == '직접입력';

  bool get _isActionEnabled {
    if (_currentIndex == 0) return _isAgree;
    if (_selectedReason == null) return false;
    if (_isDirectInput) return _reasonController.text.trim().isNotEmpty;
    return true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _showWithdrawAlert() async {
    final reason = _isDirectInput
        ? _reasonController.text.trim()
        : (_selectedReason ?? '');
    if (reason.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      builder: (_) {
        return Material(
          type: MaterialType.transparency,
          child: CommonAlertView(
            title: '회원탈퇴',
            subTitle: '정말 회원탈퇴 하시겠어요?',
            primaryButtonTitle: '회원탈퇴',
            secondaryButtonTitle: '취소',
            onPrimaryTap: () => _handleWithdraw(reason),
            onSecondaryTap: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  Future<void> _handleWithdraw(String reason) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      var withdrawn = false;
      try {
        await FcmService.deleteTokenAndExpire();
      } catch (_) {
        // Ignore push token cleanup failures on withdrawal.
      }
      try {
        await ApiClient.withdrawAccount(withdrawalReason: reason);
        withdrawn = true;
      } catch (_) {
        withdrawn = false;
      }
      if (!withdrawn) {
        if (!mounted) return;
        Navigator.of(context).pop(); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원탈퇴에 실패했습니다. 다시 시도해주세요.')),
        );
        return;
      }
      await AuthStore.instance.clear();
      if (!mounted) return;
      Navigator.of(context).pop(); // close dialog
      Navigator.of(context).pop(); // close withdraw page
      Navigator.of(context).maybePop(); // close settings page
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onBackTap() {
    if (_currentIndex == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPrimaryTap() {
    if (!_isActionEnabled || _isSubmitting) return;
    if (_currentIndex == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    _showWithdrawAlert();
  }

  Widget _buildPageOne() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '정말 탈퇴할까요?',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '회원 탈퇴 시 아래 내용을 꼭 확인해 주세요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF616161),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '탈퇴 시 유의사항',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
                SizedBox(height: 12),
                _DotText('내 프로필 정보는 삭제되며, 활동 내역은 익명 처리됩니다.'),
                SizedBox(height: 8),
                _DotText('법령에 따라 일부 정보는 일정 기간 보관될 수 있습니다.'),
                SizedBox(height: 8),
                _DotText('탈퇴 후 재가입은 일정 기간 제한될 수 있습니다.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTwo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '탈퇴하시는 이유가 궁금해요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '남겨주신 의견은 서비스 개선에 참고할게요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF616161),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((reason) {
              final selected = _selectedReason == reason;
              return CommonInkWell(
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF424242),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_isDirectInput) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '탈퇴 사유를 입력해주세요.',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF7F7F8),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
                onLeftTap: _onBackTap,
                title: '회원탈퇴',
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: [
                  _buildPageOne(),
                  _buildPageTwo(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentIndex == 0)
                  CommonInkWell(
                    onTap: () => setState(() => _isAgree = !_isAgree),
                    child: Row(
                      children: [
                        Icon(
                          _isAgree
                              ? PhosphorIconsFill.checkSquare
                              : PhosphorIconsRegular.square,
                          size: 20,
                          color: _isAgree
                              ? Colors.black
                              : const Color(0xFFBDBDBD),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '탈퇴 시 유의사항을 모두 확인했어요.',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF616161),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_currentIndex == 0) const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isActionEnabled && !_isSubmitting
                        ? _onPrimaryTap
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      disabledBackgroundColor: const Color(0xFFE0E0E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentIndex == 0
                                ? '계속하기'
                                : 'HENCE LIVE SPACE 탈퇴하기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _isActionEnabled
                                  ? Colors.white
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotText extends StatelessWidget {
  const _DotText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: CircleAvatar(
            radius: 2,
            backgroundColor: Color(0xFF616161),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: Color(0xFF616161),
            ),
          ),
        ),
      ],
    );
  }
}
