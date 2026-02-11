import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class CommonMapView extends StatefulWidget {
  const CommonMapView({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.onCenterChanged,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<NLatLng>? onCenterChanged;

  @override
  State<CommonMapView> createState() => _CommonMapViewState();
}

class _CommonMapViewState extends State<CommonMapView> {
  static const String clientId = 'e2m4s9kqcr';
  static const String styleId = 'b55d5c20-f158-4e23-851c-55c7d348a2ef';

  late final Future<void> _initFuture;
  NaverMapController? _controller;

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

        return NaverMap(
          options: NaverMapViewOptions(
            customStyleId: styleId,
            initialCameraPosition: initialPosition == null
                ? const NCameraPosition(target: NLatLng(37.5665, 126.9780), zoom: 14)
                : NCameraPosition(target: initialPosition, zoom: 14),
          ),
          onMapReady: (controller) {
            _controller = controller;
          },
          onCameraIdle: () async {
            if (widget.onCenterChanged == null) return;
            final controller = _controller;
            if (controller == null) return;
            final position = await controller.getCameraPosition();
            widget.onCenterChanged?.call(position.target);
          },
        );
      },
    );
  }
}
