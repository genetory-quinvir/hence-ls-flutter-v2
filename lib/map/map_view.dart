import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';

import '../common/permissions/location_permission_service.dart';
import '../common/state/home_tab_controller.dart';
import '../common/widgets/common_map_view.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _tabListener = () {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 0) {
        _requestPermissionIfNeeded();
      }
    };
    HomeTabController.currentIndex.addListener(_tabListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 0) {
        _requestPermissionIfNeeded();
      }
    });
  }

  Future<void> _requestPermissionIfNeeded() async {
    debugPrint('[MapView] check location permission');
    final status = await LocationPermissionService.getStatus();
    debugPrint('[MapView] location permission status: $status');
    final granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    debugPrint('[MapView] location permission granted: $granted');
    if (!granted) {
      debugPrint('[MapView] requesting location permission');
      final result = await LocationPermissionService.requestWhenInUse();
      debugPrint('[MapView] request result: $result');
    }
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CommonMapView(),
    );
  }
}
