import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_navigation_view.dart';
import '../feed_list/models/feed_models.dart';
import '../profile/models/profile_display_user.dart';
import '../profile/profile_feed_detail_view.dart';
import '../profile/widgets/profile_feed_list_item_view.dart';
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

    return DefaultTabController(
      length: 1,
      child: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
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
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeaderDelegate(
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.zero,
                    labelColor: Colors.black,
                    unselectedLabelColor: Color(0xFF8E8E8E),
                    dividerColor: Colors.transparent,
                    indicatorColor: Colors.transparent,
                    overlayColor: MaterialStatePropertyAll(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                    labelStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: [
                      Tab(text: '피드'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _ProfileInfoFeedGrid(userId: user!.id),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoFeedGrid extends StatefulWidget {
  const _ProfileInfoFeedGrid({
    required this.userId,
  });

  final String userId;

  @override
  State<_ProfileInfoFeedGrid> createState() => _ProfileInfoFeedGridState();
}

class _ProfileInfoFeedGridState extends State<_ProfileInfoFeedGrid> {
  final List<Feed> _feeds = [];
  bool _isLoading = false;
  bool _hasNext = true;
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _feeds.clear();
      _hasNext = true;
      _nextCursor = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final json = await ApiClient.fetchFeeds(
        orderBy: 'latest',
        limit: 20,
        cursor: _nextCursor,
        authorUserId: widget.userId,
        type: 'FEED',
      );
      final data = json['data'];
      final feedsJson = data is List
          ? data
          : (data is Map<String, dynamic> ? data['feeds'] as List<dynamic>? : null) ??
              const [];
      final newFeeds = feedsJson
          .whereType<Map<String, dynamic>>()
          .map(Feed.fromJson)
          .toList();
      final meta = (json['meta'] as Map<String, dynamic>? ?? const {});
      setState(() {
        _feeds.addAll(newFeeds);
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_feeds.isEmpty && _isLoading) {
      return const Center(
        child: CommonActivityIndicator(size: 24, color: Colors.black),
      );
    }
    if (_feeds.isEmpty) {
      return const CommonEmptyView(
        message: '현재 피드가 없습니다.',
        showButton: false,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_isLoading && _hasNext && notification.metrics.extentAfter == 0) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final feed = _feeds[index];
                  final url =
                      feed.images.isNotEmpty ? feed.images.first.cdnUrl : null;
                  return CommonInkWell(
                    onTap: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (_) => SizedBox.expand(
                          child: ProfileFeedListView(
                            feeds: _feeds,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: ProfileFeedListItemView(
                      imageUrl: url ?? '',
                      imageCount: feed.images.length,
                    ),
                  );
                },
                childCount: _feeds.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 4 / 5,
              ),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CommonActivityIndicator(size: 24, color: Colors.black),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}
