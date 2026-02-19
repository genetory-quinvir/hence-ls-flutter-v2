import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

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
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_textfield_view.dart';
import '../place_select/place_select_view.dart';
import '../sign/sign_view.dart';

class FeedCreateInfoView extends StatefulWidget {
  const FeedCreateInfoView({
    super.key,
    required this.selectedAssets,
    this.isFeedMode = true,
    this.editFeedId,
    this.initialContent,
    this.initialPlaceName,
    this.initialLatitude,
    this.initialLongitude,
    this.initialImageUrls = const <String>[],
    this.initialThumbnailBytes = const <String, Uint8List>{},
    this.prefillFromAssetLocation = true,
  });

  final List<AssetEntity> selectedAssets;
  final bool isFeedMode;
  final String? editFeedId;
  final String? initialContent;
  final String? initialPlaceName;
  final double? initialLatitude;
  final double? initialLongitude;
  final List<String> initialImageUrls;
  final Map<String, Uint8List> initialThumbnailBytes;
  final bool prefillFromAssetLocation;

  @override
  State<FeedCreateInfoView> createState() => _FeedCreateInfoViewState();
}

class _FeedCreateInfoViewState extends State<FeedCreateInfoView> {
  late final PageController _pageController;
  final Completer<void> _heavyLoadGate = Completer<void>();
  int _pageIndex = 0;
  final Map<String, Future<Uint8List?>> _imageFutures = {};
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final List<String> _hashtagTags = [];
  bool _isUploading = false;
  bool _isPrefillingLocation = false;
  bool _isPrefillingAssetLocation = false;
  bool _didPromptLocationPermission = false;
  double? _selectedLongitude;
  double? _selectedLatitude;
  late String _defaultTitle;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _waitForRouteAnimation();
      if (!_heavyLoadGate.isCompleted) {
        _heavyLoadGate.complete();
      }
      await _deferredInit();
    });
    if (widget.initialPlaceName != null &&
        widget.initialPlaceName!.trim().isNotEmpty) {
      _placeController.text = widget.initialPlaceName!.trim();
    }
    if (widget.initialContent != null &&
        widget.initialContent!.trim().isNotEmpty) {
      _contentController.text = widget.initialContent!.trim();
    }
    final nickname = AuthStore.instance.currentUser.value?.nickname ?? '';
    _defaultTitle = nickname.isNotEmpty ? '$nickname의 라이브스페이스' : '라이브스페이스';
    if (!widget.isFeedMode) {
      _titleController.text = widget.initialContent?.trim() ?? '';
    }
    _selectedLatitude = widget.initialLatitude;
    _selectedLongitude = widget.initialLongitude;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _placeController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _waitForRouteAnimation() async {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null) return;
    if (animation.status == AnimationStatus.completed) return;
    final completer = Completer<void>();
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        completer.complete();
      }
    };
    animation.addStatusListener(listener);
    await completer.future;
  }

  Future<void> _deferredInit() async {
    if (!mounted) return;
    await _prefillFromSelectedAsset();
    await _prefillLocation();
  }

  Future<void> _prefillFromSelectedAsset() async {
    if (!widget.prefillFromAssetLocation) return;
    if (_isPrefillingAssetLocation) return;
    if (_placeController.text.trim().isNotEmpty) return;
    if (widget.selectedAssets.isEmpty) return;
    _isPrefillingAssetLocation = true;
    try {
      final asset = widget.selectedAssets.first;
      final latLng = await asset.latlngAsync();
      if (!mounted || latLng == null) return;
      final place = await NaverLocationService.reverseGeocode(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      );
      if (!mounted) return;
      if (place == null || place.trim().isEmpty) return;
      _placeController.text = place.trim();
      _selectedLatitude = latLng.latitude;
      _selectedLongitude = latLng.longitude;
    } finally {
      _isPrefillingAssetLocation = false;
    }
  }

  Future<Uint8List?> _imageFuture(AssetEntity asset) {
    return _imageFutures.putIfAbsent(
      asset.id,
      () async {
        if (!_heavyLoadGate.isCompleted) {
          await _heavyLoadGate.future;
        }
        return asset.thumbnailDataWithSize(const ThumbnailSize(1600, 1600));
      },
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
              : (widget.initialImageUrls.isNotEmpty
                  ? CommonImageView.fetchNetworkBytes(
                      widget.initialImageUrls.first,
                    )
                  : null),
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
      final seededLat = _selectedLatitude;
      final seededLng = _selectedLongitude;
      if (seededLat != null && seededLng != null) {
        final seededPlace = await NaverLocationService.reverseGeocode(
          latitude: seededLat,
          longitude: seededLng,
        );
        if (!mounted) return;
        if (seededPlace != null && seededPlace.trim().isNotEmpty) {
          _placeController.text = seededPlace.trim();
        }
        return;
      }
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
    final title = widget.isFeedMode ? null : _titleController.text.trim();
    _commitHashtagInput();
    final hashtags = List<String>.from(_hashtagTags);
    setState(() => _isUploading = true);
    try {
      final placeName = _placeController.text.trim();
      Map<String, dynamic>? createdSpaceForMap;
      if (widget.editFeedId != null && widget.editFeedId!.isNotEmpty) {
        await ApiClient.updatePersonalFeed(
          feedId: widget.editFeedId!,
          content: content,
          placeName: placeName,
          longitude: _selectedLongitude,
          latitude: _selectedLatitude,
          hashtags: hashtags,
          type: widget.isFeedMode ? 'FEED' : 'LIVESPACE',
        );
      } else {
        final files = <File>[];
        for (final asset in widget.selectedAssets) {
          final file = await _assetToFile(asset);
          if (file == null) continue;
          final webp = await MediaConversionService.toWebp(file);
          files.add(webp);
        }

        final fileIds =
            files.isEmpty ? <String>[] : await ApiClient.uploadFeedImages(files);

        final createdJson = await ApiClient.createPersonalFeed(
          content: content,
          fileIds: fileIds,
          placeName: placeName,
          longitude: _selectedLongitude ?? 0,
          latitude: _selectedLatitude ?? 0,
          title: widget.isFeedMode
              ? null
              : (title != null && title.isNotEmpty
                  ? title
                  : _defaultTitle),
          hashtags: hashtags,
          type: widget.isFeedMode ? 'FEED' : 'LIVESPACE',
        );
        if (!widget.isFeedMode) {
          final data = createdJson?['data'];
          final created = data is Map<String, dynamic> ? data : createdJson;
          createdSpaceForMap = <String, dynamic>{
            if (created is Map<String, dynamic>) ...created,
            'id': (created is Map<String, dynamic> ? created['id'] : null) ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            'type': 'LIVESPACE',
            'title': (title != null && title.isNotEmpty) ? title : _defaultTitle,
            'content': content,
            'placeName': placeName,
            'latitude': _selectedLatitude,
            'longitude': _selectedLongitude,
          };
        }
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (widget.editFeedId == null || widget.editFeedId!.isEmpty) {
        if (widget.isFeedMode) {
          HomeTabController.switchTo(1);
        } else {
          final lat = _selectedLatitude;
          final lng = _selectedLongitude;
          if (lat != null && lng != null) {
            HomeTabController.requestMapFocus(
              latitude: lat,
              longitude: lng,
              resetFilters: true,
              createdSpace: createdSpaceForMap,
            );
          }
          HomeTabController.switchTo(0);
        }
      }
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


  List<String> _parseHashtags(String input) {
    if (input.trim().isEmpty) return [];
    final raw = input
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('#') ? e.substring(1) : e)
        .where((e) => e.isNotEmpty)
        .toList();
    return raw;
  }

  void _commitHashtagInput() {
    final raw = _hashtagController.text.trim();
    if (raw.isEmpty) return;
    final tags = _parseHashtags(raw);
    if (tags.isEmpty) {
      _hashtagController.clear();
      return;
    }
    for (final tag in tags) {
      if (!_hashtagTags.contains(tag)) {
        _hashtagTags.add(tag);
      }
    }
    _hashtagController.clear();
    if (mounted) setState(() {});
  }

  void _removeHashtag(String tag) {
    _hashtagTags.removeWhere((t) => t == tag);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editFeedId != null && widget.editFeedId!.isNotEmpty;
    final isFeedMode = widget.isFeedMode;
    final backgroundColor = isFeedMode ? Colors.black : Colors.white;
    final primaryTextColor = isFeedMode ? Colors.white : Colors.black;
    final secondaryTextColor =
        isFeedMode ? const Color(0xFFBDBDBD) : const Color(0xFF8E8E8E);
    final panelColor = isFeedMode ? Colors.black : Colors.white;
    final buttonBackground = isFeedMode ? Colors.white : Colors.black;
    final buttonTextColor = isFeedMode ? Colors.black : Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isFeedMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: backgroundColor,
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
                        Center(
                          child: Text(
                            isFeedMode ? '피드 올리기' : '라이브스페이스 만들기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CommonInkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: Icon(
                              isEdit ? Icons.close : Icons.arrow_back_ios_new,
                              size: 20,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: const SizedBox(width: 24, height: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hasAssets = widget.selectedAssets.isNotEmpty;
                    final hasInitialImages = widget.initialImageUrls.isNotEmpty;
                    if (!hasAssets && !hasInitialImages) {
                      return const SizedBox.shrink();
                    }
                    final hasMultiple =
                        hasAssets ? widget.selectedAssets.length > 1 : hasInitialImages && widget.initialImageUrls.length > 1;
                    final imageHeight = constraints.maxWidth * (5 / 4);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            child: SizedBox(
                              width: double.infinity,
                              height: imageHeight,
                              child: hasAssets
                                  ? (hasMultiple
                                      ? PageView.builder(
                                          controller: _pageController,
                                          onPageChanged: (index) {
                                            setState(() => _pageIndex = index);
                                          },
                                          allowImplicitScrolling: true,
                                          itemCount: widget.selectedAssets.length,
                                          itemBuilder: (context, index) {
                                            return _SelectedImageCard(
                                              future: _imageFuture(
                                                widget.selectedAssets[index],
                                              ),
                                              cacheKey:
                                                  '${widget.selectedAssets[index].id}_1600',
                                              placeholderBytes: widget
                                                  .initialThumbnailBytes[
                                                      widget
                                                          .selectedAssets[index]
                                                          .id],
                                              backgroundColor: backgroundColor,
                                            );
                                          },
                                        )
                                      : _SelectedImageCard(
                                          future: _imageFuture(
                                            widget.selectedAssets.first,
                                          ),
                                          cacheKey:
                                              '${widget.selectedAssets.first.id}_1600',
                                          placeholderBytes: widget
                                              .initialThumbnailBytes[
                                                  widget.selectedAssets.first.id],
                                          backgroundColor: backgroundColor,
                                        ))
                                  : (hasMultiple
                                      ? PageView.builder(
                                          controller: _pageController,
                                          onPageChanged: (index) {
                                            setState(() => _pageIndex = index);
                                          },
                                          allowImplicitScrolling: true,
                                          itemCount: widget.initialImageUrls.length,
                                          itemBuilder: (context, index) {
                                            return _NetworkImageCard(
                                              url: widget.initialImageUrls[index],
                                              backgroundColor: backgroundColor,
                                            );
                                          },
                                        )
                                      : _NetworkImageCard(
                                          url: widget.initialImageUrls.first,
                                          backgroundColor: backgroundColor,
                                        )),
                            ),
                          ),
                          if (hasMultiple) ...[
                            const SizedBox(height: 12),
                            _PageIndicator(
                              count: hasAssets
                                  ? widget.selectedAssets.length
                                  : widget.initialImageUrls.length,
                              index: _pageIndex,
                              activeColor:
                                  isFeedMode ? Colors.white : Colors.black,
                              inactiveColor: isFeedMode
                                  ? const Color(0xFF666666)
                                  : const Color(0xFFBDBDBD),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            child: Container(
                              width: double.infinity,
                              color: panelColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isFeedMode) ...[
                                    const SizedBox(height: 16),
                                    CommonTextFieldView(
                                      controller: _titleController,
                                      title: '타이틀',
                                      hintText: _defaultTitle,
                                      darkStyle: isFeedMode,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  CommonTextViewView(
                                    controller: _contentController,
                                    title: '내용',
                                    hintText: '내용 입력',
                                    darkStyle: isFeedMode,
                                  ),
                                  const SizedBox(height: 16),
                                  CommonInkWell(
                                    onTap: _selectPlace,
                                    child: IgnorePointer(
                                      child: CommonTextFieldView(
                                        controller: _placeController,
                                        title: '장소',
                                        hintText: '장소 입력',
                                        darkStyle: isFeedMode,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CommonTextFieldView(
                                    controller: _hashtagController,
                                    title: '해시태그',
                                    hintText: '#맛집 #친구',
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _commitHashtagInput(),
                                    onChanged: (value) {
                                      if (value.contains('\n')) {
                                        _commitHashtagInput();
                                      }
                                    },
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    textCapitalization: TextCapitalization.none,
                                    darkStyle: isFeedMode,
                                  ),
                                  if (_hashtagTags.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _hashtagTags
                                          .map(
                                            (tag) => _HashtagChip(
                                              label: tag,
                                              onRemove: () =>
                                                  _removeHashtag(tag),
                                              isDark: isFeedMode,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: CommonRoundedButton(
                    title: isFeedMode ? '피드 올리기' : '라이브스페이스 만들기',
                    onTap: _submitFeed,
                    height: 50,
                    radius: 12,
                    backgroundColor: buttonBackground,
                    textColor: buttonTextColor,
                  ),
                ),
              ),
            ],
          ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: isFeedMode
                    ? Colors.black.withOpacity(0.45)
                    : Colors.white.withOpacity(0.6),
                alignment: Alignment.center,
                child: CommonActivityIndicator(
                  size: 36,
                  color: isFeedMode ? Colors.white : Colors.black,
                ),
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
    this.placeholderBytes,
    required this.backgroundColor,
  });

  final Future<Uint8List?> future;
  final String cacheKey;
  final Uint8List? placeholderBytes;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          if (placeholderBytes == null) {
            return ColoredBox(color: backgroundColor);
          }
          return RepaintBoundary(
            child: CommonImageView(
              memoryBytes: placeholderBytes!,
              cacheKey: '${cacheKey}_thumb',
              fit: BoxFit.contain,
              backgroundColor: backgroundColor,
            ),
          );
        }
        return RepaintBoundary(
          child: CommonImageView(
            memoryBytes: bytes,
            cacheKey: cacheKey,
            fit: BoxFit.contain,
            backgroundColor: backgroundColor,
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
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;

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
            color: i == index ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }
}

class _NetworkImageCard extends StatelessWidget {
  const _NetworkImageCard({
    required this.url,
    required this.backgroundColor,
  });

  final String url;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CommonImageView(
      networkUrl: url,
      fit: BoxFit.contain,
      backgroundColor: backgroundColor,
    );
  }
}

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({
    required this.label,
    required this.onRemove,
    required this.isDark,
  });

  final String label;
  final VoidCallback onRemove;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final background = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 6),
          CommonInkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              Icons.close,
              size: 14,
              color: iconColor,
            ),
          ),
        ],
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
