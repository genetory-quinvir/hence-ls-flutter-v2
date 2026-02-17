import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'common_alert_view.dart';

class CommonMapView extends StatefulWidget {
  const CommonMapView({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.onCenterChanged,
    this.onCameraMoving,
    this.onCameraIdle,
    this.centerMarker,
    this.showMyLocationButton = true,
    this.onCreateLiveSpace,
    this.onMapReady,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<NLatLng>? onCenterChanged;
  final VoidCallback? onCameraMoving;
  final VoidCallback? onCameraIdle;
  final Widget? centerMarker;
  final bool showMyLocationButton;
  final VoidCallback? onCreateLiveSpace;
  final ValueChanged<NaverMapController>? onMapReady;

  @override
  State<CommonMapView> createState() => _CommonMapViewState();
}

class _CommonMapViewState extends State<CommonMapView> {
  static const String clientId = 'e2m4s9kqcr';
  static const String styleId = 'b55d5c20-f158-4e23-851c-55c7d348a2ef';

  late final Future<void> _initFuture;
  NaverMapController? _controller;
  NOverlayImage? _myLocationIcon;
  bool _didAutoPromptLocationPermission = false;
  bool _isFetchingMyLocation = false;

  @override
  void initState() {
    super.initState();
    _initFuture = FlutterNaverMap.isInitialized
        ? Future.value()
        : FlutterNaverMap().init(clientId: clientId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationPermission(autoPrompt: true);
    });
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
                _syncMyLocationOverlay();
                widget.onMapReady?.call(controller);
              },
              onCameraChange: (_, __) {
                widget.onCameraMoving?.call();
              },
              onCameraIdle: () async {
                widget.onCameraIdle?.call();
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
            if (widget.showMyLocationButton || widget.onCreateLiveSpace != null)
              Positioned(
                right: 16,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onCreateLiveSpace != null)
                      _buildFloatingButton(
                        icon: Icons.add,
                        onTap: widget.onCreateLiveSpace!,
                      ),
                    if (widget.onCreateLiveSpace != null &&
                        widget.showMyLocationButton)
                      const SizedBox(height: 10),
                    if (widget.showMyLocationButton)
                      _buildFloatingButton(
                        icon: Icons.my_location,
                        onTap: _moveToMyLocation,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(
          icon,
          size: 18,
          color: Colors.black,
        ),
      ),
    );
  }

  Future<void> _moveToMyLocation() async {
    final controller = _controller;
    if (controller == null) return;
    final granted = await _ensureLocationPermission();
    if (!granted) return;
    await _syncMyLocationOverlay(moveCamera: true);
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
          color: Colors.blue[600],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
    overlay.setIcon(_myLocationIcon!);
    overlay.setIconSize(const Size(16, 16));
  }

  Future<bool> _ensureLocationPermission({bool autoPrompt = false}) async {
    if (!mounted) return false;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[CommonMapView] serviceEnabled=$serviceEnabled');
    if (!serviceEnabled) {
      if (autoPrompt) {
        await _showLocationServiceAlert();
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    debugPrint('[CommonMapView] currentPermission=$permission');
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    if (autoPrompt && _didAutoPromptLocationPermission) return false;
    if (autoPrompt) _didAutoPromptLocationPermission = true;
    if (!mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      builder: (_) {
        return Material(
          type: MaterialType.transparency,
            child: CommonAlertView(
              title: '위치 권한 필요',
              subTitle: '지도 사용을 위해 위치 권한이 필요합니다.',
              primaryButtonTitle: '확인',
              secondaryButtonTitle: '설정으로 이동',
              onPrimaryTap: () => Navigator.of(context).pop(true),
              onSecondaryTap: () async {
                Navigator.of(context).pop(false);
                await openAppSettings();
              },
            ),
          );
        },
      );
    if (!mounted || confirmed != true) return false;

    permission = await Geolocator.requestPermission();
    debugPrint('[CommonMapView] requestedPermission=$permission');
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }
    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _syncMyLocationOverlay({bool moveCamera = false}) async {
    if (_isFetchingMyLocation) return;
    final controller = _controller;
    if (controller == null) return;

    final granted = await _ensureLocationPermission();
    if (!granted) return;

    _isFetchingMyLocation = true;
    try {
      controller.setLocationTrackingMode(NLocationTrackingMode.noFollow);
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
        '[CommonMapView] position lat=${position.latitude}, lng=${position.longitude}',
      );
      final target = NLatLng(position.latitude, position.longitude);
      final overlay = controller.getLocationOverlay();
      overlay.setIsVisible(true);
      overlay.setPosition(target);

      if (moveCamera) {
        await controller.updateCamera(
          NCameraUpdate.withParams(
            target: target,
            zoom: 15,
          ),
        );
      }
    } catch (e) {
      debugPrint('[CommonMapView] syncMyLocationOverlay failed: $e');
      // Ignore transient GPS/platform errors; user can retry with the location button.
    } finally {
      _isFetchingMyLocation = false;
    }
  }

  Future<void> _showLocationServiceAlert() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      builder: (_) {
        return Material(
          type: MaterialType.transparency,
          child: CommonAlertView(
            title: '위치 서비스 필요',
            subTitle: '기기의 위치 서비스가 꺼져 있습니다.',
            primaryButtonTitle: '확인',
            secondaryButtonTitle: '설정으로 이동',
            onPrimaryTap: () => Navigator.of(context).pop(),
            onSecondaryTap: () async {
              Navigator.of(context).pop();
              await Geolocator.openLocationSettings();
            },
          ),
        );
      },
    );
  }
}
