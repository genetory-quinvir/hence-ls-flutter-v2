import 'package:flutter/material.dart';
import 'package:hence_ls_flutter_v2/main.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hence_ls_flutter_v2/achievement/achievement_view.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/auth/auth_store.dart';
import '../../common/widgets/common_inkwell.dart';
import '../../common/widgets/common_profile_view.dart';
import '../../common/widgets/common_rounded_button.dart';
import '../../profile_edit/profile_edit_view.dart';
import '../profile_placebook_view.dart';
import '../models/profile_display_user.dart';

class ProfileUserSection extends StatefulWidget {
  const ProfileUserSection({
    super.key,
    this.showEditButton = true,
    this.showAchievementButton = true,
    this.displayUser,
    this.feedCount,
    this.createdPlaceCount,
    this.favoritePlaceCount,
    this.followingCount,
    this.followerCount,
    this.showFollowActions = false,
    this.showFollowButton = true,
    this.followingLabel = '팔로우',
    this.followerLabel = '팔로워',
    this.activityLevel,
    this.isFollowing,
    this.isFollowedByMe,
    this.onFollowToggle,
    this.onFollowingTap,
    this.onFollowerTap,
    this.onCreatedPlaceTap,
    this.onFavoritePlaceTap,
  });

  final bool showEditButton;
  final bool showAchievementButton;
  final ProfileDisplayUser? displayUser;
  final int? feedCount;
  final int? createdPlaceCount;
  final int? favoritePlaceCount;
  final int? followingCount;
  final int? followerCount;
  final bool showFollowActions;
  final bool showFollowButton;
  final String followingLabel;
  final String followerLabel;
  final int? activityLevel;
  final bool? isFollowing;
  final bool? isFollowedByMe;
  final VoidCallback? onFollowToggle;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowerTap;
  final VoidCallback? onCreatedPlaceTap;
  final VoidCallback? onFavoritePlaceTap;

  @override
  State<ProfileUserSection> createState() => _ProfileUserSectionState();
}

class _ProfileUserSectionState extends State<ProfileUserSection> {
  @override
  Widget build(BuildContext context) {
    if (widget.displayUser != null) {
      final user = widget.displayUser!;
      final fallbackEmail = AuthStore.instance.currentUser.value?.email?.trim() ?? '';
      final resolvedEmail = user.email?.trim().isNotEmpty == true
          ? user.email!.trim()
          : fallbackEmail;
        return _ProfileUserContent(
          nickname: user.nickname.trim().isNotEmpty ? user.nickname : '사용자',
          name: user.name?.trim() ?? '',
          representativeTitleName:
              user.representativeTitleInfoName?.trim() ?? '',
          representativeTitleCode:
              user.representativeTitleInfoCode?.trim() ?? '',
          rewardLevel: user.rewardLevel,
          email: resolvedEmail,
          introduction: user.introduction?.trim() ?? '',
          profileImageUrl: user.profileImageUrl,
          showEditButton: widget.showEditButton,
          showAchievementButton: widget.showAchievementButton,
          feedCount: widget.feedCount ??
              user.placebookTotalCount ??
              user.feedCount,
          createdPlaceCount:
              widget.createdPlaceCount ?? user.createdPlaceCount,
          favoritePlaceCount:
              widget.favoritePlaceCount ?? user.favoritePlaceCount,
          followingCount: widget.followingCount ?? user.followingCount,
          followerCount: widget.followerCount ?? user.followerCount,
          showFollowActions: widget.showFollowActions,
          showFollowButton: widget.showFollowButton,
          followingLabel: widget.followingLabel,
          followerLabel: widget.followerLabel,
          activityLevel: widget.activityLevel ?? user.activityLevel,
          isFollowing: widget.isFollowing ?? user.isFollowing,
          isFollowedByMe: widget.isFollowedByMe ?? user.isFollowedByMe,
          onFollowToggle: widget.onFollowToggle,
          onFollowingTap: widget.onFollowingTap,
          onFollowerTap: widget.onFollowerTap,
          onCreatedPlaceTap: widget.onCreatedPlaceTap,
          onFavoritePlaceTap: widget.onFavoritePlaceTap,
        );
    }
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.currentUser,
      builder: (context, user, _) {
        final introduction =
            (user?.introduction?.trim().isNotEmpty ?? false)
                ? user!.introduction!.trim()
                : '';
        final nickname =
            (user?.nickname.trim().isNotEmpty ?? false) ? user!.nickname : '사용자';
        final email =
            (user?.email?.trim().isNotEmpty ?? false) ? user!.email! : '';
        return _ProfileUserContent(
          nickname: nickname,
          name: '',
          representativeTitleName: '',
          representativeTitleCode: '',
          rewardLevel: null,
          email: email,
          introduction: introduction,
          profileImageUrl: user?.profileImageUrl,
          showEditButton: widget.showEditButton,
          showAchievementButton: widget.showAchievementButton,
          feedCount: widget.feedCount ??
              user?.placebookTotalCount ??
              user?.feedCount,
          createdPlaceCount:
              widget.createdPlaceCount ?? user?.createdPlaceCount,
          favoritePlaceCount:
              widget.favoritePlaceCount ?? user?.favoritePlaceCount,
          followingCount: widget.followingCount ?? user?.followingCount,
          followerCount: widget.followerCount ?? user?.followerCount,
          showFollowActions: widget.showFollowActions,
          showFollowButton: widget.showFollowButton,
          followingLabel: widget.followingLabel,
          followerLabel: widget.followerLabel,
          activityLevel: widget.activityLevel ?? user?.activityLevel,
          isFollowing: widget.isFollowing,
          isFollowedByMe: widget.isFollowedByMe,
          onFollowToggle: widget.onFollowToggle,
          onFollowingTap: widget.onFollowingTap,
          onFollowerTap: widget.onFollowerTap,
          onCreatedPlaceTap: widget.onCreatedPlaceTap,
          onFavoritePlaceTap: widget.onFavoritePlaceTap,
        );
      },
    );
  }
}

class _ProfileUserContent extends StatelessWidget {
  const _ProfileUserContent({
    required this.nickname,
    required this.name,
    required this.representativeTitleName,
    required this.representativeTitleCode,
    required this.rewardLevel,
    required this.email,
    required this.introduction,
    required this.profileImageUrl,
    required this.showEditButton,
    required this.showAchievementButton,
    this.feedCount,
    this.createdPlaceCount,
    this.favoritePlaceCount,
    this.followingCount,
    this.followerCount,
    this.showFollowActions = false,
    this.showFollowButton = true,
    required this.followingLabel,
    required this.followerLabel,
    this.activityLevel,
    this.isFollowing,
    this.isFollowedByMe,
    this.onFollowToggle,
    this.onFollowingTap,
    this.onFollowerTap,
    this.onCreatedPlaceTap,
    this.onFavoritePlaceTap,
  });

  final String nickname;
  final String name;
  final String representativeTitleName;
  final String representativeTitleCode;
  final int? rewardLevel;
  final String email;
  final String introduction;
  final String? profileImageUrl;
  final bool showEditButton;
  final bool showAchievementButton;
  final int? feedCount;
  final int? createdPlaceCount;
  final int? favoritePlaceCount;
  final int? followingCount;
  final int? followerCount;
  final bool showFollowActions;
  final bool showFollowButton;
  final String followingLabel;
  final String followerLabel;
  final int? activityLevel;
  final bool? isFollowing;
  final bool? isFollowedByMe;
  final VoidCallback? onFollowToggle;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowerTap;
  final VoidCallback? onCreatedPlaceTap;
  final VoidCallback? onFavoritePlaceTap;

  String _levelBadgeText(String raw, {int? rewardLevel}) {
    if (rewardLevel != null && rewardLevel > 0) {
      return 'LV. $rewardLevel';
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'^(LV\\d+)').firstMatch(trimmed);
    if (match != null) {
      final value = match.group(1) ?? '';
      return value.replaceFirst('LV', 'LV. ');
    }
    final parts = trimmed.split('_');
    if (parts.isNotEmpty && parts.first.startsWith('LV')) {
      return parts.first.replaceFirst('LV', 'LV. ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CommonProfileView(
                networkUrl: profileImageUrl,
                size: 56,
                placeholder: Container(
                  color: const Color(0xFFF2F2F2),
                  alignment: Alignment.center,
                  child: const Icon(
                    PhosphorIconsRegular.user,
                    size: 24,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    if (showEditButton && email.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF8E8E8E),
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (!showFollowActions && email.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF8E8E8E),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (showEditButton) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 50,
                  child: CommonRoundedButton(
                    title: '편집',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditView(),
                        ),
                      );
                    },
                    height: 32,
                    radius: 8,
                    backgroundColor: const Color(0xFFF5F5F5),
                    textColor: Colors.black,
                    textStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (!showEditButton && showFollowActions && showFollowButton) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  child: CommonRoundedButton(
                    title: (isFollowing ?? false) ? '팔로잉' : '팔로우',
                    onTap: onFollowToggle,
                    height: 32,
                    radius: 8,
                    backgroundColor: (isFollowing ?? false)
                        ? const Color(0xFFF2F2F2)
                        : Colors.black,
                    textColor:
                        (isFollowing ?? false) ? Colors.black : Colors.white,
                    textStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: (isFollowing ?? false)
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isFollowedByMe ?? false) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '맞팔로우',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          if (showFollowActions) ...[
            if (name.isNotEmpty || representativeTitleName.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (name.isNotEmpty)
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF424242),
                                        ),
                                      ),
                                    if (representativeTitleName.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            if (_levelBadgeText(
                                                    representativeTitleCode,
                                                    rewardLevel: rewardLevel)
                                                .isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  _levelBadgeText(
                                                      representativeTitleCode,
                                                      rewardLevel: rewardLevel),
                                                  style: const TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: MyApp.primary200,
                                                  ),
                                                ),
                                              ),
                                            if (_levelBadgeText(
                                                    representativeTitleCode,
                                                    rewardLevel: rewardLevel)
                                                .isNotEmpty)
                                              const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                representativeTitleName,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (showAchievementButton)
                                CommonRoundedButton(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  title: '나의 업적',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AchievementView(),
                                      ),
                                    );
                                  },
                                  height: 32,
                                  radius: 8,
                                  backgroundColor: const Color(0xFFE0E0E0),
                                  textColor: const Color(0xFF757575),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  trailing: Icon(
                                    PhosphorIconsBold.caretRight,
                                    size: 12,
                                    color: const Color(0xFF757575),
                                  ),
                                  trailingCentered: true,
                                  trailingGap: 4,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatItem(
                                  label: '나의 장소',
                                  value: createdPlaceCount ?? 0,
                                  alignCenter: true,
                                  onTap: onCreatedPlaceTap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatItem(
                                  label: '저장한 장소',
                                  value: favoritePlaceCount ?? 0,
                                  alignCenter: true,
                                  onTap: onFavoritePlaceTap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatItem(
                                  label: followingLabel,
                                  value: followingCount ?? 0,
                                  alignCenter: true,
                                  onTap: onFollowingTap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatItem(
                                  label: followerLabel,
                                  value: followerCount ?? 0,
                                  alignCenter: true,
                                  onTap: onFollowerTap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (introduction.isNotEmpty) ...[
            const SizedBox(height: 4),
            _IntroductionText(
              introduction: introduction,
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroductionText extends StatefulWidget {
  const _IntroductionText({
    required this.introduction,
  });

  final String introduction;

  @override
  State<_IntroductionText> createState() => _IntroductionTextState();
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.alignCenter = true,
    this.onTap,
  });

  final String label;
  final int value;
  final bool alignCenter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment:
          alignCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            '$value',
            textAlign: alignCenter ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: alignCenter ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E8E),
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }
    return CommonInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _IntroductionTextState extends State<_IntroductionText> {
  bool _expanded = false;
  bool _showToggle = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(
            text: widget.introduction,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.grey[800],
            ),
          ),
          maxLines: 4,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final didOverflow = painter.didExceedMaxLines;
        if (_showToggle != didOverflow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _showToggle = didOverflow);
            }
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.introduction,
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[800],
              ),
            ),
            if (_showToggle)
              CommonInkWell(
                onTap: () {
                  setState(() => _expanded = !_expanded);
                },
                child: Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? '숨기기' : '더보기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
