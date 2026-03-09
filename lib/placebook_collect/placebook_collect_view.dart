import 'package:flutter/material.dart';
import 'package:hence_ls_flutter_v2/placebook_create/placebook_create_view.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'placebook_collect_map_view.dart';
import '../common/widgets/common_navigation_view.dart';

class PlacebookCollectView extends StatefulWidget {
  const PlacebookCollectView({
    super.key,
    this.themeId,
    this.themeTitle,
  });

  final String? themeId;
  final String? themeTitle;

  @override
  State<PlacebookCollectView> createState() => _PlacebookCollectViewState();
}

class _PlacebookCollectViewState extends State<PlacebookCollectView> {
  bool _hasDeletedPlace = false;

  void _markPlaceDeleted(String _) {
    if (_hasDeletedPlace) return;
    setState(() => _hasDeletedPlace = true);
  }

  Future<bool> _handleWillPop() async {
    Navigator.of(context).pop(_hasDeletedPlace);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.themeTitle ?? '').trim();
    final themeIdList = (widget.themeId ?? '').trim().isNotEmpty
        ? [widget.themeId!.trim()]
        : null;
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
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
                onLeftTap: () =>
                    Navigator.of(context).maybePop(_hasDeletedPlace),
                right: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => PlacebookCreateView(
                        themeId: widget.themeId,
                        themeTitle: title,
                      ),
                      fullscreenDialog: true,
                    ),
                  ),
                  child: const Text('추가하기'),
                ),
                title: title.isEmpty ? '모아보기' : title,
                backgroundColor: Colors.white,
              ),
              Expanded(
                child: PlacebookCollectMapView(
                  showFilterButton: false,
                  useBottomSafeArea: false,
                  fixedThemeIds: themeIdList,
                  onPlaceDeleted: _markPlaceDeleted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
