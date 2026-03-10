import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:hence_ls_flutter_v2/common/widgets/common_inkwell.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/location/naver_location_service.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/auth/auth_store.dart';
import '../common/state/home_tab_controller.dart';
import '../sign/sign_view.dart';
import '../common/network/api_client.dart';
import '../common/state/placebook_cache.dart';
import '../common/widgets/common_map_view.dart';
import '../common/widgets/common_place_marker.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_place_cluster_marker.dart';
import '../common/widgets/common_login_guard.dart';
import '../common/widgets/common_textfield_view.dart';
import '../common/widgets/common_toast_view.dart';
import '../common/widgets/common_handle_list_sheet.dart';
import '../common/widgets/common_place_list_item_view.dart';
import '../map_cluster/map_cluster_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import 'widgets/map_navigation_view.dart';
import 'map_filter/map_filter_view.dart';
import '../common/navigation/root_navigator.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    this.showFilterButton = true,
    this.useBottomSafeArea = true,
    this.fixedThemeIds,
  });

  final bool showFilterButton;
  final bool useBottomSafeArea;
  final List<String>? fixedThemeIds;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with SingleTickerProviderStateMixin {
  static const double _focusMarkerRadiusMeters = 1200;
  static const double _liveClusterDistancePx = 84;
  static const double _clusterMaxZoom = 18.0;
  static const double _clusterSelectionZoomThreshold = 17.8;
  static const double _mapPlacesZoomThreshold = 14.0;
  static const double _placeListPeekHeight = 160.0;
  int _selectedIndex = 1;
  String? _selectedCategoryId;
  List<String> _selectedThemeIds = const [];
  String _selectedListSort = '거리순';
  String _centerPlaceText = '';
  final ScrollController _chipScrollController = ScrollController();
  Timer? _reverseGeocodeDebounce;
  bool _isLoadingNear = false;
  bool _pendingFilterFetch = false;
  bool _isLoginPromptVisible = false;
  bool _awaitingFetchMarkers = false;
  List<Map<String, dynamic>> _nearSpaces = const [];
  NaverMapController? _mapController;
  bool _isUpdatingMarkerPoints = false;
  bool _pendingMarkerPointUpdate = false;
  Map<String, NPoint> _liveMarkerPoints = const {};
  Map<String, NPoint> _clusterCenterPoints = const {};
  bool _showLiveMarkers = true;
  bool _isClusterMode = false;
  Timer? _markerUpdateDebounce;
  NLatLng? _lastMarkerUpdateCenter;
  double? _lastMarkerUpdateZoom;
  bool _isCameraMoving = false;
  bool _skipNextCameraIdleFetch = false;
  bool _isProgrammaticMove = false;
  String? _selectedLiveMarkerId;
  NLatLng? _lastCenter;
  NLatLng? _lastMyLocation;
  double? _lastZoom;
  NLatLng? _lastFetchCenter;
  double? _lastFetchZoom;
  double _screenScale = 1.0;
  double _mapViewportWidth = 0;
  double _mapViewportHeight = 0;
  double _lastViewportWidth = 0;
  double _lastViewportHeight = 0;
  static const String _radiusOverlayId = 'api-radius';
  NCircleOverlay? _radiusOverlay;
  bool _showRadiusOverlay = false;
  late final Widget _mapWidget;
  final CommonMapViewController _mapViewController = CommonMapViewController();
  List<Map<String, dynamic>> _categoryFilters = const [];
  List<Map<String, dynamic>> _themeFilters = const [];
  List<Map<String, dynamic>> _themeChipFilters = const [];
  static const String _filterLabel = '필터';
  late final Map<String, GlobalKey> _chipKeys;
  late final VoidCallback _mapFocusListener;
  late final VoidCallback _mapFilterListener;
  late final VoidCallback _tabIndexListener;
  bool _didInitialLoad = false;
  MapFocusRequest? _pendingMapFocusRequest;
  Map<String, dynamic>? _optimisticCreatedSpace;
  DateTime? _optimisticCreatedAt;
  Timer? _mapToggleToastTimer;
  String _mapToggleToastMessage = '';
  bool _isMapToggleToastVisible = false;
  int _mapToggleToastSequence = 0;
  bool _skipToastOutAnimation = false;

  Map<String, dynamic> _normalizePlaceItem(Map<String, dynamic> item) {
    final next = Map<String, dynamic>.from(item);
    String? _asString(dynamic value) {
      if (value == null) return null;
      if (value is String && value.trim().isNotEmpty) return value;
      return null;
    }

    num? _asNum(dynamic value) {
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    }

    void setLatLng(dynamic source, {String latKey = 'latitude', String lngKey = 'longitude'}) {
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
      final rawCount = item['count'] ?? item['clusterCount'] ?? item['placeCount'];
      if (rawCount is num) {
        next['clusterCount'] = rawCount.toInt();
      } else if (rawCount is String) {
        final parsed = int.tryParse(rawCount);
        if (parsed != null) next['clusterCount'] = parsed;
      }
    }

    final rawTitle = _asString(next['title']) ?? _asString(next['name']);
    final rawSubtitle = _asString(next['subtitle']);
    final rawDescription = _asString(next['description']);
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

    final lat = _asNum(next['latitude']);
    final lng = _asNum(next['longitude']);
    if (lat != null) next['latitude'] = lat.toDouble();
    if (lng != null) next['longitude'] = lng.toDouble();

    final placeName = next['placeName'] ?? next['name'];
    if (placeName is String && placeName.isNotEmpty) {
      next['placeName'] ??= placeName;
      next['title'] ??= placeName;
    }

    return next;
  }

  Future<void> _fetchPlacebookSpaces() async {
    if (_isLoadingNear) return;
    if (_selectedIndex == 0 && !AuthStore.instance.isSignedIn.value) {
      await _promptLoginForMyMap();
      if (_awaitingFetchMarkers && mounted) {
        _awaitingFetchMarkers = false;
        setState(() => _showLiveMarkers = true);
      }
      return;
    }
    if (_lastCenter != null) {
      _lastFetchCenter = _lastCenter;
    }
    if (_lastZoom != null) {
      _lastFetchZoom = _lastZoom;
    }
    setState(() => _isLoadingNear = true);
    try {
      final center = _lastCenter ?? const NLatLng(37.5665, 126.9780);
      final radiusKm = _radiusKmForScreen() ?? 10.0;
      final radiusMeters = (radiusKm * 1000).round();
      await _updateRadiusOverlay(center: center);
      const limit = 200;
      const orderBy = 'distance';
      const order = 'ASC';
      final categoryId = _selectedCategoryId;
      final themeIds = _effectiveThemeIds.isNotEmpty ? _effectiveThemeIds : null;
      final themeId = (themeIds != null && themeIds.length == 1) ? themeIds.first : null;
      final filter = _placesFilterForIndex();
      final zoom = _lastZoom ?? _mapPlacesZoomThreshold;
      final shouldUseClusters = _shouldUseClusterApi(zoom);

      Map<String, dynamic> response;
      bool isClusterMode = false;
      if (shouldUseClusters) {
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
        final clusterCount = _countFromMapResponse(response);
        if (clusterCount < 30) {
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
        if (placeCount >= 120) {
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
      await _updateLiveMarkerPoints();
      if (_awaitingFetchMarkers && mounted) {
        _awaitingFetchMarkers = false;
        setState(() => _showLiveMarkers = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearSpaces = const [];
        _isClusterMode = false;
      });
      await _updateLiveMarkerPoints();
      if (_awaitingFetchMarkers && mounted) {
        _awaitingFetchMarkers = false;
        setState(() => _showLiveMarkers = true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingNear = false);
      if (_pendingFilterFetch) {
        _pendingFilterFetch = false;
        if (mounted) {
          _fetchPlacebookSpaces();
        }
      }
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

  bool _isAllowedByTypeScope(Map<String, dynamic> item) => true;

  List<Map<String, dynamic>> get _typeScopedSpaces => _nearSpaces;

  List<Map<String, dynamic>> get _listSpaces {
    if (_nearSpaces.isEmpty) return const [];
    return _nearSpaces.where((space) => !_isClusterSpace(space)).toList();
  }

  bool _isClusterSpace(Map<String, dynamic> space) {
    if (space['isCluster'] == true) return true;
    final rawCount = space['clusterCount'] ?? space['count'] ?? space['placeCount'];
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

  @override
  void initState() {
    super.initState();
    final fixed = widget.fixedThemeIds;
    if (fixed != null && fixed.isNotEmpty) {
      _selectedThemeIds = List<String>.from(fixed);
    }
    _mapWidget = CommonMapView(
      controller: _mapViewController,
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
        controller
            .getCameraPosition()
            .then((camera) => _updateRadiusOverlay(center: camera.target));
        final pending = _pendingMapFocusRequest;
        if (pending != null) {
          _focusToCreatedLivespace(pending);
        }
        _updateLiveMarkerPoints();
      },
    );
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
    _lastCenter = initialCenter;
    _centerChip(animated: false);
    if (_mapController != null && _pendingMapFocusRequest == null) {
      _mapController!.updateCamera(
        NCameraUpdate.withParams(target: initialCenter),
      );
    }
    await _updateRadiusOverlay(center: initialCenter);
    _fetchPlacebookSpaces();
  }

  Future<NLatLng> _resolveInitialCenter() async {
    const fallback = NLatLng(37.5665, 126.9780);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final granted = await LocationPermissionService.isGranted();
      if (serviceEnabled && granted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
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
      }
    }
  }

  @override
  void dispose() {
    HomeTabController.mapFocusRequest.removeListener(_mapFocusListener);
    HomeTabController.mapFilterRequest.removeListener(_mapFilterListener);
    HomeTabController.currentIndex.removeListener(_tabIndexListener);
    _reverseGeocodeDebounce?.cancel();
    _mapToggleToastTimer?.cancel();
    _markerUpdateDebounce?.cancel();
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
    final spaces = List<Map<String, dynamic>>.from(_listSpaces);
    if (_selectedListSort == '인기순') {
      spaces.sort((a, b) {
        final aLikes = (a['likeCount'] as num?)?.toInt() ?? 0;
        final bLikes = (b['likeCount'] as num?)?.toInt() ?? 0;
        if (aLikes != bLikes) return bLikes.compareTo(aLikes);
        final aComments = (a['commentCount'] as num?)?.toInt() ?? 0;
        final bComments = (b['commentCount'] as num?)?.toInt() ?? 0;
        return bComments.compareTo(aComments);
      });
      return spaces;
    }
    if (_selectedListSort == '거리순') {
      final center = _lastCenter;
      if (center == null) return spaces;
      spaces.sort((a, b) {
        final aLat = (a['latitude'] as num?)?.toDouble();
        final aLng = (a['longitude'] as num?)?.toDouble();
        final bLat = (b['latitude'] as num?)?.toDouble();
        final bLng = (b['longitude'] as num?)?.toDouble();
        final aHas = aLat != null && aLng != null;
        final bHas = bLat != null && bLng != null;
        if (!aHas && !bHas) return 0;
        if (!aHas) return 1;
        if (!bHas) return -1;
        final aDist = _distanceMeters(
          lat1: center.latitude,
          lng1: center.longitude,
          lat2: aLat!,
          lng2: aLng!,
        );
        final bDist = _distanceMeters(
          lat1: center.latitude,
          lng1: center.longitude,
          lat2: bLat!,
          lng2: bLng!,
        );
        return aDist.compareTo(bDist);
      });
    }
    return spaces;
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
    debugPrint('[PLACEBOOK][CACHE] loaded categories=${categories.length}');
    final active = categories
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
    debugPrint('[PLACEBOOK][CACHE] loaded themes=${themes.length}');
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
          for (final item in chips)
            (item['id']?.toString() ?? ''): GlobalKey(),
        });
    });
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
      if (optimisticLat == null || optimisticLng == null || lat == null || lng == null) {
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
      _isProgrammaticMove = true;
      await controller.updateCamera(
        NCameraUpdate.withParams(
          target: target,
          zoom: 16.0,
        ),
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
        NCameraUpdate.withParams(
          target: camera.target,
          zoom: nextZoom,
        ),
      );
    } catch (_) {
      // Ignore transient map camera errors.
    }
  }

  void _onMapCenterChanged(NLatLng center) {
    _lastCenter = center;
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 320), () async {
      final place = await NaverLocationService.reverseGeocode(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted) return;
      final next = _toShortPlace((place ?? '').trim());
      if (next == _centerPlaceText) return;
      setState(() => _centerPlaceText = next);
    });
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
    return zoom < _mapPlacesZoomThreshold;
  }

  int _gridSizeMetersForZoom(double zoom) {
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
        color: Colors.blue.withOpacity(0.12),
        outlineColor: Colors.blue.withOpacity(0.35),
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
        if (mounted) setState(() => _liveMarkerPoints = const {});
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
      final canReuse = camera != null &&
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
      final nextPoints = <String, NPoint>{};
      for (var i = 0; i < _typeScopedSpaces.length; i += 1) {
        final space = _typeScopedSpaces[i];
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
        final point = await controller.latLngToScreenLocation(NLatLng(lat, lng));
        if (!_isPointInView(point)) continue;
        nextPoints[markerId] = point;
      }
      final markerEntries = <({
        String markerId,
        String type,
        NPoint point,
        String? thumbnailUrl,
        Map<String, dynamic> space,
        bool isFocused,
        bool isCluster,
        double lat,
        double lng,
      })>[];
      for (var i = 0; i < _typeScopedSpaces.length; i += 1) {
        final space = _typeScopedSpaces[i];
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
        for (final cluster in clusters) {
          final point =
              await controller.latLngToScreenLocation(cluster.centerLatLng);
          nextClusterCenters[cluster.clusterId] = point;
        }
      }
      if (mounted) {
        setState(() {
          _liveMarkerPoints = nextPoints;
          _clusterCenterPoints =
              _isClusterMode ? const {} : nextClusterCenters;
          if (_selectedLiveMarkerId != null &&
              !_liveMarkerPoints.containsKey(_selectedLiveMarkerId)) {
            _selectedLiveMarkerId = null;
          }
        });
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

  void _scheduleMarkerUpdate({Duration delay = const Duration(milliseconds: 120)}) {
    _markerUpdateDebounce?.cancel();
    _markerUpdateDebounce = Timer(delay, () {
      if (!mounted) return;
      _updateLiveMarkerPoints();
    });
  }

  void _scheduleMarkerUpdateWithReveal({
    Duration delay = const Duration(milliseconds: 120),
  }) {
    _markerUpdateDebounce?.cancel();
    _markerUpdateDebounce = Timer(delay, () {
      if (!mounted) return;
      _updateLiveMarkerPoints().whenComplete(() {
        if (!mounted) return;
        if (_showLiveMarkers) return;
        setState(() => _showLiveMarkers = true);
      });
    });
  }

  String? _thumbnailForSpace(Map<String, dynamic> space) {
    final thumbnailRaw = space['thumbnail'];
    final thumbnailMap = thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
    final imageIdRaw = space['imageId'];
    final imageIdMap = imageIdRaw is Map<String, dynamic> ? imageIdRaw : null;
    final imageRaw = space['image'];
    final imageMap = imageRaw is Map<String, dynamic> ? imageRaw : null;
    final feed = space['feed'];
    final feedMap = feed is Map<String, dynamic> ? feed : null;
    final images = (feedMap?['images'] ?? space['images']);
    final firstImage =
        images is List && images.isNotEmpty && images.first is Map<String, dynamic>
            ? images.first as Map<String, dynamic>
            : null;
    return _firstValidImageUrl([
      thumbnailRaw is String ? thumbnailRaw : null,
      thumbnailMap?['cdnUrl'] as String?,
      thumbnailMap?['fileUrl'] as String?,
      space['thumbnailUrl'] as String?,
      imageIdMap?['cdnUrl'] as String?,
      imageIdMap?['fileUrl'] as String?,
      imageIdMap?['thumbnailUrl'] as String?,
      imageMap?['cdnUrl'] as String?,
      imageMap?['fileUrl'] as String?,
      imageMap?['thumbnailUrl'] as String?,
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

  String _markerIdForSpace(Map<String, dynamic> space, int index) {
    final type = _spaceType(space);
    final rawId = _isClusterSpace(space)
        ? (space['clusterId'] ??
            space['id'] ??
            '${space['latitude']}_${space['longitude']}' ??
            index)
        : (space['id'] ?? space['feedId'] ?? space['entityId'] ?? index);
    return 'space_${type}_$rawId';
  }

  Widget _buildLiveMarkerOverlay() {
    if (_typeScopedSpaces.isEmpty || _liveMarkerPoints.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_isCameraMoving && !_showLiveMarkers) {
      return const SizedBox.shrink();
    }
    const markerSize = 44.0;
    const labelHeight = 24.0;
    const labelWidth = 96.0;
    var markerEntries = <({
      String markerId,
      String type,
      NPoint point,
      String? thumbnailUrl,
      Map<String, dynamic> space,
      bool isFocused,
      bool isCluster,
      double lat,
      double lng,
    })>[];
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
        thumbnailUrl: _thumbnailForSpace(space),
        space: space,
        isFocused: isFocused,
        isCluster: _isClusterSpace(space),
        lat: lat,
        lng: lng,
      ));
    }
    final zoom = _lastZoom ?? _mapPlacesZoomThreshold;
    final maxMarkers = _maxMarkersForZoom(zoom, isCluster: _isClusterMode);
    final center = _lastCenter;
    if (center != null && markerEntries.length > maxMarkers) {
      markerEntries = _limitEntriesByDistance(
        markerEntries,
        maxMarkers,
        distanceOf: (entry) => _distanceMeters(
          lat1: center.latitude,
          lng1: center.longitude,
          lat2: entry.lat,
          lng2: entry.lng,
        ),
      );
    }
    if (_isClusterMode) {
      final items = <Widget>[];
      for (final entry in markerEntries) {
        final clusterCount = _clusterCountForSpace(entry.space);
        final clusterSize = CommonPlaceClusterMarker.stackSizeFor(markerSize);
        items.add(
          Positioned(
            key: ValueKey(entry.markerId),
            left: entry.point.x - clusterSize / 2,
            top: entry.point.y - clusterSize / 2,
            child: GestureDetector(
              onTap: () async {
                if (!mounted) return;
                setState(() => _selectedLiveMarkerId = entry.markerId);
                await _zoomToLatLng(NLatLng(entry.lat, entry.lng));
              },
              child: AnimatedOpacity(
                opacity: _showLiveMarkers ? 1 : 0,
                duration: Duration.zero,
                child: AnimatedScale(
                  scale: _showLiveMarkers ? 1 : 0.92,
                  duration: _showLiveMarkers
                      ? const Duration(milliseconds: 180)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  child: _AppearScaleIn(
                    key: ValueKey('appear_${entry.markerId}'),
                    child: CommonPlaceClusterMarker(
                      count: clusterCount,
                      imageUrls: const [],
                      size: markerSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return Stack(
        clipBehavior: Clip.none,
        children: items,
      );
    }
    final clusters = _buildLiveMarkerClusters(markerEntries);
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
      final clusterThumbnailUrls = cluster.members
          .map((member) => member.thumbnailUrl)
          .whereType<String>()
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList();
      final isClusterSpace = single != null && _isClusterSpace(single.space);
      final clusterCount = single == null
          ? cluster.members.fold<int>(
              0,
              (sum, member) => sum + _clusterCountForSpace(member.space),
            )
          : _clusterCountForSpace(single.space);
      final showClusterMarker = single == null || (isClusterSpace && clusterCount > 1);
      final isPrimarySingle = single != null &&
          (cluster.clusterId == primaryClusterId ||
              cluster.clusterId == _selectedLiveMarkerId);
      final title = single == null ? '$clusterCount' : _titleForSpace(single.space);
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
            child: GestureDetector(
              onTap: () async {
                if (!mounted) return;
                setState(() => _selectedLiveMarkerId = cluster.clusterId);
                if (showClusterMarker && single != null) {
                  await _zoomToLatLng(cluster.centerLatLng);
                  return;
                }
                if (cluster.members.length >= 2) {
                  if (await _shouldOpenClusterSelection(cluster)) {
                    _openClusterSelection(cluster);
                    return;
                  }
                  final didZoom = await _zoomToCluster(cluster);
                  if (!didZoom) {
                    _openClusterSelection(cluster);
                  }
                  return;
                }
                if (single == null) return;
                final isDotOnly = !isPrimarySingle;
                if (isDotOnly) {
                  setState(() => _selectedLiveMarkerId = cluster.clusterId);
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlacebookDetailView(space: single.space),
                  ),
                );
              },
              child: AnimatedOpacity(
                opacity: _showLiveMarkers ? 1 : 0,
                duration: Duration.zero,
                child: AnimatedScale(
                  scale: _showLiveMarkers ? 1 : 0.92,
                  duration: _showLiveMarkers
                      ? const Duration(milliseconds: 180)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  child: _AppearScaleIn(
                    key: ValueKey('appear_${cluster.clusterId}'),
                    child: showClusterMarker
                        ? CommonPlaceClusterMarker(
                            count: clusterCount,
                            imageUrls: clusterThumbnailUrls,
                            size: markerSize,
                            title: showClusterMarker ? null : title,
                          )
                        : isPrimarySingle
                            ? CommonPlaceMarker(
                                imageUrl: single.thumbnailUrl,
                                size: markerSize,
                                title: title,
                                isFavorited:
                                    (single.space['favorited'] as bool?) ??
                                        (single.space['isFavorited'] as bool?) ??
                                        false,
                              )
                            : const Center(
                                child: _PlaceDotMarker(),
                              ),
                  ),
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

  int _maxMarkersForZoom(double zoom, {required bool isCluster}) {
    if (isCluster) {
      if (zoom >= 15) return 200;
      if (zoom >= 14) return 180;
      if (zoom >= 13) return 160;
      return 140;
    }
    if (zoom >= 16) return 200;
    if (zoom >= 15) return 180;
    if (zoom >= 14) return 160;
    return 140;
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
    List<({
      String markerId,
      String type,
      NPoint point,
      String? thumbnailUrl,
      Map<String, dynamic> space,
      bool isFocused,
      bool isCluster,
      double lat,
      double lng,
    })> entries,
  ) {
    if (entries.isEmpty) return const [];
    final clusters = <_LiveMarkerCluster>[];
    final visited = <int>{};
    for (var i = 0; i < entries.length; i += 1) {
      if (visited.contains(i)) continue;
      visited.add(i);
      final seed = entries[i];
      final members = <({
      String markerId,
      String type,
      NPoint point,
      String? thumbnailUrl,
      Map<String, dynamic> space,
      bool isFocused,
      bool isCluster,
      double lat,
      double lng,
    })>[seed];
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
      final centerLatLng = NLatLng(sumLat / members.length, sumLng / members.length);
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
      return {for (final cluster in clusters) cluster.clusterId: cluster.center};
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

  bool _isOverlappedCluster(_LiveMarkerCluster cluster) {
    if (cluster.members.length < 2) return false;
    final seed = cluster.members.first;
    const tolerance = 0.00001;
    for (final member in cluster.members.skip(1)) {
      if ((member.lat - seed.lat).abs() > tolerance ||
          (member.lng - seed.lng).abs() > tolerance) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _shouldOpenClusterSelection(_LiveMarkerCluster cluster) async {
    if (_isOverlappedCluster(cluster)) return true;
    final controller = _mapController;
    if (controller == null) return false;
    try {
      final camera = await controller.getCameraPosition();
      return camera.zoom >= _clusterSelectionZoomThreshold;
    } catch (_) {
      return false;
    }
  }

  void _openClusterSelection(_LiveMarkerCluster cluster) {
    MapClusterView.show(
      context: context,
      type: cluster.members.first.type,
      items: cluster.members.map((member) => member.space).toList(),
      currentCenter: _lastCenter == null
          ? null
          : (lat: _lastCenter!.latitude, lng: _lastCenter!.longitude),
    );
  }

  Future<bool> _zoomToCluster(_LiveMarkerCluster cluster) async {
    final controller = _mapController;
    if (controller == null) return false;
    try {
      final camera = await controller.getCameraPosition();
      final nextZoom = math.min(_clusterMaxZoom, camera.zoom + 1.2);
      if ((nextZoom - camera.zoom).abs() < 0.01) return false;
      await controller.updateCamera(
        NCameraUpdate.withParams(
          target: cluster.centerLatLng,
          zoom: nextZoom,
        ),
      );
      return true;
    } catch (_) {
      // Ignore transient map camera errors.
      return false;
    }
  }

  Future<bool> _zoomToLatLng(NLatLng target) async {
    final controller = _mapController;
    if (controller == null) return false;
    try {
      final camera = await controller.getCameraPosition();
      final nextZoom = math.min(_clusterMaxZoom, camera.zoom + 1.4);
      if ((nextZoom - camera.zoom).abs() < 0.01) return false;
      await controller.updateCamera(
        NCameraUpdate.withParams(
          target: target,
          zoom: nextZoom,
        ),
      );
      return true;
    } catch (_) {
      return false;
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

  bool _shouldFetchPlacebook({
    required NLatLng center,
    required double zoom,
  }) {
    final lastCenter = _lastFetchCenter;
    final lastZoom = _lastFetchZoom;
    if (lastCenter == null || lastZoom == null) return true;
    final movedMeters = _distanceMeters(
      lat1: lastCenter.latitude,
      lng1: lastCenter.longitude,
      lat2: center.latitude,
      lng2: center.longitude,
    );
    const minMoveMeters = 300.0;
    const minZoomDelta = 0.7;
    if (movedMeters >= minMoveMeters) return true;
    if ((zoom - lastZoom).abs() >= minZoomDelta) return true;
    return false;
  }

  void _onMapCameraMoving() {
    if (_isCameraMoving) return;
    _isCameraMoving = true;
    if (_selectedLiveMarkerId != null) {
      setState(() => _selectedLiveMarkerId = null);
    }
    if (!_showLiveMarkers) return;
    setState(() => _showLiveMarkers = false);
  }

  Future<void> _onMapCameraIdle() async {
    _isCameraMoving = false;
    if (_skipNextCameraIdleFetch) {
      _skipNextCameraIdleFetch = false;
      _isProgrammaticMove = false;
      _updateLiveMarkerPoints().whenComplete(() {
        if (!mounted) return;
        if (_showLiveMarkers) return;
        setState(() => _showLiveMarkers = true);
      });
      return;
    }
    var triggeredFetch = false;
    final controller = _mapController;
    if (controller != null) {
      try {
        final camera = await controller.getCameraPosition();
        _lastCenter = camera.target;
        _lastZoom = camera.zoom;
        await _updateRadiusOverlay(center: camera.target);
        if (!_shouldFetchPlacebook(center: camera.target, zoom: camera.zoom)) {
          triggeredFetch = false;
        } else {
          triggeredFetch = true;
          _awaitingFetchMarkers = true;
          _lastFetchCenter = camera.target;
          _lastFetchZoom = camera.zoom;
          _fetchPlacebookSpaces();
        }
      } catch (_) {
        // Ignore transient camera errors.
      }
    }
    if (!triggeredFetch) {
      _scheduleMarkerUpdateWithReveal();
    }
  }

  Future<void> _recenterToLastCenter() async {
    final controller = _mapController;
    final center = _lastCenter;
    if (controller == null || center == null) return;
    try {
      await controller.updateCamera(
        NCameraUpdate.withParams(target: center),
      );
    } catch (_) {
      // Ignore transient map camera errors.
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
    final filterCount = effectiveThemeIds.isNotEmpty
        ? effectiveThemeIds.length
        : (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty ? 1 : 0);
    final showFilterBadge = filterCount > 0;
    final filterLabel = _filterLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _chipScrollController,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  if (widget.showFilterButton)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 12),
                      child: GestureDetector(
                        onTap: _openMapFilter,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                filterLabel,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            if (showFilterBadge)
                              Positioned(
                                top: -8,
                                right: -14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Text(
                                    '$filterCount',
                                    style: const TextStyle(
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
                      ),
                    ),
                  if (themeChips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x22000000)),
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
                      final themeId = theme['id']?.toString() ?? '';
                      final displayLabel = (theme['title'] as String?) ?? '';
                      final selected = themeId.isNotEmpty &&
                          effectiveThemeIds.length == 1 &&
                          effectiveThemeIds.first == themeId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorIconsFill.tag,
                                    size: 16,
                                    color: selected ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 6),
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
                    }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilterButton() {
    if (!widget.showFilterButton) return const SizedBox.shrink();
    final effectiveThemeIds = _effectiveThemeIds;
    final filterCount = effectiveThemeIds.isNotEmpty
        ? effectiveThemeIds.length
        : (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty ? 1 : 0);
    final showFilterBadge = filterCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _MapFloatingButton(
          icon: PhosphorIconsBold.magnifyingGlass,
          onTap: _openMapFilter,
        ),
        if (showFilterBadge)
          Positioned(
            top: -8,
            right: -20,
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

  Widget _buildListKindButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.black : const Color(0x22000000),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final bottomSafe = MediaQuery.of(context).padding.bottom - 32;
    final mapBottomInset = _placeListPeekHeight +
        (widget.useBottomSafeArea ? bottomSafe : 0);
    _screenScale = (mediaSize.shortestSide / 375).clamp(0.85, 1.3);
    final topSafe = MediaQuery.of(context).padding.top;
    const searchBarHeight = 50.0;
    const searchBarVerticalPadding = 8.0;
    const navigationBottomOffset =
        searchBarHeight + (searchBarVerticalPadding * 2);
    const chipTopOffset = navigationBottomOffset;
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
                  child: _animatedLayer(
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
                            (_mapViewportWidth - _lastViewportWidth).abs() > 0.5;
                        final heightChanged =
                            (_mapViewportHeight - _lastViewportHeight).abs() > 0.5;
                        if (widthChanged || heightChanged) {
                          _lastViewportWidth = _mapViewportWidth;
                          _lastViewportHeight = _mapViewportHeight;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            _updateLiveMarkerPoints();
                          });
                        }
                        return _mapWidget;
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapZoomButton(
                        onZoomIn: () => _zoomBy(1),
                        onZoomOut: () => _zoomBy(-1),
                      ),
                      const SizedBox(height: 12),
                      _MapFloatingButton(
                        icon: PhosphorIconsFill.navigationArrow,
                        onTap: () => _mapViewController.moveToMyLocation(),
                      ),
                    ],
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
                      child: Row(
                        children: [
                          _buildTopFilterButton(),
                          const Spacer(),
                          _MapToggleHorizontal(
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
                        ],
                      ),
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: topSafe + chipTopOffset,
              left: 0,
              right: 0,
              child: const SizedBox.shrink(),
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
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: CommonHandleListOverlay(
                  peekHeight: _placeListPeekHeight,
                  initialChildSize: 0.0,
                  useBottomSafeArea: widget.useBottomSafeArea,
                  title: '${_listSpaces.length} 개의 장소를 발견했어요!',
                  count: null,
                  trailing: _buildListSortToggle(),
                  items: _sortedListSpaces().isEmpty
                      ? const [
                          CommonEmptyView(
                            message: '표시할 장소가 없습니다.',
                            showButton: false,
                            height: 80,
                          ),
                        ]
                      : _sortedListSpaces().map((space) {
                    final lat = (space['latitude'] as num?)?.toDouble();
                    final lng = (space['longitude'] as num?)?.toDouble();
                    final title = _titleForSpace(space);
                    final placeName = (space['address'] ??
                            space['placeName'] ??
                            space['location'] ??
                            '') as String;
                    String? _pickTitle(dynamic raw) {
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
                        _pickTitle(space['category']) ?? _pickTitle(space['categoryTitle']);
                    final themeText =
                        _pickTitle(space['theme']) ?? _pickTitle(space['themeTitle']);
                    final commentCount = (space['commentCount'] as num?)?.toInt() ?? 0;
                    final likeCount = (space['likeCount'] as num?)?.toInt() ?? 0;
                    final dateText =
                        (space['createdAt'] ?? space['updatedAt'] ?? '') as String;
                    final favorited = (space['favorited'] as bool?) ??
                        (space['isFavorited'] as bool?) ??
                        false;
                    return CommonPlaceListItemView(
                      thumbnailUrl: _thumbnailForSpace(space) ?? '',
                      title: title.isNotEmpty ? title : '장소',
                      address: placeName,
                      commentCount: commentCount,
                      likeCount: likeCount,
                      categoryText: categoryText,
                      themeText: themeText,
                      distanceText: _distanceLabelForSpace(lat: lat, lng: lng),
                      favorited: favorited,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlacebookDetailView(space: space),
                          ),
                        );
                      },
                    );
                  }).toList(),
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
  final List<({
    String markerId,
    String type,
    NPoint point,
    String? thumbnailUrl,
    Map<String, dynamic> space,
    bool isFocused,
    bool isCluster,
    double lat,
    double lng,
  })> members;
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

class _MapToggleButton extends StatelessWidget {
  const _MapToggleButton({
    required this.isSharedMap,
    this.icon,
    this.isLight = false,
    required this.onTap,
  });

  final bool isSharedMap;
  final IconData? icon;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: ShapeDecoration(
          color: isLight ? Colors.white : Colors.black,
          shape: const ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon ??
              (isSharedMap
                  ? PhosphorIconsBold.usersThree
                  : PhosphorIconsBold.user),
          size: 20,
          color: isLight ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _MapFilterBadge extends StatelessWidget {
  const _MapFilterBadge({
    required this.text,
  });

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
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
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
    final iconColor = isActive ? Colors.white : Colors.black;
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
          color: iconColor,
        ),
      ),
    );
  }
}

class _MapToggleHorizontal extends StatelessWidget {
  const _MapToggleHorizontal({
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
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapToggleSegmentButton(
            isActive: isSharedMap,
            icon: PhosphorIconsBold.globeHemisphereEast,
            onTap: onSharedTap,
          ),
          const SizedBox(width: 6),
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

class _AppearScaleIn extends StatefulWidget {
  const _AppearScaleIn({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<_AppearScaleIn> createState() => _AppearScaleInState();
}

class _AppearScaleInState extends State<_AppearScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
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
          shadows: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({
    required this.onZoomIn,
    required this.onZoomOut,
  });

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
        shadows: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
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
