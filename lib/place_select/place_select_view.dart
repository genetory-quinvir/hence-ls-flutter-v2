import 'dart:async';

import 'package:flutter/material.dart';

import '../common/location/naver_location_service.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_map_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_textfield_view.dart';

class PlaceSelection {
  const PlaceSelection({
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });

  final String placeName;
  final double latitude;
  final double longitude;
}

class PlaceSelectView extends StatefulWidget {
  const PlaceSelectView({
    super.key,
    required this.places,
    this.selected,
    this.initialPlaceName,
    this.initialLatitude,
    this.initialLongitude,
  });

  final List<String> places;
  final String? selected;
  final String? initialPlaceName;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<PlaceSelectView> createState() => _PlaceSelectViewState();
}

class _PlaceSelectViewState extends State<PlaceSelectView> {
  late final TextEditingController _placeController;
  final FocusNode _placeFocusNode = FocusNode();
  Timer? _reverseTimer;
  late double _latitude;
  late double _longitude;

  @override
  void initState() {
    super.initState();
    _placeController = TextEditingController(text: widget.initialPlaceName ?? '');
    _latitude = widget.initialLatitude ?? 0;
    _longitude = widget.initialLongitude ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted = await LocationPermissionService.isGranted();
      if (!granted) {
        await LocationPermissionService.requestWhenInUse();
      }
    });
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _placeFocusNode.dispose();
    _placeController.dispose();
    super.dispose();
  }

  void _onCenterChanged(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    _reverseTimer?.cancel();
    _reverseTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      if (_placeFocusNode.hasFocus) return;
      final place = await NaverLocationService.reverseGeocode(
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      if (_placeFocusNode.hasFocus) return;
      if (place != null && place.trim().isNotEmpty) {
        _placeController.text = place.trim();
      }
    });
  }

  void _submit() {
    final name = _placeController.text.trim();
    if (name.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pop(
      PlaceSelection(
        placeName: name,
        latitude: _latitude,
        longitude: _longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: CommonNavigationView(
              title: '장소 선택',
              left: CommonInkWell(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.close,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CommonMapView(
                  initialLatitude: _latitude == 0 ? null : _latitude,
                  initialLongitude: _longitude == 0 ? null : _longitude,
                  onCenterChanged: (center) {
                    _onCenterChanged(center.latitude, center.longitude);
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CommonTextFieldView(
              controller: _placeController,
              focusNode: _placeFocusNode,
              title: '장소',
              hintText: '장소를 입력해주세요',
            ),
          ),
          const SizedBox(height: 16),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommonRoundedButton(
                title: '장소 추가하기',
                onTap: _submit,
                height: 50,
                radius: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
