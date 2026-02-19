import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../common/widgets/common_image_view.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../../common/widgets/common_profile_image_view.dart';
import '../../common/widgets/common_inkwell.dart';
import '../../common/widgets/common_profile_modal.dart';
import '../../common/widgets/common_alert_view.dart';
import '../../profile/models/profile_display_user.dart';

class LivespaceDetailProfileView extends StatefulWidget {
  const LivespaceDetailProfileView({
    super.key,
    required this.title,
    required this.imageUrls,
    required this.profileImageUrl,
    required this.nickname,
    required this.userId,
    this.isDeletedUser = false,
    required this.participantCount,
    required this.checkinUsers,
    this.isCheckedIn = false,
    this.isCheckingIn = false,
    this.onCheckinTap,
  });

  final String title;
  final List<String> imageUrls;
  final String? profileImageUrl;
  final String nickname;
  final String userId;
  final bool isDeletedUser;
  final int participantCount;
  final List<dynamic> checkinUsers;
  final bool isCheckedIn;
  final bool isCheckingIn;
  final VoidCallback? onCheckinTap;

  @override
  State<LivespaceDetailProfileView> createState() =>
      _LivespaceDetailProfileViewState();
}

class _LivespaceDetailProfileViewState extends State<LivespaceDetailProfileView> {
  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);

  @override
  void dispose() {
    _pageIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void showDeletedUserAlert() {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: const Color(0x99000000),
        builder: (_) {
          return Material(
            type: MaterialType.transparency,
            child: CommonAlertView(
              title: '삭제된 사용자입니다.',
              subTitle: '탈퇴한 사용자의 프로필은 확인할 수 없습니다.',
              primaryButtonTitle: '확인',
              onPrimaryTap: () => Navigator.of(context).pop(),
            ),
          );
        },
      );
    }

    void handleProfileTap() {
      if (widget.userId.isEmpty) return;
      if (widget.isDeletedUser) {
        showDeletedUserAlert();
        return;
      }
      final displayUser = ProfileDisplayUser(
        id: widget.userId,
        nickname: widget.nickname,
        profileImageUrl: widget.profileImageUrl,
      );
      showProfileModal(
        context,
        user: displayUser,
        allowCurrentUser: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _HeaderSection.defaultHeight + _HeaderSection.titleBlockHeight;
        final extra = (totalHeight -
                (_HeaderSection.defaultHeight + _HeaderSection.titleBlockHeight))
            .clamp(0.0, double.infinity)
            .toDouble();
        final headerHeight = _HeaderSection.defaultHeight + extra;
        final imageHeight = (headerHeight -
                _HeaderSection.bottomPadding -
                _HeaderSection.overlap)
            .clamp(0.0, headerHeight)
            .toDouble();
        return SizedBox(
          height: totalHeight,
          child: Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: _HeaderSection(
                  imageUrls: widget.imageUrls,
                  onPageChanged: (index) => _pageIndex.value = index,
                  pageIndex: _pageIndex,
                  participantCount: widget.participantCount,
                  checkinUsers: widget.checkinUsers,
                  isCheckedIn: widget.isCheckedIn,
                  isCheckingIn: widget.isCheckingIn,
                  onCheckinTap: widget.onCheckinTap,
                  imageHeight: imageHeight,
                  totalHeight: headerHeight,
                ),
              ),
              SizedBox(
                height: _HeaderSection.titleBlockHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CommonInkWell(
                            onTap: handleProfileTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                CommonProfileImageView(
                                  size: 24,
                                  imageUrl: widget.profileImageUrl,
                                  useSquircle: true,
                                  placeholderIconSize: 12,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.nickname,
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.imageUrls,
    required this.onPageChanged,
    required this.pageIndex,
    required this.participantCount,
    required this.checkinUsers,
    required this.isCheckedIn,
    required this.isCheckingIn,
    required this.onCheckinTap,
    required this.imageHeight,
    required this.totalHeight,
  });

  final List<String> imageUrls;
  final ValueChanged<int> onPageChanged;
  final ValueListenable<int> pageIndex;
  final int participantCount;
  final List<dynamic> checkinUsers;
  final bool isCheckedIn;
  final bool isCheckingIn;
  final VoidCallback? onCheckinTap;
  final double imageHeight;
  final double totalHeight;

  static const double overlap = 25;
  static const double bottomPadding = 12;
  static const double defaultHeight = 317;
  static const double titleBlockHeight = 76;

  String? _extractProfileImageUrl(dynamic user) {
    if (user is Map<String, dynamic>) {
      final profile = user['profileImage'];
      if (profile is Map<String, dynamic>) {
        return profile['cdnUrl'] as String? ??
            profile['fileUrl'] as String? ??
            profile['thumbnailUrl'] as String?;
      }
      return user['profileImageUrl'] as String? ??
          user['thumbnailUrl'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: imageUrls.length <= 1
                ? CommonImageView(
                    networkUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
                    fit: BoxFit.cover,
                    backgroundColor: const Color(0xFFF2F2F2),
                  )
                : PageView.builder(
                    onPageChanged: onPageChanged,
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return CommonImageView(
                        networkUrl: imageUrls[index],
                        fit: BoxFit.cover,
                        backgroundColor: const Color(0xFFF2F2F2),
                      );
                    },
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 90,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (imageUrls.length > 1)
            Positioned(
              bottom: bottomPadding + 50 + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(   
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  alignment: Alignment.center,
                  child: ValueListenableBuilder<int>(
                    valueListenable: pageIndex,
                    builder: (context, index, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          imageUrls.length,
                          (i) => Container(
                            width: i == index ? 8 : 6,
                            height: i == index ? 8 : 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == index
                                  ? Colors.white
                                  : const Color(0x66FFFFFF),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: bottomPadding,
            left: 40,
            right: 40,
            child: Container(
              height: 50,
              padding: const EdgeInsets.only(left: 12, right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (participantCount <= 0)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '👋🏻 제일 먼저 체크인을 해보세요!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Builder(
                      builder: (context) {
                        const maxVisible = 5;
                        const size = 28.0;
                        const overlap = 10.0;
                        final visible =
                            participantCount <= maxVisible ? participantCount : maxVisible;
                        final showPlus = participantCount > maxVisible;
                        final stackCount = visible + (showPlus ? 1 : 0);
                        final width = stackCount > 0
                            ? size + (stackCount - 1) * (size - overlap)
                            : 0.0;
                        return SizedBox(
                          width: width,
                          height: size,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: List.generate(stackCount, (index) {
                              if (showPlus && index == stackCount - 1) {
                                final extra = participantCount - maxVisible;
                                return _OverlayCountDot(
                                  index: index,
                                  label: '+$extra',
                                );
                              }
                              final user = index < checkinUsers.length
                                  ? checkinUsers[index]
                                  : null;
                              final url = _extractProfileImageUrl(user);
                              return _OverlayProfileDot(
                                index: index,
                                imageUrl: url,
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ],
                  if (participantCount > 0) const Spacer(),
                  if (participantCount <= 0) const SizedBox(width: 8),
                  if (isCheckedIn)
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            PhosphorIconsRegular.check,
                            size: 14,
                            color: Color(0xFF212121),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '체크인 완료',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF212121),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isCheckedIn)
                    CommonInkWell(
                      onTap: onCheckinTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '체크인',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayProfileDot extends StatelessWidget {
  const _OverlayProfileDot({
    required this.index,
    this.imageUrl,
  });

  final int index;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const double size = 28;
    const double overlap = 10;
    return Positioned(
      left: index * (size - overlap),
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
          cornerRadius: size * 0.34,
          cornerSmoothing: 1,
        ),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(2),
          child: ClipSmoothRect(
            radius: SmoothBorderRadius(
              cornerRadius: (size - 4) * 0.34,
              cornerSmoothing: 1,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              child: CommonProfileImageView(
                size: size,
                imageUrl: imageUrl,
                useSquircle: true,
                placeholderIconSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayCountDot extends StatelessWidget {
  const _OverlayCountDot({
    required this.index,
    required this.label,
  });

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    const double size = 28;
    const double overlap = 10;
    return Positioned(
      left: index * (size - overlap),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(size * 0.34),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF424242),
          ),
        ),
      ),
    );
  }
}
