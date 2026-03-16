import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_login_guard.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_place_carousel_list_item_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../main.dart';
import '../placebook_create/placebook_create_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import '../placebook_list/placebook_list_view.dart';
import '../theme_detail/theme_detail_view.dart';

class PlacebookView extends StatefulWidget {
  const PlacebookView({super.key});

  @override
  State<PlacebookView> createState() => _PlacebookViewState();
}

class _PlacebookViewState extends State<PlacebookView>
{
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _allThemes = const [];
  List<Map<String, dynamic>> _missions = const [];
  List<_ContinueThemeItem> _continueThemes = const [];
  Map<String, dynamic>? _recentSavedPlace;
  bool _isLoading = true;
  double _refreshIconTurns = 0;
  bool _isRefreshingContinueThemes = false;
  String _selectedThemeSort = '가나다순';

  @override
  void initState() {
    super.initState();
    _loadHome(showLoading: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHome({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await ApiClient.fetchPlacebookHome();
      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _summary = data['summary'] is Map<String, dynamic>
            ? data['summary'] as Map<String, dynamic>
            : <String, dynamic>{};
        _categories = (data['categories'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const [];
        _allThemes = (data['allThemes'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const [];
        _missions = (data['missions'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const [];
        final summary = _summary;
        final lastSaved = summary['lastSavedPlace'];
        _recentSavedPlace = lastSaved is Map<String, dynamic>
            ? lastSaved
            : null;
        _continueThemes = _resolveContinueThemes();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshHome() async {
    await _loadHome(showLoading: false);
  }

  Future<void> _openCreatedPlaces() async {
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '나의 장소를 보려면 로그인해주세요.',
    )) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PlacebookListView(
          source: PlacebookListSource.created,
        ),
      ),
    );
  }

  Future<void> _openFavoritePlaces() async {
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '찜한 장소를 보려면 로그인해주세요.',
    )) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PlacebookListView(
          source: PlacebookListSource.favorites,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final summary = _buildSummary();
    final themesGrid = _buildThemeGridCards();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              backgroundColor: Colors.white,
              title: '도감',
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CommonActivityIndicator(size: 28),
                    )
                  : CommonRefreshView(
                      onRefresh: _refreshHome,
                      topPadding: 16,
                      child: SingleChildScrollView(
                        key: const PageStorageKey<String>('placebook-scroll'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + topPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            summary,
                            const SizedBox(height: 24),
                            _SectionHeader(
                              title: '이어서 장소 추가하기',
                              subtitle: '아직 채워지지 않은 테마',
                              showMore: false,
                            ),
                            const SizedBox(height: 16),
                            _ContinueThemeList(
                              items: _continueThemes,
                              onMoreTap: _handleContinueMoreTap,
                              refreshIcon: AnimatedRotation(
                                turns: _refreshIconTurns,
                                duration: const Duration(milliseconds: 500),
                                child: const Icon(
                                  PhosphorIconsBold.arrowsClockwise,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              ),
                              onFillTap: (item) {
                                _openCreateModal(
                                  themeId: item.themeId,
                                  themeTitle: item.title,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _SectionHeader(
                              title: '테마별 장소',
                              subtitle: '테마별로 모아보기',
                              showMore: false,
                              trailing: _buildThemeSortToggle(),
                            ),
                            const SizedBox(height: 16),
                            themesGrid,
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final totalSavedCount = (_summary['totalSavedCount'] as num?)?.toInt() ??
        _allThemes.fold<int>(
          0,
          (sum, entry) => sum + _savedCount(entry),
        );
    final createdPlaces =
        (_summary['createdCount'] as num?)?.toInt() ?? totalSavedCount;
    final favoritePlaces = (_summary['favoriteCount'] as num?)?.toInt() ??
        (_summary['favoriteSavedCount'] as num?)?.toInt() ??
        (_summary['favoritesCount'] as num?)?.toInt() ??
        0;
    final categoryCount =
        (_summary['categoryCount'] as num?)?.toInt() ?? _categories.length;
    final themeCount =
        (_summary['themeCount'] as num?)?.toInt() ?? _allThemes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '현재 저장 현황',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _SummaryStat(
              label: '나의 장소',
              value: '$createdPlaces',
              onTap: () => _openCreatedPlaces(),
            ),
            _SummaryStat(
              label: '찜한 장소',
              value: '$favoritePlaces',
              onTap: () => _openFavoritePlaces(),
            ),
            _SummaryStat(label: '카테고리', value: '$categoryCount'),
            _SummaryStat(label: '테마', value: '$themeCount'),
          ],
        ),
        const SizedBox(height: 16),
        _buildRecentSavedPlacePreview(),
      ],
    );
  }

  Widget _buildRecentSavedPlacePreview() {
    final place = _recentSavedPlace;
    if (place == null) {
      return const SizedBox.shrink();
    }

    final title = (place['title'] ?? '').toString().trim();
    final address = (place['address'] ?? '').toString().trim();
    final themeTitle = _placeThemeTitle(place);
    final imageUrl = _firstImageUrl(place['thumbnail'] ?? place['image']);
    final favoriteCount = (place['favoriteCount'] as num?)?.toInt() ?? 0;
    final verificationCount = (place['verificationCount'] as num?)?.toInt() ?? 0;
    final favorited = (place['isFavorited'] as bool?) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 나의 장소',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 124,
          child: CommonPlaceCarouselListItemView(
            thumbnailUrl: imageUrl,
            title: title.isEmpty ? '이름 없는 장소' : title,
            address: address,
            commentCount: verificationCount,
            likeCount: favoriteCount,
            themeText: themeTitle.isEmpty ? null : themeTitle,
            favorited: favorited,
            height: 148,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => PlacebookDetailView(space: place),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThemeGridCards() {
    final items = _resolveThemeGridCards(_sortedThemeEntries());
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 208,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ThemeGridCard(
          item: item,
          onTap: () {
            _openThemeDetail(
              themeId: item.themeId,
              themeTitle: item.title,
            );
          },
          onAddTap: () {
            _openCreateModal(
              themeId: item.themeId,
              themeTitle: item.title,
            );
          },
        );
      },
    );
  }

  Widget _buildThemeSortToggle() {
    const options = ['가나다순', '저장갯수순'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i != 0)
            Container(
              width: 1,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0x33000000),
            ),
          GestureDetector(
            onTap: () {
              if (_selectedThemeSort == options[i]) return;
              setState(() => _selectedThemeSort = options[i]);
            },
            behavior: HitTestBehavior.opaque,
            child: Text(
              options[i],
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: _selectedThemeSort == options[i]
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: _selectedThemeSort == options[i]
                    ? Colors.black
                    : const Color(0x88000000),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _sortedThemeEntries() {
    final entries = List<Map<String, dynamic>>.from(_allThemes);
    if (_selectedThemeSort == '저장갯수순') {
      entries.sort((a, b) {
        final bCount = _savedCount(b);
        final aCount = _savedCount(a);
        if (bCount != aCount) return bCount.compareTo(aCount);
        final aTitle = (_extractTheme(a)['title'] ?? '').toString().toLowerCase();
        final bTitle = (_extractTheme(b)['title'] ?? '').toString().toLowerCase();
        return aTitle.compareTo(bTitle);
      });
      return entries;
    }
    entries.sort((a, b) {
      final aTitle = (_extractTheme(a)['title'] ?? '').toString().toLowerCase();
      final bTitle = (_extractTheme(b)['title'] ?? '').toString().toLowerCase();
      return aTitle.compareTo(bTitle);
    });
    return entries;
  }

  List<_ThemeGridCardData> _resolveThemeGridCards(
    List<Map<String, dynamic>> source,
  ) {
    const fallback = [
      _ThemeGridCardData(
        title: '조용한 정리존',
        tag: '생각 정리',
      ),
      _ThemeGridCardData(
        title: '혼밥 가능한 곳',
        tag: '1인 친화',
      ),
      _ThemeGridCardData(
        title: '산책 루트',
        tag: '걷기',
      ),
      _ThemeGridCardData(
        title: '감성 카페',
        tag: '분위기',
      ),
      _ThemeGridCardData(
        title: '잠깐 들르기',
        tag: '짧은 시간',
      ),
      _ThemeGridCardData(
        title: '무료 편의',
        tag: '가볍게',
      ),
    ];
    if (source.isEmpty) {
      return fallback;
    }
    final items = <_ThemeGridCardData>[];
    for (var i = 0; i < source.length; i++) {
      final entry = source[i];
      final theme = _extractTheme(entry);
      final title = (theme['title'] ?? '').toString();
      final category = theme['category'];
      final tag = category is Map<String, dynamic>
          ? (category['title'] ?? '').toString()
          : '';
      final count = _savedCount(entry);
      items.add(
        _ThemeGridCardData(
          title: title.isEmpty ? '테마 ${i + 1}' : title,
          tag: tag,
          imageUrl: _themeImageUrl(theme),
          thumbnailUrls: _themePlaceThumbnailUrls(entry),
          count: count,
          themeId: (theme['id'] ?? '').toString(),
        ),
      );
    }
    return items;
  }

  String _themeImageUrl(Map<String, dynamic> theme) {
    final image = theme['image'];
    if (image is Map<String, dynamic>) {
      return (image['cdnUrl'] as String?) ??
          (image['thumbnailUrl'] as String?) ??
          (image['fileUrl'] as String?) ??
          '';
    }
    return '';
  }

  Map<String, dynamic> _extractTheme(Map<String, dynamic> entry) {
    final theme = entry['theme'];
    if (theme is Map<String, dynamic>) {
      return theme;
    }
    return entry;
  }

  int _savedCount(Map<String, dynamic> entry) {
    final saved = (entry['savedCount'] as num?)?.toInt() ?? 0;
    if (saved > 0) return saved;
    final created = (entry['createdCount'] as num?)?.toInt() ?? 0;
    final favorite = (entry['favoriteCount'] as num?)?.toInt() ?? 0;
    return created + favorite;
  }

  List<String> _themePlaceThumbnailUrls(Map<String, dynamic> entry) {
    final places = entry['places'];
    if (places is! List) return const [];
    final urls = <String>[];
    for (final place in places) {
      if (place is! Map<String, dynamic>) continue;
      final image = place['thumbnail'] ?? place['image'];
      urls.add(_firstImageUrl(image));
      if (urls.length >= 4) break;
    }
    return urls;
  }

  String _firstImageUrl(dynamic image) {
    if (image is! Map<String, dynamic>) return '';
    final cdn = image['cdnUrl']?.toString().trim();
    if (cdn != null && cdn.isNotEmpty) return cdn;
    final thumb = image['thumbnailUrl']?.toString().trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final file = image['fileUrl']?.toString().trim();
    if (file != null && file.isNotEmpty) return file;
    return '';
  }

  String _placeThemeTitle(Map<String, dynamic> place) {
    final theme = place['theme'];
    if (theme is Map<String, dynamic>) {
      final title = theme['title'];
      if (title is String && title.trim().isNotEmpty) {
        return title.trim();
      }
    }
    final themeTitle = place['themeTitle'];
    if (themeTitle is String && themeTitle.trim().isNotEmpty) {
      return themeTitle.trim();
    }
    return '';
  }

  List<_ContinueThemeItem> _resolveContinueThemes() {
    if (_missions.isNotEmpty) {
      return _missions.take(3).map((mission) {
        final title = (mission['title'] ?? '').toString();
        final subtitle = (mission['description'] ?? '').toString();
        final themeId = (mission['themeId'] ?? '').toString();
        final themeEntry = _findThemeEntry(themeId);
        final theme = themeEntry == null ? null : _extractTheme(themeEntry);
        return _ContinueThemeItem(
          title: title.isEmpty ? '테마를 채워보세요' : title,
          subtitle: subtitle.isEmpty ? '첫 장소를 저장해보세요' : subtitle,
          imageUrl: theme == null ? '' : _themeImageUrl(theme),
          themeId: themeId,
        );
      }).toList();
    }
    final items = <_ContinueThemeItem>[];
    final shuffled = List<Map<String, dynamic>>.from(_allThemes);
    shuffled.shuffle();
    for (final entry in shuffled) {
      final count = _savedCount(entry);
      if (count > 0) continue;
      final theme = _extractTheme(entry);
      final title = (theme['title'] ?? '').toString();
      final desc = (theme['description'] ?? '').toString();
      final imageUrl = _themeImageUrl(theme);
      items.add(
        _ContinueThemeItem(
          title: title.isEmpty ? '테마를 시작해보세요' : title,
          subtitle: desc.isEmpty ? '첫 장소를 저장해보세요' : desc,
          imageUrl: imageUrl,
          themeId: (theme['id'] ?? '').toString(),
        ),
      );
    }
    if (items.isEmpty) {
      for (final entry in shuffled.take(3)) {
        final theme = _extractTheme(entry);
        final title = (theme['title'] ?? '').toString();
        final desc = (theme['description'] ?? '').toString();
        final imageUrl = _themeImageUrl(theme);
        items.add(
          _ContinueThemeItem(
            title: title.isEmpty ? '테마를 채워보세요' : title,
            subtitle: desc.isEmpty ? '다음 장소를 추가해보세요' : desc,
            imageUrl: imageUrl,
            themeId: (theme['id'] ?? '').toString(),
          ),
        );
      }
    }
    return items.take(3).toList();
  }

  Map<String, dynamic>? _findThemeEntry(String themeId) {
    if (themeId.isEmpty) return null;
    for (final entry in _allThemes) {
      final theme = _extractTheme(entry);
      if ((theme['id'] ?? '').toString() == themeId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _refreshContinueThemes() async {
    try {
      final emptyThemes = await ApiClient.fetchPlacebookEmptyThemes();
      if (!mounted) return;
      if (emptyThemes.isEmpty) {
        setState(() {
          _continueThemes = _resolveContinueThemes();
        });
        return;
      }

      final shuffled = List<Map<String, dynamic>>.from(emptyThemes)
        ..shuffle();
      final nextItems = shuffled
          .take(3)
          .map(_toContinueThemeItem)
          .toList();
      setState(() {
        _continueThemes = nextItems;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _continueThemes = _resolveContinueThemes();
      });
    }
  }

  Future<void> _handleContinueMoreTap() async {
    if (_isRefreshingContinueThemes) return;
    setState(() {
      _isRefreshingContinueThemes = true;
      _refreshIconTurns += 1;
    });
    try {
      await _refreshContinueThemes();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingContinueThemes = false;
        });
      }
    }
  }

  _ContinueThemeItem _toContinueThemeItem(Map<String, dynamic> entry) {
    final theme = _extractTheme(entry);
    final title = (theme['title'] ?? '').toString();
    final desc = (theme['description'] ?? '').toString();
    return _ContinueThemeItem(
      title: title.isEmpty ? '테마를 채워보세요' : title,
      subtitle: desc.isEmpty ? '첫 장소를 저장해보세요' : desc,
      imageUrl: _themeImageUrl(theme),
      themeId: (theme['id'] ?? '').toString(),
    );
  }

  void _openCreateModal({
    String? themeId,
    String? themeTitle,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => SizedBox.expand(
        child: PlacebookCreateView(
          themeId: (themeId ?? '').isEmpty ? null : themeId,
          themeTitle: (themeTitle ?? '').isEmpty ? null : themeTitle,
        ),
      ),
    );
  }

  void _openThemeDetail({
    required String themeId,
    required String themeTitle,
  }) {
    if (themeId.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThemeDetailView(
          themeId: themeId,
          themeTitle: themeTitle,
        ),
      ),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  const _RoundedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        shadows: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CommonInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF757575),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.showMore = true,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool showMore;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ),
        if (showMore)
          CommonInkWell(
            onTap: () {},
            child: Row(
              children: const [
                Text(
                  '전체보기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 14,
                  color: Color(0xFF9E9E9E),
                ),
              ],
            ),
          )
        else ?trailing,
      ],
    );
  }
}

class _ThemeGridCardData {
  const _ThemeGridCardData({
    required this.title,
    required this.tag,
    this.imageUrl = '',
    this.thumbnailUrls = const [],
    this.count = 0,
    this.themeId = '',
  });

  final String title;
  final String tag;
  final String imageUrl;
  final List<String> thumbnailUrls;
  final int count;
  final String themeId;
}

class _ThemeGridCard extends StatelessWidget {
  const _ThemeGridCard({
    required this.item,
    required this.onTap,
    required this.onAddTap,
  });

  final _ThemeGridCardData item;
  final VoidCallback onTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: _RoundedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OverlappedPlaceThumbnails(
              thumbnailUrls: item.thumbnailUrls,
              seed: item.title,
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${item.count}',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const TextSpan(
                    text: '개 저장',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (item.tag.isNotEmpty)
              Text(
                item.tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            const SizedBox(height: 8),
            CommonRoundedButton(
              title: '추가하기',
              onTap: onAddTap,
              height: 32,
              radius: 8,
              backgroundColor: const Color(0xFFF5F5F5),
              textColor: Colors.black,
              borderColor: const Color(0xFFF5F5F5),
              textStyle: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF616161),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCardData {
  const _ThemeCardData({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.progress,
  });

  final String title;
  final String description;
  final String imageUrl;
  final double progress;
}

class _ThemeProgressCard extends StatelessWidget {
  const _ThemeProgressCard({required this.item});

  final _ThemeCardData item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: _RoundedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipSmoothRect(
                radius: SmoothBorderRadius(
                  cornerRadius: 20,
                  cornerSmoothing: 1,
                ),
                child: CommonImageView(
                  networkUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  backgroundColor: const Color(0xFFF2F2F2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.description.isEmpty ? '테마를 채워보세요' : item.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ThemeRecommendCard extends StatelessWidget {
  const _ThemeRecommendCard({required this.item});

  final _ThemeCardData item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: _RoundedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipSmoothRect(
                radius: SmoothBorderRadius(
                  cornerRadius: 20,
                  cornerSmoothing: 1,
                ),
                child: CommonImageView(
                  networkUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  backgroundColor: const Color(0xFFF2F2F2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.description.isEmpty ? '지금 시작해보세요' : item.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const ShapeDecoration(
                color: Colors.black,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
              child: const Text(
                '추천',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MyApp.primary200,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueThemeList extends StatelessWidget {
  const _ContinueThemeList({
    required this.items,
    required this.onMoreTap,
    required this.refreshIcon,
    required this.onFillTap,
  });

  final List<_ContinueThemeItem> items;
  final Future<void> Function() onMoreTap;
  final Widget refreshIcon;
  final void Function(_ContinueThemeItem item) onFillTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RoundedCard(
              child: Row(
                children: [
                  _PlaceListThumbnail(
                    url: item.imageUrl,
                    seed: item.title,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 62,
                    child: CommonRoundedButton(
                      title: '추가하기',
                      onTap: () => onFillTap(item),
                      height: 32,
                      radius: 16,
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                      borderColor: Colors.black,
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 2),
        CommonRoundedButton(
          title: '다른 빈 테마 더보기',
          onTap: () {
            onMoreTap();
          },
          height: 52,
          radius: 12,
          backgroundColor: Colors.grey.shade200,
          textColor: Colors.black,
          borderColor: Colors.grey.shade200,
          leading: refreshIcon,
          leadingCentered: true,
          leadingGap: 8,
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }
}

class _ContinueThemeItem {
  const _ContinueThemeItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.themeId,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String themeId;
}

class _OverlappedPlaceThumbnails extends StatelessWidget {
  const _OverlappedPlaceThumbnails({
    required this.thumbnailUrls,
    required this.seed,
  });

  final List<String> thumbnailUrls;
  final String seed;

  @override
  Widget build(BuildContext context) {
    const visibleMax = 4;
    const size = 48.0;
    const overlap = 14.0;
    final visible = thumbnailUrls.take(visibleMax).toList();

    if (visible.isEmpty) {
      return const _PlaceListThumbnail(
        url: '',
        seed: 'empty',
        size: size,
      );
    }

    final width = size + (visible.length - 1) * (size - overlap);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: List.generate(visible.length, (paintOrder) {
          final index = visible.length - 1 - paintOrder;
          return Positioned(
            left: index * (size - overlap),
            child: _PlaceListThumbnail(
              url: visible[index],
              seed: '$seed-$index',
              size: size,
            ),
          );
        }),
      ),
    );
  }
}

class _PlaceListThumbnail extends StatelessWidget {
  const _PlaceListThumbnail({
    required this.url,
    required this.seed,
    this.size = 56,
  });

  final String url;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rotation = _thumbnailRotationDegrees(seed);
    return SizedBox(
      width: size,
      height: size,
      child: Transform.rotate(
        angle: rotation * (3.141592653589793 / 180),
        child: Container(
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: size * 0.18,
                cornerSmoothing: 1,
              ),
              side: const BorderSide(color: Colors.white, width: 4),
            ),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: ClipSmoothRect(
            radius: SmoothBorderRadius(
              cornerRadius: size * 0.14,
              cornerSmoothing: 1,
            ),
            child: CommonImageView(
              networkUrl: url.isEmpty ? null : url,
              fit: BoxFit.cover,
              backgroundColor: const Color(0xFFF2F2F2),
            ),
          ),
        ),
      ),
    );
  }

  double _thumbnailRotationDegrees(String seed) {
    final value = seed.hashCode;
    final magnitude = 2 + (value.abs() % 4);
    final sign = value.isEven ? 1 : -1;
    return magnitude * sign.toDouble();
  }
}
