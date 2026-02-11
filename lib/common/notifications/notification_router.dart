import '../navigation/root_navigator.dart';
import '../state/home_tab_controller.dart';

class NotificationRouter {
  NotificationRouter._();

  static Future<void> routeByLink(String? link) async {
    if (link == null || link.isEmpty) return;

    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);

    if (link.contains('notifications')) {
      HomeTabController.switchTo(3);
      return;
    }

    if (link.contains('feeds')) {
      HomeTabController.switchTo(1);
      return;
    }
  }
}
