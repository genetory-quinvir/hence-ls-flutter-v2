import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_place_list_item_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../placebook_detail/placebook_detail_view.dart';

enum PlacebookListSource {
  all,
  created,
  favorites,
}

class PlacebookListView extends StatefulWidget {
  const PlacebookListView({
    super.key,
    this.themeId,
    this.themeTitle,
    this.latitude,
    this.longitude,
    this.orderBy,
    this.source = PlacebookListSource.all,
    this.showNavigation = true,
    this.scrollHeader,
    this.headerScrollable = false,
  });

  final String? themeId;
  final String? themeTitle;
  final double? latitude;
  final double? longitude;
  final String? orderBy;
  final PlacebookListSource source;
  final bool showNavigation;
  final Widget? scrollHeader;
  final bool headerScrollable;

  @override
  State<PlacebookListView> createState() => _PlacebookListViewState();
}

class _PlacebookListViewState extends State<PlacebookListView> {
  final List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasNext = true;
  String? _nextCursor;
  String? _requestedCursor;
  double? _latitude;
  double? _longitude;
  String _selectedSort = 'latest';
  String _selectedScope = 'all';

  @override
  void initState() {
    super.initState();
    _latitude = widget.latitude;
    _longitude = widget.longitude;
    if (widget.orderBy == 'distance') {
      _selectedSort = 'distance';
    } else if (widget.orderBy == 'popular') {
      _selectedSort = 'popular';
    }
    if (_latitude == null || _longitude == null) {
      _loadWithLocation();
    } else {
      _loadPlaces();
    }
  }

  Future<void> _loadWithLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final granted = await LocationPermissionService.isGranted();
      if (serviceEnabled && granted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        _latitude = position.latitude;
        _longitude = position.longitude;
      }
    } on Exception {
      // ignore
    }
    if (mounted) {
      _loadPlaces(forceRefresh: true);
    }
  }

  Future<void> _loadPlaces({
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      if (_isLoadingMore || _isLoading || _isRefreshing) return;
      final nextCursor = _nextCursor;
      if (nextCursor == null || nextCursor.isEmpty) return;
      if (_requestedCursor == nextCursor) return;
    }
    if (mounted) {
      if (loadMore) {
        setState(() => _isLoadingMore = true);
      } else {
        setState(() {
          if (_places.isNotEmpty) {
            _isRefreshing = true;
          } else {
            _isLoading = true;
          }
        });
      }
    }
    if (!loadMore) {
      _nextCursor = null;
      _hasNext = true;
      _requestedCursor = null;
    }
    if (!_hasNext && loadMore) {
      if (mounted) setState(() => _isLoadingMore = false);
      return;
    }
    final requestCursor = loadMore ? _nextCursor : null;
    _requestedCursor = requestCursor;
    final orderBy = _orderByForSort(_selectedSort);
    final order = orderBy == 'distance' ? 'ASC' : 'DESC';
    final response = await _fetchPlaces(
      orderBy: orderBy,
      order: order,
      cursor: requestCursor,
      loadMore: loadMore,
    );
    final items = _extractPlaceListItems(response)
        .map(_normalizePlaceListItem)
        .toList(growable: false);
    final dataNode = response['data'];
    final meta =
        dataNode is Map<String, dynamic> ? dataNode['meta'] : response['meta'];
    final hasNext =
        meta is Map<String, dynamic> ? (meta['hasNext'] as bool?) ?? false : false;
    final nextCursor =
        meta is Map<String, dynamic> ? meta['nextCursor']?.toString() : null;
    if (!mounted) return;
    setState(() {
      if (loadMore) {
        _places.addAll(items);
      } else {
        _places
          ..clear()
          ..addAll(items);
      }
      _isLoading = false;
      _isRefreshing = false;
      _isLoadingMore = false;
      _requestedCursor = null;
      final hasValidCursor = nextCursor?.isNotEmpty ?? false;
      final isSameCursor = hasValidCursor && nextCursor == _nextCursor;
      _hasNext = hasNext && hasValidCursor && !isSameCursor;
      _nextCursor = nextCursor;
    });
  }

  bool get _hasThemeFilter => _themeId.isNotEmpty;

  String get _themeId => (widget.themeId ?? '').trim();

  String get _title =>
      (widget.themeTitle ?? '').trim().isNotEmpty
          ? widget.themeTitle!.trim()
          : _titleForSource();

  bool get _showSort => true;
  bool get _showScopeToggle => widget.source == PlacebookListSource.all;

  String _titleForSource() {
    switch (widget.source) {
      case PlacebookListSource.created:
        return '나의 장소';
      case PlacebookListSource.favorites:
        return '찜한 장소';
      case PlacebookListSource.all:
      default:
        return '장소 목록';
    }
  }

  String _orderByForSort(String sort) {
    switch (sort) {
      case 'popular':
        return 'favoriteCount';
      case 'distance':
        return 'distance';
      case 'latest':
      default:
        return 'createdAt';
    }
  }

  void _handleSortTap(String next) {
    if (_selectedSort == next) return;
    setState(() => _selectedSort = next);
    if (_latitude == null || _longitude == null) {
      _loadWithLocation();
      return;
    }
    _loadPlaces(forceRefresh: true);
  }

  void _handleScopeTap(String next) {
    if (_selectedScope == next) return;
    setState(() => _selectedScope = next);
    _loadPlaces(forceRefresh: true);
  }

  Future<Map<String, dynamic>> _fetchPlaces({
    required String orderBy,
    required String order,
    required String? cursor,
    required bool loadMore,
  }) {
    switch (widget.source) {
      case PlacebookListSource.created:
        return ApiClient.fetchPlacebookCreatedPlacesList(
          limit: 20,
          orderBy: orderBy,
          order: order,
          cursor: cursor,
          latitude: _latitude,
          longitude: _longitude,
        );
      case PlacebookListSource.favorites:
        return ApiClient.fetchPlacebookFavoritePlacesList(
          limit: 20,
          orderBy: orderBy,
          order: order,
          cursor: cursor,
          latitude: _latitude,
          longitude: _longitude,
        );
      case PlacebookListSource.all:
      default:
        return ApiClient.fetchPlacebookPlacesList(
          filter: _selectedScope == 'my' ? 'mine' : 'all',
          limit: 20,
          orderBy: loadMore ? null : orderBy,
          order: loadMore ? null : order,
          themeIds: _hasThemeFilter ? [_themeId] : null,
          latitude: _latitude,
          longitude: _longitude,
          cursor: cursor,
          cursorOnly: loadMore,
        );
    }
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

  String _resolvePlaceImageUrl(Map<String, dynamic> place) {
    final image = place['image'];
    if (image is Map<String, dynamic>) {
      return _firstValidImageUrl(image);
    }
    if (image is String && image.trim().isNotEmpty) {
      return image.trim();
    }
    final thumbnail = place['thumbnail'];
    if (thumbnail is Map<String, dynamic>) {
      return _firstValidImageUrl(thumbnail);
    }
    if (thumbnail is String && thumbnail.trim().isNotEmpty) {
      return thumbnail.trim();
    }
    final thumbnailImage = place['thumbnailImage'];
    if (thumbnailImage is Map<String, dynamic>) {
      return _firstValidImageUrl(thumbnailImage);
    }
    if (thumbnailImage is String && thumbnailImage.trim().isNotEmpty) {
      return thumbnailImage.trim();
    }
    final representative = place['representativeImage'];
    if (representative is Map<String, dynamic>) {
      return _firstValidImageUrl(representative);
    }
    if (representative is String && representative.trim().isNotEmpty) {
      return representative.trim();
    }
    final photo = place['photo'];
    if (photo is Map<String, dynamic>) {
      return _firstValidImageUrl(photo);
    }
    if (photo is String && photo.trim().isNotEmpty) {
      return photo.trim();
    }
    final directUrlRaw = place['thumbnailUrl'];
    if (directUrlRaw is Map<String, dynamic>) {
      final url = _firstValidImageUrl(directUrlRaw);
      if (url.isNotEmpty) return url;
    }
    final directUrl = directUrlRaw ??
        place['thumbnailImageUrl'] ??
        place['imageUrl'] ??
        place['representativeImageUrl'] ??
        place['mainImageUrl'] ??
        place['coverImageUrl'];
    if (directUrl is String && directUrl.trim().isNotEmpty) {
      return directUrl.trim();
    }
    final images = place['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
      if (first is Map<String, dynamic>) {
        final url = _firstValidImageUrl(first);
        if (url.isNotEmpty) return url;
      }
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

  @override
  Widget build(BuildContext context) {
    final showHeaderInList = widget.headerScrollable && widget.scrollHeader != null;
    final body = Column(
      children: [
        if (widget.showNavigation)
          CommonNavigationView(
            height: 50,
            backgroundColor: Colors.white,
            left: const Icon(
              PhosphorIconsBold.caretLeft,
              size: 24,
              color: Colors.black,
            ),
            onLeftTap: () => Navigator.of(context).maybePop(),
            title: _title,
          ),
        if (_showSort && !showHeaderInList)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildSortRow(),
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
              : CommonRefreshView(
                  onRefresh: () => _loadPlaces(forceRefresh: true),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.extentAfter < 200) {
                        _loadPlaces(loadMore: true);
                      }
                      return false;
                    },
                    child: _places.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            children: [
                              if (showHeaderInList) widget.scrollHeader!,
                              if (showHeaderInList)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 16, 0, 12),
                                  child: _buildSortRow(),
                                ),
                              const CommonEmptyView(
                                message: '등록된 장소가 없습니다.',
                                showButton: false,
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _places.length +
                                (_isLoadingMore ? 1 : 0) +
                                (showHeaderInList ? 2 : 0),
                            itemBuilder: (context, index) {
                              if (showHeaderInList && index == 0) {
                                return widget.scrollHeader!;
                              }
                              if (showHeaderInList && index == 1) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 16, 0, 12),
                                  child: _buildSortRow(),
                                );
                              }
                              final dataIndex =
                                  index - (showHeaderInList ? 2 : 0);
                              if (dataIndex >= _places.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final place = _places[dataIndex];
                              final title = (place['title'] ?? '').toString();
                              final address = (place['address'] ?? '').toString();
                              final commentCount =
                                  (place['commentCount'] as num?)?.toInt() ?? 0;
                              final likeCount =
                                  (place['likeCount'] as num?)?.toInt() ?? 0;
                              final theme = place['theme'];
                              final themeText = theme is Map<String, dynamic>
                                  ? theme['title']?.toString()
                                  : null;
                              final distanceKmRaw = place['distanceKm'];
                              final distanceKm = distanceKmRaw is num
                                  ? distanceKmRaw.toDouble()
                                  : double.tryParse(
                                      distanceKmRaw?.toString() ?? '',
                                    );
                              final distanceText = distanceKm != null
                                  ? '${distanceKm.toStringAsFixed(distanceKm < 1 ? 2 : 1)}km'
                                  : null;
                              final favorited =
                                  (place['favorited'] as bool?) ??
                                      (place['isFavorited'] as bool?) ??
                                      false;
                              final placeId =
                                  (place['id'] ?? place['placeId'])?.toString() ??
                                      '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: CommonPlaceListItemView(
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
                                ),
                              );
                            },
                          ),
                  ),
                ),
        ),
      ],
    );

    if (!widget.showNavigation) return body;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: body,
      ),
    );
  }

  Widget _buildSortRow() {
    return Row(
      children: [
        if (_showScopeToggle) ...[
          _ScopeChip(
            label: '모든 장소',
            selected: _selectedScope == 'all',
            onTap: () => _handleScopeTap('all'),
          ),
          const SizedBox(width: 8),
          const _SortDivider(),
          const SizedBox(width: 8),
          _ScopeChip(
            label: '나의 장소',
            selected: _selectedScope == 'my',
            onTap: () => _handleScopeTap('my'),
          ),
          const Spacer(),
        ] else
          const Spacer(),
        _SortChip(
          label: '최신순',
          selected: _selectedSort == 'latest',
          onTap: () => _handleSortTap('latest'),
        ),
        const SizedBox(width: 8),
        const _SortDivider(),
        const SizedBox(width: 8),
        _SortChip(
          label: '인기순',
          selected: _selectedSort == 'popular',
          onTap: () => _handleSortTap('popular'),
        ),
        const SizedBox(width: 8),
        const _SortDivider(),
        const SizedBox(width: 8),
        _SortChip(
          label: '거리순',
          selected: _selectedSort == 'distance',
          onTap: () => _handleSortTap('distance'),
        ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.black : const Color(0xFF9E9E9E);
    final weight = selected ? FontWeight.w700 : FontWeight.w500;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.black : const Color(0xFF9E9E9E);
    final weight = selected ? FontWeight.w700 : FontWeight.w500;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }
}

class _SortDivider extends StatelessWidget {
  const _SortDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      color: const Color(0xFFE0E0E0),
    );
  }
}
