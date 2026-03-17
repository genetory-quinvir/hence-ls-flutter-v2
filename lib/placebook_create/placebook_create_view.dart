import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_map_view.dart';
import '../common/widgets/common_place_marker.dart';
import '../common/widgets/common_textfield_view.dart';
import '../common/widgets/common_textview_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/network/api_client.dart';
import '../common/styles/app_shadows.dart';
import '../common/media/media_picker_service.dart';
import '../common/permissions/media_permission_service.dart';
import '../common/media/media_conversion_service.dart';
import '../common/widgets/common_title_actionsheet.dart';
import '../common/location/naver_location_service.dart';
import '../common/state/placebook_cache.dart';
import '../place_select/place_select_view.dart';
import '../placebook_search/placebook_search_view.dart';
import '../placebook_saved/placebook_saved_view.dart';

class PlacebookCreateView extends StatefulWidget {
  const PlacebookCreateView({
    super.key,
    this.categoryTitle,
    this.themeTitle,
    this.themeId,
  });

  final String? categoryTitle;
  final String? themeTitle;
  final String? themeId;

  @override
  State<PlacebookCreateView> createState() => _PlacebookCreateViewState();
}

class _PlacebookCreateViewState extends State<PlacebookCreateView> {
  final Key _mapKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              title: "장소 등록",
              left: const Icon(PhosphorIconsBold.x,
                  size: 24, color: Colors.black),
              onLeftTap: () => Navigator.of(context).maybePop(),
              backgroundColor: Colors.white,
            ),
            Expanded(
              child: _PlacebookCreateBody(
                categoryTitle: widget.categoryTitle,
                themeId: widget.themeId,
                themeTitle: widget.themeTitle,
                mapKey: _mapKey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacebookCreateBody extends StatefulWidget {
  const _PlacebookCreateBody({
    required this.categoryTitle,
    required this.themeId,
    required this.themeTitle,
    required this.mapKey,
  });

  final String? categoryTitle;
  final String? themeId;
  final String? themeTitle;
  final Key mapKey;

  @override
  State<_PlacebookCreateBody> createState() => _PlacebookCreateBodyState();
}

class _PlacebookCreateBodyState extends State<_PlacebookCreateBody> {
  final CommonMapViewController _mapController = CommonMapViewController();
  Key _mapKey = UniqueKey();
  final TextEditingController _themeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  File? _photoPreview;
  Uint8List? _photoPreviewBytes;
  String? _photoFileId;
  bool _showMapStep = false;
  bool _showInfoStep = false;
  bool _isMapInteracting = false;
  bool _isSaving = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _showAdvanced = false;
  bool _canSave = false;
  Timer? _reverseGeocodeDebounce;
  List<Map<String, dynamic>> _themes = const [];
  bool _isLoadingThemes = false;
  bool _didAutoOpenThemeSheet = false;
  String? _selectedThemeId;
  String? _selectedThemeTitle;
  String? _selectedCategoryId;
  static const List<Map<String, String>> _visitTimeOptions = [
    {'value': 'all_day', 'label': '하루종일'},
    {'value': 'morning', 'label': '오전'},
    {'value': 'afternoon', 'label': '오후'},
    {'value': 'dawn', 'label': '새벽'},
  ];
  String? _bestVisitTimeValue;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = (widget.themeId ?? '').trim().isEmpty
        ? null
        : widget.themeId!.trim();
    _selectedThemeTitle = (widget.themeTitle ?? '').trim();
    if (_selectedThemeId != null && _selectedThemeTitle!.isNotEmpty) {
      _themeController.text = _selectedThemeTitle!;
    }
    if (_selectedThemeId == null || _selectedThemeId!.isEmpty) {
      _loadThemes();
    } else {
      _loadThemes();
    }
    _titleController.addListener(_syncCanSave);
    _contentController.addListener(_syncCanSave);
    _syncCanSave();
  }

  @override
  void dispose() {
    _reverseGeocodeDebounce?.cancel();
    _themeController.dispose();
    _titleController.removeListener(_syncCanSave);
    _contentController.removeListener(_syncCanSave);
    _titleController.dispose();
    _contentController.dispose();
    _subtitleController.dispose();
    _addressController.dispose();
    _hashtagsController.dispose();
    _addressFocusNode.dispose();
    _photoPreview = null;
    _photoPreviewBytes = null;
    super.dispose();
  }

  Future<void> _loadThemes() async {
    if (_isLoadingThemes) return;
    setState(() => _isLoadingThemes = true);
    try {
      final themes = await PlacebookCache.loadThemes();
      if (!mounted) return;
      setState(() {
        _themes = themes.map(_resolveThemeData).toList();
        _applySelectedThemeFromList();
      });
      _openThemeSheetIfNeeded();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoadingThemes = false);
    }
  }

  void _openThemeSheetIfNeeded() {
    if (!mounted) return;
    if (_didAutoOpenThemeSheet) return;
    final selectedThemeId = (_selectedThemeId ?? '').trim();
    if (selectedThemeId.isNotEmpty) return;
    if (_themes.isEmpty) return;
    _didAutoOpenThemeSheet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 280), () {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return;
        _openThemeSheet();
      });
    });
  }

  Map<String, dynamic> _resolveThemeData(Map<String, dynamic> theme) {
    final idMap = theme['id'];
    if (idMap is Map<String, dynamic>) {
      return {...idMap, ...theme};
    }
    return theme;
  }

  void _applySelectedThemeFromList() {
    final selectedId = (_selectedThemeId ?? '').trim();
    if (selectedId.isEmpty || _themes.isEmpty) return;
    final match = _themes.firstWhere(
      (theme) => theme['id']?.toString() == selectedId,
      orElse: () => <String, dynamic>{},
    );
    if (match.isEmpty) return;
    final resolvedTitle =
        (match['title'] as String?) ?? (match['name'] as String?);
    if ((resolvedTitle ?? '').trim().isNotEmpty) {
      _selectedThemeTitle = resolvedTitle;
      if (_themeController.text.trim().isEmpty) {
        _themeController.text = resolvedTitle!;
      }
    }
    final category = match['category'];
    if (category is Map<String, dynamic>) {
      _selectedCategoryId = category['id']?.toString();
    }
  }

  void _syncCanSave() {
    final next = _canSaveNow();
    if (next == _canSave) return;
    setState(() => _canSave = next);
  }

  Widget _buildHeader() {
    final category = (widget.categoryTitle ?? '').trim();
    final theme = (_selectedThemeTitle ?? widget.themeTitle ?? '').trim();
    const baseStyle =
        TextStyle(fontWeight: FontWeight.w400, fontSize: 20, height: 1.4);
    const boldStyle =
        TextStyle(fontWeight: FontWeight.w700, fontSize: 20, height: 1.4);
    const arrowColor = Colors.black;
    const chipColor = Color(0xFFF2F2F2);

    Widget buildThemeRow(String label) {
      return CommonInkWell(
        onTap: _openThemeSheet,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: boldStyle),
              const SizedBox(width: 4),
              const Icon(
                PhosphorIconsFill.caretDown,
                size: 18,
                color: arrowColor,
              ),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[];
    if (category.isNotEmpty) {
      children.add(Text(category, style: boldStyle));
      children.add(const SizedBox(height: 4));
    }
    if (theme.isNotEmpty) {
      children.add(buildThemeRow(theme));
      children.add(const SizedBox(height: 12));
      children.add(const Text('테마 장소를 등록하시겠어요?', style: baseStyle));
    } else {
      children.add(buildThemeRow('새로운 장소'));
      children.add(const SizedBox(height: 12));
      children.add(const Text('등록하시겠어요?', style: baseStyle));
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  String _currentThemeId() {
    final selected = (_selectedThemeId ?? '').trim();
    if (selected.isNotEmpty) return selected;
    return (widget.themeId ?? '').trim();
  }

  String _currentCategoryId() {
    final selected = (_selectedCategoryId ?? '').trim();
    if (selected.isNotEmpty) return selected;
    final themeId = _currentThemeId();
    if (themeId.isEmpty) return '';
    final match = _themes.firstWhere(
      (theme) => theme['id']?.toString() == themeId,
      orElse: () => <String, dynamic>{},
    );
    if (match.isNotEmpty) {
      final category = match['category'];
      if (category is Map<String, dynamic>) {
        final id = category['id']?.toString() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return '';
  }

  bool _canSaveNow() {
    final title = _titleController.text.trim();
    final description = _contentController.text.trim();
    final lat = _selectedLatitude;
    final lng = _selectedLongitude;
    final themeId = _currentThemeId();
    final categoryId = _currentCategoryId();
    return themeId.isNotEmpty &&
        categoryId.isNotEmpty &&
        title.isNotEmpty &&
        description.isNotEmpty &&
        lat != null &&
        lng != null;
  }

  void _openThemeSheet() async {
    if (_themes.isEmpty && !_isLoadingThemes) {
      await _loadThemes();
    }
    if (!mounted) return;
    if (_themes.isEmpty) {
      _showSnack('테마를 불러오지 못했어요.');
      return;
    }
    CommonTitleActionSheet.show(
      context,
      title: '테마 선택',
      items: _themes
          .map((theme) => CommonTitleActionSheetItem(
                label: (theme['title'] as String?) ??
                    (theme['name'] as String?) ??
                    '테마',
                value: theme['id']?.toString(),
              ))
          .toList(),
      onSelected: (value) {
        final selectedTheme = _themes.firstWhere(
          (theme) => theme['id']?.toString() == value.value?.toString(),
          orElse: () => <String, dynamic>{},
        );
        setState(() {
          _selectedThemeId = value.value;
          _selectedThemeTitle = value.label;
          _themeController.text = value.label;
          final category = selectedTheme['category'];
          if (category is Map<String, dynamic>) {
            _selectedCategoryId = category['id']?.toString();
          }
        });
        _syncCanSave();
      },
    );
  }

  void _openVisitTimeSheet() {
    CommonTitleActionSheet.show(
      context,
      title: '찾아가기 좋은 시간대',
      items: [
        for (final option in _visitTimeOptions)
          CommonTitleActionSheetItem(
            label: option['label'] ?? '',
            value: option['value'],
          ),
      ],
      onSelected: (value) {
        setState(() {
          _subtitleController.text = value.label;
          _bestVisitTimeValue = value.value;
        });
      },
    );
  }


  Future<void> _savePlace() async {
    if (_isSaving) return;
    final themeId = _currentThemeId();
    final categoryId = _currentCategoryId();
    final title = _titleController.text.trim();
    final description = _contentController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final address = _addressController.text.trim();
    final tagIds = _parseHashtags(_hashtagsController.text);
    final commonTagIds = const <String>[];
    final lat = _selectedLatitude;
    final lng = _selectedLongitude;

    if (themeId.isEmpty) {
      _showSnack('테마를 찾을 수 없어요.');
      return;
    }
    if (categoryId.isEmpty) {
      _showSnack('카테고리를 찾을 수 없어요.');
      return;
    }
    if (lat == null || lng == null) {
      _showSnack('지도를 움직여 위치를 선택해주세요.');
      return;
    }
    if (title.isEmpty) {
      _showSnack('타이틀을 입력해주세요.');
      return;
    }
    if (description.isEmpty) {
      _showSnack('내용을 입력해주세요.');
      return;
    }

    final photoFile = _photoPreview;
    final imageBytes = _photoPreviewBytes;
    final saveFuture = _createPlaceAndResolveImageUrl(
      categoryId: categoryId,
      themeId: themeId,
      title: title,
      description: description,
      subtitle: subtitle,
      address: address,
      latitude: lat,
      longitude: lng,
      thumbnailFileId: _photoFileId,
      tagIds: tagIds,
      commonTagIds: commonTagIds,
      photoFile: photoFile,
    );
    if (!mounted) return;
    setState(() => _isSaving = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlacebookSavedView(
          imageBytes: imageBytes,
          saveFuture: saveFuture,
        ),
      ),
    );
  }

  Future<PlacebookSaveResult> _createPlaceAndResolveImageUrl({
    required String categoryId,
    required String themeId,
    required String title,
    required String description,
    required String subtitle,
    required String address,
    required double latitude,
    required double longitude,
    required String? thumbnailFileId,
    required List<String> tagIds,
    required List<String> commonTagIds,
    required File? photoFile,
  }) async {
    var resolvedThumbnailFileId = (thumbnailFileId ?? '').trim().isEmpty
        ? null
        : thumbnailFileId!.trim();
    if (photoFile != null) {
      final webp = await MediaConversionService.toWebp(photoFile);
      resolvedThumbnailFileId = await ApiClient.uploadPlacebookPlaceImage(webp);
    }

    var created = await ApiClient.createPlacebookPlace(
      categoryId: categoryId,
      themeId: themeId,
      title: title,
      description: description,
      subtitle: subtitle,
      address: address,
      latitude: latitude,
      longitude: longitude,
      thumbnailFileId: resolvedThumbnailFileId,
      tagIds: tagIds,
      commonTagIds: commonTagIds,
    );
    return PlacebookSaveResult(
      imageUrl: _resolveCreatedImageUrl(created),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _resolveCreatedImageUrl(Map<String, dynamic> place) {
    String? fromMap(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return raw['cdnUrl'] as String? ??
            raw['fileUrl'] as String? ??
            raw['thumbnailUrl'] as String?;
      }
      return null;
    }

    final imageUrl = place['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) return imageUrl;
    final thumbnailUrl = place['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty) {
      return thumbnailUrl;
    }
    final image = fromMap(place['image']);
    if (image != null && image.trim().isNotEmpty) return image;
    final imageId = fromMap(place['imageId']);
    if (imageId != null && imageId.trim().isNotEmpty) return imageId;
    final thumbnail = fromMap(place['thumbnail']);
    if (thumbnail != null && thumbnail.trim().isNotEmpty) return thumbnail;
    return null;
  }

  List<String> _parseHashtags(String raw) {
    return raw
        .split(RegExp(r'[,\n ]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => value.startsWith('#') ? value.substring(1) : value)
        .toSet()
        .toList();
  }

  Future<void> _pickPhoto() async {
    await CommonTitleActionSheet.show(
      context,
      title: '사진 추가',
      items: const [
        CommonTitleActionSheetItem(label: '앨범에서 가져오기', value: 'album'),
        CommonTitleActionSheetItem(label: '카메라로 촬영하기', value: 'camera'),
      ],
      onSelected: (item) async {
        File? pickedFile;
        switch (item.value) {
          case 'album':
            if (!await MediaPermissionService.ensurePhotoLibrary()) {
              _showSnack('사진 접근 권한이 필요합니다.');
              return;
            }
            final picked = await MediaPickerService.pickFromGallery();
            if (picked == null) return;
            pickedFile = File(picked.path);
            break;
          case 'camera':
            if (!await MediaPermissionService.ensureCamera()) {
              _showSnack('카메라 권한이 필요합니다.');
              return;
            }
            final picked = await MediaPickerService.pickFromCamera();
            if (picked == null) return;
            pickedFile = File(picked.path);
            break;
        }
        if (pickedFile == null || !mounted) return;
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _photoPreview = pickedFile;
          _photoPreviewBytes = bytes;
          _photoFileId = null;
        });
      },
    );
  }

  void _handleMapCenterChanged(NLatLng center) {
    _selectedLatitude = center.latitude;
    _selectedLongitude = center.longitude;
    _requestAddressForCenter(center);
    _syncCanSave();
  }

  void _requestAddressForCenter(NLatLng center) {
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 360), () async {
      if (_addressFocusNode.hasFocus) return;
      final address = await NaverLocationService.reverseGeocode(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted) return;
      final resolved = address?.trim() ?? '';
      if (resolved.isEmpty) return;
      if (_addressFocusNode.hasFocus) return;
      _addressController.text = resolved;
    });
  }

  Future<void> _searchPlace() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PlacebookSearchView(),
      ),
    );
    if (!mounted) return;
    if (result is PlaceSelection) {
      final name = result.placeName.trim();
      if (name.isNotEmpty && _titleController.text.trim().isEmpty) {
        _titleController.text = name;
      }
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
      setState(() {
        _showMapStep = true;
        _mapKey = UniqueKey();
      });
      _handleMapCenterChanged(NLatLng(result.latitude, result.longitude));
      return;
    }
  }


  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Stack(
      children: [
        SingleChildScrollView(
          physics: _isMapInteracting
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
          // 테마는 헤더에서 선택
          if (_currentThemeId().isNotEmpty && !_showMapStep) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CommonRoundedButton(
                title: '지도에서 직접 선택하기',
                onTap: () {
                  setState(() => _showMapStep = true);
                  _syncCanSave();
                },
                height: 52,
                backgroundColor: Colors.grey.shade200,
                textColor: Colors.black,
                leading: const Icon(
                  PhosphorIconsRegular.mapPin,
                  size: 18,
                  color: Colors.black,
                ),
                leadingCentered: true,
                leadingGap: 8,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CommonRoundedButton(
                title: '검색해서 장소 가져오기',
                onTap: _searchPlace,
                height: 52,
                backgroundColor: Colors.grey.shade200,
                textColor: Colors.black,
                leading: const Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 18,
                  color: Colors.black,
                ),
                leadingCentered: true,
                leadingGap: 8,
              ),
            ),
          ],
          if (_showMapStep) ...[
            const SizedBox(height: 16),
            Listener(
              onPointerDown: (_) {
                if (_isMapInteracting) return;
                setState(() => _isMapInteracting = true);
              },
              onPointerUp: (_) {
                if (!_isMapInteracting) return;
                setState(() => _isMapInteracting = false);
              },
              onPointerCancel: (_) {
                if (!_isMapInteracting) return;
                setState(() => _isMapInteracting = false);
              },
              child: AspectRatio(
                aspectRatio: 1.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                    CommonMapView(
                      key: _mapKey,
                      controller: _mapController,
                      initialLatitude: _selectedLatitude,
                      initialLongitude: _selectedLongitude,
                      showMyLocationButton: false,
                      onMapReady: (controller) async {
                        final position = await controller.getCameraPosition();
                        _selectedLatitude ??= position.target.latitude;
                        _selectedLongitude ??= position.target.longitude;
                        _handleMapCenterChanged(position.target);
                      },
                      onCenterChanged: _handleMapCenterChanged,
                    ),
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: _photoPreviewBytes == null
                            ? const CommonPlaceMarker(size: 64)
                            : CommonPlaceMarker(
                                size: 64,
                                imageBytes: _photoPreviewBytes,
                              ),
                      ),
                    ),
                    Center(
                      child: Transform.translate(
                        offset: const Offset(24, 20),
                        child: _MapFloatingButton(
                          icon: PhosphorIconsBold.imageSquare,
                          onTap: _pickPhoto,
                          size: 32,
                          iconSize: 16,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _MapFloatingButton(
                        icon: PhosphorIconsFill.navigationArrow,
                        onTap: () => _mapController.moveToMyLocation(),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _MapFloatingButton(
                        icon: PhosphorIconsBold.magnifyingGlass,
                        onTap: _searchPlace,
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_showInfoStep) ...[
              CommonTextFieldView(
                title: '타이틀',
                hintText: '장소 이름을 입력하세요',
                maxLength: 40,
                controller: _titleController,
              ),
              const SizedBox(height: 16),
              CommonTextViewView(
                title: '내용',
                hintText: '설명을 입력하세요',
                maxLines: 4,
                maxLength: 200,
                controller: _contentController,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() => _showAdvanced = !_showAdvanced);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '추가 정보를 입력하실건가요?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Icon(
                        _showAdvanced
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_showAdvanced) ...[
                CommonTextFieldView(
                  title: '주소',
                  hintText: '주소를 입력하세요',
                  maxLength: 120,
                  controller: _addressController,
                  focusNode: _addressFocusNode,
                ),
                const SizedBox(height: 16),
                CommonInkWell(
                  onTap: _openVisitTimeSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: AbsorbPointer(
                    child: CommonTextFieldView(
                      title: '찾아가기 좋은 시간대',
                      hintText: '예: 평일 오전 / 주말 오후',
                      controller: _subtitleController,
                      enabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CommonTextFieldView(
                  title: '해시태그',
                  hintText: '#카페 #데이트 (띄어쓰기/쉼표)',
                  maxLength: 120,
                  controller: _hashtagsController,
                ),
                const SizedBox(height: 16),
              ],
            ],
            SizedBox(
              width: double.infinity,
              child: CommonRoundedButton(
                title: _showInfoStep
                    ? (_isSaving ? '저장중' : '저장하기')
                    : '정보 입력하기',
                onTap: () {
                  if (_showInfoStep) {
                    if (!_canSave) return;
                    if (_isSaving) return;
                    _savePlace();
                    return;
                  }
                  setState(() => _showInfoStep = true);
                  _syncCanSave();
                },
                backgroundColor: _showInfoStep && !_canSave
                    ? const Color(0xFFE0E0E0)
                    : Colors.black,
                textColor: _showInfoStep && !_canSave
                    ? const Color(0xFF9E9E9E)
                    : Colors.white,
                height: 52,
              ),
            ),
            const SizedBox(height: 16),
          ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: AppShadows.card,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.black,
        ),
      ),
    );
  }
}
