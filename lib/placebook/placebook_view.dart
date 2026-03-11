import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../common/state/placebook_cache.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_navigation_view.dart';

class PlacebookView extends StatefulWidget {
  const PlacebookView({super.key});

  @override
  State<PlacebookView> createState() => _PlacebookViewState();
}

class _PlacebookViewState extends State<PlacebookView> {
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _themes = const [];

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final categories = await PlacebookCache.loadCategories();
    final themes = await PlacebookCache.loadThemes();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _themes = themes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final summary = _buildSummary();
    final categories = _buildCategoryCards();
    final themes = _buildThemeCards();
    final recommended = _buildRecommendedCards();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              height: 50,
              backgroundColor: Colors.white,
              title: '도감',
              right: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CommonInkWell(
                    onTap: () {},
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CommonInkWell(
                    onTap: () {},
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        PhosphorIconsRegular.funnel,
                        size: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + topPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summary,
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: '카테고리 도감',
                      subtitle: '분류별로 모아보기',
                    ),
                    const SizedBox(height: 12),
                    categories,
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: '진행 중인 테마',
                      subtitle: '채우는 중인 테마를 이어보세요',
                    ),
                    const SizedBox(height: 12),
                    themes,
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: '이어서 채우기',
                      subtitle: '바로 할 수 있는 미션',
                    ),
                    const SizedBox(height: 12),
                    _MissionList(
                      items: const [
                        _MissionItem(
                          title: '이번 주 산책 카테고리 3곳 채우기',
                          subtitle: '산책 카테고리 진행률 +12%',
                          icon: PhosphorIconsBold.footprints,
                        ),
                        _MissionItem(
                          title: '무료 편의 테마 1곳 추가',
                          subtitle: '무료 편의 수집률 +6%',
                          icon: PhosphorIconsBold.storefront,
                        ),
                        _MissionItem(
                          title: '분위기 테마 첫 장소 저장하기',
                          subtitle: '새 테마 시작하기',
                          icon: PhosphorIconsBold.sparkle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: '추천 테마',
                      subtitle: '지금 시작하기 좋은 테마',
                    ),
                    const SizedBox(height: 12),
                    recommended,
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final categoryCount = _categories.length;
    final themeCount = _themes.length;
    final totalPlaces = _themes.fold<int>(
      0,
      (sum, theme) => sum + ((theme['placeCount'] as num?)?.toInt() ?? 0),
    );
    final progress = _calculateProgress(categoryCount, themeCount, totalPlaces);
    return _RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: ShapeDecoration(
                  color: const Color(0xFFF2F2F2),
                  shape: const ContinuousRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
                child: const Text(
                  '도감 수집가',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF616161),
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                '최근 업적',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '이번 달 도감 32% 달성',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryStat(label: '저장 장소', value: '$totalPlaces'),
              _SummaryStat(label: '카테고리', value: '$categoryCount'),
              _SummaryStat(label: '테마', value: '$themeCount'),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressBar(progress: progress, label: '전체 진행률'),
          const SizedBox(height: 10),
          const Text(
            '최근 업적: 무료 편의 카테고리 10곳 달성',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCards() {
    final items = _resolveCategoryCards();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 176,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _CategoryCard(item: item);
      },
    );
  }

  Widget _buildThemeCards() {
    final items = _resolveThemeCards(_themes);
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _ThemeProgressCard(item: item);
        },
      ),
    );
  }

  Widget _buildRecommendedCards() {
    final items = _resolveThemeCards(_themes.reversed.toList());
    return SizedBox(
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _ThemeRecommendCard(item: item);
        },
      ),
    );
  }

  List<_CategoryCardData> _resolveCategoryCards() {
    const defaults = [
      _CategoryCardData(
        title: '쉬기',
        icon: PhosphorIconsBold.umbrella,
        tag: '#힐링',
      ),
      _CategoryCardData(
        title: '집중',
        icon: PhosphorIconsBold.target,
        tag: '#몰입',
      ),
      _CategoryCardData(
        title: '산책',
        icon: PhosphorIconsBold.footprints,
        tag: '#걷기',
      ),
      _CategoryCardData(
        title: '분위기',
        icon: PhosphorIconsBold.sparkle,
        tag: '#감성',
      ),
      _CategoryCardData(
        title: '잠깐 들르기',
        icon: PhosphorIconsBold.timer,
        tag: '#잠깐',
      ),
      _CategoryCardData(
        title: '무료 편의',
        icon: PhosphorIconsBold.wifiHigh,
        tag: '#무료',
      ),
    ];

    if (_categories.isEmpty) {
      return defaults;
    }
    final items = <_CategoryCardData>[];
    for (var i = 0; i < 6; i++) {
      if (i < _categories.length) {
        final category = _categories[i];
        final title = (category['title'] ?? '').toString();
        final count = (category['placeCount'] as num?)?.toInt() ?? (i + 2) * 3;
        final progress = ((i + 1) / 6).clamp(0.1, 1.0);
        items.add(
          _CategoryCardData(
            title: title.isEmpty ? defaults[i].title : title,
            icon: defaults[i].icon,
            tag: (category['subtitle'] ?? defaults[i].tag).toString(),
            count: count,
            progress: progress,
          ),
        );
      } else {
        items.add(defaults[i]);
      }
    }
    return items;
  }

  List<_ThemeCardData> _resolveThemeCards(List<Map<String, dynamic>> source) {
    final items = <_ThemeCardData>[];
    final total = source.isEmpty ? 4 : source.length;
    for (var i = 0; i < total && items.length < 6; i++) {
      if (i < source.length) {
        final theme = source[i];
        final title = (theme['title'] ?? '').toString();
        items.add(
          _ThemeCardData(
            title: title.isEmpty ? '테마 ${i + 1}' : title,
            description: (theme['description'] ?? '').toString(),
            imageUrl: _themeImageUrl(theme),
            progress: ((i + 2) / (total + 2)).clamp(0.2, 0.95),
          ),
        );
      } else {
        items.add(
          _ThemeCardData(
            title: '테마 ${i + 1}',
            description: '지금 시작하면 좋은 테마',
            imageUrl: '',
            progress: 0.3 + (i * 0.08),
          ),
        );
      }
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

  double _calculateProgress(int categories, int themes, int places) {
    final base = (categories + themes + places / 5) / 30;
    return base.clamp(0.1, 0.95);
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
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.label,
  });

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 6),
        ClipSmoothRect(
          radius: SmoothBorderRadius(
            cornerRadius: 12,
            cornerSmoothing: 1,
          ),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFF2F2F2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
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
        ),
      ],
    );
  }
}

class _CategoryCardData {
  const _CategoryCardData({
    required this.title,
    required this.icon,
    required this.tag,
    this.count = 0,
    this.progress = 0.2,
  });

  final String title;
  final IconData icon;
  final String tag;
  final int count;
  final double progress;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item});

  final _CategoryCardData item;

  @override
  Widget build(BuildContext context) {
    final progress = item.progress.clamp(0.05, 1.0);
    return _RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const ShapeDecoration(
              color: Color(0xFFF2F2F2),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.count}곳 저장',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const Spacer(),
          _ProgressBar(progress: progress, label: item.tag),
        ],
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
            const SizedBox(height: 8),
            _ProgressBar(
              progress: item.progress,
              label: '진행 중',
            ),
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
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionList extends StatelessWidget {
  const _MissionList({required this.items});

  final List<_MissionItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RoundedCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const ShapeDecoration(
                    color: Color(0xFFF2F2F2),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: Colors.black,
                  ),
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
                      const SizedBox(height: 4),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const ShapeDecoration(
                    color: Colors.black,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                  child: const Text(
                    '바로 하기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MissionItem {
  const _MissionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
