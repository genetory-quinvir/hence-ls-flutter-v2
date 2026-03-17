import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../common/auth/auth_store.dart';
import '../../common/auth/auth_models.dart';
import '../../common/widgets/common_inkwell.dart';
import 'profile_feed_list_item_view.dart';
import 'profile_user_section.dart';
import '../../common/network/api_client.dart';
import '../../feed_list/models/feed_models.dart';
import '../../common/widgets/common_activity.dart';
import '../../common/widgets/common_image_view.dart';
import '../../common/widgets/common_livespace_list_item_view.dart';
import '../../common/widgets/common_empty_view.dart';
import '../../common/widgets/common_place_list_item_view.dart';
import '../../common/widgets/common_refresh_view.dart';
import '../../placebook_detail/placebook_detail_view.dart';
import '../../placebook_list/placebook_list_view.dart';
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
    return CommonRefreshView(
      onRefresh: () => _refreshProfileInfo(force: true),
      topPadding: 0,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: _headerKey,
              child: _ProfileHeaderUserSection(
                refreshSignal: _headerRefreshSignal,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(
            child: _ProfileActivitySummarySection(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _ProfileActivitySummarySection extends StatelessWidget {
  const _ProfileActivitySummarySection();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileActivityData>(
      future: _loadActivityData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final user = data?.user;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내 활동 요약',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '프로필 정보를 바탕으로 요약했어요',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 12),
              _buildActivitySummaryCard(
                text: _buildActivitySummarySpans(
                  user,
                  isLoading: isLoading,
                  topThemes: data?.topThemes ?? const [],
                ),
                isLoading: isLoading,
              ),
              const SizedBox(height: 32),
              _buildRecentPlaceSection(
                context: context,
                title: '가장 최근 저장한 장소',
                items: data?.recentSaved ?? const [],
                isLoading: isLoading,
                favorited: false,
              ),
              const SizedBox(height: 32),
              _buildRecentPlaceSection(
                context: context,
                title: '가장 최근 찜한 장소',
                items: data?.recentFavorites ?? const [],
                isLoading: isLoading,
                favorited: true,
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<_ProfileActivityData> _loadActivityData() async {
    final results = await Future.wait([
      ApiClient.fetchMe(),
      ApiClient.fetchPlacebookCreatedPlacesList(
        limit: 50,
        orderBy: 'createdAt',
        order: 'desc',
      ),
      ApiClient.fetchPlacebookFavoritePlacesList(
        limit: 3,
        orderBy: 'createdAt',
        order: 'desc',
      ),
    ]);
    final user = results[0] as AuthUser;
    final createdAll =
        _extractPlaceListItems(results[1] as Map<String, dynamic>);
    final created = createdAll.take(3).toList(growable: false);
    final favorites =
        _extractPlaceListItems(results[2] as Map<String, dynamic>);
    final topThemes = _extractTopThemes(createdAll, maxCount: 3);
    return _ProfileActivityData(
      user: user,
      recentSaved: created,
      recentFavorites: favorites,
      topThemes: topThemes,
    );
  }

  static Widget _buildActivitySummaryCard({
    required TextSpan text,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isLoading
          ? const CommonActivityIndicator(size: 20)
          : RichText(text: text),
    );
  }

  static List<Map<String, dynamic>> _extractPlaceListItems(
    Map<String, dynamic> response,
  ) {
    List<Map<String, dynamic>> asList(dynamic raw) {
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    }

    final direct = asList(response['items']);
    if (direct.isNotEmpty) return direct;

    final data = response['data'];
    if (data is List) {
      final list = asList(data);
      if (list.isNotEmpty) return list;
    } else if (data is Map<String, dynamic>) {
      final items = asList(
        data['items'] ?? data['places'] ?? data['favorites'] ?? data['data'],
      );
      if (items.isNotEmpty) return items;
      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        final nestedItems =
            asList(nested['items'] ?? nested['places'] ?? nested['favorites']);
        if (nestedItems.isNotEmpty) return nestedItems;
      }
    }

    final fallback = asList(response['places'] ?? response['favorites']);
    if (fallback.isNotEmpty) return fallback;
    return const [];
  }

  static List<String> _extractTopThemes(
    List<Map<String, dynamic>> items, {
    required int maxCount,
  }) {
    final counts = <String, int>{};
    for (final place in items) {
      final title = _themeTitleForPlace(place);
      if (title.isEmpty) continue;
      counts[title] = (counts[title] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final count = b.value.compareTo(a.value);
        if (count != 0) return count;
        return a.key.compareTo(b.key);
      });
    return entries.take(maxCount).map((e) => e.key).toList();
  }

  static String _themeTitleForPlace(Map<String, dynamic> place) {
    final themeTitle = place['themeTitle'];
    if (themeTitle is String && themeTitle.trim().isNotEmpty) {
      return themeTitle.trim();
    }
    final themeName = place['themeName'];
    if (themeName is String && themeName.trim().isNotEmpty) {
      return themeName.trim();
    }
    final theme = place['theme'];
    if (theme is Map<String, dynamic>) {
      final title = theme['title'];
      if (title is String && title.trim().isNotEmpty) {
        return title.trim();
      }
    }
    return '';
  }

  static Widget _buildRecentPlaceSection({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> items,
    required bool isLoading,
    required bool favorited,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: CommonActivityIndicator(size: 22),
            ),
          )
        else if (items.isEmpty)
          const SizedBox(
            height: 140,
            child: Center(
              child: CommonEmptyView(
                message: '표시할 장소가 없습니다.',
                showButton: false,
              ),
            ),
          )
        else
          Column(
            children: items
                .map((place) => _buildPlaceItem(context, place, favorited))
                .toList(),
          ),
      ],
    );
  }

  static Widget _buildPlaceItem(
    BuildContext context,
    Map<String, dynamic> place,
    bool favorited,
  ) {
    final title = (place['title'] as String?) ??
        (place['name'] as String?) ??
        (place['placeName'] as String?) ??
        '장소';
    final address = _addressForPlace(place);
    final themeText = (place['themeTitle'] as String?) ??
        (place['themeName'] as String?) ??
        (place['categoryTitle'] as String?) ??
        (place['categoryName'] as String?) ??
        (() {
          final theme = place['theme'];
          if (theme is Map<String, dynamic>) {
            final title = theme['title'];
            if (title is String && title.trim().isNotEmpty) {
              return title.trim();
            }
          }
          return null;
        })() ??
        (() {
          final category = place['category'];
          if (category is Map<String, dynamic>) {
            final title = category['title'];
            if (title is String && title.trim().isNotEmpty) {
              return title.trim();
            }
          }
          return null;
        })() ??
        '';
    final commentCount = (place['commentCount'] as num?)?.toInt() ??
        (place['comments'] as num?)?.toInt() ??
        0;
    final likeCount = (place['favoriteCount'] as num?)?.toInt() ??
        (place['likeCount'] as num?)?.toInt() ??
        (place['likes'] as num?)?.toInt() ??
        0;
    final distanceText = _distanceTextForPlace(place);
    return CommonPlaceListItemView(
      thumbnailUrl: _thumbnailForPlace(place),
      title: title,
      address: address,
      commentCount: commentCount,
      likeCount: likeCount,
      themeText: themeText,
      distanceText: distanceText.isEmpty ? null : distanceText,
      favorited: favorited,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlacebookDetailView(space: place),
          ),
        );
      },
    );
  }

  static String _thumbnailForPlace(Map<String, dynamic> place) {
    final thumbnailRaw = place['thumbnail'];
    final thumbnailMap = thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
    Map<String, dynamic>? firstImage;
    final imagesRaw = place['images'];
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
        place['thumbnailUrl'] as String? ??
        place['imageUrl'] as String? ??
        firstImage?['thumbnailUrl'] as String? ??
        firstImage?['cdnUrl'] as String? ??
        firstImage?['fileUrl'] as String? ??
        '';
  }

  static String _distanceTextForPlace(Map<String, dynamic> place) {
    final raw = place['distance'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is num) return '${raw.toDouble().toStringAsFixed(1)}km';
    final kmRaw = place['distanceKm'];
    if (kmRaw is num) return '${kmRaw.toDouble().toStringAsFixed(1)}km';
    return '';
  }

  static String _addressForPlace(Map<String, dynamic> place) {
    String? pick(dynamic raw) {
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty &&
            trimmed != '{}' &&
            trimmed.toLowerCase() != 'null') {
          return trimmed;
        }
      }
      if (raw is Map<String, dynamic>) {
        return pick(raw['address']) ??
            pick(raw['roadAddress']) ??
            pick(raw['roadAddressName']) ??
            pick(raw['fullAddress']) ??
            pick(raw['name']) ??
            pick(raw['title']) ??
            pick(raw['text']);
      }
      return null;
    }

    return pick(place['address']) ??
        pick(place['roadAddress']) ??
        pick(place['placeAddress']) ??
        pick(place['location']) ??
        '';
  }

  static TextSpan _buildActivitySummarySpans(
    AuthUser? user, {
    required bool isLoading,
    required List<String> topThemes,
  }) {
    const baseStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 16,
      height: 1.8,
      fontWeight: FontWeight.w500,
      color: Color(0xFF4A4A4A),
    );
    const achievementStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFFFF4CC),
    );
    const titleStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFE9F2FF),
    );
    const levelStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFE9F8EF),
    );
    const countStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFFFE9F2),
    );
    const followStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFF0ECFF),
    );
    const themeStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 17,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A1A),
      backgroundColor: Color(0xFFE9F2FF),
    );

    if (isLoading) {
      return const TextSpan(
        text: '최근 활동 정보를 불러오는 중이에요.',
        style: baseStyle,
      );
    }
    if (user == null) {
      return const TextSpan(
        text: '최근 활동 정보를 불러오지 못했어요.',
        style: baseStyle,
      );
    }

    final recentAchievement =
        user.recentAchievement is Map<String, dynamic>
            ? user.recentAchievement as Map<String, dynamic>
            : null;
    final recentTitle = user.recentTitle is Map<String, dynamic>
        ? user.recentTitle as Map<String, dynamic>
        : null;

    final achievementName =
        (recentAchievement?['title'] ?? '').toString().trim();
    final titleName = (recentTitle?['name'] ?? '').toString().trim();

    final spans = <TextSpan>[];
    void addLine(List<TextSpan> lineSpans) {
      if (spans.isNotEmpty) {
        spans.add(const TextSpan(text: '\n', style: baseStyle));
      }
      spans.addAll(lineSpans);
    }

    if (achievementName.isNotEmpty || titleName.isNotEmpty) {
      if (achievementName.isNotEmpty && titleName.isNotEmpty) {
        addLine([
          const TextSpan(text: '최근 받은 업적은 ', style: baseStyle),
          TextSpan(text: achievementName, style: achievementStyle),
          const TextSpan(text: ',\n호칭은 ', style: baseStyle),
          TextSpan(text: titleName, style: titleStyle),
          const TextSpan(text: '이에요.', style: baseStyle),
        ]);
      } else if (achievementName.isNotEmpty) {
        addLine([
          const TextSpan(text: '최근 받은 업적은 ', style: baseStyle),
          TextSpan(text: achievementName, style: achievementStyle),
          const TextSpan(text: '이에요.', style: baseStyle),
        ]);
      } else {
        addLine([
          const TextSpan(text: '최근 받은 호칭은 ', style: baseStyle),
          TextSpan(text: titleName, style: titleStyle),
          const TextSpan(text: '이에요.', style: baseStyle),
        ]);
      }
    }

    if (user.activityLevel != null) {
      addLine([
        const TextSpan(text: '활동 지수는 ', style: baseStyle),
        TextSpan(text: 'LV. ${user.activityLevel}', style: levelStyle),
        const TextSpan(text: '이에요.', style: baseStyle),
      ]);
    }

    if (user.createdPlaceCount != null || user.favoritePlaceCount != null) {
      final createdText =
          user.createdPlaceCount != null ? '저장 ${user.createdPlaceCount}개' : null;
      final favoriteText =
          user.favoritePlaceCount != null ? '찜 ${user.favoritePlaceCount}개' : null;
      final parts = [createdText, favoriteText].whereType<String>().toList();
      if (parts.isNotEmpty) {
        addLine([
          const TextSpan(text: '현재 ', style: baseStyle),
          TextSpan(text: parts.join(' · '), style: countStyle),
          const TextSpan(text: ' 기록 중이에요.', style: baseStyle),
        ]);
      }
    }

    if (user.followingCount != null || user.followerCount != null) {
      final followingText =
          user.followingCount != null ? '팔로잉 ${user.followingCount}명' : null;
      final followerText =
          user.followerCount != null ? '팔로우 ${user.followerCount}명' : null;
      final parts = [followingText, followerText].whereType<String>().toList();
      if (parts.isNotEmpty) {
        addLine([
          TextSpan(text: parts.join(' · '), style: followStyle),
          const TextSpan(text: '과 함께하고 있어요.', style: baseStyle),
        ]);
      }
    }

    if (topThemes.isNotEmpty) {
      final joined = topThemes.take(3).join(' · ');
      addLine([
        const TextSpan(text: '자주 저장한 테마는 ', style: baseStyle),
        TextSpan(text: joined, style: themeStyle),
        const TextSpan(text: '이에요.', style: baseStyle),
      ]);
    }

    if (spans.isEmpty) {
      return const TextSpan(
        text: '최근 활동을 시작해볼까요?',
        style: baseStyle,
      );
    }
    return TextSpan(children: spans, style: baseStyle);
  }
}

class _ProfileActivityData {
  const _ProfileActivityData({
    required this.user,
    required this.recentSaved,
    required this.recentFavorites,
    required this.topThemes,
  });

  final AuthUser user;
  final List<Map<String, dynamic>> recentSaved;
  final List<Map<String, dynamic>> recentFavorites;
  final List<String> topThemes;
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
          _detailFuture = ApiClient.fetchMyProfile();
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
              onCreatedPlaceTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlacebookListView(
                      source: PlacebookListSource.created,
                    ),
                  ),
                );
              },
              onFavoritePlaceTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlacebookListView(
                      source: PlacebookListSource.favorites,
                    ),
                  ),
                );
              },
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
                                builder: (_) => PlacebookDetailView(space: item),
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
