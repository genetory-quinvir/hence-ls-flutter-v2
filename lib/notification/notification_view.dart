import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../common/widgets/common_refresh_view.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/state/home_tab_controller.dart';
import '../common/notifications/notification_router.dart';
import '../common/widgets/common_profile_modal.dart';
import '../feed_list/models/feed_models.dart';
import '../profile/profile_feed_detail_view.dart';
import 'widgets/notification_list_item_view.dart';

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        body: _NotificationBody(),
      ),
    );
  }
}

class _NotificationBody extends StatefulWidget {
  const _NotificationBody();

  @override
  State<_NotificationBody> createState() => _NotificationBodyState();
}

class _NotificationBodyState extends State<_NotificationBody> {
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isProcessingTap = false;
  bool _hasNext = true;
  String? _nextCursor;
  String? _errorMessage;
  late final VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _tabListener = () {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 3) {
        HomeTabController.setUnreadNotifications(false);
        _reloadAll();
      }
    };
    HomeTabController.currentIndex.addListener(_tabListener);
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (!AuthStore.instance.isSignedIn.value) {
      setState(() {
        _items.clear();
        _hasNext = false;
        _nextCursor = null;
        _errorMessage = null;
      });
      return;
    }
    setState(() {
      _items.clear();
      _hasNext = true;
      _nextCursor = null;
      _errorMessage = null;
    });
    await _loadMore();
  }

  Future<void> _reloadAll() async {
    if (!AuthStore.instance.isSignedIn.value) {
      setState(() {
        _items.clear();
        _hasNext = false;
        _nextCursor = null;
        _errorMessage = null;
      });
      return;
    }
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _hasNext = true;
      _nextCursor = null;
      _errorMessage = null;
    });
    try {
      final json = await ApiClient.fetchMyNotifications(
        limit: 20,
        cursor: null,
      );
      final data = (json['data'] as Map<String, dynamic>? ?? const {});
      final itemsJson = (data['notifications'] as List<dynamic>? ??
          data['items'] as List<dynamic>? ??
          []);
      final meta = (data['meta'] as Map<String, dynamic>? ?? const {});
      setState(() {
        _items
          ..clear()
          ..addAll(itemsJson.whereType<Map<String, dynamic>>());
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items.clear();
        _hasNext = false;
        _nextCursor = null;
        _errorMessage = '알림을 불러오지 못했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (!AuthStore.instance.isSignedIn.value) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await ApiClient.markAllNotificationsRead();
      HomeTabController.setUnreadNotifications(false);
      await _reloadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 상태를 업데이트하지 못했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _extractFeedId(Map<String, dynamic> item) {
    String? fromDynamic(dynamic value) {
      if (value is String && value.isNotEmpty) return value;
      return null;
    }

    String? tryMap(dynamic map) {
      if (map is! Map<String, dynamic>) return null;
      return fromDynamic(map['feedId']) ??
          fromDynamic(map['feed_id']) ??
          fromDynamic(map['feedID']) ??
          fromDynamic(map['targetId']) ??
          fromDynamic(map['target_id']) ??
          (map['feed'] is Map<String, dynamic>
              ? fromDynamic((map['feed'] as Map<String, dynamic>)['id'])
              : null);
    }

    final direct = fromDynamic(item['feedId']) ??
        fromDynamic(item['feed_id']) ??
        fromDynamic(item['feedID']) ??
        fromDynamic(item['targetId']) ??
        fromDynamic(item['target_id']) ??
        tryMap(item['data']) ??
        tryMap(item['payload']);
    if (direct != null) return direct;

    final link = (item['link'] as String?) ??
        (item['deepLink'] as String?) ??
        (item['url'] as String?);
    if (link != null && link.isNotEmpty) {
      final match = RegExp(r'/feeds/([^/?#]+)').firstMatch(link);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  String? _extractUserId(Map<String, dynamic> item) {
    String? fromDynamic(dynamic value) {
      if (value is String && value.isNotEmpty) return value;
      return null;
    }

    String? tryMap(dynamic map) {
      if (map is! Map<String, dynamic>) return null;
      return fromDynamic(map['userId']) ??
          fromDynamic(map['user_id']) ??
          fromDynamic(map['actorUserId']) ??
          fromDynamic(map['actor_user_id']) ??
          fromDynamic(map['targetUserId']) ??
          fromDynamic(map['target_user_id']) ??
          fromDynamic(map['fromUserId']) ??
          fromDynamic(map['from_user_id']) ??
          fromDynamic(map['actorId']) ??
          fromDynamic(map['actor_id']) ??
          fromDynamic(map['senderId']) ??
          fromDynamic(map['sender_id']);
    }

    return fromDynamic(item['userId']) ??
        fromDynamic(item['user_id']) ??
        fromDynamic(item['actorUserId']) ??
        fromDynamic(item['actor_user_id']) ??
        fromDynamic(item['targetUserId']) ??
        fromDynamic(item['target_user_id']) ??
        fromDynamic(item['fromUserId']) ??
        fromDynamic(item['from_user_id']) ??
        fromDynamic(item['actorId']) ??
        fromDynamic(item['actor_id']) ??
        fromDynamic(item['senderId']) ??
        fromDynamic(item['sender_id']) ??
        tryMap(item['data']) ??
        tryMap(item['payload']);
  }

  Future<void> _openUserProfile(String userId) async {
    try {
      final user = await ApiClient.fetchUserDetail(userId);
      if (!mounted) return;
      await showProfileModal(context, user: user);
    } catch (_) {
      // ignore profile open failures
    }
  }

  void _showFeedDetail(Feed feed, {bool openComments = false}) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => SizedBox.expand(
        child: Material(
          color: Colors.black,
          child: ProfileFeedDetailView(
            feeds: [feed],
            initialIndex: 0,
            openCommentsOnAppear: openComments,
          ),
        ),
      ),
    );
  }

  Future<void> _openFeedDetail(String feedId) async {
    try {
      final json = await ApiClient.fetchFeedDetail(feedId);
      final feed = Feed.fromJson(json);
      if (!mounted) return;
      _showFeedDetail(feed);
    } catch (_) {
      // ignore detail open failures
    }
  }

  Future<void> _openFeedComments(String feedId) async {
    try {
      final json = await ApiClient.fetchFeedDetail(feedId);
      final feed = Feed.fromJson(json);
      if (!mounted) return;
      _showFeedDetail(feed, openComments: true);
    } catch (_) {
      // ignore detail open failures
    }
  }

  Future<void> _handleItemTap(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_isProcessingTap) return;
    final item = _items[index];
    final readAt = item['readAt'] as String?;
    if (readAt == null) {
      setState(() {
        _items[index] = {
          ...item,
          'readAt': DateTime.now().toIso8601String(),
        };
      });
    }

    setState(() => _isProcessingTap = true);
    try {
    String? link = item['link'] as String?;
    link ??= item['deepLink'] as String?;
    final data = item['data'];
    if (link == null && data is Map<String, dynamic>) {
      link = data['link'] as String? ?? data['url'] as String?;
    }

    if (link != null && link.isNotEmpty) {
      await NotificationRouter.routeByLink(link);
      return;
    }

    final template = item['template'] as String?;
    final body = (item['body'] as String?) ?? (item['content'] as String?) ?? '';
    if (template == null || template.isEmpty) {
      if (body.contains('좋아요')) {
        final feedId = _extractFeedId(item);
        if (feedId != null && feedId.isNotEmpty) {
          await _openFeedDetail(feedId);
        }
      }
      if (body.contains('댓글')) {
        final feedId = _extractFeedId(item);
        if (feedId != null && feedId.isNotEmpty) {
          await _openFeedComments(feedId);
        }
      }
      if (body.contains('팔로우')) {
        final userId = _extractUserId(item);
        if (userId != null && userId.isNotEmpty) {
          await _openUserProfile(userId);
        }
      }
      return;
    }
    if (template == 'FEED_LIKED') {
      final feedId = _extractFeedId(item);
      if (feedId != null && feedId.isNotEmpty) {
        await _openFeedDetail(feedId);
        return;
      }
      HomeTabController.switchTo(1);
      return;
    }
    if (template == 'NEW_COMMENT') {
      final feedId = _extractFeedId(item);
      if (feedId != null && feedId.isNotEmpty) {
        await _openFeedComments(feedId);
        return;
      }
      HomeTabController.switchTo(1);
      return;
    }
    if (template == 'NEW_FOLLOW' ||
        template == 'FOLLOWED' ||
        template == 'FOLLOWED_BY' ||
        template == 'NEW_FOLLOWER') {
      final userId = _extractUserId(item);
      if (userId != null && userId.isNotEmpty) {
        await _openUserProfile(userId);
        return;
      }
    }
    if (template == 'NEW_COMMENT' ||
        template == 'FEED_LIKED' ||
        template == 'NEW_FEED') {
      HomeTabController.switchTo(1);
      return;
    }
    if (template.contains('SPACE')) {
      HomeTabController.switchTo(0);
      return;
    }
    } finally {
      if (mounted) setState(() => _isProcessingTap = false);
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _reloadAll();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadMore() async {
    if (!AuthStore.instance.isSignedIn.value) return;
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final json = await ApiClient.fetchMyNotifications(
        limit: 20,
        cursor: _nextCursor,
      );
      final data = (json['data'] as Map<String, dynamic>? ?? const {});
      final itemsJson = (data['notifications'] as List<dynamic>? ??
          data['items'] as List<dynamic>? ??
          []);
      final meta = (data['meta'] as Map<String, dynamic>? ?? const {});
      setState(() {
        _items.addAll(itemsJson.whereType<Map<String, dynamic>>());
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasNext = false;
        _errorMessage = '알림을 불러오지 못했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: CommonNavigationView(
                title: '알림',
                right: _items.isEmpty
                    ? const SizedBox(width: 72, height: 44)
                    : const SizedBox(
                        width: 72,
                        height: 44,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '모두 읽음',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                      ),
                onRightTap: _items.isEmpty ? null : _markAllRead,
                // left: const Icon(
                //   PhosphorIconsRegular.caretLeft,
                //   size: 24,
                //   color: Colors.black,
                // ),
                // onLeftTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  _items.isEmpty && _isLoading
                      ? const Center(
                          child: CommonActivityIndicator(size: 24),
                        )
                      : _items.isEmpty
                          ? CommonEmptyView(
                              message: _errorMessage ??
                                  (AuthStore.instance.isSignedIn.value
                                      ? '알림이 없습니다.'
                                      : '로그인 후 알림을 확인할 수 있습니다.'),
                              showButton: false,
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (!_isLoading &&
                                    _hasNext &&
                                    notification.metrics.extentAfter == 0) {
                                  _loadMore();
                                }
                                return false;
                              },
                              child: CommonRefreshView(
                                onRefresh: _handleRefresh,
                                topPadding: 12,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: _items.length +
                                      (_isLoading && _items.isNotEmpty ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= _items.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: CommonActivityIndicator(size: 24),
                                        ),
                                      );
                                    }
                                    return NotificationListItemView(
                                      item: _items[index],
                                      onTap: () => _handleItemTap(index),
                                    );
                                  },
                                ),
                              ),
                            ),
                ],
              ),
            ),
          ],
        ),
        if (_isProcessingTap)
          Positioned.fill(
            child: const Center(
              child: CommonActivityIndicator(size: 24),
            ),
          ),
      ],
    );
  }
}
