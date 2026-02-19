import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';

import '../../common/auth/auth_store.dart';
import '../../common/widgets/common_inkwell.dart';
import 'profile_activity_info_view.dart';
import 'profile_feed_list_item_view.dart';
import 'profile_user_section.dart';
import '../../common/network/api_client.dart';
import '../../feed_list/models/feed_models.dart';
import '../../common/widgets/common_activity.dart';
import '../../common/widgets/common_image_view.dart';
import '../../common/widgets/common_livespace_list_item_view.dart';
import '../../common/widgets/common_empty_view.dart';
import '../../common/widgets/common_refresh_view.dart';
import '../../livespace_detail/livespace_detail_view.dart';
import '../profile_feed_detail_view.dart';
import '../models/profile_display_user.dart';
import '../../following_list/following_list_view.dart';
import '../../follow_list/follow_list_view.dart';

class ProfileSignedView extends StatefulWidget {
  const ProfileSignedView({
    super.key,
    this.onHeaderCollapsedChanged,
  });

  final ValueChanged<bool>? onHeaderCollapsedChanged;

  @override
  State<ProfileSignedView> createState() => _ProfileSignedViewState();
}

class _ProfileSignedViewState extends State<ProfileSignedView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  final ValueNotifier<int> _headerRefreshSignal = ValueNotifier<int>(0);
  double _collapseOffset = 120;
  bool _isHeaderCollapsed = false;
  Future<void>? _profileRefreshInFlight;
  DateTime? _lastHeaderRefreshAt;
  static const Duration _headerRefreshInterval = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureHeaderHeight();
      _handleScroll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _headerRefreshSignal.dispose();
    super.dispose();
  }

  void _measureHeaderHeight() {
    final context = _headerKey.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) return;
    final next = 16 + renderBox.size.height;
    if ((next - _collapseOffset).abs() < 0.5) return;
    _collapseOffset = next;
    _handleScroll();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final next = _scrollController.offset >= _collapseOffset;
    if (next == _isHeaderCollapsed) return;
    _isHeaderCollapsed = next;
    widget.onHeaderCollapsedChanged?.call(next);
  }

  Future<void> _refreshProfileInfo({bool force = false}) {
    if (!AuthStore.instance.isSignedIn.value) return Future.value();
    final now = DateTime.now();
    if (!force && _lastHeaderRefreshAt != null) {
      final elapsed = now.difference(_lastHeaderRefreshAt!);
      if (elapsed < _headerRefreshInterval) return Future.value();
    }
    if (_profileRefreshInFlight != null) return _profileRefreshInFlight!;
    final future = _doRefreshProfileInfo();
    _profileRefreshInFlight = future.whenComplete(() {
      _profileRefreshInFlight = null;
    });
    return _profileRefreshInFlight!;
  }

  Future<void> _doRefreshProfileInfo() async {
    try {
      final me = await ApiClient.fetchMe();
      await AuthStore.instance.setUser(me);
      _headerRefreshSignal.value += 1;
      _lastHeaderRefreshAt = DateTime.now();
    } catch (_) {
      // Ignore refresh failures; existing cached user remains visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureHeaderHeight();
    });
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _headerKey,
                child: _ProfileHeaderUserSection(
                  refreshSignal: _headerRefreshSignal,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: _ProfileActivitySection()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeaderDelegate(
                  const TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Color(0xFF8E8E8E),
                    indicatorColor: Colors.transparent,
                    overlayColor: MaterialStatePropertyAll(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                    labelStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: [
                      Tab(text: '피드'),
                      Tab(text: '라이브스페이스'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _ProfileFeedGrid(
              emptyMessage: '현재 피드가 없습니다.',
              emptyButtonText: '피드 작성하기',
              onRefreshTab: _refreshProfileInfo,
              refreshProfileOnTabRefresh: false,
            ),
            _ProfileParticipantList(
              onRefreshTab: _refreshProfileInfo,
              refreshProfileOnTabRefresh: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderUserSection extends StatefulWidget {
  const _ProfileHeaderUserSection({
    required this.refreshSignal,
  });

  final ValueListenable<int> refreshSignal;

  @override
  State<_ProfileHeaderUserSection> createState() =>
      _ProfileHeaderUserSectionState();
}

class _ProfileHeaderUserSectionState extends State<_ProfileHeaderUserSection> {
  String? _userId;
  String? _userSignature;
  bool _forceReload = false;
  Future<ProfileDisplayUser>? _detailFuture;
  late final VoidCallback _refreshListener;

  @override
  void initState() {
    super.initState();
    _refreshListener = _reloadDetail;
    widget.refreshSignal.addListener(_refreshListener);
  }

  @override
  void didUpdateWidget(covariant _ProfileHeaderUserSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal == widget.refreshSignal) return;
    oldWidget.refreshSignal.removeListener(_refreshListener);
    widget.refreshSignal.addListener(_refreshListener);
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_refreshListener);
    super.dispose();
  }

  void _reloadDetail() {
    _forceReload = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.currentUser,
      builder: (context, user, _) {
        final id = user?.id;
        final signature = id == null
            ? null
            : [
                id,
                user?.nickname ?? '',
                user?.profileImageUrl ?? '',
                user?.activityLevel?.toString() ?? '',
                user?.feedCount?.toString() ?? '',
                user?.followerCount?.toString() ?? '',
                user?.followingCount?.toString() ?? '',
              ].join('|');
        if (id != null &&
            id.isNotEmpty &&
            (id != _userId || _forceReload || signature != _userSignature)) {
          _userId = id;
          _userSignature = signature;
          _forceReload = false;
          _detailFuture = ApiClient.fetchUserDetail(id);
        }

        if (_detailFuture == null) {
          return const ProfileUserSection();
        }

        return FutureBuilder<ProfileDisplayUser>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final resolved = snapshot.data;
            if (resolved == null) {
              return const ProfileUserSection();
            }
            return ProfileUserSection(
              showEditButton: true,
              displayUser: resolved,
              showFollowActions: true,
              showFollowButton: false,
              feedCount: user?.feedCount ?? resolved.feedCount,
              followerCount: user?.followerCount ?? resolved.followerCount,
              followingCount: user?.followingCount ?? resolved.followingCount,
              activityLevel: user?.activityLevel ?? resolved.activityLevel,
              followingLabel: '팔로잉',
              followerLabel: '팔로우',
              onFollowingTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FollowingListView(userId: resolved.id),
                  ),
                );
              },
              onFollowerTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FollowListView(userId: resolved.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProfileActivitySection extends StatelessWidget {
  const _ProfileActivitySection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.currentUser,
      builder: (context, user, _) {
        final level = user?.activityLevel ?? 0;
        final clampedLevel = level.clamp(0, 5);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/levels/icon_level_$clampedLevel.svg',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '활동 지수',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Text(
                  'LV. $clampedLevel',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                CommonInkWell(
                  onTap: () => ProfileActivityInfoView.show(context),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      PhosphorIconsRegular.info,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _ActivityListPlaceholder extends StatelessWidget {
  const _ActivityListPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final isLast = index == 4;
              return Column(
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$title 리스트 아이템 ${index + 1}',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                ],
              );
            },
            childCount: 5,
          ),
        ),
      ],
    );
  }
}

class _ProfileParticipantList extends StatefulWidget {
  const _ProfileParticipantList({
    required this.onRefreshTab,
    required this.refreshProfileOnTabRefresh,
  });

  final Future<void> Function({bool force}) onRefreshTab;
  final bool refreshProfileOnTabRefresh;

  @override
  State<_ProfileParticipantList> createState() => _ProfileParticipantListState();
}

class _ProfileParticipantListState extends State<_ProfileParticipantList> {
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _hasNext = true;
  String? _nextCursor;
  Future<void>? _refreshInFlight;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _items.clear();
      _hasNext = true;
      _nextCursor = null;
    });
    await _loadMore();
  }

  Future<void> _handleRefresh() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    final future = _doRefresh();
    _refreshInFlight = future.whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<void> _doRefresh() async {
    if (widget.refreshProfileOnTabRefresh) {
      await widget.onRefreshTab(force: true);
    }
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final json = await ApiClient.fetchMySpaceParticipants(
        limit: 20,
        cursor: _nextCursor,
      );
      final data = json['data'];
      final itemsJson = data is List
          ? data
          : (data is Map<String, dynamic> ? data['feeds'] as List<dynamic>? : null) ??
              const [];
      final meta = (json['meta'] as Map<String, dynamic>? ?? const {});
      setState(() {
        _items.addAll(itemsJson.whereType<Map<String, dynamic>>());
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _thumbnailForItem(Map<String, dynamic> item) {
    final thumbnailRaw = item['thumbnail'];
    final thumbnailMap = thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
    final feedRaw = item['feed'];
    final feedMap = feedRaw is Map<String, dynamic> ? feedRaw : null;

    Map<String, dynamic>? firstImage;
    final imagesRaw = (feedMap?['images'] ?? item['images']);
    if (imagesRaw is List) {
      for (final entry in imagesRaw) {
        if (entry is Map<String, dynamic>) {
          firstImage = entry;
          break;
        }
      }
    }

    return (thumbnailRaw is String ? thumbnailRaw : null) ??
        thumbnailMap?['cdnUrl'] as String? ??
        thumbnailMap?['fileUrl'] as String? ??
        item['thumbnailUrl'] as String? ??
        item['imageUrl'] as String? ??
        firstImage?['thumbnailUrl'] as String? ??
        firstImage?['cdnUrl'] as String? ??
        firstImage?['fileUrl'] as String? ??
        item['fileUrl'] as String? ??
        item['image'] as String? ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final scrollView = _items.isEmpty
        ? CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CommonActivityIndicator(size: 24),
                        )
                      : const CommonEmptyView(
                          message: '참여한 스페이스가 없습니다.',
                          showButton: false,
                        ),
                ),
              ),
            ],
          )
        : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!_isLoading && _hasNext && notification.metrics.extentAfter == 0) {
                _loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _items[index];
                        final title = (item['title'] as String?) ??
                            (item['spaceTitle'] as String?) ??
                            (item['name'] as String?) ??
                            '라이브 스페이스';
                        final placeName = (item['placeName'] as String?) ??
                            (item['address'] as String?) ??
                            (item['location'] as String?) ??
                            '';
                        final dateText = (item['date'] as String?) ??
                            (item['startAt'] as String?) ??
                            (item['createdAt'] as String?) ??
                            '오늘';
                        final thumbnail = _thumbnailForItem(item);
                        final commentCount =
                            (item['commentCount'] as num?)?.toInt() ??
                                (item['comments'] as num?)?.toInt() ??
                                0;
                        final likeCount = (item['likeCount'] as num?)?.toInt() ??
                            (item['likes'] as num?)?.toInt() ??
                            0;
                        String? distanceText;
                        final distanceRaw = item['distance'];
                        if (distanceRaw is String && distanceRaw.trim().isNotEmpty) {
                          distanceText = distanceRaw.trim();
                        } else if (distanceRaw is num) {
                          final km = distanceRaw.toDouble();
                          distanceText = '${km.toStringAsFixed(1)}km';
                        } else if (item['distanceKm'] is num) {
                          final km = (item['distanceKm'] as num).toDouble();
                          distanceText = '${km.toStringAsFixed(1)}km';
                        }
                        return CommonLivespaceListItemView(
                          title: title,
                          thumbnailUrl: thumbnail,
                          dateText: dateText,
                          placeName: placeName,
                          commentCount: commentCount,
                          likeCount: likeCount,
                          distanceText: distanceText,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LivespaceDetailView(space: item),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CommonActivityIndicator(
                          size: 24,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );

    return CommonRefreshView(
      onRefresh: _handleRefresh,
      topPadding: 12,
      child: scrollView,
    );
  }
}
class _ProfileFeedGrid extends StatefulWidget {
  const _ProfileFeedGrid({
    super.key,
    required this.emptyMessage,
    required this.emptyButtonText,
    required this.onRefreshTab,
    required this.refreshProfileOnTabRefresh,
  });

  final String emptyMessage;
  final String emptyButtonText;
  final Future<void> Function({bool force}) onRefreshTab;
  final bool refreshProfileOnTabRefresh;

  @override
  State<_ProfileFeedGrid> createState() => _ProfileFeedGridState();
}

class _ProfileFeedGridState extends State<_ProfileFeedGrid> {
  final List<Feed> _feeds = [];
  bool _isLoading = false;
  bool _hasNext = true;
  String? _nextCursor;
  Future<void>? _refreshInFlight;

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

  Future<void> _handleRefresh() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    final future = _doRefresh();
    _refreshInFlight = future.whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<void> _doRefresh() async {
    if (widget.refreshProfileOnTabRefresh) {
      await widget.onRefreshTab(force: true);
    }
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final userId = AuthStore.instance.currentUser.value?.id ?? '';
      final json = await ApiClient.fetchFeeds(
        orderBy: 'latest',
        limit: 20,
        cursor: _nextCursor,
        authorUserId: userId,
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
      final prefetchUrls = newFeeds
          .map((feed) => feed.images.isNotEmpty ? (feed.images.first.cdnUrl ?? '') : '')
          .where((url) => url.trim().isNotEmpty)
          .toList();
      if (prefetchUrls.isNotEmpty) {
        CommonImageView.prefetchNetworkUrls(prefetchUrls);
      }
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
    final scrollView = _feeds.isEmpty
        ? CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CommonActivityIndicator(size: 24),
                        )
                      : CommonEmptyView(
                          message: widget.emptyMessage,
                          showButton: false,
                        ),
                ),
              ),
            ],
          )
        : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!_isLoading && _hasNext && notification.metrics.extentAfter == 0) {
                _loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  onFeedUpdated: (updated) {
                                    final i =
                                        _feeds.indexWhere((f) => f.id == updated.id);
                                    if (i < 0) return;
                                    setState(() => _feeds[i] = updated);
                                  },
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
                if (_isLoading && _feeds.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CommonActivityIndicator(
                          size: 24,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );

    return CommonRefreshView(
      onRefresh: _handleRefresh,
      topPadding: 12,
      child: scrollView,
    );
  }
}
