import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/state/placebook_cache.dart';
import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../placebook/widgets/placebook_item_view.dart';
import '../placebook/widgets/placebook_empty_view.dart';
import '../placebook_create/placebook_create_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import '../placebook_collect/placebook_collect_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_textfield_view.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_place_list_item_view.dart';

class PlacebookView extends StatefulWidget {
  const PlacebookView({
    super.key,
    this.initialThemeId,
    this.initialThemeTitle,
  });

  final String? initialThemeId;
  final String? initialThemeTitle;

  @override
  State<PlacebookView> createState() => _PlacebookViewState();
}

class _PlacebookViewState extends State<PlacebookView> {
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
  String? _placeListThemeId;
  String? _placesNextCursor;
  bool _placesHasNext = true;
  bool _isLoadingMorePlaces = false;
  String? _placesRequestedCursor;
  late final VoidCallback _tabListener;
  bool _didInitialLoad = false;
  final ScrollController _listController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _pendingSearchText = '';
  final Map<String, _PlacebookCacheSnapshot> _filterCache = {};

  @override
  void initState() {
    super.initState();
    if ((widget.initialThemeId ?? '').trim().isNotEmpty) {
      _selectedViewMode = 'place';
      _selectedCollection = 'all';
      _placeListThemeId = widget.initialThemeId?.trim();
    }
    if (HomeTabController.currentIndex.value == 2) {
      _loadInitialIfNeeded();
    }
    _tabListener = () {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 2) {
        _loadInitialIfNeeded();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _loadPlacebookInfo();
        });
      }
    };
    HomeTabController.currentIndex.addListener(_tabListener);
  }

  void _loadInitialIfNeeded() {
    if (_didInitialLoad) return;
    _didInitialLoad = true;
    if (_selectedViewMode == 'place') {
      _loadPlacebookPlacesList(filter: _selectedCollection, forceRefresh: true);
    } else {
      _loadPlacebookData();
    }
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

  void _handleSearchSubmit() {
    final next = _pendingSearchText.trim();
    if (next == _searchText.trim()) return;
    setState(() => _searchText = next);
    _scrollToTop();
    if (_selectedViewMode == 'place') {
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
    bool forceRefresh = false,
  }) async {
    final activeFilter = filter ?? _selectedCollection;
    final activeThemeOrderBy = themeOrderBy ?? _themeOrderBy(_selectedThemeSort);
    final activeThemeOrderBy2 =
        themeOrderBy2 ?? _themeOrderBy2(_selectedThemeSort);
    final activeThemeOrder = _themeOrder(_selectedThemeSort);
    final cacheKey =
        '$activeFilter|$activeThemeOrderBy|$activeThemeOrder|${activeThemeOrderBy2 ?? ''}';
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
    }
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
      themeIds: _placeListThemeId?.isNotEmpty == true
          ? [_placeListThemeId!]
          : null,
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
  }

  Map<String, dynamic> _resolveThemeData(Map<String, dynamic> theme) {
    final next = Map<String, dynamic>.from(theme);
    final category = theme['category'];
    if (category is Map<String, dynamic>) {
      next['categoryId'] ??= category['id'];
      next['categoryTitle'] ??= category['title'];
      next['categorySubtitle'] ??= category['subtitle'];
    }
    return next;
  }

  Map<String, dynamic> _resolvePlaceData(Map<String, dynamic> place) {
    final next = Map<String, dynamic>.from(place);
    final idRaw = place['id'];
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

  String _themeOrderBy(String sort) {
    return sort == 'title' ? 'title' : 'placeCount';
  }

  String? _themeOrderBy2(String sort) {
    return sort == 'title' ? null : 'title';
  }

  String _themeOrder(String sort) {
    return sort == 'title' ? 'ASC' : 'DESC';
  }

  String _placeOrderBy(String sort) {
    return sort == 'title' ? 'title' : 'createdAt';
  }

  String _placeOrder(String sort) {
    return sort == 'title' ? 'ASC' : 'DESC';
  }

  String _collectionFilter(String filter) {
    if (filter == 'mine') return 'all';
    return 'all';
  }

  String _placeListFilter(String filter) {
    if (filter == 'mine') return 'favorites_created';
    return 'all';
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    final items = response['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _extractPlaceListItems(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    final items = response['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _normalizePlaceListItem(Map<String, dynamic> place) {
    final next = Map<String, dynamic>.from(place);
    final idRaw = place['id'];
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

  List<Map<String, dynamic>> _mergeUniquePlaces(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> next,
  ) {
    final ids = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final item in current) {
      final id = (item['id'] ?? item['placeId'])?.toString();
      if (id == null || ids.contains(id)) continue;
      ids.add(id);
      merged.add(item);
    }
    for (final item in next) {
      final id = (item['id'] ?? item['placeId'])?.toString();
      if (id == null || ids.contains(id)) continue;
      ids.add(id);
      merged.add(item);
    }
    return merged;
  }

  Map<String, List<Map<String, dynamic>>> _applySearchFilter(
    List<Map<String, dynamic>> themes,
    Map<String, List<Map<String, dynamic>>> placesByTheme,
    String query,
  ) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return Map<String, List<Map<String, dynamic>>>.from(placesByTheme);
    }
    final filtered = <String, List<Map<String, dynamic>>>{};
    for (final theme in themes) {
      final themeId = _themeId(theme);
      if (themeId.isEmpty) continue;
      final themeTitle = _themeTitle(theme).toLowerCase();
      final places = placesByTheme[themeId] ?? const [];
      final matchingPlaces = places.where((place) {
        final title = (place['title'] ?? '').toString().toLowerCase();
        final address = (place['address'] ?? '').toString().toLowerCase();
        return title.contains(trimmed) || address.contains(trimmed);
      }).toList();
      if (matchingPlaces.isNotEmpty || themeTitle.contains(trimmed)) {
        filtered[themeId] = matchingPlaces.isNotEmpty ? matchingPlaces : places;
      }
    }
    return filtered;
  }

  String _themeId(Map<String, dynamic> theme) {
    final raw = theme['id'] ?? theme['themeId'];
    if (raw is Map<String, dynamic>) {
      return (raw['id'] ?? '').toString();
    }
    return raw?.toString() ?? '';
  }

  String _themeTitle(Map<String, dynamic> theme) {
    return (theme['title'] ?? theme['name'] ?? '').toString();
  }

  String _resolvePlaceImageUrl(Map<String, dynamic> place) {
    final image = place['image'];
    if (image is Map<String, dynamic>) {
      return _firstValidImageUrl(image);
    }
    final thumbnail = place['thumbnail'];
    if (thumbnail is Map<String, dynamic>) {
      return _firstValidImageUrl(thumbnail);
    }
    return '';
  }

  String _firstValidImageUrl(Map<String, dynamic> image) {
    final cdn = image['cdnUrl']?.toString().trim();
    if (cdn != null && cdn.isNotEmpty) return cdn;
    final thumb = image['thumbnailUrl']?.toString().trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final file = image['fileUrl']?.toString().trim();
    if (file != null && file.isNotEmpty) return file;
    return '';
  }

  List<String> _collectSearchThumbnails(
    Map<String, List<Map<String, dynamic>>> placesByTheme, {
    int maxCount = 4,
  }) {
    final thumbnails = <String>[];
    for (final entry in placesByTheme.entries) {
      for (final place in entry.value) {
        if (thumbnails.length >= maxCount) break;
        thumbnails.add(_resolvePlaceImageUrl(place));
      }
      if (thumbnails.length >= maxCount) break;
    }
    if (thumbnails.length < maxCount) {
      thumbnails.addAll(List.filled(maxCount - thumbnails.length, ''));
    }
    return thumbnails;
  }

  @override
  Widget build(BuildContext context) {
    final rootViewPadding =
        MediaQueryData.fromView(View.of(context)).viewPadding.bottom;
    final themes = _themes
        .whereType<Map<String, dynamic>>()
        .where((item) => item['isActive'] != false)
        .toList();
    if (_selectedThemeSort == 'title') {
      themes.sort((a, b) =>
          _themeTitle(a).toLowerCase().compareTo(_themeTitle(b).toLowerCase()));
    }
    final filteredPlacesByTheme =
        _applySearchFilter(themes, _placesByTheme, _searchText);
    final filteredThemes = _searchText.trim().isEmpty
        ? themes
        : themes
            .where((theme) => filteredPlacesByTheme.containsKey(_themeId(theme)))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: true,
        bottom: false,
        child: _isLoading
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
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 0,
                          child: _SearchThumbnailStack(
                            thumbnails: _searchThumbnails,
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CommonTextFieldView(
                              controller: _searchController,
                              hintText: '검색',
                              textInputAction: TextInputAction.search,
                              onChanged: _handleSearchChanged,
                              onSubmitted: (_) => _handleSearchSubmit(),
                              backgroundColor: Colors.white,
                              prefixIcon: const Icon(
                                PhosphorIconsRegular.magnifyingGlass,
                                size: 18,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Spacer(),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_selectedThemeSort == 'places') return;
                                setState(() => _selectedThemeSort = 'places');
                                _loadPlacebookData(
                                  filter: _selectedCollection,
                                  themeOrderBy: _themeOrderBy('places'),
                                  themeOrderBy2: _themeOrderBy2('places'),
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                '장소 순',
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
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                if (_selectedThemeSort == 'title') return;
                                setState(() => _selectedThemeSort = 'title');
                                _loadPlacebookData(
                                  filter: _selectedCollection,
                                  themeOrderBy: _themeOrderBy('title'),
                                  themeOrderBy2: _themeOrderBy2('title'),
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                '가나다',
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
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {
                                if (_selectedViewMode == 'theme') return;
                                setState(() => _selectedViewMode = 'theme');
                                _placeListThemeId = null;
                                _loadPlacebookData(
                                  filter: _selectedCollection,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                '테마로 보기',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: _selectedViewMode == 'theme'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedViewMode == 'theme'
                                      ? Colors.black
                                      : const Color(0x88000000),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                if (_selectedViewMode == 'place') return;
                                setState(() => _selectedViewMode = 'place');
                                _loadPlacebookPlacesList(
                                  filter: _selectedCollection,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                '장소로 보기',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: _selectedViewMode == 'place'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedViewMode == 'place'
                                      ? Colors.black
                                      : const Color(0x88000000),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _selectedViewMode == 'place'
                        ? _PlaceListView(
                            places: _places,
                            isLoading: _isLoading,
                            isRefreshing: _isRefreshing,
                            isLoadingMore: _isLoadingMorePlaces,
                            onRefresh: () => _loadPlacebookPlacesList(
                              filter: _selectedCollection,
                              forceRefresh: true,
                            ),
                            onLoadMore: () => _loadPlacebookPlacesList(
                              filter: _selectedCollection,
                              loadMore: true,
                            ),
                          )
                        : _ThemeGridView(
                            themes: filteredThemes,
                            placesByTheme: filteredPlacesByTheme,
                            isRefreshing: _isRefreshing,
                            onRefresh: () => _loadPlacebookData(
                              filter: _selectedCollection,
                              forceRefresh: true,
                            ),
                          ),
                  ),
                  SizedBox(height: rootViewPadding == 0 ? 12 : rootViewPadding),
                ],
              ),
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

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final safeCount = badgeCount < 0 ? 0 : badgeCount;
    final textColor = selected ? Colors.black : const Color(0xFF9E9E9E);
    final badgeBg = selected ? Colors.black : const Color(0xFFF2F2F2);
    final badgeText = selected ? Colors.white : const Color(0xFF757575);
    return CommonInkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$safeCount',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchThumbnailStack extends StatelessWidget {
  const _SearchThumbnailStack({
    required this.thumbnails,
  });

  final List<String> thumbnails;

  @override
  Widget build(BuildContext context) {
    final items = thumbnails.isNotEmpty
        ? thumbnails
        : List.filled(4, '');
    const double size = 64;
    const double overlap = 22;
    return SizedBox(
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: i * overlap,
              top: 0,
              child: _SearchThumbnailItem(
                url: items[i],
                index: i,
                size: size,
              ),
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
    required this.size,
  });

  final String url;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rotation = _rotationDegrees(url, index);
    return Transform.rotate(
      angle: rotation * (3.141592653589793 / 180),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CommonImageView(
            networkUrl: url.isEmpty ? null : url,
            fit: BoxFit.cover,
            backgroundColor: const Color(0xFFF2F2F2),
          ),
        ),
      ),
    );
  }

  double _rotationDegrees(String seed, int index) {
    final value = seed.isEmpty ? index * 31 : seed.hashCode;
    final magnitude = 2 + (value.abs() % 4); // 2~5
    final sign = value.isEven ? 1 : -1;
    return magnitude * sign.toDouble();
  }
}

class _ThemeGridView extends StatelessWidget {
  const _ThemeGridView({
    required this.themes,
    required this.placesByTheme,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> themes;
  final Map<String, List<Map<String, dynamic>>> placesByTheme;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (themes.isEmpty) {
      return CommonRefreshView(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 48),
            CommonEmptyView(
              message: '등록된 테마가 없습니다.',
              showButton: false,
            ),
          ],
        ),
      );
    }
    return CommonRefreshView(
      onRefresh: onRefresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 100,
        ),
        itemCount: themes.length,
        itemBuilder: (context, index) {
          final theme = themes[index];
          final themeId = _themeIdFromTheme(theme);
          final title = (theme['title'] ?? '').toString();
          final places = placesByTheme[themeId] ?? const [];
          final placeCount =
              (theme['placeCount'] as num?)?.toInt() ?? places.length;
          final thumbnails = places
              .map(_resolvePlaceImageUrl)
              .where((url) => url.trim().isNotEmpty)
              .toList();
          return PlacebookItemView(
            title: title,
            placeCount: placeCount,
            thumbnails: thumbnails,
            hasPlaces: placeCount > 0,
            onTap: () {
              if (themeId.isEmpty) return;
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => PlacebookCollectView(
                    themeId: themeId,
                    themeTitle: title,
                  ),
                ),
              );
            },
            onAddTap: () {
              if (themeId.isEmpty) return;
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => PlacebookCreateView(
                    themeId: themeId,
                    themeTitle: title,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _themeIdFromTheme(Map<String, dynamic> theme) {
    final raw = theme['id'] ?? theme['themeId'];
    if (raw is Map<String, dynamic>) {
      return (raw['id'] ?? '').toString();
    }
    return raw?.toString() ?? '';
  }

  String _resolvePlaceImageUrl(Map<String, dynamic> place) {
    final image = place['image'];
    if (image is Map<String, dynamic>) {
      return _firstValidImageUrl(image);
    }
    final thumbnail = place['thumbnail'];
    if (thumbnail is Map<String, dynamic>) {
      return _firstValidImageUrl(thumbnail);
    }
    return '';
  }

  String _firstValidImageUrl(Map<String, dynamic> image) {
    final cdn = image['cdnUrl']?.toString().trim();
    if (cdn != null && cdn.isNotEmpty) return cdn;
    final thumb = image['thumbnailUrl']?.toString().trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final file = image['fileUrl']?.toString().trim();
    if (file != null && file.isNotEmpty) return file;
    return '';
  }
}

class _PlaceListView extends StatelessWidget {
  const _PlaceListView({
    required this.places,
    required this.isLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final List<Map<String, dynamic>> places;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty && !isLoading) {
      return CommonRefreshView(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: const [
            CommonEmptyView(
              message: '등록된 장소가 없습니다.',
              showButton: false,
            ),
          ],
        ),
      );
    }
    return CommonRefreshView(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 200) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: places.length + (isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index >= places.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final place = places[index];
            final title = (place['title'] ?? '').toString();
            final address = (place['address'] ?? '').toString();
            final commentCount = (place['commentCount'] as num?)?.toInt() ?? 0;
            final likeCount = (place['likeCount'] as num?)?.toInt() ?? 0;
            final theme = place['theme'];
            final themeText =
                theme is Map<String, dynamic> ? theme['title']?.toString() : null;
            final distanceKm = place['distanceKm'];
            final distanceText = distanceKm is num
                ? '${distanceKm.toStringAsFixed(distanceKm < 1 ? 2 : 1)}km'
                : null;
            final favorited = (place['favorited'] as bool?) ??
                (place['isFavorited'] as bool?) ??
                false;
            final placeId = (place['id'] ?? place['placeId'])?.toString() ?? '';
            final themeId =
                theme is Map<String, dynamic> ? theme['id']?.toString() : null;
            final themeTitle =
                theme is Map<String, dynamic> ? theme['title']?.toString() : null;
            return CommonPlaceListItemView(
              thumbnailUrl: _resolvePlaceImageUrl(place),
              title: title,
              address: address,
              commentCount: commentCount,
              likeCount: likeCount,
              themeText: themeText,
              distanceText: distanceText,
              favorited: favorited,
              onTap: () {
                if (placeId.isEmpty) return;
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => PlacebookDetailView(
                      space: place,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _resolvePlaceImageUrl(Map<String, dynamic> place) {
    final image = place['image'];
    if (image is Map<String, dynamic>) {
      return _firstValidImageUrl(image);
    }
    final thumbnail = place['thumbnail'];
    if (thumbnail is Map<String, dynamic>) {
      return _firstValidImageUrl(thumbnail);
    }
    return '';
  }

  String _firstValidImageUrl(Map<String, dynamic> image) {
    final cdn = image['cdnUrl']?.toString().trim();
    if (cdn != null && cdn.isNotEmpty) return cdn;
    final thumb = image['thumbnailUrl']?.toString().trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final file = image['fileUrl']?.toString().trim();
    if (file != null && file.isNotEmpty) return file;
    return '';
  }
}
