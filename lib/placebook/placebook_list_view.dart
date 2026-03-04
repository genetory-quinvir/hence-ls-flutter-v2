import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/state/placebook_cache.dart';
import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../placebook/widgets/placebook_list_item_view.dart';
import '../placebook/widgets/placebook_list_empty_view.dart';
import '../placebook_create/placebook_create_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import '../common/widgets/common_inkwell.dart';

class PlacebookListView extends StatefulWidget {
  const PlacebookListView({super.key});

  @override
  State<PlacebookListView> createState() => _PlacebookListViewState();
}

class _PlacebookListViewState extends State<PlacebookListView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _themes = const [];
  List<Map<String, dynamic>> _registeredPlaces = const [];
  int _createdCount = 0;
  int _favoriteCount = 0;
  int _totalCount = 0;
  late final VoidCallback _tabListener;
  final Map<String, ScrollController> _categoryScrollControllers = {};

  @override
  void initState() {
    super.initState();
    _loadPlacebookData();
    _tabListener = () {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _loadPlacebookInfo();
        });
      }
    };
    HomeTabController.currentIndex.addListener(_tabListener);
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    for (final controller in _categoryScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ScrollController _controllerForCategory(String id) {
    return _categoryScrollControllers.putIfAbsent(
      id,
      () => ScrollController(),
    );
  }

  void _scrollToTop() {
    for (final controller in _categoryScrollControllers.values) {
      if (!controller.hasClients) continue;
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }


  Future<void> _loadPlacebookData() async {
    final categories = await PlacebookCache.loadCategories();
    final themes = await PlacebookCache.loadThemes();
    final places = await ApiClient.fetchMyPlacebookMyPlaces();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _themes = themes;
      _registeredPlaces = places;
      _isLoading = false;
    });
    await _loadPlacebookInfo();
  }

  Future<void> _loadPlacebookInfo() async {
    debugPrint('[PLACEBOOK] load my-places/info');
    final info = await ApiClient.fetchMyPlacebookMyPlacesInfo();
    if (!mounted) return;
    setState(() {
      _createdCount = (info['createdCount'] as num?)?.toInt() ?? 0;
      _favoriteCount = (info['favoriteCount'] as num?)?.toInt() ?? 0;
      _totalCount = (info['totalCount'] as num?)?.toInt() ?? 0;
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupPlacesByTheme() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final place in _registeredPlaces) {
      final themeId = place['themeId']?.toString() ??
          (place['theme'] is Map
              ? (place['theme'] as Map)['id']?.toString()
              : '') ??
          '';
      if (themeId.isEmpty) continue;
      grouped.putIfAbsent(themeId, () => []).add(place);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final placesByTheme = _groupPlacesByTheme();
    final categories = _categories
        .whereType<Map<String, dynamic>>()
        .where((item) => item['isActive'] != false)
        .toList()
      ..sort((a, b) {
        final aOrder = (a['sortOrder'] as num?)?.toInt() ?? 0;
        final bOrder = (b['sortOrder'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });
    final themesByCategory = <String, List<Map<String, dynamic>>>{};
    for (final theme in _themes) {
      if (theme['isActive'] == false) continue;
      final categoryId = theme['categoryId']?.toString() ?? '';
      if (categoryId.isEmpty) continue;
      themesByCategory.putIfAbsent(categoryId, () => []).add(theme);
    }
    for (final entry in themesByCategory.entries) {
      entry.value.sort((a, b) {
        final aOrder = (a['sortOrder'] as num?)?.toInt() ?? 0;
        final bOrder = (b['sortOrder'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : categories.isEmpty
                ? const _EmptyState(
                    title: '도감이 비어있어요',
                    description: '카테고리/테마 정보를 불러오지 못했어요.',
                  )
                : DefaultTabController(
                    length: categories.length,
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '내 도감',
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontFamily: 'Pretendard',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    CommonInkWell(
                                      onTap: () {},
                                      borderRadius: BorderRadius.circular(20),
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
                                  ],
                                ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CountChip(
                                          label: '내가 등록한 장소',
                                          value: _createdCount,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _CountChip(
                                          label: '즐겨찾기한 장소',
                                          value: _favoriteCount,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _CountChip(
                                          label: '모은 장소',
                                          value: _totalCount,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarHeaderDelegate(
                            TabBar(
                              isScrollable: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              indicatorPadding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.only(right: 24),
                              tabAlignment: TabAlignment.start,
                              splashFactory: NoSplash.splashFactory,
                              overlayColor: WidgetStateProperty.all(
                                  Colors.transparent),
                              labelColor: Colors.black,
                              unselectedLabelColor: const Color(0xFFB0B0B0),
                              indicator: const UnderlineTabIndicator(
                                borderSide: BorderSide(
                                    color: Colors.black, width: 2),
                                borderRadius: BorderRadius.zero,
                              ),
                              labelStyle: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              tabs: [
                                for (final category in categories)
                                  Tab(
                                    text: (category['name'] as String?) ??
                                        (category['title'] as String?) ??
                                        '카테고리',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        ];
                      },
                      body: TabBarView(
                        children: [
                          for (final category in categories)
                            ListView(
                              controller: _controllerForCategory(
                                category['id']?.toString() ?? '',
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                  16, 24, 16, 24),
                              children: [
                                _CategorySection(
                                  title: (category['name'] as String?) ??
                                      (category['title'] as String?) ??
                                      '카테고리',
                                  themes: themesByCategory[
                                          category['id']?.toString() ?? ''] ??
                                      const [],
                                  placesByTheme: placesByTheme,
                                  onCreated: (created) async {
                                    if (!mounted || created == null) return;
                                    await _loadPlacebookData();
                                    if (!mounted) return;
                                    _scrollToTop();
                                    if (!mounted) return;
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PlacebookDetailView(space: created),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
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

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.themes,
    required this.placesByTheme,
    required this.onCreated,
  });

  final String title;
  final List<Map<String, dynamic>> themes;
  final Map<String, List<Map<String, dynamic>>> placesByTheme;
  final ValueChanged<Map<String, dynamic>?> onCreated;

  @override
  Widget build(BuildContext context) {
    if (themes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final theme in themes)
            _ThemeSection(
              categoryTitle: title,
              theme: theme,
              places: placesByTheme[theme['id']?.toString() ?? ''] ?? const [],
              onCreated: onCreated,
            ),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({
    required this.categoryTitle,
    required this.theme,
    required this.places,
    required this.onCreated,
  });

  final String categoryTitle;
  final Map<String, dynamic> theme;
  final List<Map<String, dynamic>> places;
  final ValueChanged<Map<String, dynamic>?> onCreated;

  @override
  Widget build(BuildContext context) {
    final title =
        (theme['name'] as String?) ?? (theme['title'] as String?) ?? '테마';
    final subtitle = (theme['subtitle'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (places.isEmpty)
            PlacebookListEmptyView(
              themeTitle: title,
              onTap: () async {
                final result =
                    await showCupertinoModalPopup<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => SizedBox.expand(
                    child: PlacebookCreateView(
                      categoryTitle: categoryTitle,
                      themeTitle: title,
                      themeId: theme['id']?.toString(),
                    ),
                  ),
                );
                onCreated(result);
              },
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _RegisteredPlaceCard(place: places[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RegisteredPlaceCard extends StatelessWidget {
  const _RegisteredPlaceCard({
    required this.place,
  });

  final Map<String, dynamic> place;

  @override
  Widget build(BuildContext context) {
    final title = (place['title'] as String?) ??
        (place['name'] as String?) ??
        '장소';
    final thumbnailUrl = _resolvePlaceImageUrl(place);
    final favoriteCount = (place['favoriteCount'] as num?)?.toInt() ?? 0;
    final commentCount = (place['commentCount'] as num?)?.toInt() ?? 0;
    final address = (place['address'] as String?) ??
        (place['placeName'] as String?) ??
        '';
    return PlacebookListItemView(
      title: title,
      thumbnailUrl: thumbnailUrl,
      favoriteCount: favoriteCount,
      commentCount: commentCount,
      address: address,
      onTap: () {},
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            PhosphorIconsRegular.bookOpen,
            size: 32,
            color: Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF616161),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }
}

String _resolvePlaceImageUrl(Map<String, dynamic> place) {
  final thumbnailRaw = place['thumbnail'];
  final thumbnailMap =
      thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
  final imageIdRaw = place['imageId'];
  final imageIdMap = imageIdRaw is Map<String, dynamic> ? imageIdRaw : null;
  final imageRaw = place['image'];
  final imageMap = imageRaw is Map<String, dynamic> ? imageRaw : null;
  final images = place['images'];
  final firstImage =
      images is List && images.isNotEmpty && images.first is Map<String, dynamic>
          ? images.first as Map<String, dynamic>
          : null;

  return (place['thumbnailUrl'] as String?) ??
      (place['imageUrl'] as String?) ??
      (thumbnailMap?['cdnUrl'] as String?) ??
      (thumbnailMap?['fileUrl'] as String?) ??
      (thumbnailMap?['thumbnailUrl'] as String?) ??
      (imageIdMap?['cdnUrl'] as String?) ??
      (imageIdMap?['fileUrl'] as String?) ??
      (imageIdMap?['thumbnailUrl'] as String?) ??
      (imageMap?['cdnUrl'] as String?) ??
      (imageMap?['fileUrl'] as String?) ??
      (imageMap?['thumbnailUrl'] as String?) ??
      (firstImage?['cdnUrl'] as String?) ??
      (firstImage?['fileUrl'] as String?) ??
      (firstImage?['thumbnailUrl'] as String?) ??
      '';
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF616161),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$value',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
