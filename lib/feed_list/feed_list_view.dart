import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../common/widgets/common_feed_item_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../notification/notification_view.dart';
import 'models/feed_models.dart';
import 'widgets/feed_list_navigation_view.dart';

class FeedListView extends StatefulWidget {
  const FeedListView({super.key});

  @override
  State<FeedListView> createState() => _FeedListViewState();
}

class _FeedListViewState extends State<FeedListView> {
  final List<Feed> _feeds = [];
  final PageController _pageController = PageController();
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasNext = true;
  String? _nextCursor;
  int _selectedIndex = 0;
  int _currentPage = 0;
  bool _allowRefreshForCurrentDrag = false;
  late final VoidCallback _reloadListener;

  String get _orderBy => _selectedIndex == 0 ? 'latest' : 'popular';

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _reloadListener = () {
      if (!mounted) return;
      _loadInitial();
    };
    HomeTabController.feedReloadSignal.addListener(_reloadListener);
  }

  @override
  void dispose() {
    _pageController.dispose();
    HomeTabController.feedReloadSignal.removeListener(_reloadListener);
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _feeds.clear();
      _hasNext = true;
      _nextCursor = null;
    });
    await _loadMore();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    final keepPage = _currentPage;
    await _reloadFirstPage();
    if (!mounted) return;
    if (_pageController.hasClients && _feeds.isNotEmpty) {
      final target = keepPage.clamp(0, _feeds.length - 1);
      _pageController.jumpToPage(target);
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _reloadFirstPage() async {
    if (_isLoading) return;
    setState(() {
      _nextCursor = null;
      _hasNext = true;
      _isLoading = true;
    });
    try {
      final json = await ApiClient.fetchFeeds(
        orderBy: _orderBy,
        limit: 20,
      );
      final data = json['data'];
      final feedsJson = data is List
          ? data
          : (data is Map<String, dynamic> ? data['feeds'] as List<dynamic>? : null) ??
              const [];
      final refreshedFeeds = feedsJson
          .whereType<Map<String, dynamic>>()
          .map(Feed.fromJson)
          .toList();
      final meta = (json['meta'] as Map<String, dynamic>? ?? const {});
      setState(() {
        _feeds
          ..clear()
          ..addAll(refreshedFeeds);
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final json = await ApiClient.fetchFeeds(
        orderBy: _orderBy,
        limit: 20,
        cursor: _nextCursor,
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

  void _applyFeedLikeUpdate(String feedId, bool isLiked, int likeCount) {
    final index = _feeds.indexWhere((f) => f.id == feedId);
    if (index < 0) return;
    setState(() {
      _feeds[index] = _feeds[index].copyWith(
        isLiked: isLiked,
        likeCount: likeCount,
      );
    });
  }

  void _applyFeedCommentCount(String feedId, int commentCount) {
    final index = _feeds.indexWhere((f) => f.id == feedId);
    if (index < 0) return;
    setState(() {
      _feeds[index] = _feeds[index].copyWith(
        commentCount: commentCount,
      );
    });
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Stack(
            children: [
              CommonRefreshView(
                onRefresh: _handleRefresh,
                topPadding: MediaQuery.of(context).padding.top + 12,
                notificationPredicate: (notification) {
                  if (notification is ScrollStartNotification) {
                    _allowRefreshForCurrentDrag =
                        _currentPage == 0 &&
                        notification.metrics.extentBefore == 0;
                  } else if (notification is ScrollEndNotification) {
                    _allowRefreshForCurrentDrag = false;
                  }
                  if (!_allowRefreshForCurrentDrag) return false;
                  return notification.depth == 0 &&
                      notification.metrics.extentBefore == 0;
                },
                child: PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _feeds.length,
                  onPageChanged: (index) {
                    _currentPage = index;
                    if (_feeds.length > 1 &&
                        index > 0 &&
                        index >= _feeds.length - 2) {
                      _loadMore();
                    }
                  },
                  itemBuilder: (context, index) {
                    return CommonFeedItemView(
                      key: ValueKey(_feeds[index].id),
                      feed: _feeds[index],
                      padding: EdgeInsets.zero,
                      onLikeChanged: _applyFeedLikeUpdate,
                      onCommentCountChanged: _applyFeedCommentCount,
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FeedListNavigationView(
                  selectedIndex: _selectedIndex,
                  onLatestTap: () => _onTabSelected(0),
                  onPopularTap: () => _onTabSelected(1),
                  onNotificationTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationView(),
                      ),
                    );
                  },
                ),
              ),
              if (_feeds.isEmpty && _isLoading && !_isRefreshing)
                const Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
