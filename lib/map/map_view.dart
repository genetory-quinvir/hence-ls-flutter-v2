import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:hence_ls_flutter_v2/common/widgets/common_inkwell.dart';
import 'package:hence_ls_flutter_v2/main.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/location/naver_location_service.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/styles/app_shadows.dart';
import '../common/auth/auth_store.dart';
import '../common/state/home_tab_controller.dart';
import '../common/network/api_client.dart';
import '../common/state/placebook_cache.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_map_view.dart';
import '../common/widgets/common_place_marker.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_place_cluster_marker.dart';
import '../common/widgets/common_login_guard.dart';
import '../common/widgets/common_toast_view.dart';
import '../common/widgets/common_handle_list_sheet.dart';
import '../common/widgets/common_place_list_item_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import 'map_filter/map_filter_view.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    this.showFilterButton = true,
    this.useBottomSafeArea = true,
    this.fixedThemeIds,
    this.onPlaceDeleted,
    this.config = const MapViewConfig(),
  });

  final bool showFilterButton;
  final bool useBottomSafeArea;
  final List<String>? fixedThemeIds;
  final ValueChanged<String>? onPlaceDeleted;
  final MapViewConfig config;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const bool _hideBottomPlaceListForPerfTest = false;
  static const bool _disableMarkerThumbnailsForTest = true;
  // Gangnam Station fallback when current location is unavailable.
  static const NLatLng _fallbackCenter = NLatLng(37.4979, 127.0276);
  static const double _focusMarkerRadiusMeters = 1200;
  static const double _liveClusterDistancePx = 84;
  static const double _markerJitterMaxMeters = 12;
  static const double _clusterMaxZoom = 18.0;
  static const double _clusterTapAutoZoomTarget = 16.4;
  static const double _placeListPeekHeight = 160.0;
  static const int _maxProjectionCountCluster = 28;
  static const int _maxProjectionCountPlace = 40;
  int _selectedIndex = 1;
  String? _selectedCategoryId;
  List<String> _selectedThemeIds = const [];
  String _selectedListSort = '거리순';
  String _centerPlaceText = '';
  final ScrollController _chipScrollController = ScrollController();
  Timer? _reverseGeocodeDebounce;
  Timer? _cameraIdleDebounce;
  bool _isLoadingNear = false;
  bool _isListLoading = false;
  bool _isListLoadingMore = false;
  bool _hasMoreListPlaces = false;
  bool _pendingFilterFetch = false;
  bool _pendingFetchAfterInFlight = false;
  bool _isLoginPromptVisible = false;
  bool _awaitingFetchMarkers = false;
  List<Map<String, dynamic>> _nearSpaces = const [];
  List<Map<String, dynamic>> _pagedListSpaces = const [];
  NaverMapController? _mapController;
  bool _isUpdatingMarkerPoints = false;
  bool _pendingMarkerPointUpdate = false;
  Map<String, NPoint> _liveMarkerPoints = const {};
  Map<String, NPoint> _clusterCenterPoints = const {};
  final Map<String, NLatLng> _jitteredLatLngs = {};
  bool _showLiveMarkers = true;
  bool _isClusterMode = false;
  NLatLng? _lastMarkerUpdateCenter;
  double? _lastMarkerUpdateZoom;
  bool _isCameraMoving = false;
  bool _skipNextCameraIdleFetch = false;
  bool _isClusterAutoZooming = false;
  bool _didFitToAllPlaces = false;
  String? _selectedLiveMarkerId;
  NLatLng? _lastCenter;
  NLatLng? _lastMyLocation;
  double? _lastZoom;
  double _mapViewportWidth = 0;
  double _mapViewportHeight = 0;
  double _lastViewportWidth = 0;
  double _lastViewportHeight = 0;
  static const String _radiusOverlayId = 'api-radius';
  NCircleOverlay? _radiusOverlay;
  final bool _showRadiusOverlay = false;
  final CommonMapViewController _mapViewController = CommonMapViewController();
  List<Map<String, dynamic>> _categoryFilters = const [];
  List<Map<String, dynamic>> _themeFilters = const [];
  List<Map<String, dynamic>> _themeChipFilters = const [];
  late final Map<String, GlobalKey> _chipKeys;
  late final VoidCallback _mapFocusListener;
  late final VoidCallback _mapFilterListener;
  late final VoidCallback _tabIndexListener;
  AnimationController? _shuffleController;
  bool _didInitialLoad = false;
  bool _isInitialCenterReady = false;
  MapFocusRequest? _pendingMapFocusRequest;
  Map<String, dynamic>? _optimisticCreatedSpace;
  DateTime? _optimisticCreatedAt;
  Timer? _mapToggleToastTimer;
  Timer? _markerRevealLoadingTimer;
  String _mapToggleToastMessage = '';
  bool _isMapToggleToastVisible = false;
  int _mapToggleToastSequence = 0;
  bool _skipToastOutAnimation = false;
  int _markerRevealSequence = 0;
  String? _lastFetchRequestKey;
  String? _listNextCursor;
  String? _lastListRequestKey;

  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic> _normalizePlaceItem(Map<String, dynamic> item) {
    final next = Map<String, dynamic>.from(item);
    String? asString(dynamic value) {
      if (value == null) return null;
      if (value is String && value.trim().isNotEmpty) return value;
      return null;
    }

    num? asNum(dynamic value) {
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    }

    void setLatLng(
      dynamic source, {
      String latKey = 'latitude',
      String lngKey = 'longitude',
    }) {
      if (source is! Map<String, dynamic>) return;
      next['latitude'] ??= source[latKey] ?? source['lat'];
      next['longitude'] ??= source[lngKey] ?? source['lng'] ?? source['lon'];
    }

    next['latitude'] ??= item['lat'];
    next['longitude'] ??= item['lng'] ?? item['lon'];
    if (item['centerLat'] != null) next['latitude'] ??= item['centerLat'];
    if (item['centerLng'] != null) next['longitude'] ??= item['centerLng'];
    if (item['centerLatitude'] != null) {
      next['latitude'] ??= item['centerLatitude'];
    }
    if (item['centerLongitude'] != null) {
      next['longitude'] ??= item['centerLongitude'];
    }
    setLatLng(item['location']);
    setLatLng(item['position']);
    setLatLng(item['center']);
    setLatLng(item['coords']);

    if (next['clusterCount'] == null) {
      final rawCount =
          item['count'] ?? item['clusterCount'] ?? item['placeCount'];
      if (rawCount is num) {
        next['clusterCount'] = rawCount.toInt();
      } else if (rawCount is String) {
        final parsed = int.tryParse(rawCount);
        if (parsed != null) next['clusterCount'] = parsed;
      }
    }

    final rawTitle = asString(next['title']) ?? asString(next['name']);
    final rawSubtitle = asString(next['subtitle']);
    final rawDescription = asString(next['description']);
    if (rawTitle != null) {
      next['title'] = rawTitle;
      next['placeName'] ??= rawTitle;
    }
    if (rawSubtitle != null) {
      next['subtitle'] = rawSubtitle;
    }
    if (rawDescription != null) {
      next['description'] = rawDescription;
    }

    final lat = asNum(next['latitude']);
    final lng = asNum(next['longitude']);
    if (lat != null) next['latitude'] = lat.toDouble();
    if (lng != null) next['longitude'] = lng.toDouble();

    final placeName = next['placeName'] ?? next['name'];
    if (placeName is String && placeName.isNotEmpty) {
      next['placeName'] ??= placeName;
      next['title'] ??= placeName;
    }

    if (next['thumbnail'] == null && next['thumbnailUrl'] != null) {
      final value = next['thumbnailUrl'];
      if (value is String && value.trim().isNotEmpty) {
        next['thumbnail'] = value.trim();
      } else if (value is Map<String, dynamic>) {
        next['thumbnail'] = value;
      }
    }
    if (next['thumbnail'] == null && next['thumbnailUrls'] is List) {
      final list = next['thumbnailUrls'] as List;
      for (final entry in list) {
        if (entry is String && entry.trim().isNotEmpty) {
          next['thumbnail'] = entry.trim();
          break;
        }
      }
    }

    return next;
  }

  String _buildMapFetchRequestKey({
    required NLatLng center,
    required int radiusMeters,
  }) {
    return [
      center.latitude.toStringAsFixed(4),
      center.longitude.toStringAsFixed(4),
      (_lastZoom ?? widget.config.mapPlacesZoomThreshold).toStringAsFixed(2),
      radiusMeters.toString(),
      _placesFilterForIndex(),
      _selectedCategoryId ?? '',
      _effectiveThemeIds.join(','),
    ].join('|');
  }

  String _listOrderBy() {
    if (_selectedListSort == '인기순') return 'helpfulCount';
    return 'distance';
  }

  String _listOrder() {
    if (_selectedListSort == '인기순') return 'DESC';
    return 'ASC';
  }

  Future<void> _fetchPlacebookSpaces() async {
    if (_isLoadingNear) {
      _pendingFetchAfterInFlight = true;
      return;
    }
    if (_selectedIndex == 0 && !AuthStore.instance.isSignedIn.value) {
      await _promptLoginForMyMap();
      if (_awaitingFetchMarkers && mounted) {
        _awaitingFetchMarkers = false;
        setState(() => _showLiveMarkers = true);
      }
      return;
    }
    setState(() => _isLoadingNear = true);
    try {
      final center = _lastCenter ?? _fallbackCenter;
      final radiusKm = _radiusKmForScreen() ?? 10.0;
      final radiusMeters = (radiusKm * 1000).round();
      final requestKey = _buildMapFetchRequestKey(
        center: center,
        radiusMeters: radiusMeters,
      );
      if (_lastFetchRequestKey == requestKey) {
        if (_awaitingFetchMarkers && mounted) {
          await _updateLiveMarkerPoints();
          _awaitingFetchMarkers = false;
          if (!_isCameraMoving) {
            _showMarkersWithReveal();
          }
        }
        return;
      }
      await _updateRadiusOverlay(center: center);
      const limit = 80;
      const orderBy = 'distance';
      const order = 'ASC';
      final categoryId = _selectedCategoryId;
      final themeIds = _effectiveThemeIds.isNotEmpty
          ? _effectiveThemeIds
          : null;
      final themeId = (themeIds != null && themeIds.length == 1)
          ? themeIds.first
          : null;
      final filter = _placesFilterForIndex();
      final zoom = _lastZoom ?? widget.config.mapPlacesZoomThreshold;
      final shouldUseClusters = _shouldUseClusterApi(zoom);

      Map<String, dynamic> response;
      bool isClusterMode = false;
      if (_shouldFitAllPlaces) {
        const listOrderBy = 'createdAt';
        const listOrder = 'DESC';
        response = await ApiClient.fetchPlacebookPlacesList(
          filter: filter,
          limit: null,
          orderBy: listOrderBy,
          order: listOrder,
          themeIds: themeIds,
        );
        isClusterMode = false;
      } else if (shouldUseClusters) {
        try {
          response = await ApiClient.fetchMapPlaceClusters(
            latitude: center.latitude,
            longitude: center.longitude,
            radiusMeters: radiusMeters,
            gridSizeMeters: _gridSizeMetersForZoom(zoom),
            categoryId: categoryId,
            themeId: themeId,
            isActive: true,
            filter: filter,
            orderBy: orderBy,
            order: order,
            page: 1,
            limit: limit,
          );
          isClusterMode = true;
        } catch (_) {
          response = await ApiClient.fetchMapPlaces(
            latitude: center.latitude,
            longitude: center.longitude,
            radiusMeters: radiusMeters,
            categoryId: categoryId,
            themeId: themeId,
            isActive: true,
            filter: filter,
            orderBy: orderBy,
            order: order,
            page: 1,
            limit: limit,
          );
          isClusterMode = false;
        }
        final clusterCount = _countFromMapResponse(response);
        if (isClusterMode && clusterCount < widget.config.clusterMinCount) {
          response = await ApiClient.fetchMapPlaces(
            latitude: center.latitude,
            longitude: center.longitude,
            radiusMeters: radiusMeters,
            categoryId: categoryId,
            themeId: themeId,
            isActive: true,
            filter: filter,
            orderBy: orderBy,
            order: order,
            page: 1,
            limit: limit,
          );
          isClusterMode = false;
        }
      } else {
        response = await ApiClient.fetchMapPlaces(
          latitude: center.latitude,
          longitude: center.longitude,
          radiusMeters: radiusMeters,
          categoryId: categoryId,
          themeId: themeId,
          isActive: true,
          filter: filter,
          orderBy: orderBy,
          order: order,
          page: 1,
          limit: limit,
        );
        isClusterMode = false;
        final placeCount = _countFromMapResponse(response);
        if (widget.config.enableClusters &&
            placeCount >= widget.config.placeCountForCluster) {
          try {
            response = await ApiClient.fetchMapPlaceClusters(
              latitude: center.latitude,
              longitude: center.longitude,
              radiusMeters: radiusMeters,
              gridSizeMeters: _gridSizeMetersForZoom(zoom),
              categoryId: categoryId,
              themeId: themeId,
              isActive: true,
              filter: filter,
              orderBy: orderBy,
              order: order,
              page: 1,
              limit: limit,
            );
            isClusterMode = true;
          } catch (_) {
            // Keep map places response as fallback.
            isClusterMode = false;
          }
        }
      }

      if (!mounted) return;
      final spaces = _extractPlacesFromListResponse(response);
      final normalized = spaces.map((item) {
        final normalized = _normalizePlaceItem(item);
        if (isClusterMode) normalized['isCluster'] = true;
        return normalized;
      }).toList();
      final merged = isClusterMode
          ? normalized
          : _dedupeSpaces(_mergeOptimisticCreatedSpace(normalized));
      setState(() {
        _nearSpaces = merged;
        _isClusterMode = isClusterMode;
      });
      _pruneMarkerCaches(merged);
      _lastFetchRequestKey = requestKey;
      unawaited(_prefetchListThumbnails(merged));
      await _updateLiveMarkerPoints();
      await _fitToAllPlaces();
      unawaited(
        _resetAndFetchListPlaces(
          requestKey: requestKey,
          center: center,
          radiusMeters: radiusMeters,
        ),
      );
      if (mounted) {
        _awaitingFetchMarkers = false;
        if (!_isCameraMoving) {
          _showMarkersWithReveal();
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearSpaces = const [];
        _isClusterMode = false;
      });
      _jitteredLatLngs.clear();
      _lastFetchRequestKey = null;
      await _updateLiveMarkerPoints();
      _awaitingFetchMarkers = false;
      if (!_isCameraMoving) {
        _showMarkersWithReveal();
      }
    } finally {
      if (mounted) setState(() => _isLoadingNear = false);
      if (_pendingFetchAfterInFlight) {
        _pendingFetchAfterInFlight = false;
        if (mounted) {
          _fetchPlacebookSpaces();
        }
      }
      if (_pendingFilterFetch) {
        _pendingFilterFetch = false;
        if (mounted) {
          _fetchPlacebookSpaces();
        }
      }
    }
  }

  Future<void> _prefetchListThumbnails(
    List<Map<String, dynamic>> spaces,
  ) async {
    final urls = spaces
        .map((space) => (_thumbnailForSpace(space) ?? '').trim())
        .where((url) => url.isNotEmpty)
        .take(24)
        .toList(growable: false);
    if (urls.isEmpty) return;
    try {
      await CommonImageView.prefetchNetworkUrls(
        urls,
      ).timeout(const Duration(milliseconds: 900));
    } catch (_) {
      // Ignore prefetch failures; list should render regardless.
    }
  }

  Future<void> _promptLoginForMyMap() async {
    if (!mounted || _isLoginPromptVisible) return;
    _isLoginPromptVisible = true;
    await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '내 지도를 보려면 로그인해주세요.',
    );
    _isLoginPromptVisible = false;
  }

  List<Map<String, dynamic>> get _typeScopedSpaces => _nearSpaces;

  List<Map<String, dynamic>> get _listSpaces {
    return _pagedListSpaces;
  }

  bool _isClusterSpace(Map<String, dynamic> space) {
    if (space['isCluster'] == true) return true;
    final rawCount =
        space['clusterCount'] ?? space['count'] ?? space['placeCount'];
    if (rawCount is num && rawCount.toInt() > 1) return true;
    if (_isClusterMode) return true;
    return false;
  }

  int _clusterCountForSpace(Map<String, dynamic> space) {
    final raw = space['clusterCount'] ?? space['count'] ?? space['placeCount'];
    if (raw is num) return raw.toInt().clamp(1, 9999);
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed.clamp(1, 9999);
    }
    return 1;
  }

  List<String> get _effectiveThemeIds {
    final fixed = widget.fixedThemeIds;
    if (fixed != null && fixed.isNotEmpty) {
      return fixed;
    }
    return _selectedThemeIds;
  }

  bool get _shouldFitAllPlaces {
    final fixed = widget.fixedThemeIds;
    return fixed != null && fixed.isNotEmpty;
  }

  String _placesFilterForIndex() {
    return _selectedIndex == 1 ? 'all' : 'mine';
  }

  List<Map<String, dynamic>> _extractPlacesFromListResponse(
    Map<String, dynamic> response,
  ) {
    final items = response['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['items'];
      if (nested is List) {
        return nested.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  String? _extractNextCursor(Map<String, dynamic> response) {
    final direct = response['nextCursor'];
    if (direct is String && direct.isNotEmpty) return direct;
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['nextCursor'];
      if (nested is String && nested.isNotEmpty) return nested;
    }
    final meta = response['meta'];
    if (meta is Map<String, dynamic>) {
      final nested = meta['nextCursor'] ?? meta['cursor'];
      if (nested is String && nested.isNotEmpty) return nested;
    }
    return null;
  }

  bool _extractHasMore(Map<String, dynamic> response) {
    final hasMore = response['hasMore'] ?? response['hasNext'];
    if (hasMore is bool) return hasMore;
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['hasMore'] ?? data['hasNext'];
      if (nested is bool) return nested;
    }
    return _extractNextCursor(response) != null;
  }

  Future<void> _refreshListForCurrentViewport() async {
    final center = _lastCenter ?? _fallbackCenter;
    final radiusKm = _radiusKmForScreen() ?? 10.0;
    final radiusMeters = (radiusKm * 1000).round();
    final requestKey = _buildMapFetchRequestKey(
      center: center,
      radiusMeters: radiusMeters,
    );
    await _resetAndFetchListPlaces(
      requestKey: requestKey,
      center: center,
      radiusMeters: radiusMeters,
      force: true,
    );
  }

  Future<void> _resetAndFetchListPlaces({
    required String requestKey,
    required NLatLng center,
    required int radiusMeters,
    bool force = false,
  }) async {
    final listKey = '$requestKey|sort:$_selectedListSort';
    if (!force && _lastListRequestKey == listKey) return;
    _lastListRequestKey = listKey;
    _listNextCursor = null;
    _hasMoreListPlaces = false;
    if (mounted) {
      setState(() {
        _isListLoading = true;
        _isListLoadingMore = false;
        _pagedListSpaces = const [];
      });
    }
    await _fetchListPlacesPage(
      requestKey: listKey,
      center: center,
      radiusMeters: radiusMeters,
      reset: true,
    );
  }

  Future<void> _loadMoreListPlaces() async {
    if (_isListLoading || _isListLoadingMore || !_hasMoreListPlaces) return;
    final cursor = _listNextCursor;
    if (cursor == null || cursor.isEmpty) return;
    final center = _lastCenter ?? _fallbackCenter;
    final radiusKm = _radiusKmForScreen() ?? 10.0;
    final radiusMeters = (radiusKm * 1000).round();
    final requestKey = _lastListRequestKey;
    if (requestKey == null || requestKey.isEmpty) return;
    await _fetchListPlacesPage(
      requestKey: requestKey,
      center: center,
      radiusMeters: radiusMeters,
      cursor: cursor,
      reset: false,
    );
  }

  Future<void> _fetchListPlacesPage({
    required String requestKey,
    required NLatLng center,
    required int radiusMeters,
    required bool reset,
    String? cursor,
  }) async {
    if (_selectedIndex == 0 && !AuthStore.instance.isSignedIn.value) return;
    if (!reset) {
      if (!mounted) return;
      setState(() => _isListLoadingMore = true);
    }
    try {
      final response = await ApiClient.fetchMapPlaces(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: radiusMeters,
        categoryId: _selectedCategoryId,
        themeId: _effectiveThemeIds.length == 1 ? _effectiveThemeIds.first : null,
        isActive: true,
        filter: _placesFilterForIndex(),
        orderBy: _listOrderBy(),
        order: _listOrder(),
        cursor: cursor,
        limit: 20,
      );
      if (!mounted || _lastListRequestKey != requestKey) return;
      final items = _extractPlacesFromListResponse(response).map((item) {
        final normalized = _normalizePlaceItem(item);
        normalized.remove('isCluster');
        return normalized;
      }).toList(growable: false);
      final nextCursor = _extractNextCursor(response);
      final hasMore = _extractHasMore(response);
      setState(() {
        if (reset) {
          _pagedListSpaces = items;
        } else {
          _pagedListSpaces = List<Map<String, dynamic>>.from(_pagedListSpaces)
            ..addAll(items);
        }
        _listNextCursor = nextCursor;
        _hasMoreListPlaces = hasMore;
      });
    } catch (_) {
      if (!mounted || _lastListRequestKey != requestKey) return;
      if (reset) {
        setState(() {
          _pagedListSpaces = const [];
          _listNextCursor = null;
          _hasMoreListPlaces = false;
        });
      }
    } finally {
      if (mounted && _lastListRequestKey == requestKey) {
        setState(() {
          _isListLoading = false;
          _isListLoadingMore = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    final fixed = widget.fixedThemeIds;
    if (fixed != null && fixed.isNotEmpty) {
      _selectedThemeIds = List<String>.from(fixed);
    }
    _mapFocusListener = _handleMapFocusRequest;
    _mapFilterListener = _handleMapFilterRequest;
    HomeTabController.mapFocusRequest.addListener(_mapFocusListener);
    HomeTabController.mapFilterRequest.addListener(_mapFilterListener);
    _tabIndexListener = () {
      if (HomeTabController.currentIndex.value == 1) {
        _ensureMapInitialized();
        _handleMapFilterRequest();
      }
    };
    HomeTabController.currentIndex.addListener(_tabIndexListener);
    if (HomeTabController.currentIndex.value == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureMapInitialized();
      });
    }
    if (HomeTabController.currentIndex.value == 1 &&
        HomeTabController.mapFilterRequest.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleMapFilterRequest();
      });
    }
    _chipKeys = <String, GlobalKey>{};
  }

  Widget _buildMapWidget() {
    return CommonMapView(
      key: const ValueKey('home-main-common-map-view'),
      controller: _mapViewController,
      initialLatitude: _lastCenter?.latitude,
      initialLongitude: _lastCenter?.longitude,
      showMyLocationButton: false,
      onMyLocationChanged: (location) {
        _lastMyLocation = location;
      },
      onCenterChanged: _onMapCenterChanged,
      onCameraMoving: _onMapCameraMoving,
      onCameraIdle: _onMapCameraIdle,
      onMapReady: (controller) {
        _mapController = controller;
        if (_lastCenter != null && _pendingMapFocusRequest == null) {
          controller.updateCamera(
            NCameraUpdate.withParams(target: _lastCenter!),
          );
        }
        controller.getCameraPosition().then(
          (camera) => _updateRadiusOverlay(center: camera.target),
        );
        final pending = _pendingMapFocusRequest;
        if (pending != null) {
          _focusToCreatedLivespace(pending);
        }
        _updateLiveMarkerPoints();
      },
    );
  }

  void _ensureMapInitialized() {
    if (_didInitialLoad) return;
    _didInitialLoad = true;
    _loadCategoryFilters();
    _loadThemeFilters();
    _initInitialCenter();
  }

  Future<void> _initInitialCenter() async {
    final initialCenter = await _resolveInitialCenter();
    if (!mounted) return;
    setState(() {
      _lastCenter = initialCenter;
      _isInitialCenterReady = true;
    });
    _centerChip(animated: false);
    if (_mapController != null && _pendingMapFocusRequest == null) {
      // Initial camera move can trigger onCameraIdle; avoid duplicate initial fetch.
      _skipNextCameraIdleFetch = true;
      _mapController!.updateCamera(
        NCameraUpdate.withParams(target: initialCenter),
      );
    }
    await _updateRadiusOverlay(center: initialCenter);
    _fetchPlacebookSpaces();
  }

  Future<NLatLng> _resolveInitialCenter() async {
    const fallback = _fallbackCenter;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final granted = await LocationPermissionService.isGranted();
      if (serviceEnabled && granted) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        return NLatLng(position.latitude, position.longitude);
      }
    } catch (_) {
      // ignore and use fallback
    }
    return fallback;
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fixed = widget.fixedThemeIds;
    final oldFixed = oldWidget.fixedThemeIds;
    if (fixed != oldFixed) {
      if (fixed != null && fixed.isNotEmpty) {
        _selectedThemeIds = List<String>.from(fixed);
        _didFitToAllPlaces = false;
      }
    }
  }

  @override
  void dispose() {
    _shuffleController?.dispose();
    HomeTabController.mapFocusRequest.removeListener(_mapFocusListener);
    HomeTabController.mapFilterRequest.removeListener(_mapFilterListener);
    HomeTabController.currentIndex.removeListener(_tabIndexListener);
    _reverseGeocodeDebounce?.cancel();
    _cameraIdleDebounce?.cancel();
    _mapToggleToastTimer?.cancel();
    _markerRevealLoadingTimer?.cancel();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _triggerMapToggleToast(String message) {
    _mapToggleToastTimer?.cancel();
    if (_isMapToggleToastVisible) {
      setState(() {
        _skipToastOutAnimation = true;
        _isMapToggleToastVisible = false;
      });
      Future.microtask(() {
        if (!mounted) return;
        setState(() {
          _skipToastOutAnimation = false;
          _mapToggleToastMessage = message;
          _isMapToggleToastVisible = true;
          _mapToggleToastSequence += 1;
        });
      });
    } else {
      setState(() {
        _mapToggleToastMessage = message;
        _isMapToggleToastVisible = true;
        _mapToggleToastSequence += 1;
      });
    }
    _mapToggleToastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _isMapToggleToastVisible = false);
    });
  }

  void _resetMapFiltersToDefault() {
    setState(() {
      _selectedListSort = '거리순';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
    });
  }

  List<Map<String, dynamic>> _sortedListSpaces() {
    return _listSpaces;
  }

  Widget _buildListSortToggle() {
    const options = ['거리순', '인기순'];
    return Row(
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
              if (_selectedListSort == options[i]) return;
              setState(() => _selectedListSort = options[i]);
              _refreshListForCurrentViewport();
            },
            behavior: HitTestBehavior.opaque,
            child: Text(
              options[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: _selectedListSort == options[i]
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: _selectedListSort == options[i]
                    ? Colors.black
                    : const Color(0x88000000),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadCategoryFilters() async {
    final categories = await PlacebookCache.loadCategories();
    if (!mounted) return;
    final active =
        categories
            .whereType<Map<String, dynamic>>()
            .where((item) => item['isActive'] != false)
            .toList()
          ..sort((a, b) {
            final aOrder = (a['sortOrder'] as num?)?.toInt() ?? 0;
            final bOrder = (b['sortOrder'] as num?)?.toInt() ?? 0;
            return aOrder.compareTo(bOrder);
          });
    setState(() {
      _categoryFilters = active;
    });
  }

  Future<void> _loadThemeFilters() async {
    final themes = await PlacebookCache.loadThemes();
    if (!mounted) return;
    final active = themes
        .whereType<Map<String, dynamic>>()
        .where((item) => item['isActive'] != false)
        .toList();
    final shuffled = List<Map<String, dynamic>>.from(active);
    shuffled.shuffle(math.Random());
    final chips = shuffled.take(5).toList();
    setState(() {
      _themeFilters = active;
      _themeChipFilters = chips;
      _chipKeys
        ..clear()
        ..addAll({
          for (final item in chips) (item['id']?.toString() ?? ''): GlobalKey(),
        });
    });
  }

  void _shuffleThemeChips() {
    final active = _themeFilters;
    if (active.isEmpty) return;
    if (widget.fixedThemeIds == null || widget.fixedThemeIds!.isEmpty) {
      if (_selectedThemeIds.isNotEmpty || _selectedCategoryId != null) {
        setState(() {
          _selectedThemeIds = const [];
          _selectedCategoryId = null;
        });
      }
    }
    final shuffled = List<Map<String, dynamic>>.from(active);
    shuffled.shuffle(math.Random());
    final chips = shuffled.take(5).toList();
    setState(() {
      _themeChipFilters = chips;
      _chipKeys
        ..clear()
        ..addAll({
          for (final item in chips) (item['id']?.toString() ?? ''): GlobalKey(),
        });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
      if (_chipScrollController.hasClients) {
        _chipScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
    _fetchPlacebookSpaces();
  }

  void _upsertCreatedSpaceForImmediateMarker(Map<String, dynamic> raw) {
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lng = (raw['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final normalized = <String, dynamic>{
      ...raw,
      'id': raw['id'] ?? 'created_${DateTime.now().microsecondsSinceEpoch}',
      'type': 'PLACE',
      'latitude': lat,
      'longitude': lng,
    };
    _optimisticCreatedSpace = normalized;
    _optimisticCreatedAt = DateTime.now();
    final createdId = normalized['id'];
    setState(() {
      final next = List<Map<String, dynamic>>.from(_nearSpaces)
        ..removeWhere((item) => item['id'] == createdId)
        ..insert(0, normalized);
      _nearSpaces = _dedupeSpaces(next);
    });
    _updateLiveMarkerPoints();
  }

  List<NLatLng> _collectSpaceLatLngs() {
    final points = <NLatLng>[];
    for (final space in _nearSpaces) {
      final lat = (space['latitude'] as num?)?.toDouble();
      final lng = (space['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      points.add(NLatLng(lat, lng));
    }
    return points;
  }

  Future<void> _fitToAllPlaces() async {
    if (!_shouldFitAllPlaces || _didFitToAllPlaces) return;
    final controller = _mapController;
    if (controller == null) return;
    final points = _collectSpaceLatLngs();
    if (points.isEmpty) return;
    try {
      _skipNextCameraIdleFetch = true;
      if (points.length == 1) {
        await controller.updateCamera(
          NCameraUpdate.withParams(target: points.first, zoom: 15.5),
        );
      } else {
        final bounds = NLatLngBounds.from(points);
        final update = NCameraUpdate.fitBounds(
          bounds,
          padding: const EdgeInsets.fromLTRB(24, 140, 24, 220),
        );
        update.setAnimation(duration: const Duration(milliseconds: 500));
        await controller.updateCamera(update);
      }
      _didFitToAllPlaces = true;
    } catch (_) {
      // Ignore camera update errors.
    }
  }

  void _removePlaceFromMap(String placeId) {
    if (placeId.isEmpty) return;
    setState(() {
      _nearSpaces = _nearSpaces.where((space) {
        final id = _placeIdOf(space);
        return id != placeId;
      }).toList();
      if (_selectedLiveMarkerId == placeId) {
        _selectedLiveMarkerId = null;
      }
    });
    _updateLiveMarkerPoints();
    widget.onPlaceDeleted?.call(placeId);
  }

  String _placeIdOf(Map<String, dynamic> space) {
    final id = space['id'] ?? space['placeId'];
    if (id is String) return id;
    return id?.toString() ?? '';
  }

  String _spaceDedupeKey(Map<String, dynamic> space) {
    final id = space['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return 'id:$id';
    }
    final type = _spaceType(space);
    final lat = (space['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (space['longitude'] as num?)?.toDouble() ?? 0;
    final latKey = lat.toStringAsFixed(6);
    final lngKey = lng.toStringAsFixed(6);
    final title = (space['title'] as String?)?.trim() ?? '';
    final place = (space['placeName'] as String?)?.trim() ?? '';
    return 'geo:$type:$latKey:$lngKey:$title:$place';
  }

  List<Map<String, dynamic>> _dedupeSpaces(List<Map<String, dynamic>> spaces) {
    final byId = <String, Map<String, dynamic>>{};
    for (final space in spaces) {
      final id = space['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byId[id] = space;
    }
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final space in spaces) {
      final id = space['id']?.toString();
      if (id != null && id.isNotEmpty && byId[id] != space) {
        continue;
      }
      final key = _spaceDedupeKey(space);
      if (!seen.add(key)) continue;
      result.add(space);
    }
    return result;
  }

  void _pruneMarkerCaches(List<Map<String, dynamic>> spaces) {
    if (_jitteredLatLngs.isEmpty) return;
    final validKeys = <String>{};
    for (final space in spaces) {
      final lat = (space['latitude'] as num?)?.toDouble();
      final lng = (space['longitude'] as num?)?.toDouble();
      final rawKey = space['id'] ?? space['placeId'] ?? space['spaceId'];
      final key =
          rawKey?.toString() ??
          (lat != null && lng != null ? '$lat,$lng' : '');
      if (key.isNotEmpty) {
        validKeys.add(key);
      }
    }
    _jitteredLatLngs.removeWhere((key, _) => !validKeys.contains(key));
    if (_jitteredLatLngs.length > 1000) {
      _jitteredLatLngs.clear();
    }
  }

  List<Map<String, dynamic>> _mergeOptimisticCreatedSpace(
    List<Map<String, dynamic>> spaces,
  ) {
    final optimistic = _optimisticCreatedSpace;
    if (optimistic == null) return spaces;
    final insertedAt = _optimisticCreatedAt;
    if (insertedAt != null &&
        DateTime.now().difference(insertedAt) > const Duration(seconds: 45)) {
      _optimisticCreatedSpace = null;
      _optimisticCreatedAt = null;
      return spaces;
    }
    final optimisticId = optimistic['id'];
    final optimisticLat = (optimistic['latitude'] as num?)?.toDouble();
    final optimisticLng = (optimistic['longitude'] as num?)?.toDouble();
    final exists = spaces.any((item) {
      if (item['id'] == optimisticId) return true;
      final lat = (item['latitude'] as num?)?.toDouble();
      final lng = (item['longitude'] as num?)?.toDouble();
      if (optimisticLat == null ||
          optimisticLng == null ||
          lat == null ||
          lng == null) {
        return false;
      }
      return _spaceType(item) == _spaceType(optimistic) &&
          (lat - optimisticLat).abs() < 0.00001 &&
          (lng - optimisticLng).abs() < 0.00001;
    });
    if (exists) {
      _optimisticCreatedSpace = null;
      _optimisticCreatedAt = null;
      return _dedupeSpaces(spaces);
    }
    return _dedupeSpaces(<Map<String, dynamic>>[optimistic, ...spaces]);
  }

  Future<void> _focusToCreatedLivespace(
    MapFocusRequest request, {
    bool consumeRequest = false,
  }) async {
    if (consumeRequest &&
        identical(HomeTabController.mapFocusRequest.value, request)) {
      HomeTabController.mapFocusRequest.value = null;
    }
    if (request.resetFilters) {
      _resetMapFiltersToDefault();
    }
    final createdSpace = request.createdSpace;
    if (createdSpace != null) {
      _upsertCreatedSpaceForImmediateMarker(createdSpace);
    }
    final target = NLatLng(request.latitude, request.longitude);
    _lastCenter = target;
    _onMapCenterChanged(target);
    final controller = _mapController;
    if (controller == null) {
      _pendingMapFocusRequest = request;
      return;
    }
    _pendingMapFocusRequest = null;
    try {
      _skipNextCameraIdleFetch = true;
      await controller.updateCamera(
        NCameraUpdate.withParams(target: target, zoom: 16.0),
      );
    } catch (_) {
      // Ignore camera update errors.
    }
    await _forceRefreshLiveMarkers();
    await _fetchPlacebookSpaces();
    await _forceRefreshLiveMarkers();
  }

  void _handleMapFocusRequest() {
    final request = HomeTabController.mapFocusRequest.value;
    if (request == null) return;
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
    _focusToCreatedLivespace(request, consumeRequest: true);
  }

  void _handleMapFilterRequest() {
    final request = HomeTabController.mapFilterRequest.value;
    if (request == null) return;
    if (HomeTabController.currentIndex.value != 1) return;
    if (request.selectMyMap && _selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
    setState(() {
      _selectedCategoryId = request.categoryId;
      if (widget.fixedThemeIds == null || widget.fixedThemeIds!.isEmpty) {
        _selectedThemeIds = request.themeIds;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
      _updateLiveMarkerPoints();
      if (_isLoadingNear) {
        _pendingFilterFetch = true;
        return;
      }
      _fetchPlacebookSpaces();
    });
    if (identical(HomeTabController.mapFilterRequest.value, request)) {
      HomeTabController.mapFilterRequest.value = null;
    }
  }

  Future<void> _forceRefreshLiveMarkers() async {
    if (!mounted) return;
    setState(() {
      _showLiveMarkers = false;
      _liveMarkerPoints = const {};
    });
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await _updateLiveMarkerPoints();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _updateLiveMarkerPoints();
    if (!mounted) return;
    setState(() => _showLiveMarkers = true);
  }

  Future<void> _zoomBy(double delta) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      final camera = await controller.getCameraPosition();
      final nextZoom = (camera.zoom + delta).clamp(1.0, 20.0);
      await controller.updateCamera(
        NCameraUpdate.withParams(target: camera.target, zoom: nextZoom),
      );
    } catch (_) {
      // Ignore transient map camera errors.
    }
  }

  void _onMapCenterChanged(NLatLng center) {
    _lastCenter = center;
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(
      const Duration(milliseconds: 320),
      () async {
        final place = await NaverLocationService.reverseGeocode(
          latitude: center.latitude,
          longitude: center.longitude,
        );
        if (!mounted) return;
        final next = _toShortPlace((place ?? '').trim());
        if (next == _centerPlaceText) return;
        setState(() => _centerPlaceText = next);
      },
    );
  }

  String _toShortPlace(String raw) {
    if (raw.isEmpty) return raw;
    final parts = raw
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]} ${parts.last}';
    }
    return parts.first;
  }

  double? _radiusKmForScreen() {
    final controller = _mapController;
    if (controller == null || _mapViewportWidth <= 0) return null;
    final halfWidth = _mapViewportWidth / 2;
    final metersPerDp = controller.getMeterPerDp();
    final meters = metersPerDp * halfWidth;
    if (meters.isNaN || meters.isInfinite || meters <= 0) return null;
    return meters / 1000;
  }

  bool _shouldUseClusterApi(double zoom) {
    return widget.config.enableClusters &&
        zoom < widget.config.mapPlacesZoomThreshold;
  }

  int _gridSizeMetersForZoom(double zoom) {
    final override = widget.config.gridSizeMetersForZoom;
    if (override != null) return override(zoom);
    return _defaultGridSizeMetersForZoom(zoom);
  }

  int _defaultGridSizeMetersForZoom(double zoom) {
    if (zoom >= 15) return 250;
    if (zoom >= 14) return 400;
    if (zoom >= 13) return 700;
    return 1100;
  }

  int _countFromMapResponse(Map<String, dynamic> response) {
    final total = response['total'];
    if (total is num) return total.toInt();
    if (total is String) {
      final parsed = int.tryParse(total);
      if (parsed != null) return parsed;
    }
    final items = _extractPlacesFromListResponse(response);
    return items.length;
  }

  Future<void> _updateRadiusOverlay({NLatLng? center}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_showRadiusOverlay) {
      final existing = _radiusOverlay;
      if (existing != null) {
        await controller.deleteOverlay(existing.info);
        _radiusOverlay = null;
      }
      return;
    }
    final target = center ?? _lastCenter;
    if (target == null) return;
    final radiusKm = _radiusKmForScreen() ?? 10.0;
    final radiusMeters = radiusKm * 1000;
    final overlay = _radiusOverlay;
    if (overlay == null) {
      final created = NCircleOverlay(
        id: _radiusOverlayId,
        center: target,
        radius: radiusMeters,
        color: Colors.blue.withValues(alpha: 0.12),
        outlineColor: Colors.blue.withValues(alpha: 0.35),
        outlineWidth: 1.2,
      );
      _radiusOverlay = created;
      await controller.addOverlay(created);
    } else {
      overlay.setCenter(target);
      overlay.setRadius(radiusMeters);
    }
  }

  Future<void> _updateLiveMarkerPoints() async {
    final controller = _mapController;
    if (controller == null) return;
    if (_isCameraMoving) return;
    if (_isUpdatingMarkerPoints) {
      _pendingMarkerPointUpdate = true;
      return;
    }
    _isUpdatingMarkerPoints = true;
    try {
      if (_typeScopedSpaces.isEmpty) {
        if (mounted) {
          setState(() {
            _liveMarkerPoints = const {};
            _clusterCenterPoints = const {};
            _selectedLiveMarkerId = null;
          });
        }
        return;
      }
      NCameraPosition? camera;
      try {
        camera = await controller.getCameraPosition();
      } catch (_) {
        camera = null;
      }
      final lastCenter = _lastMarkerUpdateCenter;
      final lastZoom = _lastMarkerUpdateZoom;
      final canReuse =
          camera != null &&
          lastCenter != null &&
          lastZoom != null &&
          _distanceMeters(
                lat1: lastCenter.latitude,
                lng1: lastCenter.longitude,
                lat2: camera.target.latitude,
                lng2: camera.target.longitude,
              ) <
              4 &&
          (camera.zoom - lastZoom).abs() < 0.02;
      final projectionCandidates = _selectProjectionCandidates(
        spaces: _typeScopedSpaces,
        center: camera?.target ?? _lastCenter,
      );
      final nextPoints = <String, NPoint>{};
      final projectionFutures = <Future<({String markerId, NPoint? point})>>[];
      for (var i = 0; i < projectionCandidates.length; i += 1) {
        final space = projectionCandidates[i];
        final lat = (space['latitude'] as num?)?.toDouble();
        final lng = (space['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final markerId = _markerIdForSpace(space, i);
        if (canReuse) {
          final cached = _liveMarkerPoints[markerId];
          if (cached != null) {
            nextPoints[markerId] = cached;
            continue;
          }
        }
        final displayLatLng = _displayLatLngForSpace(space, lat: lat, lng: lng);
        projectionFutures.add(() async {
          final point = await controller.latLngToScreenLocation(displayLatLng);
          if (!_isPointInView(point)) {
            return (markerId: markerId, point: null);
          }
          return (markerId: markerId, point: point);
        }());
      }
      if (projectionFutures.isNotEmpty) {
        final projected = await Future.wait(projectionFutures);
        for (final item in projected) {
          final point = item.point;
          if (point == null) continue;
          nextPoints[item.markerId] = point;
        }
      }
      final markerEntries =
          <
            ({
              String markerId,
              String type,
              NPoint point,
              String? thumbnailUrl,
              Map<String, dynamic> space,
              bool isFocused,
              bool isCluster,
              double lat,
              double lng,
            })
          >[];
      for (var i = 0; i < projectionCandidates.length; i += 1) {
        final space = projectionCandidates[i];
        final type = _spaceType(space);
        final markerId = _markerIdForSpace(space, i);
        final point = nextPoints[markerId];
        if (point == null) continue;
        final lat = (space['latitude'] as num?)?.toDouble();
        final lng = (space['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final isFocused = _isWithinFocusRadius(lat: lat, lng: lng);
        markerEntries.add((
          markerId: markerId,
          type: type,
          point: point,
          thumbnailUrl: _thumbnailForSpace(space),
          space: space,
          isFocused: isFocused,
          isCluster: _isClusterSpace(space),
          lat: lat,
          lng: lng,
        ));
      }
      final nextClusterCenters = <String, NPoint>{};
      if (!_isClusterMode) {
        final clusters = _buildLiveMarkerClusters(markerEntries);
        nextClusterCenters.addAll(_buildDisplayCentersForOverlaps(clusters));
      }
      if (mounted) {
        final nextClusterMap = _isClusterMode ? const <String, NPoint>{} : nextClusterCenters;
        final pointsChanged = !_pointMapAlmostEquals(_liveMarkerPoints, nextPoints);
        final clustersChanged = !_pointMapAlmostEquals(_clusterCenterPoints, nextClusterMap);
        final needsSelectionReset = _selectedLiveMarkerId != null &&
            !nextPoints.containsKey(_selectedLiveMarkerId);
        if (pointsChanged || clustersChanged || needsSelectionReset) {
          setState(() {
            _liveMarkerPoints = nextPoints;
            _clusterCenterPoints = nextClusterMap;
            if (needsSelectionReset) {
              _selectedLiveMarkerId = null;
            }
          });
        }
      }
      if (camera != null) {
        _lastMarkerUpdateCenter = camera.target;
        _lastMarkerUpdateZoom = camera.zoom;
      }
    } finally {
      _isUpdatingMarkerPoints = false;
      if (_pendingMarkerPointUpdate) {
        _pendingMarkerPointUpdate = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _updateLiveMarkerPoints();
        });
      }
    }
  }

  List<Map<String, dynamic>> _selectProjectionCandidates({
    required List<Map<String, dynamic>> spaces,
    required NLatLng? center,
  }) {
    final limit = _isClusterMode
        ? _maxProjectionCountCluster
        : _maxProjectionCountPlace;
    if (spaces.length <= limit) return spaces;
    if (center == null) return spaces.take(limit).toList(growable: false);
    final indexed = <({Map<String, dynamic> space, double distance})>[];
    for (final space in spaces) {
      final lat = (space['latitude'] as num?)?.toDouble();
      final lng = (space['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      indexed.add((
        space: space,
        distance: _distanceMeters(
          lat1: center.latitude,
          lng1: center.longitude,
          lat2: lat,
          lng2: lng,
        ),
      ));
    }
    if (indexed.isEmpty) return spaces.take(limit).toList(growable: false);
    indexed.sort((a, b) => a.distance.compareTo(b.distance));
    return indexed.take(limit).map((entry) => entry.space).toList(growable: false);
  }

  bool _pointMapAlmostEquals(Map<String, NPoint> a, Map<String, NPoint> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if ((entry.value.x - other.x).abs() > 0.3 ||
          (entry.value.y - other.y).abs() > 0.3) {
        return false;
      }
    }
    return true;
  }

  void _showMarkersWithReveal() {
    if (!mounted) return;
    _markerRevealLoadingTimer?.cancel();
    setState(() {
      _markerRevealSequence += 1;
      _showLiveMarkers = true;
    });
    final revealSeq = _markerRevealSequence;
    _markerRevealLoadingTimer = Timer(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      if (_isCameraMoving) return;
      if (!_showLiveMarkers) return;
      if (_markerRevealSequence != revealSeq) return;
      setState(() => _awaitingFetchMarkers = false);
    });
  }

  String? _thumbnailForSpace(Map<String, dynamic> space) {
    final thumbnailRaw = space['thumbnail'];
    final thumbnailMap = thumbnailRaw is Map<String, dynamic>
        ? thumbnailRaw
        : null;
    final thumbnailUrlRaw = space['thumbnailUrl'];
    final thumbnailUrlMap = thumbnailUrlRaw is Map<String, dynamic>
        ? thumbnailUrlRaw
        : null;
    final thumbnailImageRaw = space['thumbnailImage'];
    final thumbnailImageMap = thumbnailImageRaw is Map<String, dynamic>
        ? thumbnailImageRaw
        : null;
    final imageIdRaw = space['imageId'];
    final imageIdMap = imageIdRaw is Map<String, dynamic> ? imageIdRaw : null;
    final imageRaw = space['image'];
    final imageMap = imageRaw is Map<String, dynamic> ? imageRaw : null;
    final photoRaw = space['photo'];
    final photoMap = photoRaw is Map<String, dynamic> ? photoRaw : null;
    final representativeRaw = space['representativeImage'];
    final representativeMap = representativeRaw is Map<String, dynamic>
        ? representativeRaw
        : null;
    final feed = space['feed'];
    final feedMap = feed is Map<String, dynamic> ? feed : null;
    final images = (feedMap?['images'] ?? space['images']);
    final firstImage =
        images is List &&
            images.isNotEmpty &&
            images.first is Map<String, dynamic>
        ? images.first as Map<String, dynamic>
        : null;
    final firstImageUrl =
        images is List && images.isNotEmpty && images.first is String
        ? images.first as String
        : null;
    String? firstThumbnailUrl;
    final thumbnailUrls = space['thumbnailUrls'];
    if (thumbnailUrls is List) {
      for (final entry in thumbnailUrls) {
        if (entry is String && entry.trim().isNotEmpty) {
          firstThumbnailUrl = entry.trim();
          break;
        }
      }
    }
    return _firstValidImageUrl([
      thumbnailRaw is String ? thumbnailRaw : null,
      thumbnailImageRaw is String ? thumbnailImageRaw : null,
      thumbnailMap?['thumbnailUrl'] as String?,
      thumbnailMap?['cdnUrl'] as String?,
      thumbnailMap?['fileUrl'] as String?,
      thumbnailUrlMap?['thumbnailUrl'] as String?,
      thumbnailUrlMap?['cdnUrl'] as String?,
      thumbnailUrlMap?['fileUrl'] as String?,
      thumbnailImageMap?['thumbnailUrl'] as String?,
      thumbnailImageMap?['cdnUrl'] as String?,
      thumbnailImageMap?['fileUrl'] as String?,
      space['thumbnailUrl'] as String?,
      space['thumbnailImageUrl'] as String?,
      space['imageUrl'] as String?,
      space['representativeImageUrl'] as String?,
      space['mainImageUrl'] as String?,
      space['coverImageUrl'] as String?,
      imageIdMap?['cdnUrl'] as String?,
      imageIdMap?['fileUrl'] as String?,
      imageIdMap?['thumbnailUrl'] as String?,
      imageMap?['cdnUrl'] as String?,
      imageMap?['fileUrl'] as String?,
      imageMap?['thumbnailUrl'] as String?,
      photoMap?['cdnUrl'] as String?,
      photoMap?['fileUrl'] as String?,
      photoMap?['thumbnailUrl'] as String?,
      representativeMap?['cdnUrl'] as String?,
      representativeMap?['fileUrl'] as String?,
      representativeMap?['thumbnailUrl'] as String?,
      firstThumbnailUrl,
      firstImageUrl,
      firstImage?['thumbnailUrl'] as String?,
      firstImage?['cdnUrl'] as String?,
      firstImage?['fileUrl'] as String?,
    ]);
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
    if (trimmed.toLowerCase() == 'null') return null;
    if (trimmed.toLowerCase() == 'undefined') return null;
    return trimmed;
  }

  String _spaceType(Map<String, dynamic> space) {
    return _isClusterSpace(space) ? 'CLUSTER' : 'PLACE';
  }

  String _titleForSpace(Map<String, dynamic> space) {
    final rawTitle = space['title'] ?? space['placeName'] ?? space['name'];
    if (rawTitle is String && rawTitle.trim().isNotEmpty) {
      return rawTitle.trim();
    }
    return '';
  }

  String _addressForSpace(Map<String, dynamic> space) {
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
      if (raw != null) {
        final fallback = raw.toString().trim();
        if (fallback.isNotEmpty &&
            fallback != '{}' &&
            fallback.toLowerCase() != 'null') {
          return fallback;
        }
      }
      return null;
    }

    return pick(space['address']) ??
        pick(space['placeName']) ??
        pick(space['location']) ??
        '';
  }

  String _markerIdForSpace(Map<String, dynamic> space, int index) {
    final type = _spaceType(space);
    final lat = (space['latitude'] as num?)?.toDouble();
    final lng = (space['longitude'] as num?)?.toDouble();
    final geoFallback = (lat != null && lng != null)
        ? '${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}'
        : index.toString();
    final rawId = _isClusterSpace(space)
        ? (space['clusterId'] ??
              space['id'] ??
              '${space['latitude']}_${space['longitude']}' ??
              index)
        : (space['id'] ?? space['feedId'] ?? space['entityId'] ?? geoFallback);
    return 'space_${type}_$rawId';
  }

  NLatLng _displayLatLngForSpace(
    Map<String, dynamic> space, {
    required double lat,
    required double lng,
  }) {
    final rawId =
        space['id'] ?? space['placeId'] ?? space['spaceId'] ?? '$lat,$lng';
    final key = rawId.toString();
    final cached = _jitteredLatLngs[key];
    if (cached != null) return cached;
    final hash = key.hashCode;
    final radius = ((hash & 0xFF) / 255.0) * _markerJitterMaxMeters;
    final angle = (((hash >> 8) & 0xFF) / 255.0) * 2 * math.pi;
    final latRad = lat * math.pi / 180.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = (111320.0 * math.cos(latRad)).abs().clamp(
      1.0,
      111320.0,
    );
    final deltaLat = (radius * math.cos(angle)) / metersPerDegLat;
    final deltaLng = (radius * math.sin(angle)) / metersPerDegLng;
    final jittered = NLatLng(lat + deltaLat, lng + deltaLng);
    _jitteredLatLngs[key] = jittered;
    return jittered;
  }

  Widget _buildLiveMarkerOverlay() {
    if (!_showLiveMarkers ||
        _typeScopedSpaces.isEmpty ||
        _liveMarkerPoints.isEmpty) {
      return const SizedBox.shrink();
    }
    const maxRichOverlays = 5;
    const markerSize = 44.0;
    const labelHeight = 38.0;
    const labelWidth = 96.0;
    var markerEntries =
        <
          ({
            String markerId,
            String type,
            NPoint point,
            String? thumbnailUrl,
            Map<String, dynamic> space,
            bool isFocused,
            bool isCluster,
            double lat,
            double lng,
          })
        >[];
    for (var i = 0; i < _typeScopedSpaces.length; i += 1) {
      final space = _typeScopedSpaces[i];
      final type = _spaceType(space);
      final markerId = _markerIdForSpace(space, i);
      final point = _liveMarkerPoints[markerId];
      if (point == null) continue;
      final lat = (space['latitude'] as num?)?.toDouble();
      final lng = (space['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final isFocused = _isWithinFocusRadius(lat: lat, lng: lng);
      markerEntries.add((
        markerId: markerId,
        type: type,
        point: point,
        thumbnailUrl: _disableMarkerThumbnailsForTest
            ? null
            : _thumbnailForSpace(space),
        space: space,
        isFocused: isFocused,
        isCluster: _isClusterSpace(space),
        lat: lat,
        lng: lng,
      ));
    }
    final center = _lastCenter;
    if (_isClusterMode) {
      final richEntries = center != null && markerEntries.length > maxRichOverlays
          ? _limitEntriesByDistance(
              markerEntries,
              maxRichOverlays,
              distanceOf: (entry) => _distanceMeters(
                lat1: center.latitude,
                lng1: center.longitude,
                lat2: entry.lat,
                lng2: entry.lng,
              ),
            )
          : markerEntries;
      final richIds = richEntries
          .map((entry) => entry.markerId)
          .toSet();
      final items = <Widget>[];
      for (final entry in markerEntries) {
        final clusterCount = _clusterCountForSpace(entry.space);
        final clusterSize = CommonPlaceClusterMarker.stackSizeFor(markerSize);
        final isRich = richIds.contains(entry.markerId);
        items.add(
          Positioned(
            key: ValueKey(entry.markerId),
            left: entry.point.x - clusterSize / 2,
            top: entry.point.y - clusterSize / 2,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () async {
                if (!mounted) return;
                setState(() => _selectedLiveMarkerId = entry.markerId);
                await _zoomToLatLngUntil(
                  target: NLatLng(entry.lat, entry.lng),
                  targetZoom: _clusterTapAutoZoomTarget,
                );
              },
                child: _buildMarkerReveal(
                  id: entry.markerId,
                  child: isRich
                      ? CommonPlaceClusterMarker(
                          count: clusterCount,
                          imageUrls: _disableMarkerThumbnailsForTest
                              ? const []
                              : [entry.thumbnailUrl],
                          size: markerSize,
                        )
                      : const Center(child: _PlaceDotMarker()),
              ),
            ),
          ),
        );
      }
      return Stack(clipBehavior: Clip.none, children: items);
    }
    var clusters = _buildLiveMarkerClusters(markerEntries);
    final richClusters = center != null && clusters.length > maxRichOverlays
        ? _limitEntriesByDistance(
            clusters,
            maxRichOverlays,
            distanceOf: (cluster) => _distanceMeters(
              lat1: center.latitude,
              lng1: center.longitude,
              lat2: cluster.centerLatLng.latitude,
              lng2: cluster.centerLatLng.longitude,
            ),
          )
        : clusters;
    final richClusterIds = richClusters
        .map((cluster) => cluster.clusterId)
        .toSet();
    final displayCenters = _clusterCenterPoints.isNotEmpty
        ? _clusterCenterPoints
        : {for (final cluster in clusters) cluster.clusterId: cluster.center};
    final primaryClusterId = _primaryClusterIdForCenter(clusters);
    final markerItems = <({String id, Widget child})>[];
    final clusterItems = <({String id, Widget child})>[];
    for (final cluster in clusters) {
      final single = cluster.members.length == 1 ? cluster.members.first : null;
      final displayCenter =
          single?.point ?? displayCenters[cluster.clusterId] ?? cluster.center;
      final adjustedCenter = displayCenter;
      final isClusterSpace = single != null && _isClusterSpace(single.space);
      final clusterCount = single == null
          ? cluster.members.fold<int>(
              0,
              (sum, member) => sum + _clusterCountForSpace(member.space),
            )
          : _clusterCountForSpace(single.space);
      final showClusterMarker =
          single == null || (isClusterSpace && clusterCount > 1);
      final isRichCluster = richClusterIds.contains(cluster.clusterId);
      final isPrimarySingle =
          single != null &&
          (cluster.clusterId == primaryClusterId ||
              cluster.clusterId == _selectedLiveMarkerId);
      final title = single == null
          ? '$clusterCount'
          : _titleForSpace(single.space);
      final hasLabel = single != null && !showClusterMarker && title.isNotEmpty;
      final clusterSize = showClusterMarker
          ? CommonPlaceClusterMarker.stackSizeFor(markerSize)
          : markerSize;
      final itemWidth = hasLabel ? labelWidth : clusterSize;
      final itemHeight = clusterSize + (hasLabel ? labelHeight : 0);
      final markerCenterOffset = clusterSize / 2;
      final item = (
        id: cluster.clusterId,
        child: Positioned(
          key: ValueKey(cluster.clusterId),
          left: adjustedCenter.x - itemWidth / 2,
          top: adjustedCenter.y - markerCenterOffset,
          child: SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: RepaintBoundary(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () async {
                  if (!mounted) return;
                  setState(() => _selectedLiveMarkerId = cluster.clusterId);
                  if (showClusterMarker && single != null) {
                    await _zoomToLatLngUntil(
                      target: cluster.centerLatLng,
                      targetZoom: _clusterTapAutoZoomTarget,
                    );
                    return;
                  }
                  if (cluster.members.length >= 2) {
                    await _zoomToLatLngUntil(
                      target: cluster.centerLatLng,
                      targetZoom: _clusterTapAutoZoomTarget,
                    );
                    return;
                  }
                  if (single == null) return;
                  final isDotOnly = !isPrimarySingle;
                  if (isDotOnly) {
                    setState(() => _selectedLiveMarkerId = cluster.clusterId);
                    return;
                  }
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlacebookDetailView(space: single.space),
                        ),
                      )
                      .then((deleted) {
                        if (deleted == true) {
                          final placeId = _placeIdOf(single.space);
                          _removePlaceFromMap(placeId);
                        }
                      });
                },
                child: _buildMarkerReveal(
                  id: cluster.clusterId,
                  child: !isRichCluster
                      ? const Center(child: _PlaceDotMarker())
                      : showClusterMarker
                      ? CommonPlaceClusterMarker(
                          count: clusterCount,
                          imageUrls: _disableMarkerThumbnailsForTest
                              ? const []
                              : cluster.members
                                    .map((member) => member.thumbnailUrl)
                                    .toList(growable: false),
                          size: markerSize,
                          title: showClusterMarker ? null : title,
                        )
                      : isPrimarySingle
                      ? CommonPlaceMarker(
                          cacheKey: _disableMarkerThumbnailsForTest
                              ? null
                              : single.thumbnailUrl,
                          imageUrl: _disableMarkerThumbnailsForTest
                              ? null
                              : single.thumbnailUrl,
                          size: markerSize,
                          title: title,
                          isFavorited:
                              (single.space['favorited'] as bool?) ??
                              (single.space['isFavorited'] as bool?) ??
                              false,
                        )
                      : const Center(child: _PlaceDotMarker()),
                ),
              ),
            ),
          ),
        ),
      );
      if (single == null) {
        clusterItems.add(item);
      } else {
        markerItems.add(item);
      }
    }

    if (_selectedLiveMarkerId != null) {
      markerItems.sort((a, b) {
        if (a.id == _selectedLiveMarkerId) return 1;
        if (b.id == _selectedLiveMarkerId) return -1;
        return 0;
      });
      clusterItems.sort((a, b) {
        if (a.id == _selectedLiveMarkerId) return 1;
        if (b.id == _selectedLiveMarkerId) return -1;
        return 0;
      });
    }
    final renderItems = <({String id, Widget child})>[
      ...clusterItems,
      ...markerItems,
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: renderItems.map((item) => item.child).toList(),
    );
  }

  Widget _buildMarkerReveal({required String id, required Widget child}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('marker-reveal-$id-$_markerRevealSequence'),
      tween: Tween(begin: 0.72, end: 1.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: value,
            alignment: Alignment.center,
            child: builtChild,
          ),
        );
      },
    );
  }

  String? _primaryClusterIdForCenter(List<_LiveMarkerCluster> clusters) {
    final center = _lastCenter;
    if (center == null || clusters.isEmpty) return null;
    String? closestId;
    double? closestDistance;
    for (final cluster in clusters) {
      if (cluster.members.length != 1) continue;
      final member = cluster.members.first;
      final distance = _distanceMeters(
        lat1: center.latitude,
        lng1: center.longitude,
        lat2: member.lat,
        lng2: member.lng,
      );
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
        closestId = cluster.clusterId;
      }
    }
    return closestId;
  }

  Widget _buildAnimatedLiveMarkerOverlay() {
    return RepaintBoundary(child: _buildLiveMarkerOverlay());
  }

  bool _isPointInView(NPoint point) {
    if (_mapViewportWidth <= 0 || _mapViewportHeight <= 0) return true;
    const padding = 40.0;
    return point.x >= -padding &&
        point.y >= -padding &&
        point.x <= _mapViewportWidth + padding &&
        point.y <= _mapViewportHeight + padding;
  }

  List<T> _limitEntriesByDistance<T>(
    List<T> entries,
    int limit, {
    required double Function(T entry) distanceOf,
  }) {
    if (entries.length <= limit) return entries;
    final sorted = List<T>.from(entries)
      ..sort((a, b) => distanceOf(a).compareTo(distanceOf(b)));
    return sorted.take(limit).toList();
  }

  List<_LiveMarkerCluster> _buildLiveMarkerClusters(
    List<
      ({
        String markerId,
        String type,
        NPoint point,
        String? thumbnailUrl,
        Map<String, dynamic> space,
        bool isFocused,
        bool isCluster,
        double lat,
        double lng,
      })
    >
    entries,
  ) {
    if (entries.isEmpty) return const [];
    final clusters = <_LiveMarkerCluster>[];
    final visited = <int>{};
    for (var i = 0; i < entries.length; i += 1) {
      if (visited.contains(i)) continue;
      visited.add(i);
      final seed = entries[i];
      final members =
          <
            ({
              String markerId,
              String type,
              NPoint point,
              String? thumbnailUrl,
              Map<String, dynamic> space,
              bool isFocused,
              bool isCluster,
              double lat,
              double lng,
            })
          >[seed];
      if (!seed.isCluster) {
        for (var j = i + 1; j < entries.length; j += 1) {
          if (visited.contains(j)) continue;
          final candidate = entries[j];
          if (candidate.isCluster) continue;
          if (candidate.type != seed.type) continue;
          final dx = candidate.point.x - seed.point.x;
          final dy = candidate.point.y - seed.point.y;
          final distance = math.sqrt((dx * dx) + (dy * dy));
          if (distance <= _liveClusterDistancePx) {
            visited.add(j);
            members.add(candidate);
          }
        }
      }
      final sumX = members.fold<double>(0, (sum, it) => sum + it.point.x);
      final sumY = members.fold<double>(0, (sum, it) => sum + it.point.y);
      final center = NPoint(sumX / members.length, sumY / members.length);
      final sumLat = members.fold<double>(0, (sum, it) => sum + it.lat);
      final sumLng = members.fold<double>(0, (sum, it) => sum + it.lng);
      final centerLatLng = NLatLng(
        sumLat / members.length,
        sumLng / members.length,
      );
      final memberIds = members.map((member) => member.markerId).toList()
        ..sort();
      final clusterId = members.length == 1
          ? memberIds.first
          : 'cluster_${memberIds.join("_")}';
      clusters.add(
        _LiveMarkerCluster(
          clusterId: clusterId,
          center: center,
          centerLatLng: centerLatLng,
          members: members,
        ),
      );
    }
    return clusters;
  }

  Map<String, NPoint> _buildDisplayCentersForOverlaps(
    List<_LiveMarkerCluster> clusters,
  ) {
    if (clusters.length <= 1) {
      return {
        for (final cluster in clusters) cluster.clusterId: cluster.center,
      };
    }
    const overlapDistancePx = 2.0;
    const spreadRadiusPx = 18.0;
    final result = <String, NPoint>{};
    final visited = <int>{};
    for (var i = 0; i < clusters.length; i += 1) {
      if (visited.contains(i)) continue;
      visited.add(i);
      final seed = clusters[i];
      final group = <int>[i];
      for (var j = i + 1; j < clusters.length; j += 1) {
        if (visited.contains(j)) continue;
        final candidate = clusters[j];
        final dx = candidate.center.x - seed.center.x;
        final dy = candidate.center.y - seed.center.y;
        final distance = math.sqrt((dx * dx) + (dy * dy));
        if (distance <= overlapDistancePx) {
          visited.add(j);
          group.add(j);
        }
      }
      if (group.length == 1) {
        result[seed.clusterId] = seed.center;
        continue;
      }
      for (var index = 0; index < group.length; index += 1) {
        final cluster = clusters[group[index]];
        final angle = (2 * math.pi * index) / group.length;
        final offsetX = math.cos(angle) * spreadRadiusPx;
        final offsetY = math.sin(angle) * spreadRadiusPx;
        result[cluster.clusterId] = NPoint(
          seed.center.x + offsetX,
          seed.center.y + offsetY,
        );
      }
    }
    return result;
  }

  Future<void> _zoomToLatLngUntil({
    required NLatLng target,
    required double targetZoom,
  }) async {
    if (_isClusterAutoZooming) return;
    final controller = _mapController;
    if (controller == null) return;
    _isClusterAutoZooming = true;
    try {
      if (!mounted) return;
      final camera = await controller.getCameraPosition();
      final clampedTarget = targetZoom.clamp(1.0, _clusterMaxZoom);
      final diff = clampedTarget - camera.zoom;
      if (diff <= 0.05) {
        await controller.updateCamera(
          NCameraUpdate.withParams(target: target, zoom: camera.zoom),
        );
        return;
      }
      final nextZoom = math.min(clampedTarget, camera.zoom + 1.1);
      await controller.updateCamera(
        NCameraUpdate.withParams(target: target, zoom: nextZoom),
      );
    } catch (_) {
      // Ignore transient map camera errors.
    } finally {
      _isClusterAutoZooming = false;
    }
  }

  bool _isWithinFocusRadius({required double? lat, required double? lng}) {
    final center = _lastCenter;
    if (center == null || lat == null || lng == null) return false;
    final distance = _distanceMeters(
      lat1: center.latitude,
      lng1: center.longitude,
      lat2: lat,
      lng2: lng,
    );
    return distance <= _focusMarkerRadiusMeters;
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            (math.sin(dLng / 2) * math.sin(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

  String? _distanceLabelForSpace({required double? lat, required double? lng}) {
    final location = _lastMyLocation;
    if (location == null || lat == null || lng == null) return null;
    final meters = _distanceMeters(
      lat1: location.latitude,
      lng1: location.longitude,
      lat2: lat,
      lng2: lng,
    );
    if (meters.isNaN || meters.isInfinite) return null;
    if (meters < 1000) return '${meters.round()}m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)}km';
  }

  void _onMapCameraMoving() {
    _cameraIdleDebounce?.cancel();
    if (_isCameraMoving) return;
    _isCameraMoving = true;
    final needsUpdate = _selectedLiveMarkerId != null ||
        _showLiveMarkers ||
        _liveMarkerPoints.isNotEmpty ||
        _clusterCenterPoints.isNotEmpty;
    if (needsUpdate) {
      setState(() {
        _selectedLiveMarkerId = null;
        _showLiveMarkers = false;
        _liveMarkerPoints = const {};
        _clusterCenterPoints = const {};
        _awaitingFetchMarkers = true;
      });
    }
  }

  void _onMapCameraIdle() {
    _cameraIdleDebounce?.cancel();
    _onMapCameraIdleSettled();
  }

  Future<void> _onMapCameraIdleSettled() async {
    _isCameraMoving = false;
    if (_skipNextCameraIdleFetch) {
      _skipNextCameraIdleFetch = false;
      await _updateLiveMarkerPoints();
      _awaitingFetchMarkers = false;
      if (!_isCameraMoving) {
        _showMarkersWithReveal();
      }
      return;
    }
    final controller = _mapController;
    if (controller != null) {
      try {
        final camera = await controller.getCameraPosition();
        _lastCenter = camera.target;
        _lastZoom = camera.zoom;
        await _updateRadiusOverlay(center: camera.target);
        _awaitingFetchMarkers = true;
        _fetchPlacebookSpaces();
      } catch (_) {
        // Ignore transient camera errors.
      }
    }
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
      _updateLiveMarkerPoints();
      _fetchPlacebookSpaces();
    });
  }

  Future<void> _onMyMapTap() async {
    if (!AuthStore.instance.isSignedIn.value) {
      await _promptLoginForMyMap();
      return;
    }
    _onTabSelected(0);
  }

  String? _activeChipId() {
    final themeIds = _effectiveThemeIds;
    if (themeIds.length == 1) return themeIds.first;
    return _selectedCategoryId;
  }

  void _centerChip({bool animated = true}) {
    final selectedId = _activeChipId();
    if (selectedId == null) return;
    final key = _chipKeys[selectedId];
    final targetContext = key?.currentContext;
    if (targetContext == null) return;
    final scrollableState = Scrollable.maybeOf(targetContext);
    if (scrollableState == null) return;
    try {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: animated ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // Ignore transient frame race while AnimatedSwitcher is replacing chip rows.
    }
  }

  Widget _animatedLayer({
    required bool visible,
    required Offset hiddenOffset,
    required Widget child,
  }) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : hiddenOffset,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: visible ? 1 : 0.97,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final themeChips = _themeChipFilters;
    final effectiveThemeIds = _effectiveThemeIds;
    return Container(
      height: 56,
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
      child: Padding(
        padding: const EdgeInsets.only(left: 36, right: 32),
        child: SingleChildScrollView(
          controller: _chipScrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: [
              if (themeChips.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: const ShapeDecoration(
                      color: Colors.white,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                        side: BorderSide(color: Color(0x22000000)),
                      ),
                    ),
                    child: const Text(
                      '테마 없음',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                )
              else
                ...themeChips.map((theme) {
                  final index = themeChips.indexOf(theme);
                  final themeId = theme['id']?.toString() ?? '';
                  final displayLabel = (theme['title'] as String?) ?? '';
                  final selected =
                      themeId.isNotEmpty &&
                      effectiveThemeIds.length == 1 &&
                      effectiveThemeIds.first == themeId;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == themeChips.length - 1 ? 8 : 4,
                      left: index == 0 ? 8 : 4,
                    ),
                    child: KeyedSubtree(
                      key: _chipKeys[themeId],
                      child: GestureDetector(
                        onTap: () async {
                          if (themeId.isEmpty) return;
                          if (widget.fixedThemeIds != null &&
                              widget.fixedThemeIds!.isNotEmpty) {
                            return;
                          }
                          setState(() {
                            if (selected) {
                              _selectedThemeIds = const [];
                            } else {
                              _selectedThemeIds = [themeId];
                            }
                            _selectedCategoryId = null;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _centerChip();
                          });
                          final center = _lastCenter;
                          if (center != null) {
                            _fetchPlacebookSpaces();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: ShapeDecoration(
                            color: selected ? Colors.black : Colors.white,
                            shape: const ContinuousRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            shadows: AppShadows.card,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayLabel,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShuffleButton() {
    return GestureDetector(
      onTap: () {
        _shuffleController?.forward(from: 0);
        _shuffleThemeChips();
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: Colors.black,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          shadows: AppShadows.card,
        ),
        child: RotationTransition(
          turns: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _shuffleController ?? kAlwaysDismissedAnimation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: const Icon(
            PhosphorIconsBold.arrowsClockwise,
            size: 16,
            color: MyApp.primary200,
          ),
        ),
      ),
    );
  }

  Widget _buildTopFilterButton() {
    if (!widget.showFilterButton) return const SizedBox.shrink();
    final effectiveThemeIds = _effectiveThemeIds;
    final filterCount = effectiveThemeIds.isNotEmpty
        ? effectiveThemeIds.length
        : (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty
              ? 1
              : 0);
    final showFilterBadge = filterCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _MapFloatingButton(
          icon: PhosphorIconsBold.magnifyingGlass,
          onTap: _openMapFilter,
          iconColor: Colors.black,
        ),
        if (showFilterBadge)
          Positioned(
            top: -8,
            right: -16,
            child: _MapFilterBadge(text: '$filterCount'),
          ),
      ],
    );
  }

  Future<void> _openMapFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapFilterView(
        categories: _categoryFilters,
        selectedCategoryId: _selectedCategoryId,
        selectedThemeIds: _effectiveThemeIds,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedCategoryId = result['categoryId'] as String?;
      if (widget.fixedThemeIds == null || widget.fixedThemeIds!.isEmpty) {
        _selectedThemeIds = (result['themeIds'] as List<String>? ?? const []);
      }
    });
    _updateLiveMarkerPoints();
    _fetchPlacebookSpaces();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom - 32;
    final mapBottomInset =
        _placeListPeekHeight + (widget.useBottomSafeArea ? bottomSafe : 0);
    final topSafe = MediaQuery.of(context).padding.top;
    const searchBarVerticalPadding = 8.0;
    const filterRowHeight = 50.0;
    const chipRowHeight = filterRowHeight + 8;
    const shuffleButtonSize = 36.0;
    final filterRowTop = topSafe + searchBarVerticalPadding;
    final markerLoadingTop = filterRowTop + chipRowHeight + 20;
    const chipLeftOffset = 16.0;
    final sortedListSpaces = _sortedListSpaces();
    final showInitialListLoading =
        _isListLoading && sortedListSpaces.isEmpty;
    final showListLoadingMore =
        _isListLoadingMore && sortedListSpaces.isNotEmpty;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: mapBottomInset,
                  child: !_isInitialCenterReady
                      ? const ColoredBox(
                          color: Colors.white,
                          child: Center(
                            child: CommonActivityIndicator(size: 24),
                          ),
                        )
                      : _animatedLayer(
                          visible: true,
                          hiddenOffset: const Offset(-0.04, 0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 0) {
                                _mapViewportWidth = constraints.maxWidth;
                              }
                              if (constraints.maxHeight > 0) {
                                _mapViewportHeight = constraints.maxHeight;
                              }
                              final widthChanged =
                                  (_mapViewportWidth - _lastViewportWidth)
                                          .abs() >
                                      0.5;
                              final heightChanged =
                                  (_mapViewportHeight - _lastViewportHeight)
                                          .abs() >
                                      0.5;
                              if (widthChanged || heightChanged) {
                                _lastViewportWidth = _mapViewportWidth;
                                _lastViewportHeight = _mapViewportHeight;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _updateLiveMarkerPoints();
                                });
                              }
                              return _buildMapWidget();
                            },
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: mapBottomInset,
                  child: IgnorePointer(
                    ignoring: false,
                    child: _animatedLayer(
                      visible: true,
                      hiddenOffset: const Offset(-0.04, 0),
                      child: _buildAnimatedLiveMarkerOverlay(),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: mapBottomInset + 32,
                  child: RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MapToggleVertical(
                          isSharedMap: _selectedIndex == 1,
                          onSharedTap: () {
                            if (_selectedIndex == 1) return;
                            _onTabSelected(1);
                            _triggerMapToggleToast('공유 지도를 보여줄게요!');
                          },
                          onMyTap: () {
                            if (_selectedIndex == 0) return;
                            _onMyMapTap();
                            _triggerMapToggleToast('내 지도를 보여줄게요!');
                          },
                        ),
                        const SizedBox(height: 16),
                        _MapZoomButton(
                          onZoomIn: () => _zoomBy(1),
                          onZoomOut: () => _zoomBy(-1),
                        ),
                        const SizedBox(height: 12),
                        _MapFloatingButton(
                          icon: PhosphorIconsFill.navigationArrow,
                          iconColor: MyApp.primary200,
                          onTap: () => _mapViewController.moveToMyLocation(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: topSafe + 150,
                  color: Colors.transparent,
                ),
              ),
            ),
            Positioned(
              top: filterRowTop,
              left: chipLeftOffset,
              right: 20,
              height: chipRowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildFilterChips(),
              ),
            ),
            Positioned(
              top: filterRowTop,
              right: 16,
              width: shuffleButtonSize,
              height: chipRowHeight,
              child: Align(
                alignment: Alignment.center,
                child: _buildShuffleButton(),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        searchBarVerticalPadding,
                        16,
                        searchBarVerticalPadding,
                      ),
                      child: SizedBox(
                        height: chipRowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildTopFilterButton(),
                        ),
                      ),
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: markerLoadingTop,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  ignoring: !_awaitingFetchMarkers,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOutCubic,
                    opacity: _awaitingFetchMarkers ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 190),
                      curve: Curves.easeOutBack,
                      scale: _awaitingFetchMarkers ? 1 : 0.82,
                      child: Container(
                        width: 56,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppShadows.card,
                        ),
                        alignment: Alignment.center,
                        child: LoadingIndicator(
                          indicatorType: Indicator.ballPulseSync,
                          strokeWidth: 1.6,
                          colors: const [
                            Colors.black,
                            Colors.black,
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.of(context).padding.top + 8,
              child: IgnorePointer(
                ignoring: true,
                child: CommonToastView(
                  visible: _isMapToggleToastVisible,
                  message: _mapToggleToastMessage,
                  sequence: _mapToggleToastSequence,
                  skipOutAnimation: _skipToastOutAnimation,
                ),
              ),
            ),
            if (!_hideBottomPlaceListForPerfTest)
              Positioned.fill(
                child: RepaintBoundary(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: CommonHandleListOverlay(
                      peekHeight: _placeListPeekHeight,
                      initialChildSize: 0.0,
                      useBottomSafeArea: widget.useBottomSafeArea,
                      cacheExtent: 420,
                      title: '이런 장소들을 발견했어요!',
                      count: null,
                      trailing: _buildListSortToggle(),
                      onEndReached: _loadMoreListPlaces,
                      itemCount: showInitialListLoading
                          ? 1
                          : sortedListSpaces.isEmpty
                          ? 1
                          : sortedListSpaces.length + (showListLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showInitialListLoading) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CommonActivityIndicator(size: 20),
                            ),
                          );
                        }
                        if (sortedListSpaces.isEmpty) {
                          return const CommonEmptyView(
                            message: '표시할 장소가 없습니다.',
                            showButton: false,
                            height: 140,
                          );
                        }
                        if (showListLoadingMore &&
                            index == sortedListSpaces.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CommonActivityIndicator(size: 18),
                            ),
                          );
                        }
                        final space = sortedListSpaces[index];
                        final lat = (space['latitude'] as num?)?.toDouble();
                        final lng = (space['longitude'] as num?)?.toDouble();
                        final title = _titleForSpace(space);
                        final placeName = _addressForSpace(space);
                        String? pickTitle(dynamic raw) {
                          if (raw is Map<String, dynamic>) {
                            final title = raw['title'];
                            if (title is String && title.trim().isNotEmpty) {
                              return title.trim();
                            }
                          }
                          if (raw is String && raw.trim().isNotEmpty) {
                            return raw.trim();
                          }
                          return null;
                        }

                        final categoryText =
                            pickTitle(space['category']) ??
                            pickTitle(space['categoryTitle']);
                        final themeText =
                            pickTitle(space['theme']) ??
                            pickTitle(space['themeTitle']);
                        final commentCount = _readCount(space, const [
                          'commentCount',
                        ]);
                        final likeCount = _readCount(space, const [
                          'helpfulCount',
                          'verificationCount',
                          'likeCount',
                        ]);
                        final favorited =
                            (space['favorited'] as bool?) ??
                            (space['isFavorited'] as bool?) ??
                            false;
                        final placeId = _placeIdOf(space);
                        return KeyedSubtree(
                          key: ValueKey('place_$placeId'),
                          child: RepaintBoundary(
                            child: CommonPlaceListItemView(
                              thumbnailUrl: _thumbnailForSpace(space) ?? '',
                              title: title.isNotEmpty ? title : '장소',
                              address: placeName,
                              commentCount: commentCount,
                              likeCount: likeCount,
                              categoryText: categoryText,
                              themeText: themeText,
                              distanceText: _distanceLabelForSpace(
                                lat: lat,
                                lng: lng,
                              ),
                              favorited: favorited,
                              onTap: () async {
                                final deleted = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PlacebookDetailView(space: space),
                                  ),
                                );
                                if (deleted == true) {
                                  _removePlaceFromMap(placeId);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveMarkerCluster {
  const _LiveMarkerCluster({
    required this.clusterId,
    required this.center,
    required this.centerLatLng,
    required this.members,
  });

  final String clusterId;
  final NPoint center;
  final NLatLng centerLatLng;
  final List<
    ({
      String markerId,
      String type,
      NPoint point,
      String? thumbnailUrl,
      Map<String, dynamic> space,
      bool isFocused,
      bool isCluster,
      double lat,
      double lng,
    })
  >
  members;
}

class _PlaceDotMarker extends StatelessWidget {
  const _PlaceDotMarker();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 12,
      height: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class _MapFilterBadge extends StatelessWidget {
  const _MapFilterBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isSingle = text.length <= 1;
    final content = Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
    return Container(
      width: isSingle ? 28 : null,
      height: 28,
      padding: isSingle
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: content,
    );
  }
}

class _MapToggleSegmentButton extends StatelessWidget {
  const _MapToggleSegmentButton({
    required this.isActive,
    required this.icon,
    required this.onTap,
  });

  final bool isActive;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = isActive ? Colors.black : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: ShapeDecoration(
          color: background,
          shape: const ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: isActive ? MyApp.primary200 : Colors.black,
        ),
      ),
    );
  }
}

class _MapToggleVertical extends StatelessWidget {
  const _MapToggleVertical({
    required this.isSharedMap,
    required this.onSharedTap,
    required this.onMyTap,
  });

  final bool isSharedMap;
  final VoidCallback onSharedTap;
  final VoidCallback onMyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        shadows: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapToggleSegmentButton(
            isActive: isSharedMap,
            icon: PhosphorIconsBold.globeHemisphereEast,
            onTap: onSharedTap,
          ),
          const SizedBox(height: 6),
          _MapToggleSegmentButton(
            isActive: !isSharedMap,
            icon: PhosphorIconsBold.user,
            onTap: onMyTap,
          ),
        ],
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          shadows: AppShadows.card,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 88,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        shadows: AppShadows.card,
      ),
      child: Column(
        children: [
          Expanded(
            child: CommonInkWell(
              onTap: onZoomIn,
              borderRadius: BorderRadius.circular(20),
              child: const Center(
                child: Icon(
                  PhosphorIconsBold.plus,
                  size: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: CommonInkWell(
              onTap: onZoomOut,
              borderRadius: BorderRadius.circular(20),
              child: const Center(
                child: Icon(
                  PhosphorIconsBold.minus,
                  size: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapViewConfig {
  const MapViewConfig({
    this.enableClusters = false,
    this.mapPlacesZoomThreshold = 14.0,
    this.clusterMinCount = 30,
    this.placeCountForCluster = 120,
    this.gridSizeMetersForZoom,
    this.maxMarkersForZoom,
  });

  final bool enableClusters;
  final double mapPlacesZoomThreshold;
  final int clusterMinCount;
  final int placeCountForCluster;
  final int Function(double zoom)? gridSizeMetersForZoom;
  final int Function(double zoom, {required bool isCluster})? maxMarkersForZoom;
}

int _toIntCount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  if (value is Map) {
    return _toIntCount(value['count']) != 0
        ? _toIntCount(value['count'])
        : _toIntCount(value['value']);
  }
  return 0;
}

int _readCount(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (!source.containsKey(key)) continue;
    final raw = source[key];
    if (raw == null) continue;
    return _toIntCount(raw);
  }
  final data = source['data'];
  if (data is Map<String, dynamic>) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final raw = data[key];
      if (raw == null) continue;
      return _toIntCount(raw);
    }
  }
  return 0;
}
