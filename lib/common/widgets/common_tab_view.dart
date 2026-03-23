import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hence_ls_flutter_v2/main.dart';
import 'package:figma_squircle/figma_squircle.dart';

import 'common_inkwell.dart';

class CommonTabView extends StatelessWidget {
  const CommonTabView({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
    this.height = 50,
    this.iconSize = 24,
    this.activeColor = Colors.black,
    this.inactiveColor = const Color(0xFF9E9E9E),
    this.backgroundColor = Colors.white,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;
  final double height;
  final double iconSize;
  final Color activeColor;
  final Color inactiveColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    const items = [
      _TabItem(
        label: '피쳐드',
        icon: PhosphorIconsRegular.star,
        activeIcon: PhosphorIconsFill.star,
      ),
      _TabItem(
        label: '맵',
        icon: PhosphorIconsRegular.mapPin,
        activeIcon: PhosphorIconsFill.mapPin,
      ),
      _TabItem(
        label: '도감',
        icon: PhosphorIconsRegular.book,
        activeIcon: PhosphorIconsFill.book,
      ),
      _TabItem(
        label: '프로필',
        icon: PhosphorIconsRegular.user,
        activeIcon: PhosphorIconsFill.user,
      ),
    ];

    return Container(
      height: height + 10,
      color: backgroundColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: _TabIconButton(
                  item: items[0],
                  isActive: currentIndex == 0,
                  iconSize: iconSize,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  showUnreadDot: false,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _TabIconButton(
                  item: items[1],
                  isActive: currentIndex == 1,
                  iconSize: iconSize,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  showUnreadDot: false,
                  onTap: () => onTap(1),
                ),
              ),
              const SizedBox(width: 72),
              Expanded(
                child: _TabIconButton(
                  item: items[2],
                  isActive: currentIndex == 2,
                  iconSize: iconSize,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  showUnreadDot: false,
                  onTap: () => onTap(2),
                ),
              ),
              Expanded(
                child: _TabIconButton(
                  item: items[3],
                  isActive: currentIndex == 3,
                  iconSize: iconSize,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  showUnreadDot: false,
                  onTap: () => onTap(3),
                ),
              ),
            ],
          ),
          CommonInkWell(
            onTap: onCenterTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: ShapeDecoration(
                color: Colors.black,
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: 12,
                    cornerSmoothing: 2,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsBold.plus,
                size: 18,
                color: MyApp.primary200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabIconButton extends StatelessWidget {
  const _TabIconButton({
    required this.item,
    required this.isActive,
    required this.iconSize,
    required this.activeColor,
    required this.inactiveColor,
    required this.showUnreadDot,
    required this.onTap,
  });

  final _TabItem item;
  final bool isActive;
  final double iconSize;
  final Color activeColor;
  final Color inactiveColor;
  final bool showUnreadDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return CommonInkWell(
      onTap: onTap,
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
            if (showUnreadDot)
              Positioned(
                right: -2,
                top: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
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
