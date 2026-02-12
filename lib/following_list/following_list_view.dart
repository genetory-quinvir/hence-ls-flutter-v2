import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_profile_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/network/api_client.dart';
import '../profile/models/follow_user.dart';
import '../profile/models/profile_display_user.dart';
import '../profile_info/profile_info_view.dart';
import 'package:flutter/cupertino.dart';

class FollowingListView extends StatefulWidget {
  const FollowingListView({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<FollowingListView> createState() => _FollowingListViewState();
}

class _FollowingListViewState extends State<FollowingListView> {
  final List<FollowUser> _users = [];
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
      _users.clear();
      _hasNext = true;
      _nextCursor = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final json = await ApiClient.fetchFollowing(
        userId: widget.userId,
        limit: 20,
        cursor: _nextCursor,
      );
      final data = (json['data'] as Map<String, dynamic>? ?? const {});
      final listJson = (data['following'] as List<dynamic>? ??
          data['users'] as List<dynamic>? ??
          data['items'] as List<dynamic>? ??
          const []);
      final newUsers = listJson
          .whereType<Map<String, dynamic>>()
          .map(FollowUser.fromJson)
          .toList();
      final meta = (data['meta'] as Map<String, dynamic>? ?? const {});
      setState(() {
        _users.addAll(newUsers);
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          CommonNavigationView(
            title: '팔로잉',
            left: CommonInkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Icon(PhosphorIconsRegular.caretLeft, size: 24, color: Colors.black),
            ),
          ),
          Expanded(
            child: _users.isEmpty && _isLoading
                ? const Center(
                    child: CommonActivityIndicator(size: 32, color: Colors.black),
                  )
                : _users.isEmpty
                    ? const CommonEmptyView(
                        message: '팔로잉이 없습니다.',
                        buttonText: '닫기',
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
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _users.length + (_isLoading ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index >= _users.length) {
                              return const Center(
                                child: CommonActivityIndicator(
                                  size: 24,
                                  color: Colors.black,
                                ),
                              );
                            }
                            final user = _users[index];
                            final name = user.nickname.isNotEmpty
                                ? user.nickname
                                : (user.name ?? '사용자');
                            return CommonInkWell(
                              onTap: () {
                                final displayUser = ProfileDisplayUser(
                                  id: user.id,
                                  nickname: user.nickname,
                                  profileImageUrl: user.profileImageUrl,
                                );
                                showCupertinoModalPopup(
                                  context: context,
                                  builder: (_) => SizedBox.expand(
                                    child: ProfileInfoView(user: displayUser),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  CommonProfileView(
                                    networkUrl: user.profileImageUrl,
                                    size: 40,
                                    placeholder: Container(
                                      color: const Color(0xFFF2F2F2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
