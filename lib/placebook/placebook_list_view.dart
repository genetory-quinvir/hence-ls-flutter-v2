import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/state/placebook_cache.dart';
import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../placebook/widgets/placebook_list_item_view.dart';
import '../placebook_create/placebook_create_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import '../placebook_collect/placebook_collect_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_textfield_view.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_place_list_item_view.dart';

class PlacebookListView extends StatefulWidget {
  const PlacebookListView({super.key});

  @override
  State<PlacebookListView> createState() => _PlacebookListViewState();
}

class _PlacebookListViewState extends State<PlacebookListView> {
  static const double _kCommonTabHeight = 66;
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _themes = const [];
  Map<String, List<Map<String, dynamic>>> _placesByTheme = const {};
  List<Map<String, dynamic>> _places = const [];
  List<String> _searchThumbnails = const [];
  bool _hasFixedSearchThumbnails = false;
  int _createdCount = 0;
  int _favoriteCount = 0;
  int _totalCount = 0;
  String _selectedThemeSort = 'places';
  String _selectedCollection = 'mine';
  String _selectedViewMode = 'theme';
  String _selectedPlaceSort = 'latest';
  String? _placesNextCursor;
  bool _placesHasNext = true;
  bool _isLoadingMorePlaces = false;
  String? _placesRequestedCursor;
  late final VoidCallback _tabListener;
  final ScrollController _listController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _pendingSearchText = '';
  final Map<String, _PlacebookCacheSnapshot> _filterCache = {};

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
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_listController.hasClients) return;
    _listController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleSearchChanged(String value) {
    final nextValue = value.trim();
    final shouldClear = nextValue.isEmpty && _searchText.trim().isNotEmpty;
    setState(() => _pendingSearchText = value);
    if (!shouldClear) return;
    setState(() {
      _searchText = '';
      _pendingSearchText = '';
    });
    _scrollToTop();
    if (_selectedViewMode == 'place') {
      _loadPlacebookPlacesList(
        filter: _selectedCollection,
        forceRefresh: true,
      );
    }
  }

  void _handleSearchCancel() {
    _searchController.clear();
    setState(() {
      _searchText = '';
      _pendingSearchText = '';
    });
    _scrollToTop();
    if (_selectedViewMode == 'place') {
      _loadPlacebookPlacesList(
        filter: _selectedCollection,
        forceRefresh: true,
      );
    }
  }

  void _handleSearchSubmitted(String value) {
    final nextValue = _pendingSearchText.trim();
    if (nextValue == _searchText.trim()) return;
    setState(() {
      _searchText = value;
      _pendingSearchText = value;
    });
    _scrollToTop();
    if (nextValue.isNotEmpty || _selectedViewMode == 'place') {
      _loadPlacebookPlacesList(
        filter: _selectedCollection,
        forceRefresh: true,
      );
    }
  }

  Future<void> _loadPlacebookData({
    String? filter,
    String? themeOrderBy,
    String? themeOrderBy2,
    String? themeOrder,
    bool forceRefresh = false,
  }) async {
    final activeFilter = filter ?? _selectedCollection;
    final activeThemeOrderBy = themeOrderBy ?? _themeOrderBy(_selectedThemeSort);
    final activeThemeOrderBy2 =
        themeOrderBy2 ?? _themeOrderBy2(_selectedThemeSort);
    final activeThemeOrder = themeOrder ?? _themeOrder(_selectedThemeSort);
    final cacheKey =
        '$activeFilter|$activeThemeOrderBy|${activeThemeOrderBy2 ?? ''}|$activeThemeOrder';
    if (forceRefresh) {
      _filterCache.remove(cacheKey);
      _hasFixedSearchThumbnails = false;
    }
    if (!forceRefresh) {
      final cached = _filterCache[cacheKey];
      if (cached != null && mounted) {
        setState(() {
          _categories = cached.categories;
          _themes = cached.themes;
          _placesByTheme = cached.placesByTheme;
          if (!_hasFixedSearchThumbnails) {
            _searchThumbnails =
                _collectSearchThumbnails(cached.placesByTheme, maxCount: 4);
            _hasFixedSearchThumbnails = true;
          }
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }
    }
    if (mounted) {
      final hasData = _themes.isNotEmpty || _placesByTheme.isNotEmpty;
      setState(() {
        if (hasData) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }
      });
    }
    final categories = await PlacebookCache.loadCategories();
    final themes = <Map<String, dynamic>>[];
    final placesByTheme = <String, List<Map<String, dynamic>>>{};
    final response = activeFilter == 'all'
        ? await ApiClient.fetchPlacebookThemesPlaces(
            themeOrderBy: activeThemeOrderBy,
            themeOrder: activeThemeOrder,
            themeOrderBy2: activeThemeOrderBy2,
            placeOrderBy: 'title',
            themeLimit: 200,
            themePage: 1,
            placeLimit: 3,
            placePage: 1,
            includeTotal: 0,
          )
        : await ApiClient.fetchMyPlacebookThemes(
            filter: _collectionFilter(activeFilter),
            themeOrderBy: activeThemeOrderBy,
            themeOrder: activeThemeOrder,
            themeOrderBy2: activeThemeOrderBy2,
            placeOrderBy: 'title',
            themeLimit: 200,
            themePage: 1,
            placeLimit: 3,
            placePage: 1,
            includeTotal: 0,
          );
    final items = _extractItems(response);
    for (final item in items) {
      final rawTheme = item['theme'];
      final rawThemeId = item['themeId'];
      Map<String, dynamic>? theme;
      if (rawTheme is Map<String, dynamic>) {
        theme = _resolveThemeData(rawTheme);
      } else if (rawThemeId is Map<String, dynamic>) {
        theme = _resolveThemeData(rawThemeId);
      }
      if (theme == null) continue;
      final themeId = _themeId(theme);
      if (themeId.isEmpty) continue;
      themes.add(theme);
      final rawPlaces = item['places'];
      final placeList = rawPlaces is List
          ? rawPlaces.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      placesByTheme[themeId] =
          placeList.map(_resolvePlaceData).toList(growable: false);
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _themes = themes;
      _placesByTheme = placesByTheme;
      if (!_hasFixedSearchThumbnails) {
        _searchThumbnails =
            _collectSearchThumbnails(placesByTheme, maxCount: 4);
        _hasFixedSearchThumbnails = true;
      }
      _isLoading = false;
      _isRefreshing = false;
    });
    _filterCache[cacheKey] = _PlacebookCacheSnapshot(
      categories: categories,
      themes: themes,
      placesByTheme: placesByTheme,
    );
    await _loadPlacebookInfo();
  }

  Future<void> _loadPlacebookPlacesList({
    String? filter,
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    final activeFilter = filter ?? _selectedCollection;
    if (loadMore) {
      if (_isLoadingMorePlaces || _isLoading || _isRefreshing) return;
      final nextCursor = _placesNextCursor;
      if (nextCursor == null || nextCursor.isEmpty) return;
      if (_placesRequestedCursor == nextCursor) return;
    }
    if (mounted) {
      if (loadMore) {
        setState(() => _isLoadingMorePlaces = true);
      } else {
        final hasData = _places.isNotEmpty;
        setState(() {
          if (hasData) {
            _isRefreshing = true;
          } else {
            _isLoading = true;
          }
        });
      }
    }
    if (!loadMore) {
      _placesNextCursor = null;
      _placesHasNext = true;
      _placesRequestedCursor = null;
    }
    if (!_placesHasNext && loadMore) {
      if (mounted) setState(() => _isLoadingMorePlaces = false);
      return;
    }
    final placeOrderBy = _placeOrderBy(_selectedPlaceSort);
    final placeOrder = _placeOrder(_selectedPlaceSort);
    final requestCursor = loadMore ? _placesNextCursor : null;
    _placesRequestedCursor = requestCursor;
    final response = await ApiClient.fetchPlacebookPlacesList(
      filter: _placeListFilter(activeFilter),
      limit: 20,
      orderBy: loadMore ? null : placeOrderBy,
      order: loadMore ? null : placeOrder,
      query: _searchText,
      cursor: requestCursor,
      cursorOnly: loadMore,
    );
    final items = _extractPlaceListItems(response)
        .map(_normalizePlaceListItem)
        .toList(growable: false);
    final dataNode = response['data'];
    final meta = dataNode is Map<String, dynamic> ? dataNode['meta'] : response['meta'];
    final hasNext = meta is Map<String, dynamic>
        ? (meta['hasNext'] as bool?) ?? false
        : false;
    final nextCursor = meta is Map<String, dynamic>
        ? meta['nextCursor']?.toString()
        : null;
    if (!mounted) return;
    setState(() {
      if (loadMore) {
        _places = _mergeUniquePlaces(_places, items);
      } else {
        _places = items;
      }
      _isLoading = false;
      _isRefreshing = false;
      _isLoadingMorePlaces = false;
      _placesRequestedCursor = null;
      final hasValidCursor = nextCursor?.isNotEmpty ?? false;
      final isSameCursor = hasValidCursor && nextCursor == _placesNextCursor;
      _placesHasNext = hasNext && hasValidCursor && !isSameCursor;
      _placesNextCursor = nextCursor;
    });
    // no place list cache (cursor-based pagination)
  }

  Future<void> _loadPlacebookInfo() async {
    debugPrint('[PLACEBOOK] load my-places/info');
    try {
      final info = await ApiClient.fetchMyPlacebookMyPlacesInfo();
      if (!mounted) return;
      setState(() {
        _createdCount = (info['createdCount'] as num?)?.toInt() ?? 0;
        _favoriteCount = (info['favoriteCount'] as num?)?.toInt() ?? 0;
        _totalCount = (info['publicTotalCount'] as num?)?.toInt() ??
            (info['totalCount'] as num?)?.toInt() ??
            0;
      });
    } catch (e) {
      debugPrint('[PLACEBOOK] info load failed: $e');
      if (!mounted) return;
      setState(() {
        _createdCount = _createdCount;
        _favoriteCount = _favoriteCount;
        _totalCount = _totalCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rootViewPadding =
        MediaQueryData.fromView(View.of(context)).viewPadding.bottom;
    final hasSearch = _searchText.trim().isNotEmpty;
    final isPlaceView = hasSearch || _selectedViewMode == 'place';
    final hasThemeData = _themes.isNotEmpty || _placesByTheme.isNotEmpty;
    final hasPlaceData = _places.isNotEmpty;
    final showInitialLoading = _isLoading && !(hasThemeData || hasPlaceData);
    final themes = _themes
        .whereType<Map<String, dynamic>>()
        .where((item) => item['isActive'] != false)
        .toList();
    if (!isPlaceView && _selectedThemeSort == 'title') {
      themes.sort((a, b) =>
          _themeTitle(a).toLowerCase().compareTo(_themeTitle(b).toLowerCase()));
    }
    final filteredPlacesByTheme = isPlaceView
        ? const <String, List<Map<String, dynamic>>>{}
        : _applySearchFilter(themes, _placesByTheme, _searchText);
    final filteredThemes = isPlaceView
        ? const <Map<String, dynamic>>[]
        : (_searchText.trim().isEmpty
            ? themes
            : themes
                .where(
                    (theme) => filteredPlacesByTheme.containsKey(_themeId(theme)))
                .toList());
    final filteredPlaces = isPlaceView ? _places : const [];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: showInitialLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 96,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (!(_selectedCollection == 'mine' &&
                                _searchThumbnails.isEmpty))
                              Positioned(
                                left: 24,
                                right: 16,
                                top: 12,
                                child: _SearchThumbnailStack(
                                  thumbnails: _searchThumbnails,
                                ),
                              ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 0,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 16,
                                            offset: const Offset(0, 0),
                                          ),
                                        ],
                                      ),
                                      child: CommonTextFieldView(
                                        controller: _searchController,
                                        hintText: '검색',
                                        textInputAction: TextInputAction.search,
                                        onChanged: _handleSearchChanged,
                                        onSubmitted: _handleSearchSubmitted,
                                        backgroundColor: Colors.white,
                                        prefixIcon: const Icon(
                                          PhosphorIconsRegular.magnifyingGlass,
                                          size: 18,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasSearch) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _handleSearchCancel,
                                      behavior: HitTestBehavior.opaque,
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          '취소',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                        _CollectionChip(
                          label: '전체',
                          selected: _selectedCollection == 'all',
                          badgeCount: _totalCount,
                          onTap: () {
                            if (_selectedCollection == 'all') return;
                            setState(() => _selectedCollection = 'all');
                            if (_searchText.trim().isNotEmpty ||
                                _selectedViewMode == 'place') {
                              _loadPlacebookPlacesList(filter: 'all');
                            } else {
                            _loadPlacebookData(
                              filter: 'all',
                              themeOrderBy: _themeOrderBy(_selectedThemeSort),
                              themeOrder: _themeOrder(_selectedThemeSort),
                              themeOrderBy2:
                                  _themeOrderBy2(_selectedThemeSort),
                            );
                            }
                            _scrollToTop();
                          },
                        ),
                        const SizedBox(width: 24),
                        _CollectionChip(
                          label: '나의 장소',
                          selected: _selectedCollection == 'mine',
                          badgeCount: _createdCount + _favoriteCount,
                          onTap: () {
                            if (_selectedCollection == 'mine') return;
                            setState(() => _selectedCollection = 'mine');
                            if (_searchText.trim().isNotEmpty ||
                                _selectedViewMode == 'place') {
                              _loadPlacebookPlacesList(filter: 'mine');
                            } else {
                              _loadPlacebookData(
                                filter: 'mine',
                                themeOrderBy: _themeOrderBy(_selectedThemeSort),
                                themeOrder: _themeOrder(_selectedThemeSort),
                                themeOrderBy2:
                                    _themeOrderBy2(_selectedThemeSort),
                              );
                            }
                            _scrollToTop();
                          },
                        ),
                      ],
                    ),
                  ),
                  if (!hasSearch) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                        GestureDetector(
                          onTap: () {
                            if (!isPlaceView) return;
                            setState(() => _selectedViewMode = 'theme');
                            _loadPlacebookData(
                              filter: _selectedCollection,
                              themeOrderBy: _themeOrderBy(_selectedThemeSort),
                              themeOrder: _themeOrder(_selectedThemeSort),
                              themeOrderBy2:
                                  _themeOrderBy2(_selectedThemeSort),
                            );
                            _scrollToTop();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsRegular.squaresFour,
                                size: 14,
                                color: !isPlaceView
                                    ? Colors.black
                                    : const Color(0x88000000),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '테마로 보기',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: !isPlaceView
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: !isPlaceView
                                      ? Colors.black
                                      : const Color(0x88000000),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: const Color(0x33000000),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (isPlaceView) return;
                            setState(() => _selectedViewMode = 'place');
                            _loadPlacebookPlacesList(
                              filter: _selectedCollection,
                            );
                            _scrollToTop();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsRegular.listBullets,
                                size: 14,
                                color: isPlaceView
                                    ? Colors.black
                                    : const Color(0x88000000),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '장소로 보기',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: isPlaceView
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isPlaceView
                                      ? Colors.black
                                      : const Color(0x88000000),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (!isPlaceView)
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_selectedThemeSort == 'places') return;
                                  setState(
                                      () => _selectedThemeSort = 'places');
                              _loadPlacebookData(
                                filter: _selectedCollection,
                                themeOrderBy: _themeOrderBy('places'),
                                themeOrder: _themeOrder('places'),
                                themeOrderBy2: _themeOrderBy2('places'),
                              );
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  '장소순',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: _selectedThemeSort == 'places'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedThemeSort == 'places'
                                        ? Colors.black
                                        : const Color(0x88000000),
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 12,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                color: const Color(0x33000000),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (_selectedThemeSort == 'title') return;
                                  setState(() => _selectedThemeSort = 'title');
                              _loadPlacebookData(
                                filter: _selectedCollection,
                                themeOrderBy: _themeOrderBy('title'),
                                themeOrder: _themeOrder('title'),
                                themeOrderBy2: _themeOrderBy2('title'),
                              );
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  '가나다순',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: _selectedThemeSort == 'title'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedThemeSort == 'title'
                                        ? Colors.black
                                        : const Color(0x88000000),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (isPlaceView)
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_selectedPlaceSort == 'latest') return;
                                  setState(
                                      () => _selectedPlaceSort = 'latest');
                                  _loadPlacebookPlacesList(
                                    filter: _selectedCollection,
                                    forceRefresh: true,
                                  );
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  '최신순',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: _selectedPlaceSort == 'latest'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedPlaceSort == 'latest'
                                        ? Colors.black
                                        : const Color(0x88000000),
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 12,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                color: const Color(0x33000000),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (_selectedPlaceSort == 'popular') return;
                                  setState(
                                      () => _selectedPlaceSort = 'popular');
                                  _loadPlacebookPlacesList(
                                    filter: _selectedCollection,
                                    forceRefresh: true,
                                  );
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  '인기순',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: _selectedPlaceSort == 'popular'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedPlaceSort == 'popular'
                                        ? Colors.black
                                        : const Color(0x88000000),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: isPlaceView
                        ? CommonRefreshView(
                            onRefresh: () => _loadPlacebookPlacesList(
                              filter: _selectedCollection,
                              forceRefresh: true,
                            ),
                            topPadding: 16,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.vertical,
                            child: _isLoading && filteredPlaces.isEmpty
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : filteredPlaces.isEmpty
                                    ? ListView(
                                        padding: EdgeInsets.only(
                                          top: 12,
                                          left: 16,
                                          right: 16,
                                          bottom: _kCommonTabHeight +
                                              rootViewPadding +
                                              MediaQuery.of(context)
                                                  .viewInsets
                                                  .bottom,
                                        ),
                                        children: const [
                                          CommonEmptyView(
                                            message: '검색 결과가 없습니다.',
                                            showButton: false,
                                            height: 200,
                                          ),
                                        ],
                                      )
                                    : NotificationListener<ScrollNotification>(
                                        onNotification: (notification) {
                                          if (_placesHasNext &&
                                              !_isLoadingMorePlaces &&
                                              notification
                                                      .metrics.extentAfter <
                                                  300) {
                                            _loadPlacebookPlacesList(
                                                loadMore: true);
                                          }
                                          return false;
                                        },
                                        child: ListView.separated(
                                          controller: _listController,
                                          padding: EdgeInsets.only(
                                            top: 12,
                                            left: 16,
                                            right: 16,
                                            bottom: _kCommonTabHeight +
                                                rootViewPadding +
                                                MediaQuery.of(context)
                                                    .viewInsets
                                                    .bottom,
                                          ),
                                          itemCount: filteredPlaces.length +
                                              (_placesHasNext ? 1 : 0),
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 4),
                                          itemBuilder: (context, index) {
                                            if (index >=
                                                filteredPlaces.length) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                child: Center(
                                                  child: _isLoadingMorePlaces
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : const SizedBox.shrink(),
                                                ),
                                              );
                                            }
                                            final place =
                                                filteredPlaces[index];
                                            final title = _placeTitle(place);
                                            final address =
                                                _placeAddress(place);
                                            final themeLabel =
                                                _placeThemeLabel(place);
                                            final thumbnail =
                                                _resolvePlaceImageUrl(place);
                                            final commentCount =
                                                (place['commentCount'] as num?)
                                                        ?.toInt() ??
                                                    0;
                                            final likeCount =
                                                (place['likeCount'] as num?)
                                                        ?.toInt() ??
                                                    0;
                                            final favorited =
                                                place['favorited'] == true;
                                            return CommonPlaceListItemView(
                                              thumbnailUrl: thumbnail,
                                              title: title,
                                              address: address,
                                              commentCount: commentCount,
                                              likeCount: likeCount,
                                              themeText: themeLabel,
                                              favorited: favorited,
                                              onTap: () async {
                                                final deleted =
                                                    await Navigator.of(context)
                                                        .push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        PlacebookDetailView(
                                                      space: place,
                                                    ),
                                                  ),
                                                );
                                                if (!mounted ||
                                                    deleted != true) {
                                                  return;
                                                }
                                                final deletedId =
                                                    place['id'] ??
                                                        place['placeId'];
                                                if (deletedId == null) {
                                                  _loadPlacebookPlacesList(
                                                    filter: _selectedCollection,
                                                    forceRefresh: true,
                                                  );
                                                  return;
                                                }
                                                setState(() {
                                                  _places = _places
                                                      .where((item) {
                                                        final id =
                                                            item['id'] ??
                                                                item['placeId'];
                                                        return id != deletedId;
                                                      })
                                                      .toList();
                                                });
                                                _loadPlacebookInfo();
                                              },
                                            );
                                          },
                                          addSemanticIndexes: false,
                                        ),
                                      ),
                          )
                        : filteredThemes.isEmpty
                            ? const CommonEmptyView(
                                message: '검색 결과가 없습니다.',
                                showButton: false,
                              )
                            : CommonRefreshView(
                                onRefresh: () => _loadPlacebookData(
                                  filter: _selectedCollection,
                                  forceRefresh: true,
                                ),
                                topPadding: 16,
                                notificationPredicate: (notification) =>
                                    notification.metrics.axis == Axis.vertical,
                                child: GridView.builder(
                                  controller: _listController,
                                  padding: EdgeInsets.only(
                                    top: 64,
                                    left: 16,
                                    right: 16,
                                    bottom: _kCommonTabHeight +
                                        rootViewPadding +
                                        MediaQuery.of(context)
                                            .viewInsets
                                            .bottom,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 64,
                                    childAspectRatio: 1.5,
                                  ),
                                  itemCount: filteredThemes.length,
                                  itemBuilder: (context, index) {
                                    final theme = filteredThemes[index];
                                    final title = _themeTitle(theme);
                                    final places =
                                        filteredPlacesByTheme[_themeId(theme)] ??
                                            const [];
                                    return PlacebookListItemView(
                                      title: title,
                                      placeCount: places.length,
                                      hasPlaces: places.isNotEmpty,
                                      thumbnails: places
                                          .map(_resolvePlaceImageUrl)
                                          .where((url) => url.isNotEmpty)
                                          .toList(),
                                      onTap: () async {
                                        final deleted =
                                            await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PlacebookCollectView(
                                              themeId: _themeId(theme),
                                              themeTitle: title,
                                            ),
                                          ),
                                        );
                                        if (!mounted || deleted != true) {
                                          return;
                                        }
                                        await _loadPlacebookData(
                                          filter: _selectedCollection,
                                          themeOrderBy:
                                              _themeOrderBy(_selectedThemeSort),
                                          themeOrder: _themeOrder(_selectedThemeSort),
                                          themeOrderBy2:
                                              _themeOrderBy2(_selectedThemeSort),
                                          forceRefresh: true,
                                        );
                                        await _loadPlacebookInfo();
                                      },
                                      onAddTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            fullscreenDialog: true,
                                            builder: (_) => PlacebookCreateView(
                                              themeId: _themeId(theme),
                                              themeTitle: title,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                  ),
                    ],
                  ),
          ),
          Positioned(
            right: 16,
            bottom: _kCommonTabHeight +
                rootViewPadding +
                MediaQuery.of(context).viewInsets.bottom,
            child: _PlacebookFloatingButton(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const PlacebookCreateView(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _collectSearchThumbnails(
  Map<String, List<Map<String, dynamic>>> placesByTheme, {
  int maxCount = 4,
}) {
  final urls = <String>[];
  for (final places in placesByTheme.values) {
    for (final place in places) {
      final url = _resolvePlaceImageUrl(place);
      if (url.isNotEmpty) {
        urls.add(url);
      }
      if (urls.length >= maxCount) return urls;
    }
  }
  return urls;
}

class _SearchThumbnailStack extends StatelessWidget {
  const _SearchThumbnailStack({
    required this.thumbnails,
  });

  final List<String> thumbnails;

  @override
  Widget build(BuildContext context) {
    final filled = List<String>.from(thumbnails);
    if (filled.length < 4) {
      filled.addAll(List.filled(4 - filled.length, ''));
    } else if (filled.length > 4) {
      filled.length = 4;
    }
    return SizedBox(
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < filled.length; i++)
            Positioned(
              left: i * 36,
              top: i.isEven ? 0 : 12,
              child: _SearchThumbnailItem(url: filled[i], index: i),
            ),
        ],
      ),
    );
  }
}

class _SearchThumbnailItem extends StatelessWidget {
  const _SearchThumbnailItem({
    required this.url,
    required this.index,
  });

  final String url;
  final int index;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final degrees = _rotationDegrees(url, index);
    return Transform.rotate(
      angle: degrees * (3.141592653589793 / 180),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CommonImageView(
            networkUrl: url,
            fit: BoxFit.cover,
            backgroundColor: const Color(0xFFF2F2F2),
          ),
        ),
      ),
    );
  }

  double _rotationDegrees(String seed, int index) {
    final value = seed.isEmpty ? index : seed.hashCode;
    final magnitude = 2 + (value.abs() % 4); // 2~5
    final sign = value.isEven ? 1 : -1;
    return magnitude * sign.toDouble();
  }
}


String _resolvePlaceImageUrl(Map<String, dynamic> place) {
  final idRaw = place['id'];
  final idMap = idRaw is Map<String, dynamic> ? idRaw : null;
  final thumbnailRaw = place['thumbnail'];
  final thumbnailMap = thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
  final imageIdRaw = place['imageId'];
  final imageIdMap = imageIdRaw is Map<String, dynamic> ? imageIdRaw : null;
  final imageRaw = place['image'];
  final imageMap = imageRaw is Map<String, dynamic> ? imageRaw : null;
  final idImageRaw = idMap?['image'];
  final idImageMap =
      idImageRaw is Map<String, dynamic> ? idImageRaw : null;
  final feed = place['feed'];
  final feedMap = feed is Map<String, dynamic> ? feed : null;
  final images = feedMap?['images'] ?? place['images'];
  Map<String, dynamic>? firstImageMap;
  String? firstImageString;
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is Map<String, dynamic>) {
      firstImageMap = first;
    } else if (first is String) {
      firstImageString = first;
    }
  }

  return _firstValidImageUrl([
    thumbnailRaw is String ? thumbnailRaw : null,
    place['thumbnailUrl'] as String?,
    place['imageUrl'] as String?,
    idMap?['thumbnailUrl'] as String?,
    idMap?['imageUrl'] as String?,
    thumbnailMap?['cdnUrl'] as String?,
    thumbnailMap?['fileUrl'] as String?,
    thumbnailMap?['thumbnailUrl'] as String?,
    imageIdMap?['cdnUrl'] as String?,
    imageIdMap?['fileUrl'] as String?,
    imageIdMap?['thumbnailUrl'] as String?,
    imageMap?['cdnUrl'] as String?,
    imageMap?['fileUrl'] as String?,
    imageMap?['thumbnailUrl'] as String?,
    idImageMap?['cdnUrl'] as String?,
    idImageMap?['fileUrl'] as String?,
    idImageMap?['thumbnailUrl'] as String?,
    firstImageMap?['thumbnailUrl'] as String?,
    firstImageMap?['cdnUrl'] as String?,
    firstImageMap?['fileUrl'] as String?,
    firstImageString,
  ]) ??
      '';
}

String? _firstValidImageUrl(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final cleaned = _cleanImageUrl(candidate);
    if (cleaned != null) return cleaned;
  }
  return null;
}

String? _cleanImageUrl(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final lowered = trimmed.toLowerCase();
  if (lowered == 'null' || lowered == 'undefined') return null;
  return trimmed;
}

List<Map<String, dynamic>> _extractItems(Map<String, dynamic> json) {
  final items = json['items'];
  if (items is List) {
    return items.whereType<Map<String, dynamic>>().toList();
  }
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    final nestedItems = data['items'];
    if (nestedItems is List) {
      return nestedItems.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

String _collectionFilter(String key) {
  switch (key) {
    case 'all':
      return 'all';
    case 'mine':
      return 'all';
    case 'favorites':
      return 'favorites';
    case 'created':
    default:
      return 'created';
  }
}

String _themeOrderBy(String key) {
  switch (key) {
    case 'title':
      return 'title';
    case 'places':
    default:
      return 'placeCount';
  }
}

String _themeOrder(String key) {
  switch (key) {
    case 'places':
      return 'DESC';
    case 'title':
    default:
      return 'ASC';
  }
}

String? _themeOrderBy2(String key) {
  return 'title';
}

Map<String, dynamic> _resolveThemeData(Map<String, dynamic> theme) {
  final idMap = theme['id'];
  if (idMap is Map<String, dynamic>) {
    return {...idMap, ...theme};
  }
  return theme;
}

Map<String, dynamic> _resolvePlaceData(Map<String, dynamic> place) {
  final idMap = place['id'];
  if (idMap is Map<String, dynamic>) {
    return {...idMap, ...place};
  }
  return place;
}

String _themeId(Map<String, dynamic> theme) {
  final id = theme['id'];
  if (id is String) return id;
  if (id is Map<String, dynamic>) {
    final inner = id['id'];
    if (inner != null) return inner.toString();
  }
  final themeId = theme['themeId'];
  return themeId?.toString() ?? '';
}

String _themeTitle(Map<String, dynamic> theme) {
  final title = (theme['title'] as String?) ??
      (theme['name'] as String?) ??
      '테마';
  return title.trim().isEmpty ? '테마' : title.trim();
}

String _themeSubtitle(Map<String, dynamic> theme) {
  final subtitle = theme['subtitle'];
  if (subtitle is String) {
    return subtitle.trim();
  }
  return '';
}

String _placeListFilter(String key) {
  switch (key) {
    case 'all':
      return 'all';
    case 'mine':
    default:
      return 'favorites_created';
  }
}

List<Map<String, dynamic>> _extractPlaceListItems(Map<String, dynamic> json) {
  final items = json['items'];
  if (items is List) {
    return items.whereType<Map<String, dynamic>>().toList();
  }
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    final nestedItems = data['items'];
    if (nestedItems is List) {
      return nestedItems.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

Map<String, dynamic> _normalizePlaceListItem(Map<String, dynamic> item) {
  final next = Map<String, dynamic>.from(item);
  final idRaw = item['id'];
  if (idRaw is Map<String, dynamic>) {
    next.remove('id');
    next.addAll(idRaw);
    final nestedId = idRaw['id'];
    if (nestedId != null) {
      next['id'] = nestedId.toString();
      next['placeId'] ??= nestedId.toString();
    }
  }
  return next;
}

Map<String, List<Map<String, dynamic>>> _applySearchFilter(
  List<Map<String, dynamic>> themes,
  Map<String, List<Map<String, dynamic>>> placesByTheme,
  String query,
) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) {
    return placesByTheme;
  }

  bool contains(String? source) {
    if (source == null) return false;
    return source.toLowerCase().contains(keyword);
  }

  final filtered = <String, List<Map<String, dynamic>>>{};
  for (final theme in themes) {
    final themeId = _themeId(theme);
    if (themeId.isEmpty) continue;
    final themeMatches = contains(_themeTitle(theme)) ||
        contains(_themeSubtitle(theme));
    final places = placesByTheme[themeId] ?? const [];
    if (themeMatches) {
      filtered[themeId] = places;
      continue;
    }
    final matchedPlaces = <Map<String, dynamic>>[];
    for (final place in places) {
      final title = (place['title'] as String?) ??
          (place['name'] as String?) ??
          '';
      final address = (place['address'] as String?) ??
          (place['placeName'] as String?) ??
          '';
      if (contains(title) || contains(address)) {
        matchedPlaces.add(place);
      }
    }
    if (matchedPlaces.isNotEmpty) {
      filtered[themeId] = matchedPlaces;
    }
  }
  return filtered;
}

List<Map<String, dynamic>> _applyPlaceSearchFilter(
  List<Map<String, dynamic>> places,
  String query,
) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return places;

  bool contains(String? source) {
    if (source == null) return false;
    return source.toLowerCase().contains(keyword);
  }

  return places.where((place) {
    final title = _placeTitle(place);
    final address = _placeAddress(place);
    final themeLabel = _placeThemeLabel(place);
    return contains(title) || contains(address) || contains(themeLabel);
  }).toList();
}

String _placeTitle(Map<String, dynamic> place) {
  final title = (place['title'] as String?) ??
      (place['name'] as String?) ??
      (place['placeName'] as String?) ??
      '장소';
  return title.trim().isEmpty ? '장소' : title.trim();
}

String _placeAddress(Map<String, dynamic> place) {
  final address = (place['address'] as String?) ??
      (place['placeName'] as String?) ??
      (place['location'] as String?) ??
      '';
  return address.trim().isEmpty ? '장소 등록 안됨' : address.trim();
}

String _placeThemeLabel(Map<String, dynamic> place) {
  final theme = place['theme'];
  if (theme is Map<String, dynamic>) {
    final title = (theme['title'] as String?) ?? (theme['name'] as String?);
    if (title != null && title.trim().isNotEmpty) return title.trim();
  }
  final raw = place['themeTitle'] as String? ?? place['themeName'] as String?;
  return raw?.trim() ?? '';
}

List<Map<String, dynamic>> _mergeUniquePlaces(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  final merged = <Map<String, dynamic>>[];
  final seen = <String>{};

  String placeIdOf(Map<String, dynamic> place) {
    final id = place['id'] ?? place['placeId'];
    if (id is String && id.isNotEmpty) return id;
    return id?.toString() ?? '';
  }

  for (final place in existing) {
    final id = placeIdOf(place);
    if (id.isNotEmpty) seen.add(id);
    merged.add(place);
  }
  for (final place in incoming) {
    final id = placeIdOf(place);
    if (id.isNotEmpty && seen.contains(id)) continue;
    if (id.isNotEmpty) seen.add(id);
    merged.add(place);
  }
  return merged;
}

class _PlacebookFloatingButton extends StatelessWidget {
  const _PlacebookFloatingButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          PhosphorIconsBold.plus,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

String _placeOrderBy(String key) {
  switch (key) {
    case 'popular':
      return 'popularity';
    case 'latest':
    default:
      return 'createdAt';
  }
}

String _placeOrder(String key) {
  switch (key) {
    case 'popular':
      return 'DESC';
    case 'latest':
    default:
      return 'DESC';
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.black : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -6,
              right: -12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  badgeCount.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlacebookCacheSnapshot {
  const _PlacebookCacheSnapshot({
    required this.categories,
    required this.themes,
    required this.placesByTheme,
  });

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> themes;
  final Map<String, List<Map<String, dynamic>>> placesByTheme;
}
