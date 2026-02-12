import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../permissions/location_permission_service.dart';

class CommonMapView extends StatefulWidget {
  const CommonMapView({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.onCenterChanged,
    this.centerMarker,
    this.showMyLocationButton = true,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<NLatLng>? onCenterChanged;
  final Widget? centerMarker;
  final bool showMyLocationButton;

  @override
  State<CommonMapView> createState() => _CommonMapViewState();
}

class _CommonMapViewState extends State<CommonMapView> {
  static const String clientId = 'e2m4s9kqcr';
  static const String styleId = 'b55d5c20-f158-4e23-851c-55c7d348a2ef';

  late final Future<void> _initFuture;
  NaverMapController? _controller;
  NOverlayImage? _myLocationIcon;

  @override
  void initState() {
    super.initState();
    _initFuture = FlutterNaverMap.isInitialized
        ? Future.value()
        : FlutterNaverMap().init(clientId: clientId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final initialPosition = (widget.initialLatitude != null &&
                widget.initialLongitude != null)
            ? NLatLng(widget.initialLatitude!, widget.initialLongitude!)
            : null;

        return Stack(
          alignment: Alignment.center,
          children: [
            NaverMap(
              options: NaverMapViewOptions(
                customStyleId: styleId,
                initialCameraPosition: initialPosition == null
                    ? const NCameraPosition(
                        target: NLatLng(37.5665, 126.9780),
                        zoom: 14,
                      )
                    : NCameraPosition(target: initialPosition, zoom: 14),
              ),
              onMapReady: (controller) {
                _controller = controller;
                _configureLocationOverlay(context);
              },
              onCameraIdle: () async {
                if (widget.onCenterChanged == null) return;
                final controller = _controller;
                if (controller == null) return;
                final position = await controller.getCameraPosition();
                widget.onCenterChanged?.call(position.target);
              },
            ),
            if (widget.centerMarker != null)
              IgnorePointer(
                child: widget.centerMarker!,
              ),
            if (widget.showMyLocationButton)
              Positioned(
                right: 16,
                bottom: 16,
                child: GestureDetector(
                  onTap: _moveToMyLocation,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.my_location,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _moveToMyLocation() async {
    final controller = _controller;
    if (controller == null) return;
    final granted = await LocationPermissionService.isGranted();
    if (!granted) {
      final requested = await LocationPermissionService.requestWhenInUse();
      if (!requested) return;
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final overlay = controller.getLocationOverlay();
    overlay.setIsVisible(true);
    overlay.setPosition(NLatLng(position.latitude, position.longitude));
    await controller.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(position.latitude, position.longitude),
        zoom: 15,
      ),
    );
  }

  Future<void> _configureLocationOverlay(BuildContext context) async {
    final controller = _controller;
    if (controller == null) return;
    final overlay = controller.getLocationOverlay();
    overlay.setCircleColor(Colors.transparent);
    overlay.setCircleOutlineWidth(0);
    overlay.setCircleRadius(0);
    overlay.setIsVisible(true);
    _myLocationIcon ??= await NOverlayImage.fromWidget(
      context: context,
      size: const Size(16, 16),
      widget: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
    overlay.setIcon(_myLocationIcon!);
    overlay.setIconSize(const Size(16, 16));
  }
}
