import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../common/widgets/common_map_view.dart';
import '../../common/widgets/common_place_marker.dart';

class PlacebookDetailInfoView extends StatefulWidget {
  const PlacebookDetailInfoView({
    super.key,
    required this.title,
    required this.place,
    required this.latitude,
    required this.longitude,
    required this.time,
    required this.status,
    required this.profileImageUrl,
    required this.nickname,
  });

  final String title;
  final String place;
  final double? latitude;
  final double? longitude;
  final String time;
  final String status;
  final String? profileImageUrl;
  final String nickname;

  @override
  State<PlacebookDetailInfoView> createState() =>
      _PlacebookDetailInfoViewState();
}

class _PlacebookDetailInfoViewState extends State<PlacebookDetailInfoView> {
  static const double _markerSize = 44;
  NaverMapController? _mapController;
  NPoint? _markerPoint;
  Timer? _markerUpdateDebounce;
  bool _showMarker = false;
  bool _isCameraMoving = false;

  @override
  void didUpdateWidget(covariant PlacebookDetailInfoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _scheduleMarkerPointUpdate();
    }
  }

  @override
  void dispose() {
    _markerUpdateDebounce?.cancel();
    super.dispose();
  }

  void _scheduleMarkerPointUpdate() {
    _markerUpdateDebounce?.cancel();
    _markerUpdateDebounce = Timer(const Duration(milliseconds: 16), () {
      _updateMarkerPoint();
    });
  }

  Future<void> _updateMarkerPoint() async {
    final controller = _mapController;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (controller == null || lat == null || lng == null) return;
    try {
      final point =
          await controller.latLngToScreenLocation(NLatLng(lat, lng));
      if (!mounted) return;
      if (_markerPoint == null ||
          (_markerPoint!.x != point.x || _markerPoint!.y != point.y)) {
        setState(() => _markerPoint = point);
      }
    } catch (_) {
      // Ignore transient projection errors.
    }
  }

  Future<void> _moveToPlace() async {
    final controller = _mapController;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (controller == null || lat == null || lng == null) return;
    try {
      await controller.updateCamera(
        NCameraUpdate.withParams(
          target: NLatLng(lat, lng),
        ),
      );
    } catch (_) {
      // Ignore transient camera errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapController = CommonMapViewController();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '장소',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 20,
                  offset: Offset(0, 0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 180,
              child: widget.latitude != null && widget.longitude != null
                  ? Stack(
                      children: [
                        CommonMapView(
                          controller: mapController,
                          initialLatitude: widget.latitude,
                          initialLongitude: widget.longitude,
                          showMyLocationButton: false,
                          forceGesture: true,
                          onMapReady: (controller) {
                            _mapController = controller;
                            _scheduleMarkerPointUpdate();
                          },
                          onCameraMoving: () {
                            if (_isCameraMoving) return;
                            _isCameraMoving = true;
                            if (_showMarker) setState(() => _showMarker = false);
                            _scheduleMarkerPointUpdate();
                          },
                          onCameraIdle: () {
                            _isCameraMoving = false;
                            _updateMarkerPoint().whenComplete(() {
                              if (!mounted) return;
                              if (_showMarker) return;
                              setState(() => _showMarker = true);
                            });
                          },
                        ),
                        if (_markerPoint != null)
                          Positioned(
                            left: _markerPoint!.x - (_markerSize / 2),
                            top: _markerPoint!.y - (_markerSize / 2),
                            child: AnimatedOpacity(
                              opacity: _showMarker ? 1 : 0,
                              duration: Duration.zero,
                              child: AnimatedScale(
                                scale: _showMarker ? 1 : 0.92,
                                duration: _showMarker
                                    ? const Duration(milliseconds: 180)
                                    : Duration.zero,
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.center,
                                child: const _AppearScaleIn(
                                  child: CommonPlaceMarker(size: _markerSize),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MapFloatingButton(
                                icon: PhosphorIconsFill.mapPinArea,
                                onTap: _moveToPlace,
                              ),
                              const SizedBox(height: 10),
                              _MapZoomButton(
                                onZoomIn: () => mapController.zoomBy(1),
                                onZoomOut: () => mapController.zoomBy(-1),
                              ),
                              const SizedBox(height: 10),
                              _MapFloatingButton(
                                icon: PhosphorIconsFill.navigationArrow,
                                onTap: () => mapController.moveToMyLocation(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: const Color(0xFFF5F5F5),
                      alignment: Alignment.center,
                      child: const Text(
                        '위치 정보 없음',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
              ),
            ),
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
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          shadows: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 0),
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
      width: 40,
      height: 80,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
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
            child: GestureDetector(
              onTap: onZoomIn,
              behavior: HitTestBehavior.opaque,
              child: const Center(
                child: Icon(
                  PhosphorIconsBold.plus,
                  size: 18,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onZoomOut,
              behavior: HitTestBehavior.opaque,
              child: const Center(
                child: Icon(
                  PhosphorIconsBold.minus,
                  size: 18,
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

class _AppearScaleIn extends StatefulWidget {
  const _AppearScaleIn({
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
