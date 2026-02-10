import 'package:flutter/material.dart';

import '../../common/widgets/common_inkwell.dart';

class FeedListNavigationView extends StatelessWidget {
  const FeedListNavigationView({
    super.key,
    required this.selectedIndex,
    this.onLatestTap,
    this.onPopularTap,
  });

  final int selectedIndex;
  final VoidCallback? onLatestTap;
  final VoidCallback? onPopularTap;

  @override
  Widget build(BuildContext context) {
    const selectedStyle = TextStyle(
      color: Colors.white,
      fontFamily: 'Pretendard',
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
    const unselectedStyle = TextStyle(
      color: Color(0x55FFFFFF),
      fontFamily: 'Pretendard',
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CommonInkWell(
              onTap: onLatestTap,
              child: Text('최신', style: selectedIndex == 0 ? selectedStyle : unselectedStyle),
            ),
            const SizedBox(width: 16),
            CommonInkWell(
              onTap: onPopularTap,
              child: Text('인기', style: selectedIndex == 1 ? selectedStyle : unselectedStyle),
            ),
          ],
        ),
      ),
    );
  }
}
