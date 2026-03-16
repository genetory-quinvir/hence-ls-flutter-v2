import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../profile/models/profile_display_user.dart';
import '../profile/widgets/profile_user_section.dart';

class ProfileInfoView extends StatelessWidget {
  const ProfileInfoView({super.key, this.user});

  final ProfileDisplayUser? user;

  @override
  Widget build(BuildContext context) {
    final displayUser = user;
    final Future<ProfileDisplayUser>? userFuture =
        displayUser?.id.isNotEmpty == true
        ? ApiClient.fetchUserDetail(displayUser!.id)
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top),
            CommonNavigationView(
              title: '프로필 정보',
              left: const Icon(
                PhosphorIconsBold.x,
                size: 24,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: userFuture == null
                  ? _ProfileInfoBody(user: displayUser)
                  : FutureBuilder<ProfileDisplayUser>(
                      future: userFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: CommonActivityIndicator());
                        }
                        final resolved = snapshot.data ?? displayUser;
                        return _ProfileInfoBody(user: resolved);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoBody extends StatefulWidget {
  const _ProfileInfoBody({required this.user});

  final ProfileDisplayUser? user;

  @override
  State<_ProfileInfoBody> createState() => _ProfileInfoBodyState();
}

class _ProfileInfoBodyState extends State<_ProfileInfoBody> {
  bool _isTogglingFollow = false;
  bool _isFollowing = false;
  int _followerCount = 0;

  @override
  void initState() {
    super.initState();
    _syncFromUser(widget.user);
  }

  @override
  void didUpdateWidget(covariant _ProfileInfoBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.user?.isFollowing != widget.user?.isFollowing ||
        oldWidget.user?.followerCount != widget.user?.followerCount) {
      _syncFromUser(widget.user);
    }
  }

  void _syncFromUser(ProfileDisplayUser? user) {
    _isFollowing = user?.isFollowing ?? false;
    _followerCount = user?.followerCount ?? 0;
  }

  Future<void> _toggleFollow() async {
    final user = widget.user;
    if (user == null || user.id.isEmpty || _isTogglingFollow) return;
    final nextFollowing = !_isFollowing;
    final nextCount = _followerCount + (nextFollowing ? 1 : -1);
    setState(() {
      _isTogglingFollow = true;
      _isFollowing = nextFollowing;
      _followerCount = nextCount < 0 ? 0 : nextCount;
    });
    try {
      if (nextFollowing) {
        await ApiClient.followUser(user.id);
      } else {
        await ApiClient.unfollowUser(user.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFollowing = !nextFollowing;
        _followerCount = user.followerCount ?? _followerCount;
      });
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null || user.id.isEmpty) {
      return const Center(
        child: CommonEmptyView(
          message: '프로필 정보를 불러올 수 없습니다.',
          buttonText: '새로고침',
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: ProfileUserSection(
            showEditButton: false,
            showAchievementButton: false,
            displayUser: user,
            showFollowActions: true,
            showFollowButton: true,
            isFollowing: _isFollowing,
            isFollowedByMe: user.isFollowedByMe,
            followerCount: _followerCount,
            onFollowToggle: _isTogglingFollow ? null : _toggleFollow,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildActivitySummarySection(user),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildActivitySummarySection(ProfileDisplayUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '활동 요약',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: RichText(
            text: _buildActivitySummarySpans(user),
          ),
        ),
      ],
    );
  }

  TextSpan _buildActivitySummarySpans(ProfileDisplayUser user) {
    const baseStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 16,
      height: 1.8,
      fontWeight: FontWeight.w500,
      color: Color(0xFF4A4A4A),
    );
    const highlightStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFE9F2FF),
    );
    const countStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFFFE9F2),
    );
    const followStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFF0ECFF),
    );

    final spans = <TextSpan>[];
    void addLine(List<TextSpan> lineSpans) {
      if (spans.isNotEmpty) {
        spans.add(const TextSpan(text: '\n', style: baseStyle));
      }
      spans.addAll(lineSpans);
    }

    if (user.activityLevel != null) {
      addLine([
        const TextSpan(text: '활동 지수는 ', style: baseStyle),
        TextSpan(text: 'LV. ${user.activityLevel}', style: highlightStyle),
        const TextSpan(text: '예요.', style: baseStyle),
      ]);
    }

    if (user.createdPlaceCount != null || user.favoritePlaceCount != null) {
      final createdText = user.createdPlaceCount != null
          ? '저장 ${user.createdPlaceCount}개'
          : null;
      final favoriteText = user.favoritePlaceCount != null
          ? '찜 ${user.favoritePlaceCount}개'
          : null;
      final parts = [createdText, favoriteText].whereType<String>().toList();
      if (parts.isNotEmpty) {
        addLine([
          const TextSpan(text: '현재 ', style: baseStyle),
          TextSpan(text: parts.join(' · '), style: countStyle),
          const TextSpan(text: ' 기록이 있어요.', style: baseStyle),
        ]);
      }
    }

    if (user.followingCount != null || user.followerCount != null) {
      final followingText =
          user.followingCount != null ? '팔로잉 ${user.followingCount}명' : null;
      final followerText =
          user.followerCount != null ? '팔로우 ${user.followerCount}명' : null;
      final parts = [followingText, followerText].whereType<String>().toList();
      if (parts.isNotEmpty) {
        addLine([
          TextSpan(text: parts.join(' · '), style: followStyle),
          const TextSpan(text: '과 함께하고 있어요.', style: baseStyle),
        ]);
      }
    }

    final repTitle = (user.representativeTitleInfoName ?? '').trim();
    if (repTitle.isNotEmpty) {
      addLine([
        const TextSpan(text: '대표 호칭은 ', style: baseStyle),
        TextSpan(text: repTitle, style: highlightStyle),
        const TextSpan(text: '이에요.', style: baseStyle),
      ]);
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}
