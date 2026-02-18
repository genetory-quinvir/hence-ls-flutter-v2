import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/location/naver_location_service.dart';
import '../common/auth/auth_store.dart';
import '../sign/sign_view.dart';
import '../feed_create_photo/feed_create_photo_view.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_calendar_view.dart';
import '../common/widgets/common_dot_marker.dart';
import '../common/widgets/common_cluster_marker.dart';
import '../common/widgets/common_feed_marker.dart';
import '../common/widgets/common_map_view.dart';
import '../common/widgets/common_livespace_marker.dart';
import '../feed_list/models/feed_models.dart';
import '../list/list_view.dart';
import '../profile/profile_feed_detail_view.dart';
import '../livespace_detail/livespace_detail_view.dart';
import 'widgets/map_navigation_view.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const double _focusMarkerRadiusMeters = 1200;
  static const double _liveClusterDistancePx = 52;
  int _selectedIndex = 0;
  String _selectedFilter = '오늘';
  bool _isHotArea = false;
  String _selectedListSort = '최신순';
  String _selectedListKind = 'LIVESPACE';
  String _selectedPurposeScope = '전체';
  String _centerPlaceText = '';
  DateTime? _selectedFilterDate;
  final ScrollController _chipScrollController = ScrollController();
  Timer? _reverseGeocodeDebounce;
  bool _isLoadingNear = false;
  List<Map<String, dynamic>> _nearSpaces = const [];
  NaverMapController? _mapController;
  bool _isUpdatingMarkerPoints = false;
  Map<String, NPoint> _liveMarkerPoints = const {};
  bool _showLiveMarkers = true;
  bool _isCameraMoving = false;
  bool _skipNextCameraIdleFetch = false;
  bool _isProgrammaticMove = false;
  String? _selectedLiveMarkerId;
  NLatLng? _lastCenter;
  double? _lastZoom;
  double _screenScale = 1.0;
  double _mapViewportWidth = 0;
  double _mapViewportHeight = 0;
  NCircleOverlay? _radiusOverlay;
  bool _isAddingRadiusOverlay = false;
  ({NLatLng center, double radiusKm})? _pendingRadiusUpdate;
  bool _radiusOverlayAdded = false;
  static const List<String> _filters = <String>[
    '오늘',
    '핫한 지역',
    '러닝',
    '카페',
    '전시',
  ];
  static const List<String> _listSorts = <String>[
    '최신순',
    '인기순',
    '거리순',
  ];
  static const List<String> _purposeScopes = <String>[
    '전체',
    '라이브스페이스만',
    '피드만',
  ];
  late final Map<String, GlobalKey> _chipKeys;

  bool _isAllowedByPurposeScope(Map<String, dynamic> item) {
    final purpose = (item['purpose'] as String?)?.toUpperCase();
    if (purpose == null || purpose.isEmpty) return true;
    if (purpose == 'LIVESPACE') return _selectedPurposeScope == '라이브스페이스만';
    if (purpose == 'FEED') return _selectedPurposeScope == '피드만';
    return _selectedPurposeScope == '전체';
  }

  List<Map<String, dynamic>> get _purposeScopedSpaces {
    return _nearSpaces;
  }

  List<Map<String, dynamic>> get _listItems {
    return _purposeScopedSpaces.toList();
  }

  String get _orderBy {
    switch (_selectedListSort) {
      case '인기순':
        return 'popular';
      case '거리순':
        return 'distance';
      default:
        return 'latest';
    }
  }

  String _displayFilterLabel(String label) {
    if (label != '오늘') return label;
    final selected = _selectedFilterDate;
    if (selected == null) return '오늘';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(selected.year, selected.month, selected.day);
    final diffDays = today.difference(picked).inDays;
    if (diffDays == 0) return '오늘';
    if (diffDays == 1) return '어제';
    return '${picked.year}. ${picked.month}. ${picked.day}';
  }

  @override
  void initState() {
    super.initState();
    _chipKeys = <String, GlobalKey>{
      for (final label in _filters) label: GlobalKey(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
      const initialCenter = NLatLng(37.5665, 126.9780);
      _lastCenter = initialCenter;
      _fetchNearSpaces(initialCenter);
    });
  }

  @override
  void dispose() {
    _reverseGeocodeDebounce?.cancel();
    _chipScrollController.dispose();
    super.dispose();
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

  double _radiusKmForZoom(double zoom) {
    if (zoom >= 17) return 1;
    if (zoom >= 15) return 3;
    if (zoom >= 13) return 5;
    if (zoom >= 11) return 30;
    return 20;
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

  Future<void> _updateRadiusOverlay({
    required NLatLng center,
    required double radiusKm,
  }) async {
    return;
    final controller = _mapController;
    if (controller == null) return;
    final radiusMeters = radiusKm * 1000;
    if (_isAddingRadiusOverlay) {
      _pendingRadiusUpdate = (center: center, radiusKm: radiusKm);
      return;
    }
    if (_radiusOverlay == null || !_radiusOverlayAdded) {
      final overlay = NCircleOverlay(
        id: 'map_radius_overlay',
        center: center,
        radius: radiusMeters,
        color: const Color(0x332E6BFF),
        outlineColor: const Color(0x662E6BFF),
        outlineWidth: 1.2,
      );
      _radiusOverlay = overlay;
      _isAddingRadiusOverlay = true;
      try {
        await controller.addOverlay(overlay);
        _radiusOverlayAdded = true;
      } finally {
        _isAddingRadiusOverlay = false;
      }
      final pending = _pendingRadiusUpdate;
      _pendingRadiusUpdate = null;
      if (pending != null) {
        _updateRadiusOverlay(
          center: pending.center,
          radiusKm: pending.radiusKm,
        );
      }
    } else {
      try {
        _radiusOverlay!.setCenter(center);
        _radiusOverlay!.setRadius(radiusMeters);
      } catch (_) {
        _radiusOverlay = null;
        _radiusOverlayAdded = false;
        _updateRadiusOverlay(center: center, radiusKm: radiusKm);
      }
    }
  }

  Future<void> _fetchNearSpaces(
    NLatLng center, {
    double? zoom,
    int? hotRankOverride,
  }) async {
    final filter = _selectedFilter;
    final isHotArea = hotRankOverride != null ? true : _isHotArea;
    final isTagFilter = filter == '러닝' || filter == '카페' || filter == '전시';
    final type = switch (_selectedPurposeScope) {
      '라이브스페이스만' => 'LIVESPACE',
      '피드만' => 'FEED',
      _ => 'ALL',
    };
    String formatDate(DateTime value) {
      final yyyy = value.year.toString().padLeft(4, '0');
      final mm = value.month.toString().padLeft(2, '0');
      final dd = value.day.toString().padLeft(2, '0');
      return '$yyyy-$mm-$dd';
    }
    final date = filter == '오늘'
        ? formatDate(_selectedFilterDate ?? DateTime.now())
        : null;
    final effectiveZoom = zoom ?? _lastZoom;
    final screenRadiusKm = _selectedIndex == 1 ? 100.0 : _radiusKmForScreen();
    final baseRadiusKm =
        effectiveZoom == null ? 10.0 : _radiusKmForZoom(effectiveZoom);
    final fallbackRadiusKm = (baseRadiusKm * _screenScale).clamp(1.0, 30.0);
    final radiusKm = (screenRadiusKm ?? fallbackRadiusKm).clamp(1.0, 500.0);
    _updateRadiusOverlay(center: center, radiusKm: radiusKm);
    setState(() => _isLoadingNear = true);
    try {
      List<Map<String, dynamic>> spaces;
      Map<String, dynamic>? movedCenter;
      if (isHotArea) {
        final res = await ApiClient.fetchNearbySpacesWithMeta(
          latitude: center.latitude,
          longitude: center.longitude,
          radiusKm: radiusKm,
          date: date,
          type: type,
          tags: isTagFilter ? <String>[filter] : null,
          orderBy: _orderBy,
          hotRank: hotRankOverride ?? 1,
        );
        spaces = res.feeds;
        movedCenter = res.movedCenter;
      } else {
        spaces = await ApiClient.fetchNearbySpaces(
          latitude: center.latitude,
          longitude: center.longitude,
          radiusKm: radiusKm,
          date: date,
          type: type,
          tags: isTagFilter ? <String>[filter] : null,
          orderBy: _orderBy,
        );
      }
      if (!mounted) return;
      setState(() => _nearSpaces = spaces);
      if (movedCenter is Map<String, dynamic>) {
        final lat = (movedCenter['latitude'] as num?)?.toDouble();
        final lng = (movedCenter['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final target = NLatLng(lat, lng);
          _lastCenter = target;
          _onMapCenterChanged(target);
          final controller = _mapController;
          if (controller != null) {
            try {
              _skipNextCameraIdleFetch = true;
              _isProgrammaticMove = true;
              const nextZoom = 14.0;
              await controller.updateCamera(
                NCameraUpdate.withParams(
                  target: target,
                  zoom: nextZoom,
                ),
              );
            } catch (_) {
              // Ignore camera update errors.
            }
          }
        }
      }
      _updateLiveMarkerPoints();
    } catch (_) {
      if (!mounted) return;
      setState(() => _nearSpaces = const []);
      _updateLiveMarkerPoints();
    } finally {
      if (mounted) setState(() => _isLoadingNear = false);
    }
  }

  Future<void> _updateLiveMarkerPoints() async {
    final controller = _mapController;
    if (controller == null || _isUpdatingMarkerPoints) return;
    _isUpdatingMarkerPoints = true;
    try {
      if (_purposeScopedSpaces.isEmpty) {
        if (mounted) setState(() => _liveMarkerPoints = const {});
        return;
      }
      final nextPoints = <String, NPoint>{};
      for (var i = 0; i < _purposeScopedSpaces.length; i += 1) {
        final space = _purposeScopedSpaces[i];
        final lat = (space['latitude'] as num?)?.toDouble();
        final lng = (space['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final point = await controller.latLngToScreenLocation(NLatLng(lat, lng));
        nextPoints['space_${space['id'] ?? i}'] = point;
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

  Feed? _feedFromSpace(Map<String, dynamic> space) {
    final raw = space['feed'];
    if (raw is Map<String, dynamic>) {
      final feed = Feed.fromJson(raw);
      if (feed.id.isEmpty) return null;
      return feed;
    }
    // /api/v1/map/near returns feed items directly (no wrapper).
    if (space.containsKey('id') &&
        (space.containsKey('content') || space.containsKey('images'))) {
      final feed = Feed.fromJson(space);
      if (feed.id.isEmpty) return null;
      return feed;
    }
    return null;
  }

  Widget _buildLiveMarkerOverlay() {
    if (_purposeScopedSpaces.isEmpty || _liveMarkerPoints.isEmpty) {
      return const SizedBox.shrink();
    }
    const markerSize = 44.0;
    final markerEntries = <({
      String markerId,
      String purpose,
      NPoint point,
      String? thumbnailUrl,
      Feed? feed,
      Map<String, dynamic> space,
      bool isFocused,
      double lat,
      double lng,
    })>[];
    for (var i = 0; i < _purposeScopedSpaces.length; i += 1) {
      final space = _purposeScopedSpaces[i];
      final purpose =
          ((space['purpose'] as String?) ?? 'LIVESPACE').toUpperCase();
      final markerId = 'space_${space['id'] ?? i}';
      final point = _liveMarkerPoints[markerId];
      if (point == null) continue;
      final lat = (space['latitude'] as num?)?.toDouble();
      final lng = (space['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final isFocused = _isWithinFocusRadius(lat: lat, lng: lng);
      markerEntries.add((
        markerId: markerId,
        purpose: purpose,
        point: point,
        thumbnailUrl: _thumbnailForSpace(space),
        feed: _feedFromSpace(space),
        space: space,
        isFocused: isFocused,
        lat: lat,
        lng: lng,
      ));
    }
    final clusters = _buildLiveMarkerClusters(markerEntries);
    final markerItems = <({String id, Widget child})>[];
    final clusterItems = <({String id, Widget child})>[];
    for (final cluster in clusters) {
      final single = cluster.members.length == 1 ? cluster.members.first : null;
      const feedWidth = 44.0;
      const feedHeight = feedWidth * 5 / 4;
      final isSingleFeed = single != null && single.purpose == 'FEED';
      final itemWidth = isSingleFeed ? feedWidth : markerSize;
      final itemHeight = isSingleFeed ? feedHeight : markerSize;
      final item = (
        id: cluster.clusterId,
        child: Positioned(
          key: ValueKey(cluster.clusterId),
          left: cluster.center.x - itemWidth / 2,
          top: cluster.center.y - itemHeight / 2,
          child: SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: GestureDetector(
              onTap: () {
                if (!mounted) return;
                setState(() => _selectedLiveMarkerId = cluster.clusterId);
                if (cluster.members.length >= 2) {
                  _zoomToCluster(cluster);
                  return;
                }
                if (single == null) return;
                if (single.purpose == 'FEED') {
                  final tapped = single.feed;
                  if (tapped == null) return;
                  final feeds = markerEntries
                      .map((entry) => entry.feed)
                      .whereType<Feed>()
                      .toList();
                  if (feeds.isEmpty) return;
                  final initialIndex =
                      feeds.indexWhere((feed) => feed.id == tapped.id);
                  if (initialIndex < 0) return;
                  showCupertinoModalPopup(
                    context: context,
                    builder: (_) => SizedBox.expand(
                      child: ProfileFeedListView(
                        feeds: feeds,
                        initialIndex: initialIndex,
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LivespaceDetailView(space: single.space),
                    ),
                  );
                }
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
                        ? Center(
                            child: CommonClusterMarker(
                              count: cluster.members.length,
                              width: markerSize,
                              borderRadius: 999,
                            ),
                          )
                        : isSingleFeed
                            ? CommonFeedMarker(
                                imageUrl: single.thumbnailUrl,
                                width: feedWidth,
                              )
                            : single.isFocused
                                ? CommonLivespaceMarker(
                                    imageUrl: single.thumbnailUrl,
                                    size: markerSize,
                                  )
                                : const Center(
                                    child: CommonDotMarker(),
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
      ...markerItems,
      ...clusterItems,
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: renderItems.map((item) => item.child).toList(),
    );
  }

  Widget _buildAnimatedLiveMarkerOverlay() {
    return _buildLiveMarkerOverlay();
  }

  List<_LiveMarkerCluster> _buildLiveMarkerClusters(
    List<({
      String markerId,
      String purpose,
      NPoint point,
      String? thumbnailUrl,
      Feed? feed,
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
      String purpose,
      NPoint point,
      String? thumbnailUrl,
      Feed? feed,
      Map<String, dynamic> space,
      bool isFocused,
      double lat,
      double lng,
    })>[seed];
      for (var j = i + 1; j < entries.length; j += 1) {
        if (visited.contains(j)) continue;
        final candidate = entries[j];
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

  Future<void> _zoomToCluster(_LiveMarkerCluster cluster) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      final camera = await controller.getCameraPosition();
      final nextZoom = math.min(18.0, camera.zoom + 1.2);
      await controller.updateCamera(
        NCameraUpdate.withParams(
          target: cluster.centerLatLng,
          zoom: nextZoom,
        ),
      );
    } catch (_) {
      // Ignore transient map camera errors.
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

  void _onMapCameraMoving() {
    if (_isCameraMoving) return;
    _isCameraMoving = true;
    if (!_isProgrammaticMove && _isHotArea) {
      setState(() => _isHotArea = false);
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
    final controller = _mapController;
    if (controller != null) {
      try {
        final camera = await controller.getCameraPosition();
        _lastCenter = camera.target;
        _lastZoom = camera.zoom;
        _fetchNearSpaces(camera.target, zoom: camera.zoom);
      } catch (_) {
        // Ignore transient camera errors.
      }
    }
    _updateLiveMarkerPoints().whenComplete(() {
      if (!mounted) return;
      if (_showLiveMarkers) return;
      setState(() => _showLiveMarkers = true);
    });
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

  IconData _iconForFilter(String label) {
    switch (label) {
      case '오늘':
        return PhosphorIconsFill.calendarBlank;
      case '핫한 지역':
        return PhosphorIconsFill.fire;
      case '러닝':
        return PhosphorIconsFill.personSimpleRun;
      case '카페':
        return PhosphorIconsFill.coffee;
      case '전시':
        return PhosphorIconsFill.paintBrush;
      default:
        return PhosphorIconsFill.tag;
    }
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
      if (index == 0) {
        _updateLiveMarkerPoints();
      }
      if (index == 1 && _nearSpaces.isEmpty && !_isLoadingNear) {
        _fetchNearSpaces(_lastCenter ?? const NLatLng(37.5665, 126.9780));
      }
    });
  }

  void _centerChip({bool animated = true}) {
    final key = _chipKeys[_selectedFilter];
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
      if (_filters.isNotEmpty) _filters.first,
      '__purpose_scope__',
      ..._filters.skip(1),
    ];
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
                  if (label == '__purpose_scope__') {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          final currentIndex =
                              _purposeScopes.indexOf(_selectedPurposeScope);
                          final nextIndex =
                              (currentIndex + 1) % _purposeScopes.length;
                          final nextScope = _purposeScopes[nextIndex];
                          setState(() => _selectedPurposeScope = nextScope);
                          _updateLiveMarkerPoints();
                          _fetchNearSpaces(
                            _lastCenter ?? const NLatLng(37.5665, 126.9780),
                          );
                        },
                        child: AnimatedContainer(
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
                            _selectedPurposeScope,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final selected = label == '핫한 지역'
                      ? _isHotArea
                      : _selectedFilter == label;
                  final icon = _iconForFilter(label);
                  final displayLabel = _displayFilterLabel(label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: KeyedSubtree(
                      key: _chipKeys[label],
                      child: GestureDetector(
                        onTap: () async {
                          if (label == '핫한 지역') {
                            final nextHotArea = !_isHotArea;
                            setState(() => _isHotArea = nextHotArea);
                            final center = _lastCenter;
                            if (center != null) {
                              _fetchNearSpaces(
                                center,
                                hotRankOverride: nextHotArea ? 1 : null,
                              );
                            }
                            return;
                          }
                          if (label == '오늘') {
                            final picked = await CommonCalendarView.show(
                              context,
                              initialDate: _selectedFilterDate ?? DateTime.now(),
                              lastDate: DateTime.now(),
                            );
                            if (!mounted) return;
                            if (picked != null) {
                              _selectedFilterDate = picked;
                            }
                          }
                          setState(() => _selectedFilter = label);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _centerChip();
                          });
                          final center = _lastCenter;
                          if (center != null) {
                            _fetchNearSpaces(center);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: label == '핫한 지역' && selected
                                ? const Color(0xFFE53935)
                                : Colors.white,
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
                                color: label == '핫한 지역'
                                    ? (selected
                                        ? Colors.white
                                        : const Color(0xFFE53935))
                                    : label == '오늘'
                                        ? const Color(0xFF7A5AF8)
                                        : (selected ? Colors.white : Colors.black),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                displayLabel,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: label == '핫한 지역' && selected
                                      ? Colors.white
                                      : Colors.black,
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

  Widget _buildListSortBar() {
    return Container(
      height: 40,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Spacer(),
            ...List.generate(_listSorts.length, (index) {
              final label = _listSorts[index];
              final selected = _selectedListSort == label;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0)
                    Container(
                      width: 1,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: const Color(0x33000000),
                    ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedListSort = label);
                      final center = _lastCenter;
                      if (center != null) {
                        _fetchNearSpaces(center);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.black : const Color(0x88000000),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
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
    const listSortBarHeight = 40.0;
    const listGapBelowChips = 4.0;
    const listGradientHeight = 16.0;
    final listSortBarBottom =
        topSafe + chipTopOffset + chipBlockHeight + 12 + listSortBarHeight;
    final listTopPadding = topSafe +
        chipTopOffset +
        chipBlockHeight +
        listSortBarHeight +
        listGapBelowChips;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
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
                    visible: _selectedIndex == 0,
                    hiddenOffset: const Offset(-0.04, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 0) {
                          _mapViewportWidth = constraints.maxWidth;
                        }
                        if (constraints.maxHeight > 0) {
                          _mapViewportHeight = constraints.maxHeight;
                        }
                        return CommonMapView(
                          onCenterChanged: _onMapCenterChanged,
                          onCameraMoving: _onMapCameraMoving,
                          onCameraIdle: _onMapCameraIdle,
                          onCreateLiveSpace: _handleCreateLiveSpace,
                          onMapReady: (controller) {
                            _mapController = controller;
                            _updateLiveMarkerPoints();
                          },
                        );
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
                      visible: _selectedIndex == 0,
                      hiddenOffset: const Offset(-0.04, 0),
                      child: _buildAnimatedLiveMarkerOverlay(),
                    ),
                    ),
                  ),
                Positioned.fill(
                  child: _animatedLayer(
                    visible: _selectedIndex == 1,
                    hiddenOffset: const Offset(0.04, 0),
                    child: MapListView(
                      topPadding: listTopPadding,
                      items: _listItems,
                      isLoading: _isLoadingNear,
                      currentCenter: _lastCenter == null
                          ? null
                          : (lat: _lastCenter!.latitude, lng: _lastCenter!.longitude),
                      onRefresh: () async {
                        final center = _lastCenter;
                        if (center == null) return;
                        await _fetchNearSpaces(center);
                      },
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
                  height: _selectedIndex == 1 ? listSortBarBottom : topSafe + 150,
                  decoration: _selectedIndex == 1
                      ? const BoxDecoration(color: Colors.white)
                      : const BoxDecoration(
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
            if (_selectedIndex == 1)
              Positioned(
                top: listSortBarBottom,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: listGradientHeight,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF),
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
                onLatestTap: () => _onTabSelected(0),
                onPopularTap: () => _onTabSelected(1),
                onAddressTap: () async {
                  _onTabSelected(0);
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
            if (_selectedIndex == 1)
              Positioned(
                top: topSafe + chipTopOffset + chipBlockHeight + 12,
                left: 0,
                right: 0,
                child: _buildListSortBar(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreateLiveSpace() {
    if (!AuthStore.instance.isSignedIn.value) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return const SizedBox.expand(
            child: SignView(),
          );
        },
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (_) {
        final height = MediaQuery.of(context).size.height;
        return SizedBox(
          height: height,
          child: const FeedCreatePhotoView(),
        );
      },
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
    String purpose,
    NPoint point,
    String? thumbnailUrl,
    Feed? feed,
    Map<String, dynamic> space,
    bool isFocused,
    double lat,
    double lng,
  })> members;
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
