import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_image_view.dart';
import '../common/network/api_client.dart';
import '../common/auth/auth_store.dart';
import '../common/styles/app_shadows.dart';

class PlacebookSaveResult {
  const PlacebookSaveResult({
    this.imageUrl,
  });

  final String? imageUrl;
}

class PlacebookSavedView extends StatefulWidget {
  const PlacebookSavedView({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.saveFuture,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final Future<PlacebookSaveResult>? saveFuture;

  @override
  State<PlacebookSavedView> createState() => _PlacebookSavedViewState();
}

class _PlacebookSavedViewState extends State<PlacebookSavedView>
{
  bool _isLoadingInfo = false;
  bool _isSaving = false;
  bool _isSaveFailed = false;
  int _createdCount = 0;
  String _nickname = '';
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _resolvedImageUrl = widget.imageUrl;
    _isSaving = widget.saveFuture != null;
    if (_isSaving) {
      _waitForSave();
      return;
    }
    _loadMyPlacesInfo();
  }

  @override
  void dispose() {
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
        _createdCount = (info['savedCount'] as num?)?.toInt() ??
            (info['createdCount'] as num?)?.toInt() ??
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

  Future<void> _waitForSave() async {
    final future = widget.saveFuture;
    if (future == null) return;
    try {
      final result = await future;
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaveFailed = false;
        if ((result.imageUrl ?? '').trim().isNotEmpty) {
          _resolvedImageUrl = result.imageUrl!.trim();
        }
      });
      _loadMyPlacesInfo();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSaveFailed
        ? '장소 저장에 실패했어요'
        : (_isSaving ? '장소 입력중...' : '장소 입력 완료 🎉');
    final showActions = !_isSaving;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              left: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                opacity: showActions ? 1 : 0,
                child: const Icon(
                  PhosphorIconsBold.x,
                  size: 24,
                  color: Colors.black,
                ),
              ),
              onLeftTap: showActions ? () => Navigator.of(context).maybePop() : null,
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
                                imageUrl: _resolvedImageUrl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                            child: Text(
                              title,
                              key: ValueKey<String>('title_$title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                            child: RichText(
                              key: ValueKey<String>(
                                _isSaveFailed
                                    ? 'subtitle_failed'
                                    : (_isSaving
                                        ? 'subtitle_saving'
                                        : 'subtitle_completed'),
                              ),
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
                                  if (_isSaveFailed)
                                    const TextSpan(
                                      text: '저장에 실패했어요.\n잠시 후 다시 시도해주세요.',
                                    )
                                  else if (_isSaving)
                                    const TextSpan(
                                      text: '장소 정보를 저장하고 있어요.\n잠시만 기다려주세요.',
                                    )
                                  else ...[
                                    const TextSpan(text: '벌써, '),
                                    TextSpan(
                                      text: _nickname.isEmpty ? '회원' : _nickname,
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
                                ],
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
                child: AbsorbPointer(
                  absorbing: !showActions,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: showActions ? 1 : 0,
                    child: SizedBox(
                      width: double.infinity,
                      child: CommonRoundedButton(
                        title: '확인',
                        onTap: showActions
                            ? () => Navigator.of(context).maybePop()
                            : null,
                      ),
                    ),
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
          shadows: AppShadows.card,
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
