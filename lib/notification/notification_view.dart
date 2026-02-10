import 'package:flutter/material.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_inkwell.dart';
import 'widgets/notification_list_item_view.dart';

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: _NotificationBody(),
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
  bool _hasNext = true;
  String? _nextCursor;

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

  Future<void> _reloadAll() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _hasNext = true;
      _nextCursor = null;
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await ApiClient.markAllNotificationsRead();
      await _reloadAll();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
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
            right: CommonInkWell(
              onTap: _markAllRead,
              child: const Text(
                '모두 읽음',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111111),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _items.isEmpty && _isLoading
              ? const Center(
                  child: CommonActivityIndicator(size: 24),
                )
                  : _items.isEmpty
                  ? CommonEmptyView(
                      message: '알림이 없습니다.',
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
                        onRefresh: _reloadAll,
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
        ),
      ],
    );
  }
}
