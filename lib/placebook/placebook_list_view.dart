import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/state/placebook_cache.dart';
import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../placebook/widgets/placebook_list_item_view.dart';
import '../placebook/widgets/placebook_list_empty_view.dart';
import '../common/widgets/common_textfield_view.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = const [];
  bool _isSearching = false;
  bool _isSearchingMore = false;
  bool _hasMoreSearch = false;
  String? _searchCursor;
  Timer? _searchDebounce;
  late final VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _loadPlacebookData();
    _searchController.addListener(_handleSearchChanged);
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
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
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

  Future<void> _applySearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    if (query == _searchQuery && _searchResults.isNotEmpty) {
      return;
    }
    setState(() {
      _searchQuery = query;
      _isSearching = true;
      _searchResults = const [];
      _hasMoreSearch = false;
      _searchCursor = null;
    });
    try {
      final result = await ApiClient.fetchMyPlacebookMyPlacesSearch(
        query: query,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _searchResults =
            (result['items'] as List<Map<String, dynamic>>?) ?? const [];
        _hasMoreSearch = (result['hasNext'] as bool?) ?? false;
        _searchCursor = result['nextCursor'] as String?;
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadMoreSearch() async {
    if (_isSearchingMore || !_hasMoreSearch) return;
    final query = _searchQuery.trim();
    final cursor = _searchCursor;
    if (query.isEmpty || cursor == null || cursor.isEmpty) return;
    setState(() => _isSearchingMore = true);
    try {
      final result = await ApiClient.fetchMyPlacebookMyPlacesSearch(
        query: query,
        cursor: cursor,
        limit: 20,
      );
      if (!mounted) return;
      final items =
          (result['items'] as List<Map<String, dynamic>>?) ?? const [];
      setState(() {
        _searchResults = List.of(_searchResults)..addAll(items);
        _hasMoreSearch = (result['hasNext'] as bool?) ?? false;
        _searchCursor = result['nextCursor'] as String?;
      });
    } finally {
      if (mounted) setState(() => _isSearchingMore = false);
    }
  }

  void _clearSearch() {
    if (_searchQuery.isEmpty &&
        _searchResults.isEmpty &&
        !_hasMoreSearch) {
      return;
    }
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = const [];
      _hasMoreSearch = false;
      _searchCursor = null;
      _isSearching = false;
      _isSearchingMore = false;
    });
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (next.isEmpty) {
      _clearSearch();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), _applySearch);
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.of(context).padding.top;
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
    final filteredPlaces = _searchResults;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '내 도감',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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
          Expanded(
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
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CommonTextFieldView(
                                      controller: _searchController,
                                      hintText: '도감에서 검색',
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (_) => _applySearch(),
                                      prefixIcon: const Icon(
                                        PhosphorIconsRegular.magnifyingGlass,
                                        size: 18,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  CommonInkWell(
                                    onTap: _applySearch,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 56,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        '검색',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    CommonInkWell(
                                      onTap: _clearSearch,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          '취소',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF9E9E9E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_searchQuery.isEmpty)
                              TabBar(
                                isScrollable: true,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                indicatorPadding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.only(right: 24),
                                tabAlignment: TabAlignment.start,
                                splashFactory: NoSplash.splashFactory,
                                overlayColor:
                                    WidgetStateProperty.all(Colors.transparent),
                                // dividerColor: const Color.fromARGB(255, 24, 24, 24),
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
                            Expanded(
                              child: _searchQuery.isNotEmpty
                                  ? (_isSearching
                                      ? const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        )
                                      : filteredPlaces.isEmpty
                                          ? const _EmptyState(
                                              title: '검색 결과가 없어요',
                                              description:
                                                  '다른 키워드로 다시 검색해보세요.',
                                            )
                                          : NotificationListener<
                                              ScrollNotification>(
                                              onNotification: (notification) {
                                                if (notification.metrics
                                                        .extentAfter <
                                                    300) {
                                                  _loadMoreSearch();
                                                }
                                                return false;
                                              },
                                              child: ListView.separated(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        16, 8, 16, 24),
                                                itemCount:
                                                    filteredPlaces.length +
                                                        (_isSearchingMore
                                                            ? 1
                                                            : 0),
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(height: 12),
                                                itemBuilder: (context, index) {
                                                  if (index >=
                                                      filteredPlaces.length) {
                                                    return const Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 8, bottom: 8),
                                                      child: Center(
                                                        child: SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  final place =
                                                      filteredPlaces[index];
                                                  return PlacebookListItemView(
                                                    title: place['title']
                                                            as String? ??
                                                        '',
                                                    address: place['address']
                                                            as String? ??
                                                        '',
                                                    thumbnailUrl:
                                                        place['thumbnailUrl']
                                                                as String? ??
                                                            '',
                                                    favoriteCount: (place[
                                                                'favoriteCount']
                                                            as num?)
                                                        ?.toInt() ??
                                                        0,
                                                    commentCount: (place[
                                                                'commentCount']
                                                            as num?)
                                                        ?.toInt() ??
                                                        0,
                                                  );
                                                },
                                              ),
                                            ))
                                  : TabBarView(
                                      children: [
                                        for (final category in categories)
                                          ListView(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 24, 16, 24),
                                            children: [
                                              _CategorySection(
                                                title: '',
                                                themes: themesByCategory[
                                                        category['id']
                                                            ?.toString() ??
                                                    ''] ??
                                                    const [],
                                                placesByTheme: placesByTheme,
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.themes,
    required this.placesByTheme,
  });

  final String title;
  final List<Map<String, dynamic>> themes;
  final Map<String, List<Map<String, dynamic>>> placesByTheme;

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
              theme: theme,
              places: placesByTheme[theme['id']?.toString() ?? ''] ?? const [],
            ),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({
    required this.theme,
    required this.places,
  });

  final Map<String, dynamic> theme;
  final List<Map<String, dynamic>> places;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
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
          const SizedBox(height: 14),
          if (places.isEmpty)
            PlacebookListEmptyView(
              themeTitle: title,
              onTap: () {},
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
    final thumbnailUrl = (place['thumbnailUrl'] as String?) ??
        (place['imageUrl'] as String?) ??
        (place['thumbnail'] as String?) ??
        '';
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
                fontSize: 16,
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
