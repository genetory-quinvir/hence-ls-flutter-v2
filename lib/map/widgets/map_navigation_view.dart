import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/widgets/common_inkwell.dart';

class MapNavigationView extends StatelessWidget {
  const MapNavigationView({
    super.key,
    required this.selectedIndex,
    this.onLatestTap,
    this.onPopularTap,
    this.onAddressTap,
    this.rightText,
  });

  final int selectedIndex;
  final VoidCallback? onLatestTap;
  final VoidCallback? onPopularTap;
  final VoidCallback? onAddressTap;
  final String? rightText;

  @override
  Widget build(BuildContext context) {
    const selectedStyle = TextStyle(
      color: Colors.black,
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );
    final unselectedStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.3),
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CommonInkWell(
                      onTap: onLatestTap,
                      child: _TabLabel(
                        title: '지도',
                        selected: selectedIndex == 0,
                        selectedStyle: selectedStyle,
                        unselectedStyle: unselectedStyle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    CommonInkWell(
                      onTap: onPopularTap,
                      child: _TabLabel(
                        title: '리스트',
                        selected: selectedIndex == 1,
                        selectedStyle: selectedStyle,
                        unselectedStyle: unselectedStyle,
                      ),
                    ),
                  ],
                ),
              ),
              if (rightText != null && rightText!.trim().isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: CommonInkWell(
                    onTap: onAddressTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsFill.mapPin,
                            size: 14,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              rightText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
            color: selected ? Colors.black : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
