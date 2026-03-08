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
  List<String> _searchThumbnails = const [];
  bool _hasFixedSearchThumbnails = false;
  int _createdCount = 0;
  int _favoriteCount = 0;
  int _totalCount = 0;
  String _selectedThemeSort = 'places';
  String _selectedCollection = 'mine';
  late final VoidCallback _tabListener;
  final ScrollController _listController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
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
    setState(() => _searchText = value);
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
    final cacheKey =
        '$activeFilter|$activeThemeOrderBy|${activeThemeOrderBy2 ?? ''}';
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
            themeOrderBy2: activeThemeOrderBy2,
            placeOrderBy: 'title',
            themeLimit: 200,
            themePage: 1,
            placeLimit: 4,
            placePage: 1,
            includeTotal: 1,
          )
        : await ApiClient.fetchMyPlacebookThemes(
            filter: _collectionFilter(activeFilter),
            themeOrderBy: activeThemeOrderBy,
            themeOrderBy2: activeThemeOrderBy2,
            placeOrderBy: 'title',
            themeLimit: 200,
            themePage: 1,
            placeLimit: 4,
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
                              left: 24,
                              right: 16,
                              top: 4,
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
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: CommonTextFieldView(
                                  controller: _searchController,
                                  hintText: '검색',
                                  textInputAction: TextInputAction.search,
                                  onChanged: _handleSearchChanged,
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
                            _loadPlacebookData(
                              filter: 'all',
                              themeOrderBy: _themeOrderBy(_selectedThemeSort),
                              themeOrderBy2: _themeOrderBy2(_selectedThemeSort),
                            );
                            _scrollToTop();
                          },
                        ),
                        const SizedBox(width: 16),
                        _CollectionChip(
                          label: '나의 장소',
                          selected: _selectedCollection == 'mine',
                          badgeCount: _createdCount + _favoriteCount,
                          onTap: () {
                            if (_selectedCollection == 'mine') return;
                            setState(() => _selectedCollection = 'mine');
                            _loadPlacebookData(
                              filter: 'mine',
                              themeOrderBy: _themeOrderBy(_selectedThemeSort),
                              themeOrderBy2: _themeOrderBy2(_selectedThemeSort),
                            );
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredThemes.isEmpty
                        ? const CommonEmptyView(
                            message: '검색 결과가 없습니다.',
                            showButton: false,
                          )
                        : CommonRefreshView(
                            onRefresh: () => _loadPlacebookData(
                              filter: _selectedCollection,
                              forceRefresh: true,
                            ),
                            topPadding: 12,
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
                                    MediaQuery.of(context).viewInsets.bottom,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 64,
                                childAspectRatio: 2.0,
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
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PlacebookCollectView(
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
      return 'hasPlaces';
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
              right: -6,
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
