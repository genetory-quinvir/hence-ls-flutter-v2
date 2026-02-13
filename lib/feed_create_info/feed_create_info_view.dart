import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:hence_ls_flutter_v2/common/widgets/common_textview_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:geolocator/geolocator.dart';

import '../common/location/naver_location_service.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/media/media_conversion_service.dart';
import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_alert_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_textfield_view.dart';
import '../place_select/place_select_view.dart';
import '../sign/sign_view.dart';

class FeedCreateInfoView extends StatefulWidget {
  const FeedCreateInfoView({
    super.key,
    required this.selectedAssets,
  });

  final List<AssetEntity> selectedAssets;

  @override
  State<FeedCreateInfoView> createState() => _FeedCreateInfoViewState();
}

class _FeedCreateInfoViewState extends State<FeedCreateInfoView> {
  late final PageController _pageController;
  int _pageIndex = 0;
  final Map<String, Future<Uint8List?>> _imageFutures = {};
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isUploading = false;
  bool _isPrefillingLocation = false;
  bool _didPromptLocationPermission = false;
  double? _selectedLongitude;
  double? _selectedLatitude;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _prefillLocation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _placeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefillLocation();
  }

  Future<Uint8List?> _imageFuture(AssetEntity asset) {
    return _imageFutures.putIfAbsent(
      asset.id,
      () => asset.thumbnailDataWithSize(const ThumbnailSize(1600, 1600)),
    );
  }

  Future<void> _selectPlace() async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => PlaceSelectView(
          places: const [],
          initialPlaceName: _placeController.text.trim(),
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          markerImageFuture: widget.selectedAssets.isNotEmpty
              ? _imageFuture(widget.selectedAssets.first)
              : null,
        ),
      ),
    );
    if (!mounted) return;
    if (result is PlaceSelection) {
      final name = result.placeName.trim();
      if (name.isNotEmpty) {
        _placeController.text = name;
      }
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
    } else if (result is String && result.trim().isNotEmpty) {
      _placeController.text = result.trim();
    }
  }

  Future<void> _prefillLocation() async {
    if (_isPrefillingLocation) return;
    if (_placeController.text.trim().isNotEmpty) return;
    _isPrefillingLocation = true;
    try {
      final granted = await _ensureLocationPermission();
      if (!mounted || !granted) return;
      final position = await _getCurrentPosition();
      if (!mounted || position == null) return;
      _selectedLatitude = position.latitude;
      _selectedLongitude = position.longitude;
      final place = await NaverLocationService.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      if (place != null && place.trim().isNotEmpty) {
        _placeController.text = place.trim();
      }
    } finally {
      _isPrefillingLocation = false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final status = await LocationPermissionService.getStatus();
    if (LocationPermissionService.isGrantedStatus(status)) {
      return true;
    }
    if (_didPromptLocationPermission) return false;
    _didPromptLocationPermission = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      builder: (_) {
        return Material(
          type: MaterialType.transparency,
          child: CommonAlertView(
            title: '위치 권한 필요',
            subTitle: '현재 위치로 장소를 자동 입력하려면 위치 권한이 필요합니다.',
            primaryButtonTitle: '확인',
            secondaryButtonTitle: '취소',
            onPrimaryTap: () => Navigator.of(context).pop(true),
            onSecondaryTap: () => Navigator.of(context).pop(false),
          ),
        );
      },
    );
    if (!mounted || confirmed != true) return false;
    return LocationPermissionService.requestWhenInUse();
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      final granted = await LocationPermissionService.isGranted();
      if (!granted) return null;
      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } on MissingPluginException {
      // Plugin not yet registered (e.g. hot-reload). Ignore and skip.
      return null;
    }
  }

  Future<File?> _assetToFile(AssetEntity asset) async {
    final file = await asset.file;
    if (file != null) return file;
    return asset.originFile;
  }

  Future<void> _submitFeed() async {
    if (_isUploading) return;
    if (!AuthStore.instance.isSignedIn.value) {
      await showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return const SizedBox.expand(
            child: SignView(),
          );
        },
      );
      return;
    }
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      final placeName = _placeController.text.trim();

      final files = <File>[];
      for (final asset in widget.selectedAssets) {
        final file = await _assetToFile(asset);
        if (file == null) continue;
        final webp = await MediaConversionService.toWebp(file);
        files.add(webp);
      }

      final fileIds =
          files.isEmpty ? <String>[] : await ApiClient.uploadFeedImages(files);

      await ApiClient.createPersonalFeed(
        content: content,
        fileIds: fileIds,
        placeName: placeName,
        longitude: _selectedLongitude ?? 0,
        latitude: _selectedLatitude ?? 0,
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      HomeTabController.switchTo(1);
      HomeTabController.requestFeedReload();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final isPathProviderError =
          message.contains('path_provider_foundation') ||
          message.contains('PathProviderApi.getDirectoryPath');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPathProviderError
                ? '피드 업로드 실패: 임시 저장소 접근 오류입니다. 앱을 완전히 종료 후 다시 시도해주세요.'
                : '피드 업로드 실패: $message',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8,),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text(
                            '정보 입력',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CommonInkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: CommonInkWell(
                            onTap: _submitFeed,
                            child: const Text(
                              '올리기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (widget.selectedAssets.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final hasMultiple = widget.selectedAssets.length > 1;
                    final imageHeight = constraints.maxWidth * (5 / 4);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: imageHeight,
                            child: hasMultiple
                                ? PageView.builder(
                                    controller: _pageController,
                                    onPageChanged: (index) {
                                      setState(() => _pageIndex = index);
                                    },
                                    itemCount: widget.selectedAssets.length,
                                    itemBuilder: (context, index) {
                                      return _SelectedImageCard(
                                        future: _imageFuture(widget.selectedAssets[index]),
                                        cacheKey: '${widget.selectedAssets[index].id}_1600',
                                      );
                                    },
                                  )
                                : _SelectedImageCard(
                                    future: _imageFuture(widget.selectedAssets.first),
                                    cacheKey: '${widget.selectedAssets.first.id}_1600',
                                  ),
                          ),
                          if (hasMultiple) ...[
                            const SizedBox(height: 12),
                            _PageIndicator(
                              count: widget.selectedAssets.length,
                              index: _pageIndex,
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            color: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CommonInkWell(
                                  onTap: _selectPlace,
                                  child: IgnorePointer(
                                    child: CommonTextFieldView(
                                      controller: _placeController,
                                      title: '장소',
                                      hintText: '장소 입력',
                                      darkStyle: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                CommonTextViewView(
                                  controller: _contentController,
                                  title: '내용',
                                  hintText: '내용 입력',
                                  darkStyle: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                alignment: Alignment.center,
                child: const CommonActivityIndicator(size: 36, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedImageCard extends StatelessWidget {
  const _SelectedImageCard({
    required this.future,
    required this.cacheKey,
  });

  final Future<Uint8List?> future;
  final String cacheKey;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const ColoredBox(color: Colors.black);
        }
        return RepaintBoundary(
          child: CommonImageView(
            memoryBytes: bytes,
            cacheKey: cacheKey,
            fit: BoxFit.contain,
            backgroundColor: Colors.black,
          ),
        );
      },
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (i) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == index ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.title,
    required this.hintText,
    required this.onTap,
    this.isPlaceholder = true,
  });

  final String title;
  final String hintText;
  final VoidCallback onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF757575),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hintText,
                style: TextStyle(
                  fontSize: 16,
                  color: isPlaceholder
                      ? Colors.black.withOpacity(0.35)
                      : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
