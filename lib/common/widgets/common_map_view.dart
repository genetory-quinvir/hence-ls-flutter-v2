import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class CommonMapView extends StatefulWidget {
  const CommonMapView({super.key});

  @override
  State<CommonMapView> createState() => _CommonMapViewState();
}

class _CommonMapViewState extends State<CommonMapView> {
  static const String clientId = 'e2m4s9kqcr';
  static const String styleId = 'b55d5c20-f158-4e23-851c-55c7d348a2ef';

  late final Future<void> _initFuture;

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

        return NaverMap(
          options: const NaverMapViewOptions(
            customStyleId: styleId,
          ),
        );
      },
    );
  }
}
