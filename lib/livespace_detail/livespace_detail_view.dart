import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/network/api_client.dart';
import '../common/auth/auth_store.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_login_guard.dart';
import '../common/widgets/common_profile_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/utils/time_format.dart';
import 'widgets/livespace_detail_profile_view.dart';
import 'widgets/livespace_detail_info_view.dart';
import 'widgets/livespace_detail_content_view.dart';
import '../feed_comment/feed_comment_view.dart';
import '../feed_comment/models/feed_comment_model.dart';

class LivespaceDetailView extends StatefulWidget {
  const LivespaceDetailView({
    super.key,
    required this.space,
  });

  final Map<String, dynamic> space;

  @override
  State<LivespaceDetailView> createState() => _LivespaceDetailViewState();
}

class _LivespaceDetailViewState extends State<LivespaceDetailView> {
  late Map<String, dynamic> _space;
  bool _isLoading = false;
  bool _isLoadingComments = false;
  bool _isCheckingIn = false;
  bool _hasCheckedIn = false;
  int _commentCount = 0;
  List<FeedCommentItem> _commentPreview = const [];

  @override
  void initState() {
    super.initState();
    _space = Map<String, dynamic>.from(widget.space);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final feedId = _extractFeedId(_space);
    if (feedId == null || feedId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final detail = await ApiClient.fetchFeedDetail(feedId);
      if (!mounted) return;
      setState(() {
        _space = detail;
        _commentCount = (detail['commentCount'] as num?)?.toInt() ?? 0;
        _hasCheckedIn = _isCurrentUserCheckedIn(
          detail['checkinUsers'] is List ? detail['checkinUsers'] as List : const [],
        );
      });
      await _loadCommentPreview(feedId);
    } catch (_) {
      // ignore for now, keep initial data
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCommentPreview(String feedId) async {
    if (_isLoadingComments) return;
    setState(() => _isLoadingComments = true);
    try {
      final page = await ApiClient.fetchFeedComments(
        feedId: feedId,
        limit: 5,
      );
      if (!mounted) return;
      setState(() {
        _commentPreview = page.comments;
        if (page.totalCount != null) {
          _commentCount = page.totalCount!;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentPreview = const []);
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _handleCheckin() async {
    if (_isCheckingIn) return;
    final feedId = _extractFeedId(_space);
    if (feedId == null || feedId.isEmpty) return;
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '체크인하려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() => _isCheckingIn = true);
    try {
      await ApiClient.checkinFeed(feedId);
      if (!mounted) return;
      final currentUser = AuthStore.instance.currentUser.value;
      final userId = currentUser?.id ?? '';
      final nextUsers = List<dynamic>.from(
        _space['checkinUsers'] is List ? _space['checkinUsers'] as List : const [],
      );
      if (userId.isNotEmpty &&
          !nextUsers.any((u) => _extractUserId(u) == userId)) {
        nextUsers.insert(0, {
          'userId': userId,
          'profileImageUrl': currentUser?.profileImageUrl,
          'nickname': currentUser?.nickname,
        });
      }
      setState(() {
        _hasCheckedIn = true;
        _space = {
          ..._space,
          'checkinUsers': nextUsers,
          'checkinCount': nextUsers.length,
          'participantCount': nextUsers.length,
        };
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isReady = !_isLoading && !_isLoadingComments;
    final title = (_space['title'] as String?) ??
        (_space['spaceTitle'] as String?) ??
        (_space['name'] as String?) ??
        '라이브 스페이스';
    final imageUrls = _extractImageUrls(_space);
    final thumbnail = imageUrls.isNotEmpty ? imageUrls.first : '';
    final user = _space['user'] is Map<String, dynamic>
        ? _space['user'] as Map<String, dynamic>
        : _space['author'] is Map<String, dynamic>
            ? _space['author'] as Map<String, dynamic>
            : _space['creator'] is Map<String, dynamic>
                ? _space['creator'] as Map<String, dynamic>
                : _space['host'] is Map<String, dynamic>
                    ? _space['host'] as Map<String, dynamic>
                    : null;
    final profileImageUrl = _extractProfileImageUrl(user?['profileImage']) ??
        _stringOrEmpty(user?['profileImageUrl']) ??
        _stringOrEmpty(user?['thumbnailUrl']) ??
        _stringOrEmpty(user?['avatarUrl']);
    final nickname = _stringOrEmpty(user?['nickname']) ??
        '-';
    final userId = _stringOrEmpty(user?['userId']) ??
        _stringOrEmpty(user?['id']) ??
        '';
    final place = _stringOrEmpty(_space['placeName']) ??
        '-';
    final time = _formatTime(
      _stringOrEmpty(_space['time']) ??
          _stringOrEmpty(_space['startAt']) ??
          _stringOrEmpty(_space['startTime']) ??
          _stringOrEmpty(_space['date']) ??
          _stringOrEmpty(_space['createdAt']),
    );
    final status = _stringOrEmpty(_space['status']) ??
        _stringOrEmpty(_space['liveStatus']) ??
        _stringOrEmpty(_space['state']) ??
        '-';
    final content = _stringOrEmpty(_space['content']) ?? '';
    if (_commentCount == 0) {
      _commentCount = (_space['commentCount'] as num?)?.toInt() ?? 0;
    }
    final checkinUsers = _space['checkinUsers'] is List
        ? _space['checkinUsers'] as List
        : const [];
    final hasCheckedIn = _hasCheckedIn || _isCurrentUserCheckedIn(checkinUsers);
    final participantCount =
        checkinUsers.length > 0
            ? checkinUsers.length
            : (_space['participantCount'] as num?)?.toInt() ??
                (_space['participantsCount'] as num?)?.toInt() ??
                (_space['checkinCount'] as num?)?.toInt() ??
                (_space['checkins'] as num?)?.toInt() ??
                0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          AnimatedOpacity(
            opacity: isReady ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !isReady,
              child: Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        automaticallyImplyLeading: false,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        pinned: false,
                        stretch: true,
                        expandedHeight: 385,
                        collapsedHeight: 385,
                        toolbarHeight: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          stretchModes: const [
                            StretchMode.zoomBackground,
                          ],
                          background: LivespaceDetailProfileView(
                            title: title,
                            imageUrls:
                                imageUrls.isNotEmpty ? imageUrls : [thumbnail],
                            profileImageUrl: profileImageUrl,
                            nickname: nickname,
                            userId: userId,
                            participantCount: participantCount,
                            checkinUsers: checkinUsers,
                            isCheckedIn: hasCheckedIn,
                            isCheckingIn: _isCheckingIn,
                            onCheckinTap: _handleCheckin,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: LivespaceDetailInfoView(
                          title: title,
                          place: place,
                          time: time,
                          status: status,
                          profileImageUrl: profileImageUrl,
                          nickname: nickname,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: _SectionDivider(),
                      ),
                      SliverToBoxAdapter(
                        child: LivespaceDetailContentView(
                          content: content,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: _SectionDivider(),
                      ),
                      SliverToBoxAdapter(
                        child: _LivespaceDetailCommentsSection(
                          commentCount: _commentCount,
                          comments: _commentPreview,
                          isLoading: _isLoadingComments,
                          onViewAll: () {
                            final feedId = _extractFeedId(_space);
                            if (feedId == null || feedId.isEmpty) return;
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (_) => FeedCommentView(
                                feedId: feedId,
                                spaceId: null,
                                comments: const [],
                                initialTotalCount: _commentCount,
                                onCommentAdded: () {
                                  if (!mounted) return;
                                  setState(() => _commentCount += 1);
                                  _loadCommentPreview(feedId);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              (hasCheckedIn ? 24.0 : (24 + 50 + 16)) +
                                  safeBottom,
                        ),
                      ),
                    ],
                  ),
                  SafeArea(
                    bottom: false,
                    child: CommonNavigationView(
                      backgroundColor: Colors.transparent,
                      left: const Icon(
                        PhosphorIconsRegular.caretLeft,
                        size: 24,
                        color: Colors.white,
                      ),
                      onLeftTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  if (!hasCheckedIn)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + safeBottom),
                        child: CommonRoundedButton(
                          title: '체크인하기',
                          onTap: _isCheckingIn ? null : _handleCheckin,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!isReady)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String? _stringOrEmpty(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      final name = value['name'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
      final address = value['address'];
      if (address is String && address.trim().isNotEmpty) {
        return address.trim();
      }
    }
    return value.toString();
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${parsed.year}.${two(parsed.month)}.${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  static String? _extractProfileImageUrl(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return _stringOrEmpty(raw['cdnUrl']) ??
          _stringOrEmpty(raw['fileUrl']) ??
          _stringOrEmpty(raw['thumbnailUrl']);
    }
    return null;
  }

  static String? _extractFeedId(Map<String, dynamic> space) {
    final direct = space['feedId'] ?? space['id'] ?? space['entityId'];
    if (direct is String && direct.isNotEmpty) return direct;
    final feed = space['feed'];
    if (feed is Map<String, dynamic>) {
      final nested = feed['id'] ?? feed['feedId'];
      if (nested is String && nested.isNotEmpty) return nested;
    }
    return null;
  }

  bool _isCurrentUserCheckedIn(List<dynamic> users) {
    final currentUserId = AuthStore.instance.currentUser.value?.id;
    if (currentUserId == null || currentUserId.isEmpty) return false;
    return users.any((user) => _extractUserId(user) == currentUserId);
  }

  String? _extractUserId(dynamic user) {
    if (user is Map<String, dynamic>) {
      final id = user['userId'] ?? user['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  static List<String> _extractImageUrls(Map<String, dynamic> space) {
    final urls = <String>[];
    final imagesRaw = space['images'];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is String) {
          if (item.trim().isNotEmpty) urls.add(item.trim());
        } else if (item is Map<String, dynamic>) {
          final url = item['cdnUrl'] as String? ??
              item['fileUrl'] as String? ??
              item['thumbnailUrl'] as String?;
          if (url != null && url.trim().isNotEmpty) {
            urls.add(url.trim());
          }
        }
      }
    }
    final thumbRaw = space['thumbnail'];
    if (thumbRaw is String && thumbRaw.trim().isNotEmpty) {
      urls.add(thumbRaw.trim());
    } else if (thumbRaw is Map<String, dynamic>) {
      final url = thumbRaw['cdnUrl'] as String? ??
          thumbRaw['fileUrl'] as String? ??
          thumbRaw['thumbnailUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        urls.add(url.trim());
      }
    }
    final fallback = space['thumbnailUrl'] as String? ??
        space['imageUrl'] as String?;
    if (fallback != null && fallback.trim().isNotEmpty) {
      urls.add(fallback.trim());
    }
    final deduped = <String>[];
    for (final url in urls) {
      if (!deduped.contains(url)) deduped.add(url);
    }
    return deduped;
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      color: const Color(0xFFF5F5F5),
    );
  }
}

class _LivespaceDetailCommentsSection extends StatelessWidget {
  const _LivespaceDetailCommentsSection({
    required this.commentCount,
    required this.comments,
    required this.isLoading,
    required this.onViewAll,
  });

  final int commentCount;
  final List<FeedCommentItem> comments;
  final bool isLoading;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    const minBodyHeight = 120.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '댓글',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minBodyHeight),
            child: Builder(
              builder: (_) {
                if (isLoading) {
                  return const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (comments.isEmpty) {
                  return Center(
                    child: CommonEmptyView(
                      message: '아직 댓글이 없어요.',
                      buttonText: '첫 댓글 작성하기',
                      onTap: onViewAll,
                    ),
                  );
                }
                return Column(
                  children: [
                    ...comments.map((comment) {
                      final time = formatRelativeTime(comment.createdAt);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CommonProfileView(
                              size: 26,
                              networkUrl: comment.authorProfileUrl,
                              placeholder: const ColoredBox(
                                color: Color(0xFFF2F2F2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.authorName.isNotEmpty
                                            ? comment.authorName
                                            : '익명',
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment.content,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CommonRoundedButton(
                        title: '전체 댓글 보기',
                        height: 50,
                        radius: 10,
                        onTap: onViewAll,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
