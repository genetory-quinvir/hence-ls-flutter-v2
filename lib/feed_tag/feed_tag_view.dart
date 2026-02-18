import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/widgets/common_feed_list_item_view.dart';
import '../common/widgets/common_empty_view.dart';
import '../feed_list/models/feed_models.dart';
import '../profile/profile_feed_detail_view.dart';

class FeedTagView extends StatefulWidget {
  const FeedTagView({
    super.key,
    required this.tag,
  });

  final String tag;

  @override
  State<FeedTagView> createState() => _FeedTagViewState();
}

class _FeedTagViewState extends State<FeedTagView> {
  final List<Feed> _feeds = [];
  bool _isLoading = false;
  bool _hasNext = true;
  String? _nextCursor;
  String _selectedSort = '최신순';
  static const List<String> _sorts = <String>['최신순', '인기순'];

  String get _normalizedTag {
    final raw = widget.tag.trim();
    return raw.startsWith('#') ? raw.substring(1) : raw;
  }

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
        orderBy: _orderBy,
        limit: 20,
        cursor: _nextCursor,
        hashtags: [_normalizedTag],
      );
      final data = json['data'];
      dynamic feedsRaw = data;
      if (feedsRaw is Map<String, dynamic>) {
        feedsRaw = feedsRaw['feeds'] ??
            feedsRaw['items'] ??
            feedsRaw['list'] ??
            feedsRaw['data'];
        if (feedsRaw is Map) {
          feedsRaw =
              feedsRaw['items'] ?? feedsRaw['feeds'] ?? feedsRaw['list'] ?? [];
        }
      }
      final feedsJson = feedsRaw is List ? feedsRaw : const [];
      final newFeeds = feedsJson
          .whereType<Map>()
          .map((item) => Feed.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final meta = (data is Map<String, dynamic> ? data['meta'] : null) ??
          (json['meta'] as Map<String, dynamic>?) ??
          const {};
      setState(() {
        _feeds.addAll(newFeeds);
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasNext = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _orderBy => _selectedSort == '인기순' ? 'popular' : 'latest';

  @override
  Widget build(BuildContext context) {
    final title = '#$_normalizedTag';
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: CommonNavigationView(
                left: const Icon(
                  PhosphorIconsRegular.caretLeft,
                  size: 24,
                  color: Colors.black,
                ),
                title: title,
                onLeftTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildSortBar(),
                  Expanded(
                    child: CommonRefreshView(
                      onRefresh: _loadInitial,
                      topPadding: 12,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.extentAfter == 0) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: _feeds.isEmpty && !_isLoading
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 24),
                                children: const [
                                  SizedBox(height: 120),
                                  CommonEmptyView(
                                    message: '피드가 없습니다.',
                                    showButton: false,
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _feeds.length + (_hasNext ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _feeds.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final feed = _feeds[index];
                                  return CommonFeedListItemView(
                                    feed: feed,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ProfileFeedDetailView(
                                            feeds: _feeds,
                                            initialIndex: index,
                                            onFeedUpdated: (updated) {
                                              final idx = _feeds.indexWhere(
                                                (f) => f.id == updated.id,
                                              );
                                              if (idx < 0) return;
                                              setState(() => _feeds[idx] = updated);
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      height: 40,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Spacer(),
            ...List.generate(_sorts.length, (index) {
              final label = _sorts[index];
              final selected = _selectedSort == label;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0)
                    Container(
                      width: 1,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: const Color(0x33000000),
                    ),
                  GestureDetector(
                    onTap: () {
                      if (_selectedSort == label) return;
                      setState(() {
                        _selectedSort = label;
                        _feeds.clear();
                        _hasNext = true;
                        _nextCursor = null;
                      });
                      _loadMore();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.black : const Color(0x88000000),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
