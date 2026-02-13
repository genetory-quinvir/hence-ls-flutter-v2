import 'package:flutter/foundation.dart';

class HomeTabController {
  HomeTabController._();

  static final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  static final ValueNotifier<int> feedReloadSignal = ValueNotifier<int>(0);
  static final ValueNotifier<int> profileReloadSignal = ValueNotifier<int>(0);
  static final ValueNotifier<bool> hasUnreadNotifications =
      ValueNotifier<bool>(false);

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
}
