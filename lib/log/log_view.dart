import 'package:flutter/material.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../notification/notification_view.dart';

class LogView extends StatelessWidget {
  const LogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: CommonNavigationView(
              title: '기록',
              right: const Icon(
                PhosphorIconsRegular.bell,
                size: 24,
                color: Colors.black,
              ),
              onRightTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationView(),
                  ),
                );
              },
            ),
          ),
          const Expanded(
            child: CommonEmptyView(
              message: '기록이 없습니다.',
              showButton: false,
            ),
          ),
        ],
      ),
    );
  }
}
