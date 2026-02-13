import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/location/naver_location_service.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_map_view.dart';
import '../list/list_view.dart';
import 'widgets/map_navigation_view.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  int _selectedIndex = 0;
  String _selectedFilter = '오늘';
  String _centerPlaceText = '';
  final ScrollController _chipScrollController = ScrollController();
  Timer? _reverseGeocodeDebounce;
  bool _isLoadingNear = false;
  List<Map<String, dynamic>> _nearSpaces = const [];
  NLatLng? _lastCenter;
  static const List<String> _filters = <String>[
    '오늘',
    '핫한 지역',
    '러닝',
    '카페',
    '전시',
  ];
  late final Map<String, GlobalKey> _chipKeys;

  @override
  void initState() {
    super.initState();
    _chipKeys = <String, GlobalKey>{
      for (final label in _filters) label: GlobalKey(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerChip(animated: false);
      _fetchNearSpaces(const NLatLng(37.5665, 126.9780));
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
    _fetchNearSpaces(center);
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

  Future<void> _fetchNearSpaces(NLatLng center) async {
    final filter = _selectedFilter;
    final isTagFilter = filter == '러닝' || filter == '카페' || filter == '전시';
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final date = filter == '오늘' ? '$yyyy-$mm-$dd' : null;
    setState(() => _isLoadingNear = true);
    try {
      final spaces = await ApiClient.fetchNearbySpaces(
        latitude: center.latitude,
        longitude: center.longitude,
        onlyMine: false,
        radiusKm: 10,
        date: date,
        liveStatus: 'all',
        tagNames: isTagFilter ? <String>[filter] : null,
        hasCategory: 'all',
      );
      if (!mounted) return;
      setState(() => _nearSpaces = spaces);
    } catch (_) {
      if (!mounted) return;
      setState(() => _nearSpaces = const []);
    } finally {
      if (mounted) setState(() => _isLoadingNear = false);
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
                children: _filters.map((label) {
                  final selected = _selectedFilter == label;
                  final icon = _iconForFilter(label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: KeyedSubtree(
                      key: _chipKeys[label],
                      child: GestureDetector(
                        onTap: () {
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
                                label,
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

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.of(context).padding.top;
    const navigationBottomOffset = 56.0;
    const chipTopOffset = navigationBottomOffset + 8;
    const chipBlockHeight = 44.0;
    const listGapBelowChips = 16.0;
    final listTopPadding = topSafe + chipTopOffset + chipBlockHeight + listGapBelowChips;

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
                    child: CommonMapView(
                      onCenterChanged: _onMapCenterChanged,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _animatedLayer(
                    visible: _selectedIndex == 1,
                    hiddenOffset: const Offset(0.04, 0),
                    child: MapListView(
                      topPadding: listTopPadding,
                      items: _nearSpaces,
                      isLoading: _isLoadingNear,
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
                onLatestTap: () => _onTabSelected(0),
                onPopularTap: () => _onTabSelected(1),
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
