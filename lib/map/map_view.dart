import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/location/naver_location_service.dart';
import '../common/auth/auth_store.dart';
import '../common/state/home_tab_controller.dart';
import '../sign/sign_view.dart';
import '../common/network/api_client.dart';
import '../common/state/placebook_cache.dart';
import '../common/widgets/common_map_view.dart';
import '../common/widgets/common_place_marker.dart';
import '../common/widgets/common_place_cluster_marker.dart';
import '../common/widgets/common_login_guard.dart';
import '../map_cluster/map_cluster_view.dart';
import '../livespace_detail/livespace_detail_view.dart';
import 'widgets/map_navigation_view.dart';
import 'map_filter/map_filter_view.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const double _focusMarkerRadiusMeters = 1200;
  static const double _liveClusterDistancePx = 52;
  static const double _clusterMaxZoom = 18.0;
  static const double _clusterSelectionZoomThreshold = 17.8;
  int _selectedIndex = 0;
  String? _selectedCategoryId;
  List<String> _selectedThemeIds = const [];
  String _selectedListSort = '최신순';
  String _selectedListKind = 'LIVESPACE';
  String _centerPlaceText = '';
  final ScrollController _chipScrollController = ScrollController();
  Timer? _reverseGeocodeDebounce;
  bool _isLoadingNear = false;
  bool _isLoginPromptVisible = false;
  bool _awaitingFetchMarkers = false;
  List<Map<String, dynamic>> _nearSpaces = const [];
  NaverMapController? _mapController;
  bool _isUpdatingMarkerPoints = false;
  bool _pendingMarkerPointUpdate = false;
  Map<String, NPoint> _liveMarkerPoints = const {};
  bool _showLiveMarkers = true;
  bool _isCameraMoving = false;
  bool _skipNextCameraIdleFetch = false;
  bool _isProgrammaticMove = false;
  String? _selectedLiveMarkerId;
  NLatLng? _lastCenter;
  double? _lastZoom;
  NLatLng? _lastFetchCenter;
  double? _lastFetchZoom;
  double _screenScale = 1.0;
  double _mapViewportWidth = 0;
  double _mapViewportHeight = 0;
  late final Widget _mapWidget;
  List<Map<String, dynamic>> _categoryFilters = const [];
  static const String _filterLabel = '필터';
  late final Map<String, GlobalKey> _chipKeys;
  late final VoidCallback _mapFocusListener;
  MapFocusRequest? _pendingMapFocusRequest;
  Map<String, dynamic>? _optimisticCreatedSpace;
  DateTime? _optimisticCreatedAt;

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
    setLatLng(item['location']);
    setLatLng(item['position']);
    setLatLng(item['center']);
    setLatLng(item['coords']);

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
      final radiusKm =
          (_radiusKmForScreen() ?? 10.0).clamp(1.0, 500.0);
      const limit = 200;
      const orderBy = 'createdAt';
      const order = 'DESC';
      final categoryId = _selectedCategoryId;
      final themeIds = _selectedThemeIds.isNotEmpty ? _selectedThemeIds : null;
      final spaces = _selectedIndex == 1
          ? await ApiClient.fetchTopPlacebookThemes(
              latitude: center.latitude,
              longitude: center.longitude,
              radiusKm: radiusKm,
              limit: limit,
              orderBy: orderBy,
              order: order,
              categoryId: categoryId,
              themeIds: themeIds,
            )
          : await ApiClient.fetchMyPlacebookPlaces(
              latitude: center.latitude,
              longitude: center.longitude,
              radiusKm: radiusKm,
              limit: limit,
              orderBy: orderBy,
              order: order,
              categoryId: categoryId,
              themeIds: themeIds,
            );
      if (!mounted) return;
      final normalized = spaces.map(_normalizePlaceItem).toList();
      final merged = _dedupeSpaces(_mergeOptimisticCreatedSpace(normalized));
      setState(() => _nearSpaces = merged);
      await _updateLiveMarkerPoints();
      if (_awaitingFetchMarkers && mounted) {
        _awaitingFetchMarkers = false;
        setState(() => _showLiveMarkers = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _nearSpaces = const []);
      await _updateLiveMarkerPoints();
      if (_awaitingFetchMarkers && mounted) {
        _awaitingFetchMarkers = false;
        setState(() => _showLiveMarkers = true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingNear = false);
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


  @override
  void initState() {
    super.initState();
    _mapWidget = CommonMapView(
      onCenterChanged: _onMapCenterChanged,
      onCameraMoving: _onMapCameraMoving,
      onCameraIdle: _onMapCameraIdle,
      onMapReady: (controller) {
        _mapController = controller;
        final pending = _pendingMapFocusRequest;
        if (pending != null) {
          _focusToCreatedLivespace(pending);
        }
        _updateLiveMarkerPoints();
      },
    );
    _mapFocusListener = _handleMapFocusRequest;
    HomeTabController.mapFocusRequest.addListener(_mapFocusListener);
    _chipKeys = <String, GlobalKey>{};
    _loadCategoryFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
      const initialCenter = NLatLng(37.5665, 126.9780);
      _lastCenter = initialCenter;
      _fetchPlacebookSpaces();
    });
  }

  @override
  void dispose() {
    HomeTabController.mapFocusRequest.removeListener(_mapFocusListener);
    _reverseGeocodeDebounce?.cancel();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _resetMapFiltersToDefault() {
    setState(() {
      _selectedListSort = '최신순';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
    });
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
      _chipKeys
        ..clear()
        ..addAll({
          for (final item in active)
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
      'type': 'LIVESPACE',
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
    if (controller == null || _mapViewportHeight <= 0) return null;
    final halfHeight = _mapViewportHeight / 2;
    final metersPerDp = controller.getMeterPerDp();
    final meters = metersPerDp * halfHeight;
    if (meters.isNaN || meters.isInfinite || meters <= 0) return null;
    return meters / 1000;
  }


  Future<void> _updateLiveMarkerPoints() async {
    final controller = _mapController;
    if (controller == null) return;
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
      final nextPoints = <String, NPoint>{};
      for (var i = 0; i < _typeScopedSpaces.length; i += 1) {
        final space = _typeScopedSpaces[i];
        final lat = (space['latitude'] as num?)?.toDouble();
        final lng = (space['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final point = await controller.latLngToScreenLocation(NLatLng(lat, lng));
        nextPoints[_markerIdForSpace(space, i)] = point;
      }
      if (mounted) {
        setState(() {
          _liveMarkerPoints = nextPoints;
          if (_selectedLiveMarkerId != null &&
              !_liveMarkerPoints.containsKey(_selectedLiveMarkerId)) {
            _selectedLiveMarkerId = null;
          }
        });
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

  String? _thumbnailForSpace(Map<String, dynamic> space) {
    final thumbnailRaw = space['thumbnail'];
    final thumbnailMap = thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
    final feed = space['feed'];
    final feedMap = feed is Map<String, dynamic> ? feed : null;
    final images = (feedMap?['images'] ?? space['images']);
    final firstImage =
        images is List && images.isNotEmpty && images.first is Map<String, dynamic>
            ? images.first as Map<String, dynamic>
            : null;
    return (thumbnailRaw is String ? thumbnailRaw : null) ??
        thumbnailMap?['cdnUrl'] as String? ??
        thumbnailMap?['fileUrl'] as String? ??
        space['thumbnailUrl'] as String? ??
        firstImage?['thumbnailUrl'] as String? ??
        firstImage?['cdnUrl'] as String? ??
        firstImage?['fileUrl'] as String?;
  }

  String _spaceType(Map<String, dynamic> space) {
    return 'PLACE';
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
    final rawId = space['id'] ?? space['feedId'] ?? space['entityId'] ?? index;
    return 'space_${type}_$rawId';
  }

  Widget _buildLiveMarkerOverlay() {
    if (_typeScopedSpaces.isEmpty || _liveMarkerPoints.isEmpty) {
      return const SizedBox.shrink();
    }
    const markerSize = 44.0;
    const labelHeight = 24.0;
    const labelWidth = 96.0;
    final markerEntries = <({
      String markerId,
      String type,
      NPoint point,
      String? thumbnailUrl,
      Map<String, dynamic> space,
      bool isFocused,
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
        lat: lat,
        lng: lng,
      ));
    }
    final clusters = _buildLiveMarkerClusters(markerEntries);
    final displayCenters = {for (final cluster in clusters) cluster.clusterId: cluster.center};
    final primaryClusterId = _primaryClusterIdForCenter(clusters);
    final markerItems = <({String id, Widget child})>[];
    final clusterItems = <({String id, Widget child})>[];
    for (final cluster in clusters) {
      final single = cluster.members.length == 1 ? cluster.members.first : null;
      final displayCenter = single?.point ?? displayCenters[cluster.clusterId] ?? cluster.center;
      final clusterThumbnailUrl = cluster.members
          .map((member) => member.thumbnailUrl)
          .whereType<String>()
          .firstWhere(
            (url) => url.trim().isNotEmpty,
            orElse: () => '',
          );
      final isPrimarySingle = single != null &&
          (cluster.clusterId == primaryClusterId ||
              cluster.clusterId == _selectedLiveMarkerId);
      final title = single == null ? '${cluster.members.length}' : _titleForSpace(single.space);
      final hasLabel = title.isNotEmpty;
      final itemWidth = hasLabel ? labelWidth : markerSize;
      final itemHeight = markerSize + (hasLabel ? labelHeight : 0);
      final item = (
        id: cluster.clusterId,
        child: Positioned(
          key: ValueKey(cluster.clusterId),
          left: displayCenter.x - itemWidth / 2,
          top: displayCenter.y - markerSize / 2,
          child: SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: GestureDetector(
              onTap: () async {
                if (!mounted) return;
                setState(() => _selectedLiveMarkerId = cluster.clusterId);
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
                    builder: (_) => LivespaceDetailView(space: single.space),
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
                    child: single == null
                        ? CommonPlaceClusterMarker(
                            count: cluster.members.length,
                            imageUrl: clusterThumbnailUrl,
                            size: markerSize,
                            title: title,
                          )
                        : isPrimarySingle
                            ? CommonPlaceMarker(
                                imageUrl: single.thumbnailUrl,
                                size: markerSize,
                                title: title,
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
    return _buildLiveMarkerOverlay();
  }

  List<_LiveMarkerCluster> _buildLiveMarkerClusters(
    List<({
      String markerId,
      String type,
      NPoint point,
      String? thumbnailUrl,
      Map<String, dynamic> space,
      bool isFocused,
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
      double lat,
      double lng,
    })>[seed];
      for (var j = i + 1; j < entries.length; j += 1) {
        if (visited.contains(j)) continue;
        final candidate = entries[j];
        if (candidate.type != seed.type) continue;
        final dx = candidate.point.x - seed.point.x;
        final dy = candidate.point.y - seed.point.y;
        final distance = math.sqrt((dx * dx) + (dy * dy));
        if (distance <= _liveClusterDistancePx) {
          visited.add(j);
          members.add(candidate);
        }
      }
      final sumX = members.fold<double>(0, (sum, it) => sum + it.point.x);
      final sumY = members.fold<double>(0, (sum, it) => sum + it.point.y);
      final center = NPoint(sumX / members.length, sumY / members.length);
      final sumLat = members.fold<double>(0, (sum, it) => sum + it.lat);
      final sumLng = members.fold<double>(0, (sum, it) => sum + it.lng);
      final centerLatLng = NLatLng(sumLat / members.length, sumLng / members.length);
      final clusterId = members.length == 1
          ? members.first.markerId
          : 'cluster_${members.first.markerId}_${members.length}';
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
      _updateLiveMarkerPoints().whenComplete(() {
        if (!mounted) return;
        if (_showLiveMarkers) return;
        setState(() => _showLiveMarkers = true);
      });
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

  void _centerChip({bool animated = true}) {
    final selectedId = _selectedCategoryId;
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
    final labels = <String>[
      '__filter__',
      ..._categoryFilters.map((e) => e['id']?.toString() ?? '').where((id) => id.isNotEmpty),
      if (_categoryFilters.isEmpty) '__empty__',
    ];
    final filterCount = _selectedThemeIds.isNotEmpty
        ? _selectedThemeIds.length
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
                children: labels.map((label) {
                  if (label == '__filter__') {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, right: 12),
                      child: GestureDetector(
                        onTap: () async {
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
                              selectedThemeIds: _selectedThemeIds,
                            ),
                          );
                          if (!mounted || result == null) return;
                          setState(() {
                            _selectedCategoryId = result['categoryId'] as String?;
                            _selectedThemeIds =
                                (result['themeIds'] as List<String>? ?? const []);
                          });
                          _updateLiveMarkerPoints();
                          _fetchPlacebookSpaces();
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                right: -10,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    );
                  }
                  if (label == '__empty__') {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x22000000)),
                        ),
                        child: const Text(
                          '카테고리 없음',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    );
                  }
                  final category = _categoryFilters
                      .firstWhere((e) => (e['id']?.toString() ?? '') == label);
                  final selected = _selectedCategoryId == label;
                  final icon = PhosphorIconsFill.tag;
                  final displayLabel = (category['title'] as String?) ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: KeyedSubtree(
                      key: _chipKeys[label],
                      child: GestureDetector(
                        onTap: () async {
                          setState(() => _selectedCategoryId = label);
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
                                icon,
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
              ),
            ),
          ),
        ],
      ),
    );
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
    _screenScale = (mediaSize.shortestSide / 375).clamp(0.85, 1.3);
    final topSafe = MediaQuery.of(context).padding.top;
    const navigationBottomOffset = 56.0;
    const chipTopOffset = navigationBottomOffset + 8;
    const chipBlockHeight = 44.0;
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
                  top: topSafe + navigationBottomOffset,
                  left: 0,
                  right: 0,
                  bottom: 0,
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
                        return _mapWidget;
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: topSafe + navigationBottomOffset,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: false,
                  child: _animatedLayer(
                    visible: true,
                    hiddenOffset: const Offset(-0.04, 0),
                    child: _buildAnimatedLiveMarkerOverlay(),
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xddFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MapNavigationView(
                selectedIndex: _selectedIndex,
                onLatestTap: _onMyMapTap,
                onPopularTap: () => _onTabSelected(1),
                onAddressTap: () async {
                  await _onMyMapTap();
                  if (!AuthStore.instance.isSignedIn.value) return;
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  _recenterToLastCenter();
                },
                rightText: _centerPlaceText,
              ),
            ),
            Positioned(
              top: topSafe + chipTopOffset,
              left: 0,
              right: 0,
              child: _buildFilterChips(),
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
