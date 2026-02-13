import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/state/home_tab_controller.dart';
import 'widgets/notification_list_item_view.dart';

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
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
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: CommonNavigationView(
            title: '알림',
            right: const Text(
              '모두 읽음',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
            onRightTap: _markAllRead,
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
                          buttonText: '새로고침',
                          onTap: _loadInitial,
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
                          child: RefreshIndicator(
                            onRefresh: _handleRefresh,
                            color: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            strokeWidth: 0.01,
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
                                );
                              },
                            ),
                          ),
                        ),
              if (_isRefreshing && _items.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CommonActivityIndicator(
                      size: 20,
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
