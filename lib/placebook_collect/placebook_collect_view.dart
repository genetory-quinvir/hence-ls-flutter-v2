import 'package:flutter/material.dart';
import 'package:hence_ls_flutter_v2/placebook_create/placebook_create_view.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'placebook_collect_map_view.dart';
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
                PhosphorIconsBold.caretLeft,
                size: 22,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              right: TextButton(onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => PlacebookCreateView(themeId: themeId, themeTitle: title), fullscreenDialog: true),
              ), child: Text('추가하기')),
              title: title.isEmpty ? '모아보기' : title,
              backgroundColor: Colors.white,
            ),
            Expanded(
              child: PlacebookCollectMapView(
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
