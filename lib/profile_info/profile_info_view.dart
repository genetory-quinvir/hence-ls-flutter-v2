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
  const ProfileInfoView({
    super.key,
    this.user,
  });

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
                PhosphorIconsRegular.x,
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
                          return const Center(
                            child: CommonActivityIndicator(),
                          );
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
  const _ProfileInfoBody({
    required this.user,
  });

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
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: ProfileUserSection(
            showEditButton: false,
            displayUser: user,
            showFollowActions: true,
            showFollowButton: true,
            isFollowing: _isFollowing,
            isFollowedByMe: user.isFollowedByMe,
            followerCount: _followerCount,
            onFollowToggle: _isTogglingFollow ? null : _toggleFollow,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}
