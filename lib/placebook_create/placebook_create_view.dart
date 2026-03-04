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
import '../common/network/api_client.dart';
import '../common/media/media_picker_service.dart';
import '../common/permissions/media_permission_service.dart';
import '../common/media/media_conversion_service.dart';
import '../common/widgets/common_title_actionsheet.dart';

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
              left: const Icon(PhosphorIconsRegular.x,
                  size: 22, color: Colors.black),
              onLeftTap: () => Navigator.of(context).maybePop(),
              backgroundColor: Colors.white,
            ),
            Expanded(
              child: _PlacebookCreateBody(
                titleSpan: _buildTitleSpan(),
                themeId: widget.themeId,
                mapKey: _mapKey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildTitleSpan() {
    final category = (widget.categoryTitle ?? '').trim();
    final theme = (widget.themeTitle ?? '').trim();
    const baseStyle = TextStyle(fontWeight: FontWeight.w400);
    const boldStyle = TextStyle(fontWeight: FontWeight.w700);
    if (category.isEmpty && theme.isEmpty) {
      return const TextSpan(
        text: '새로운 장소를\n등록하시겠습니까?',
        style: baseStyle,
      );
    }
    if (category.isEmpty) {
      return TextSpan(
        children: [
          TextSpan(text: theme, style: boldStyle),
          const TextSpan(text: ' 장소를\n등록하시겠습니까?', style: baseStyle),
        ],
      );
    }
    if (theme.isEmpty) {
      return TextSpan(
        children: [
          TextSpan(text: category, style: boldStyle),
          const TextSpan(text: ' 장소를\n등록하시겠습니까?', style: baseStyle),
        ],
      );
    }
    return TextSpan(
      children: [
        TextSpan(text: category, style: boldStyle),
        const TextSpan(text: '의\n', style: baseStyle),
        TextSpan(text: theme, style: boldStyle),
        const TextSpan(text: ' 장소를\n등록하시겠습니까?', style: baseStyle),
      ],
    );
  }
}

class _PlacebookCreateBody extends StatefulWidget {
  const _PlacebookCreateBody({
    required this.titleSpan,
    required this.themeId,
    required this.mapKey,
  });

  final TextSpan titleSpan;
  final String? themeId;
  final Key mapKey;

  @override
  State<_PlacebookCreateBody> createState() => _PlacebookCreateBodyState();
}

class _PlacebookCreateBodyState extends State<_PlacebookCreateBody> {
  final CommonMapViewController _mapController = CommonMapViewController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController();
  File? _photoPreview;
  Uint8List? _photoPreviewBytes;
  bool _isUploadingPhoto = false;
  String? _photoId;
  bool _showMapStep = false;
  bool _showInfoStep = false;
  bool _isMapInteracting = false;
  bool _isSaving = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _showAdvanced = false;
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_syncCanSave);
    _contentController.addListener(_syncCanSave);
    _syncCanSave();
  }

  @override
  void dispose() {
    _titleController.removeListener(_syncCanSave);
    _contentController.removeListener(_syncCanSave);
    _titleController.dispose();
    _contentController.dispose();
    _subtitleController.dispose();
    _addressController.dispose();
    _hashtagsController.dispose();
    _photoPreview = null;
    _photoPreviewBytes = null;
    super.dispose();
  }

  void _syncCanSave() {
    final next = _canSaveNow();
    if (next == _canSave) return;
    setState(() => _canSave = next);
  }

  bool _canSaveNow() {
    final title = _titleController.text.trim();
    final description = _contentController.text.trim();
    final lat = _selectedLatitude;
    final lng = _selectedLongitude;
    final themeId = (widget.themeId ?? '').trim();
    return themeId.isNotEmpty &&
        title.isNotEmpty &&
        description.isNotEmpty &&
        lat != null &&
        lng != null;
  }


  Future<void> _savePlace() async {
    if (_isSaving) return;
    final themeId = (widget.themeId ?? '').trim();
    final title = _titleController.text.trim();
    final description = _contentController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final address = _addressController.text.trim();
    final imageId = _photoId;
    final hashtags = _parseHashtags(_hashtagsController.text);
    final lat = _selectedLatitude;
    final lng = _selectedLongitude;

    if (themeId.isEmpty) {
      _showSnack('테마를 찾을 수 없어요.');
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

    setState(() => _isSaving = true);
    try {
      var created = await ApiClient.createPlacebookPlace(
        themeId: themeId,
        title: title,
        description: description,
        subtitle: subtitle,
        address: address,
        latitude: lat,
        longitude: lng,
        imageId: imageId,
        hashtags: hashtags,
      );
      if (imageId != null && imageId.isNotEmpty) {
        final id = created['id']?.toString() ?? '';
        if (id.isNotEmpty && !_hasImageUrl(created)) {
          created = await ApiClient.updatePlacebookPlace(
            placeId: id,
            title: title,
            description: description,
            subtitle: subtitle,
            address: address,
            latitude: lat,
            longitude: lng,
            imageId: imageId,
            hashtags: hashtags,
          );
        }
      }
      if (!mounted) return;
      _showSnack('저장 완료');
      Navigator.of(context).maybePop(created);
    } catch (e) {
      if (!mounted) return;
      _showSnack('저장에 실패했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _hasImageUrl(Map<String, dynamic> place) {
    final thumb = place['thumbnailUrl'] as String?;
    if (thumb != null && thumb.trim().isNotEmpty) return true;
    final image = place['imageUrl'] as String?;
    if (image != null && image.trim().isNotEmpty) return true;
    final imageIdRaw = place['imageId'];
    if (imageIdRaw is Map<String, dynamic>) {
      final url = imageIdRaw['cdnUrl'] as String? ??
          imageIdRaw['fileUrl'] as String? ??
          imageIdRaw['thumbnailUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) return true;
    }
    final imageRaw = place['image'];
    if (imageRaw is Map<String, dynamic>) {
      final url = imageRaw['cdnUrl'] as String? ??
          imageRaw['fileUrl'] as String? ??
          imageRaw['thumbnailUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) return true;
    }
    final thumbnailRaw = place['thumbnail'];
    if (thumbnailRaw is Map<String, dynamic>) {
      final url = thumbnailRaw['cdnUrl'] as String? ??
          thumbnailRaw['fileUrl'] as String? ??
          thumbnailRaw['thumbnailUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) return true;
    }
    return false;
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
    if (_isUploadingPhoto) return;
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
        });
        setState(() => _isUploadingPhoto = true);
        try {
          final webp = await MediaConversionService.toWebp(pickedFile);
          final id = await ApiClient.uploadPlacebookPlaceImage(webp);
          _photoId = id;
        } catch (e) {
          _showSnack('사진 업로드에 실패했어요.');
        } finally {
          if (mounted) setState(() => _isUploadingPhoto = false);
        }
      },
    );
  }

  void _handleMapCenterChanged(NLatLng center) {
    _selectedLatitude = center.latitude;
    _selectedLongitude = center.longitude;
    _syncCanSave();
  }


  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      physics: _isMapInteracting
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            widget.titleSpan,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          if (!_showMapStep)
          ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CommonRoundedButton(
                title: '맵에서 장소 가져오기',
                onTap: () {
                  setState(() => _showMapStep = true);
                  _syncCanSave();
                },
                height: 52,
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
                      key: widget.mapKey,
                      controller: _mapController,
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
                        offset: const Offset(24, 16),
                        child: _MapFloatingButton(
                          icon: Icons.add_a_photo,
                          onTap: _pickPhoto,
                          size: 28,
                          iconSize: 14,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _MapFloatingButton(
                        icon: Icons.my_location,
                        onTap: () => _mapController.moveToMyLocation(),
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
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
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
