import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/widgets/common_inkwell.dart';

class FeedListNavigationView extends StatelessWidget {
  const FeedListNavigationView({
    super.key,
    required this.selectedIndex,
    this.onLatestTap,
    this.onPopularTap,
    this.onNotificationTap,
  });

  final int selectedIndex;
  final VoidCallback? onLatestTap;
  final VoidCallback? onPopularTap;
  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    const selectedStyle = TextStyle(
      color: Colors.white,
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );
    const unselectedStyle = TextStyle(
      color: Color(0x55FFFFFF),
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CommonInkWell(
                    onTap: onLatestTap,
                    child: _TabLabel(
                      title: '최신',
                      selected: selectedIndex == 0,
                      selectedStyle: selectedStyle,
                      unselectedStyle: unselectedStyle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  CommonInkWell(
                    onTap: onPopularTap,
                    child: _TabLabel(
                      title: '인기',
                      selected: selectedIndex == 1,
                      selectedStyle: selectedStyle,
                      unselectedStyle: unselectedStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.title,
    required this.selected,
    required this.selectedStyle,
    required this.unselectedStyle,
  });

  final String title;
  final bool selected;
  final TextStyle selectedStyle;
  final TextStyle unselectedStyle;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: selected ? selectedStyle : unselectedStyle,
          ),
          Container(
            height: 2,
            width: double.infinity,
            color: selected ? Colors.white : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
