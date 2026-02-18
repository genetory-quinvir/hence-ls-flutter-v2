import 'package:flutter/material.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

class CommonRefreshView extends StatelessWidget {
  const CommonRefreshView({
    super.key,
    required this.onRefresh,
    required this.child,
    this.topPadding = 12,
    this.notificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double topPadding;
  final ScrollNotificationPredicate? notificationPredicate;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      notificationPredicate: notificationPredicate ?? (_) => true,
      builder: (context, child, controller) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            child,
            Positioned(
              top: topPadding,
              child: Opacity(
                opacity: controller.value.clamp(0.0, 1.0),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
