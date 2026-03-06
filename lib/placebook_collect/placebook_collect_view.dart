import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../map/map_view.dart';
import '../common/widgets/common_navigation_view.dart';

class PlacebookCollectView extends StatelessWidget {
  const PlacebookCollectView({
    super.key,
    this.themeId,
    this.themeTitle,
  });

  final String? themeId;
  final String? themeTitle;

  @override
  Widget build(BuildContext context) {
    final title = (themeTitle ?? '').trim();
    final themeIdList = (themeId ?? '').trim().isNotEmpty ? [themeId!.trim()] : null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              left: const Icon(
                PhosphorIconsRegular.caretLeft,
                size: 22,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              title: title.isEmpty ? '모아보기' : title,
              backgroundColor: Colors.white,
            ),
            Expanded(
              child: MapView(
                showFilterButton: false,
                useBottomSafeArea: false,
                fixedThemeIds: themeIdList,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
