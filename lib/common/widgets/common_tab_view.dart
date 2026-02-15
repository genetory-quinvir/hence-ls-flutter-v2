import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/home_tab_controller.dart';
import 'common_inkwell.dart';

class CommonTabView extends StatelessWidget {
  const CommonTabView({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.height = 50,
    this.iconSize = 24,
    this.activeColor = Colors.black,
    this.inactiveColor = const Color(0xFF9E9E9E),
    this.backgroundColor = Colors.white,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;
  final double iconSize;
  final Color activeColor;
  final Color inactiveColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final unread = HomeTabController.hasUnreadNotifications;
    const items = [
      _TabItem(
        label: '맵',
        icon: PhosphorIconsRegular.mapPin,
        activeIcon: PhosphorIconsFill.mapPin,
      ),
      _TabItem(
        label: '피드',
        icon: PhosphorIconsRegular.article,
        activeIcon: PhosphorIconsFill.article,
      ),
      _TabItem(
        label: '만들기',
        icon: PhosphorIconsRegular.plus,
        activeIcon: PhosphorIconsFill.plus,
      ),
      _TabItem(
        label: '알림',
        icon: PhosphorIconsRegular.bell,
        activeIcon: PhosphorIconsFill.bell,
      ),
      _TabItem(
        label: '프로필',
        icon: PhosphorIconsRegular.user,
        activeIcon: PhosphorIconsFill.user,
      ),
    ];

    return Container(
      height: height,
      color: backgroundColor,
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = index == currentIndex;
          final color = isActive ? activeColor : inactiveColor;

          return Expanded(
            child: CommonInkWell(
              onTap: () => onTap(index),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      size: iconSize,
                      color: color,
                      semanticLabel: item.label,
                    ),
                    if (index == 3)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: unread,
                          builder: (context, hasUnread, _) {
                            if (!hasUnread) return const SizedBox.shrink();
                            return Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
