import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_title_actionsheet.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/media/media_picker_service.dart';
import '../common/permissions/media_permission_service.dart';
import '../common/location/naver_location_service.dart';
import '../feed_create_info/feed_create_info_view.dart';

class FeedCreatePhotoView extends StatefulWidget {
  const FeedCreatePhotoView({super.key});

  @override
  State<FeedCreatePhotoView> createState() => _FeedCreatePhotoViewState();
}

class _FeedCreatePhotoViewState extends State<FeedCreatePhotoView> {
  final List<AssetEntity> _assets = [];
  final List<AssetPathEntity> _albums = [];
  final Map<String, int> _albumCounts = {};
  final List<AssetEntity> _selected = [];
  final ScrollController _gridController = ScrollController();
  AssetPathEntity? _currentAlbum;
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  bool _permissionDenied = false;

  static const int _pageSize = 60;
  static const int _maxSelection = 5;

  Future<void> _goNext() async {
    if (_selected.isEmpty) return;
    final place = await _resolveSelectedPlace();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedCreateInfoView(
          selectedAssets: List.of(_selected),
          initialPlaceName: place?.name,
          initialLatitude: place?.lat,
          initialLongitude: place?.lng,
        ),
      ),
    );
  }

  Future<({String name, double lat, double lng})?> _resolveSelectedPlace() async {
    if (_selected.isEmpty) return null;
    final asset = _selected.first;
    final latLng = await asset.latlngAsync();
    if (latLng == null) return null;
    final place = await NaverLocationService.reverseGeocode(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
    if (place == null || place.trim().isEmpty) return null;
    return (name: place.trim(), lat: latLng.latitude, lng: latLng.longitude);
  }

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbum() async {
    setState(() => _isLoading = true);
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.isLimited) {
      setState(() {
        _assets.clear();
        _isLoading = false;
        _hasMore = false;
        _permissionDenied = true;
      });
      return;
    }
    _permissionDenied = false;

    final albums = await PhotoManager.getAssetPathList(
      onlyAll: false,
      type: RequestType.image,
    );
    if (albums.isEmpty) {
      setState(() {
        _assets.clear();
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }
    _albums
      ..clear()
      ..addAll(albums);
    _albumCounts.clear();
    for (final album in albums) {
      _albumCounts[album.id] = await album.assetCountAsync;
    }
    _currentAlbum = albums.first;
    _page = 0;
    _assets.clear();
    _selected.clear();
    _hasMore = true;
    await _loadMore();
  }

  Future<void> _openAlbumSheet() async {
    if (_albums.isEmpty) return;
    final items = _albums
        .map(
          (album) => CommonTitleActionSheetItem(
            label: _albumCounts.containsKey(album.id)
                ? '${album.name} (${_albumCounts[album.id]})'
                : album.name,
            value: album.id,
          ),
        )
        .toList();
    await CommonTitleActionSheet.show(
      context,
      title: '앨범 선택',
      items: items,
      onSelected: (item) {
        final selected = _albums.firstWhere(
          (album) => album.id == item.value,
          orElse: () => _albums.first,
        );
        _selectAlbum(selected);
      },
    );
  }

  Future<void> _selectAlbum(AssetPathEntity album) async {
    setState(() {
      _currentAlbum = album;
      _page = 0;
      _assets.clear();
      _selected.clear();
      _hasMore = true;
      _isLoading = true;
    });
    await _loadMore();
  }

  void _toggleSelect(AssetEntity asset) {
    setState(() {
      final existingIndex = _selected.indexWhere((item) => item.id == asset.id);
      if (existingIndex >= 0) {
        _selected.removeAt(existingIndex);
        return;
      }
      if (_selected.length >= _maxSelection) return;
      _selected.add(asset);
    });
  }

  Future<void> _loadMore() async {
    if (_currentAlbum == null || !_hasMore) return;
    final items = await _currentAlbum!.getAssetListPaged(
      page: _page,
      size: _pageSize,
    );
    if (items.isEmpty) {
      _hasMore = false;
    } else {
      _assets.addAll(items);
      _page += 1;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openCamera() async {
    if (!await MediaPermissionService.ensureCamera()) {
      _showSnack('카메라 권한이 필요합니다.');
      return;
    }
    final picked = await MediaPickerService.pickFromCamera();
    if (picked == null) return;
    final asset = await PhotoManager.editor.saveImageWithPath(picked.path);
    if (!mounted) return;
    if (asset == null) {
      _showSnack('촬영한 사진을 불러올 수 없습니다.');
      return;
    }
    setState(() {
      if (_assets.every((item) => item.id != asset.id)) {
        _assets.insert(0, asset);
      }
      if (_selected.length < _maxSelection &&
          _selected.every((item) => item.id != asset.id)) {
        _selected.add(asset);
      }
    });
    if (_gridController.hasClients) {
      _gridController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 44,
              left: 8,
              right: 8,
            ),
            child: SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text(
                      '사진 선택',
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
                        Icons.close,
                        color: Colors.white,
                        size: 24,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CommonInkWell(
                  onTap: _openAlbumSheet,
                  child: Row(
                    children: [
                      Text(
                        _currentAlbum?.name ?? 'Recents',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _permissionDenied
                ? _PermissionDeniedView(
                    onOpenSettings: PhotoManager.openSetting,
                    onRetry: _loadAlbum,
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (!_isLoading &&
                          _hasMore &&
                          notification.metrics.extentAfter == 0) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: GridView.builder(
                      controller: _gridController,
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                        childAspectRatio: 4 / 5,
                      ),
                      itemCount: _assets.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return CommonInkWell(
                            onTap: _openCamera,
                            child: Container(
                              color: const Color(0xFF1E1E1E),
                              child: Center(
                                child: Icon(
                                  PhosphorIconsFill.camera,
                                  color: const Color(0xFFBDBDBD),
                                  size: 28,
                                ),
                              ),
                            ),
                          );
                        }
                        final asset = _assets[index - 1];
                        final selectedIndex = _selected
                            .indexWhere((item) => item.id == asset.id);
                        final isSelected = selectedIndex >= 0;
                        return CommonInkWell(
                          onTap: () => _toggleSelect(asset),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _AssetThumbnail(asset: asset),
                              if (isSelected)
                                Container(
                                  color: Colors.black.withOpacity(0.15),
                                ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: _SelectionBadge(
                                  index: isSelected ? selectedIndex + 1 : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Opacity(
                opacity: _selected.isNotEmpty ? 1 : 0.5,
                child: CommonRoundedButton(
                  title: _selected.isNotEmpty
                      ? '다음 (${_selected.length})'
                      : '다음',
                  onTap: _selected.isNotEmpty ? _goNext : null,
                  height: 50,
                  radius: 12,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.onOpenSettings,
    required this.onRetry,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '사진 접근 권한이 필요합니다.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          CommonInkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '설정에서 허용',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CommonInkWell(
            onTap: onRetry,
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFBDBDBD),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  const _AssetThumbnail({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(400, 400)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final Widget child = bytes == null
            ? Container(color: const Color(0xFF1E1E1E))
            : CommonImageView(
                memoryBytes: bytes,
                cacheKey: '${asset.id}_thumb',
                fit: BoxFit.cover,
              );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: child,
        );
      },
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({this.index});

  final int? index;

  @override
  Widget build(BuildContext context) {
    final isSelected = index != null;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.6),
          width: 1.5,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: isSelected
          ? Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            )
          : null,
    );
  }
}
