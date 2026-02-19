import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_profile_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/network/api_client.dart';
import '../common/auth/auth_store.dart';
import '../profile/models/follow_user.dart';
import '../profile/models/profile_display_user.dart';
import '../profile_info/profile_info_view.dart';
import 'package:flutter/cupertino.dart';

class FollowListView extends StatefulWidget {
  const FollowListView({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<FollowListView> createState() => _FollowListViewState();
}

class _FollowListViewState extends State<FollowListView> {
  final List<FollowUser> _users = [];
  final Set<String> _togglingUserIds = <String>{};
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
      final json = await ApiClient.fetchFollowers(
        userId: widget.userId,
        limit: 20,
        cursor: _nextCursor,
      );
      final data = json['data'];
      final root = data is Map<String, dynamic>
          ? data
          : json;
      final listJson = (root['followers'] as List<dynamic>? ??
          root['users'] as List<dynamic>? ??
          root['items'] as List<dynamic>? ??
          const []);
      final newUsers = listJson
          .whereType<Map<String, dynamic>>()
          .map(FollowUser.fromJson)
          .toList();
      final meta = (root['meta'] as Map<String, dynamic>? ?? const {});
      setState(() {
        _users.addAll(newUsers);
        _nextCursor = meta['nextCursor'] as String?;
        _hasNext = (meta['hasNext'] as bool?) ?? false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(FollowUser user) async {
    if (_togglingUserIds.contains(user.id)) return;
    final index = _users.indexWhere((item) => item.id == user.id);
    if (index < 0) return;
    final previous = _users[index];
    final nextFollowing = !previous.isFollowing;
    setState(() {
      _togglingUserIds.add(user.id);
      _users[index] = previous.copyWith(isFollowing: nextFollowing);
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
        _users[index] = previous;
      });
    } finally {
      if (mounted) {
        setState(() {
          _togglingUserIds.remove(user.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          CommonNavigationView(
            title: '팔로워',
            left: const Icon(
              PhosphorIconsRegular.caretLeft,
              size: 24,
              color: Colors.black,
            ),
            onLeftTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: _users.isEmpty && _isLoading
                ? const Center(
                    child: CommonActivityIndicator(size: 32, color: Colors.black),
                  )
                : _users.isEmpty
                    ? const CommonEmptyView(
                        message: '팔로워가 없습니다.',
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
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _users.length + (_isLoading ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                            final isMe = AuthStore.instance.currentUser.value?.id == user.id;
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
                                    placeholder: const ColoredBox(
                                      color: Color(0xFFF2F2F2),
                                      child: Center(
                                        child: Icon(
                                          PhosphorIconsRegular.user,
                                          size: 18,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
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
                                  if (!isMe) ...[
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 64,
                                      child: CommonRoundedButton(
                                        title: user.isFollowing ? '팔로잉' : '팔로우',
                                        onTap: _togglingUserIds.contains(user.id)
                                            ? null
                                            : () => _toggleFollow(user),
                                        height: 32,
                                        radius: 8,
                                        backgroundColor: user.isFollowing
                                            ? const Color(0xFFF2F2F2)
                                            : Colors.black,
                                        textColor: user.isFollowing
                                            ? Colors.black
                                            : Colors.white,
                                        textStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 12,
                                          color: user.isFollowing
                                              ? Colors.black
                                              : Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          ],
        ),
      ),
    );
  }
}
