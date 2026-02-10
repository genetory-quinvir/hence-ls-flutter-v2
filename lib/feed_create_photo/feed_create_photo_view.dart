import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_title_actionsheet.dart';

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
  AssetPathEntity? _currentAlbum;
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  bool _permissionDenied = false;

  static const int _pageSize = 60;
  static const int _maxSelection = 5;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 44,
              left: 16,
              right: 16,
            ),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  CommonInkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _selected.isNotEmpty
                          ? Colors.white
                          : const Color(0xFF9E9E9E),
                    ),
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
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                        childAspectRatio: 1,
                      ),
                      itemCount: _assets.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Container(
                            color: const Color(0xFF2F2F2F),
                            child: Center(
                              child: Icon(
                                PhosphorIconsRegular.camera,
                                color: Colors.white,
                                size: 28,
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
                                  color: Colors.black.withOpacity(0.25),
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
        ],
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
                color: Color(0xFF9E9E9E),
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
        if (bytes == null) {
          return Container(color: const Color(0xFF1F1F1F));
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
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
          color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
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
