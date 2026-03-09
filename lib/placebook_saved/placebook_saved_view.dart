import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_image_view.dart';
import '../common/network/api_client.dart';
import '../common/auth/auth_store.dart';

class PlacebookSavedView extends StatefulWidget {
  const PlacebookSavedView({
    super.key,
    this.imageBytes,
    this.imageUrl,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;

  @override
  State<PlacebookSavedView> createState() => _PlacebookSavedViewState();
}

class _PlacebookSavedViewState extends State<PlacebookSavedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _subOpacity;
  late final Animation<Offset> _subOffset;
  bool _isLoadingInfo = false;
  int _createdCount = 0;
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    _titleOffset = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _subOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
    );
    _subOffset = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _controller.forward();
      });
    });
    _loadMyPlacesInfo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMyPlacesInfo() async {
    if (_isLoadingInfo) return;
    setState(() => _isLoadingInfo = true);
    try {
      final info = await ApiClient.fetchMyPlacebookMyPlacesInfo();
      if (!mounted) return;
      final currentUser = AuthStore.instance.currentUser.value;
      setState(() {
        _createdCount = (info['createdCount'] as num?)?.toInt() ??
            (info['totalCount'] as num?)?.toInt() ??
            0;
        _nickname = (currentUser?.nickname ?? '').trim();
      });
    } catch (_) {
      if (!mounted) return;
      final currentUser = AuthStore.instance.currentUser.value;
      setState(() {
        _createdCount = _createdCount;
        _nickname = (currentUser?.nickname ?? '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              left: const Icon(
                PhosphorIconsRegular.x,
                size: 22,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              backgroundColor: Colors.white,
            ),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 340,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: Lottie.asset(
                                'assets/images/lottie/confetti.json',
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                            ),
                            Center(
                              child: _SavedPlaceMarker(
                                size: 120,
                                imageBytes: widget.imageBytes,
                                imageUrl: widget.imageUrl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          FadeTransition(
                            opacity: _titleOpacity,
                            child: SlideTransition(
                              position: _titleOffset,
                              child: const Text(
                                '장소 저장 완료 🎉',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _subOpacity,
                            child: SlideTransition(
                              position: _subOffset,
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                    height: 1.5,
                                    fontFamily: 'Pretendard',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF616161),
                                  ),
                                  children: [
                                    const TextSpan(text: '벌써, '),
                                    TextSpan(
                                      text: _nickname.isEmpty
                                          ? '회원'
                                          : _nickname,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(text: '님이\n추가한 장소는 '),
                                    TextSpan(
                                      text: '$_createdCount',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(text: '개가 되었어요!'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: CommonRoundedButton(
                    title: '확인',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPlaceMarker extends StatelessWidget {
  const _SavedPlaceMarker({
    required this.size,
    this.imageBytes,
    this.imageUrl,
  });

  final double size;
  final Uint8List? imageBytes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        width: size,
        height: size,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(48)),
            side: BorderSide(color: Colors.white, width: 1),
          ),
          shadows: [
            BoxShadow(
              color: Color(0xFFe2e2e2),
              blurRadius: 16,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(48)),
              ),
            ),
            child: CommonImageView(
              memoryBytes: imageBytes,
              networkUrl: imageUrl,
              fit: BoxFit.cover,
              backgroundColor: const Color(0xFFF2F2F2),
              placeholderLogoSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
