import 'package:flutter/foundation.dart';

class HomeTabController {
  HomeTabController._();

  static final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  static final ValueNotifier<int> feedReloadSignal = ValueNotifier<int>(0);

  static void switchTo(int index) {
    currentIndex.value = index;
  }

  static void requestFeedReload() {
    feedReloadSignal.value += 1;
  }
}
