import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/location/naver_location_service.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/widgets/common_feed_marker.dart';
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
    this.markerImageFuture,
  });

  final List<String> places;
  final String? selected;
  final String? initialPlaceName;
  final double? initialLatitude;
  final double? initialLongitude;
  final Future<Uint8List?>? markerImageFuture;

  @override
  State<PlaceSelectView> createState() => _PlaceSelectViewState();
}

class _PlaceSelectViewState extends State<PlaceSelectView> {
  late final TextEditingController _placeController;
  final FocusNode _placeFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _textFieldKey = GlobalKey();
  Timer? _reverseTimer;
  late double _latitude;
  late double _longitude;
  ({double lat, double lng})? _initialCenter;
  bool _hasMovedCenter = false;

  @override
  void initState() {
    super.initState();
    _placeController = TextEditingController(text: widget.initialPlaceName ?? '');
    _latitude = widget.initialLatitude ?? 0;
    _longitude = widget.initialLongitude ?? 0;
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _initialCenter = (lat: widget.initialLatitude!, lng: widget.initialLongitude!);
    }
    _placeFocusNode.addListener(_handleFocusChange);
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
    _placeFocusNode.removeListener(_handleFocusChange);
    _placeFocusNode.dispose();
    _placeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_placeFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _textFieldKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  void _onCenterChanged(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    if (!_hasMovedCenter && _initialCenter != null) {
      final meters = _distanceMeters(
        lat1: _initialCenter!.lat,
        lng1: _initialCenter!.lng,
        lat2: latitude,
        lng2: longitude,
      );
      if (meters < 5) {
        return;
      }
      _hasMovedCenter = true;
    }
    _reverseTimer?.cancel();
    _reverseTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      if (_placeFocusNode.hasFocus) return;
      if (!_hasMovedCenter &&
          (widget.initialPlaceName?.trim().isNotEmpty ?? false)) {
        return;
      }
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

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            (math.sin(dLng / 2) * math.sin(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final marker = widget.markerImageFuture == null
        ? null
        : FutureBuilder<Uint8List?>(
            future: widget.markerImageFuture,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return const SizedBox.shrink();
              }
              return CommonFeedMarker(
                imageBytes: bytes,
                width: 44,
              );
            },
          );
    final content = Column(
      children: [
        SafeArea(
          bottom: false,
          child: CommonNavigationView(
            titleWidget: const Text(
              '장소 선택',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            left: const Icon(
              Icons.close,
              size: 24,
              color: Colors.white,
            ),
            onLeftTap: () => Navigator.of(context).maybePop(),
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
                centerMarker: marker,
                onCenterChanged: (center) {
                  _onCenterChanged(center.latitude, center.longitude);
                },
              ),
            ),
          ),
        ),
        AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: KeyedSubtree(
                    key: _textFieldKey,
                    child: CommonTextFieldView(
                      controller: _placeController,
                      focusNode: _placeFocusNode,
                      title: '장소',
                      hintText: '장소를 입력해주세요',
                      darkStyle: true,
                    ),
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
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black,
        child: Column(children: [Expanded(child: content)]),
      ),
    );
  }
}
