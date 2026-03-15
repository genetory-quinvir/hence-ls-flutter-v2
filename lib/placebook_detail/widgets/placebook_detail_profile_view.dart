import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../common/widgets/common_image_view.dart';

import '../../common/widgets/common_profile_image_view.dart';
import '../../common/widgets/common_inkwell.dart';
import '../../common/widgets/common_profile_modal.dart';
import '../../common/widgets/common_alert_view.dart';
import '../../profile/models/profile_display_user.dart';

class PlacebookDetailProfileView extends StatefulWidget {
  const PlacebookDetailProfileView({
    super.key,
    required this.title,
    required this.locationTitle,
    required this.imageUrls,
    required this.profileImageUrl,
    required this.nickname,
    required this.userId,
    this.categoryLabel,
    this.themeLabel,
    this.isDeletedUser = false,
    required this.participantCount,
    required this.checkinUsers,
    this.isCheckedIn = false,
    this.isCheckingIn = false,
    this.onCheckinTap,
  });

  final String title;
  final String locationTitle;
  final List<String> imageUrls;
  final String? profileImageUrl;
  final String nickname;
  final String userId;
  final String? categoryLabel;
  final String? themeLabel;
  final bool isDeletedUser;
  final int participantCount;
  final List<dynamic> checkinUsers;
  final bool isCheckedIn;
  final bool isCheckingIn;
  final VoidCallback? onCheckinTap;

  @override
  State<PlacebookDetailProfileView> createState() =>
      _PlacebookDetailProfileViewState();
}

class _PlacebookDetailProfileViewState
    extends State<PlacebookDetailProfileView> {
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
      showProfileModal(context, user: displayUser, allowCurrentUser: true);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseHeight =
            _HeaderSection.defaultHeight + _HeaderSection.titleBlockHeight;
        final totalHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : baseHeight;
        final desiredGap = 24.0;
        final extra = (totalHeight - (baseHeight + desiredGap))
            .clamp(0.0, double.infinity)
            .toDouble();
        final headerHeight = _HeaderSection.defaultHeight + extra;
        final imageHeight =
            (headerHeight -
                    _HeaderSection.bottomPadding -
                    _HeaderSection.overlap)
                .clamp(0.0, headerHeight)
                .toDouble();
        final gap =
            (totalHeight - (headerHeight + _HeaderSection.titleBlockHeight))
                .clamp(0.0, desiredGap)
                .toDouble();
        final displayTitle = widget.title.trim().isNotEmpty
            ? widget.title
            : widget.locationTitle;
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
              Padding(
                padding: EdgeInsets.fromLTRB(16, gap, 16, 0),
                child: SizedBox(
                  height: _HeaderSection.titleBlockHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if ((widget.themeLabel ?? '').trim().isNotEmpty)
                        Text(
                          (widget.themeLabel ?? '').trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF616161),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CommonInkWell(
                            onTap: handleProfileTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                CommonProfileImageView(
                                  size: 28,
                                  imageUrl: widget.profileImageUrl,
                                  useSquircle: true,
                                  placeholderIconSize: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
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

  static const double overlap = 0;
  static const double bottomPadding = 0;
  static const double defaultHeight = 317;
  static const double titleBlockHeight = 96;

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
        ],
      ),
    );
  }
}
