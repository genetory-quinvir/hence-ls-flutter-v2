import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/auth/auth_store.dart';
import '../../common/widgets/common_profile_view.dart';
import '../../common/widgets/common_inkwell.dart';
import '../../common/widgets/common_rounded_button.dart';
import '../../profile_edit/profile_edit_view.dart';
import 'profile_activity_info_view.dart';
import 'profile_feed_list_item_view.dart';
import '../../common/network/api_client.dart';
import '../../feed_list/models/feed_models.dart';
import '../../common/widgets/common_activity.dart';
import 'profile_participant_list_item_view.dart';
import '../../common/widgets/common_empty_view.dart';

class ProfileSignedView extends StatelessWidget {
  const ProfileSignedView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: _ProfileUserSection()),
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
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
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
                      Tab(text: '참여 스페이스'),
                      Tab(text: '기록'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            const _ProfileFeedGrid(
              emptyMessage: '현재 피드가 없습니다.',
              emptyButtonText: '피드 작성하기',
            ),
            const _ProfileParticipantList(),
            const CommonEmptyView(
              message: '기록이 없습니다.',
              buttonText: '기록하기',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileUserSection extends StatefulWidget {
  const _ProfileUserSection();

  @override
  State<_ProfileUserSection> createState() => _ProfileUserSectionState();
}

class _ProfileUserSectionState extends State<_ProfileUserSection> {
  bool _expanded = false;
  bool _showToggle = false;

  String? _providerIconAsset(String? provider) {
    switch (provider?.toLowerCase()) {
      case 'naver':
        return 'lib/assets/images/icon_naver.svg';
      case 'kakao':
        return 'lib/assets/images/icon_kakao.svg';
      case 'google':
        return 'lib/assets/images/icon_google.svg';
      case 'apple':
        return 'lib/assets/images/icon_apple.svg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.currentUser,
      builder: (context, user, _) {
        final introduction =
            (user?.introduction?.trim().isNotEmpty ?? false)
                ? user!.introduction!.trim()
                : '';
        return ValueListenableBuilder<String?>(
          valueListenable: AuthStore.instance.lastProvider,
          builder: (context, provider, _) {
            final nickname = (user?.nickname.trim().isNotEmpty ?? false) ? user!.nickname : '사용자';
            final email = (user?.email?.trim().isNotEmpty ?? false) ? user!.email! : '';
            // final effectiveProvider =
                // (user?.provider?.trim().isNotEmpty ?? false) ? user!.provider : provider;
            // final providerIcon = _providerIconAsset(effectiveProvider);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CommonProfileView(
                        networkUrl: user?.profileImageUrl,
                        size: 56,
                        placeholder: Container(
                          color: const Color(0xFFF2F2F2),
                          alignment: Alignment.center,
                          child: const Icon(
                            PhosphorIconsRegular.user,
                            size: 24,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Row(
                              children: [
                                // if (providerIcon != null) ...[
                                //   SvgPicture.asset(
                                //     providerIcon,
                                //     width: 16,
                                //     height: 16,
                                //   ),
                                //   const SizedBox(width: 4),
                                // ],
                                Expanded(
                                  child: Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF8E8E8E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 50,
                        child: CommonRoundedButton(
                          title: '편집',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProfileEditView()),
                            );
                          },
                          height: 32,
                          radius: 8,
                          backgroundColor: const Color(0xFFF5F5F5),
                          textColor: Colors.black,
                          textStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (introduction.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final painter = TextPainter(
                          text: TextSpan(
                            text: introduction,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[800],
                            ),
                          ),
                          maxLines: 4,
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: constraints.maxWidth);
                        final didOverflow = painter.didExceedMaxLines;
                        if (_showToggle != didOverflow) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _showToggle = didOverflow);
                            }
                          });
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              introduction,
                              maxLines: _expanded ? null : 4,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (_showToggle)
                              CommonInkWell(
                                onTap: () {
                                  setState(() => _expanded = !_expanded);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _expanded ? '접기' : '더보기',
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
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
                  'lib/assets/images/levels/icon_level_$clampedLevel.svg',
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
  const _ProfileParticipantList();

  @override
  State<_ProfileParticipantList> createState() => _ProfileParticipantListState();
}

class _ProfileParticipantListState extends State<_ProfileParticipantList> {
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

  Future<void> _loadMore() async {
    if (_isLoading || !_hasNext) return;
    setState(() => _isLoading = true);
    try {
      final json = await ApiClient.fetchMySpaceParticipants(
        limit: 20,
        cursor: _nextCursor,
      );
      final data = (json['data'] as Map<String, dynamic>? ?? const {});
      final itemsJson = (data['spaces'] as List<dynamic>? ??
          data['participants'] as List<dynamic>? ??
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
    if (_items.isEmpty && _isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CommonActivityIndicator(size: 24),
        ),
      );
    }
    if (_items.isEmpty) {
      return const CommonEmptyView(
        message: '참여한 스페이스가 없습니다.',
        buttonText: '스페이스 둘러보기',
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _items[index];
                final title = (item['title'] as String?) ??
                    (item['spaceTitle'] as String?) ??
                    (item['name'] as String?) ??
                    '라이브스페이스';
                final subtitle = (item['placeName'] as String?) ??
                    (item['address'] as String?) ??
                    (item['location'] as String?) ??
                    '';
                final thumbnail = (item['thumbnail'] as String?) ??
                    (item['thumbnailUrl'] as String?) ??
                    (item['imageUrl'] as String?) ??
                    '';
                final fallbackUrl = (item['fileUrl'] as String?) ??
                    (item['image'] as String?) ??
                    '';
                return Column(
                  children: [
                    ProfileParticipantListItemView(
                      title: title,
                      subtitle: subtitle,
                      thumbnailUrl: thumbnail,
                      fallbackUrl: fallbackUrl,
                    ),
                    if (index != _items.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE0E0E0),
                      ),
                  ],
                );
              },
              childCount: _items.length,
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
  }
}
class _ProfileFeedGrid extends StatefulWidget {
  const _ProfileFeedGrid({
    super.key,
    required this.emptyMessage,
    required this.emptyButtonText,
  });

  final String emptyMessage;
  final String emptyButtonText;

  @override
  State<_ProfileFeedGrid> createState() => _ProfileFeedGridState();
}

class _ProfileFeedGridState extends State<_ProfileFeedGrid> {
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
      final json = await ApiClient.fetchMyFeeds(
        limit: 20,
        cursor: _nextCursor,
      );
      final data = (json['data'] as Map<String, dynamic>? ?? const {});
      final feedsJson = (data['feeds'] as List<dynamic>? ?? []);
      final newFeeds = feedsJson
          .whereType<Map<String, dynamic>>()
          .map(Feed.fromJson)
          .toList();
      final meta = (data['meta'] as Map<String, dynamic>? ?? const {});
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
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_feeds.isEmpty) {
      return CommonEmptyView(
        message: widget.emptyMessage,
        buttonText: widget.emptyButtonText,
        onTap: () {},
      );
    }
    final itemCount = _feeds.length + (_isLoading && _feeds.isNotEmpty ? 1 : 0);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_isLoading &&
            _hasNext &&
            notification.metrics.extentAfter == 0) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(1, 1, 1, 1),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final feed = _feeds[index];
                  final url = feed.images.isNotEmpty ? feed.images.first.cdnUrl : null;
                  return ProfileFeedListItemView(
                    imageUrl: url ?? '',
                  );
                },
                childCount: _feeds.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
                childAspectRatio: 1,
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
  }
}
