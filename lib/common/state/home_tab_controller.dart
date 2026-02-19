import 'package:flutter/foundation.dart';

class MapFocusRequest {
  const MapFocusRequest({
    required this.latitude,
    required this.longitude,
    this.resetFilters = false,
    this.createdSpace,
  });

  final double latitude;
  final double longitude;
  final bool resetFilters;
  final Map<String, dynamic>? createdSpace;
}

class HomeTabController {
  HomeTabController._();

  static final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  static final ValueNotifier<int> feedReloadSignal = ValueNotifier<int>(0);
  static final ValueNotifier<int> profileReloadSignal = ValueNotifier<int>(0);
  static final ValueNotifier<bool> hasUnreadNotifications =
      ValueNotifier<bool>(false);
  static final ValueNotifier<MapFocusRequest?> mapFocusRequest =
      ValueNotifier<MapFocusRequest?>(null);

  static void switchTo(int index) {
    currentIndex.value = index;
  }

  static void requestFeedReload() {
    feedReloadSignal.value += 1;
  }

  static void requestProfileReload() {
    profileReloadSignal.value += 1;
  }

  static void setUnreadNotifications(bool value) {
    if (hasUnreadNotifications.value == value) return;
    hasUnreadNotifications.value = value;
  }

  static void requestMapFocus({
    required double latitude,
    required double longitude,
    bool resetFilters = false,
    Map<String, dynamic>? createdSpace,
  }) {
    mapFocusRequest.value = MapFocusRequest(
      latitude: latitude,
      longitude: longitude,
      resetFilters: resetFilters,
      createdSpace: createdSpace,
    );
  }
}
