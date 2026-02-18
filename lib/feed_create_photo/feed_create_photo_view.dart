import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_title_actionsheet.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_activity.dart';
import '../common/media/media_picker_service.dart';
import '../common/permissions/media_permission_service.dart';
import '../feed_create_info/feed_create_info_view.dart';
import '../livespace_create/livespace_create_view.dart';

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
  final Map<String, Uint8List> _thumbCache = {};
  final ScrollController _gridController = ScrollController();
  AssetPathEntity? _currentAlbum;
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  bool _permissionDenied = false;
  _CreateMode _createMode = _CreateMode.feed;
  bool _isNavigating = false;

  static const int _pageSize = 60;
  static const int _maxSelection = 5;

  Future<void> _goNext() async {
    if (_selected.isEmpty) return;
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    await Future.delayed(const Duration(milliseconds: 16));
    final initialThumbs = <String, Uint8List>{};
    for (final asset in _selected) {
      final bytes = _thumbCache[asset.id];
      if (bytes != null) {
        initialThumbs[asset.id] = bytes;
      }
    }
    Navigator.of(context)
        .push(
      CupertinoPageRoute(
        builder: (_) => FeedCreateInfoView(
          selectedAssets: List.of(_selected),
          isFeedMode: _createMode == _CreateMode.feed,
          initialThumbnailBytes: initialThumbs,
        ),
      ),
    )
        .whenComplete(() {
      if (mounted) setState(() => _isNavigating = false);
    });
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
    _prefetchThumb(asset);
  }

  Future<void> _prefetchThumb(AssetEntity asset) async {
    if (_thumbCache.containsKey(asset.id)) return;
    final bytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize(400, 400),
    );
    if (!mounted || bytes == null) return;
    _thumbCache[asset.id] = bytes;
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
    final isFeed = _createMode == _CreateMode.feed;
    final backgroundColor = isFeed ? Colors.black : Colors.white;
    final primaryTextColor = isFeed ? Colors.white : Colors.black;
    final secondaryTextColor =
        isFeed ? const Color(0xFFBDBDBD) : const Color(0xFF8E8E8E);
    final segmentBackground =
        isFeed ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
    final segmentThumb = isFeed ? Colors.white : Colors.black;
    final segmentTextColor = isFeed ? Colors.white : Colors.black;
    final segmentSelectedTextColor = isFeed ? Colors.black : Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isFeed ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          color: backgroundColor,
          child: Column(
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
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: segmentBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: CupertinoSlidingSegmentedControl<_CreateMode>(
                        groupValue: _createMode,
                        backgroundColor: Colors.transparent,
                        thumbColor: segmentThumb,
                        onValueChanged: (value) {
                          if (value == null) return;
                          setState(() => _createMode = value);
                        },
                        children: {
                          _CreateMode.feed: Padding(
                            padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _createMode == _CreateMode.feed
                                    ? segmentSelectedTextColor
                                    : segmentTextColor,
                              ),
                              child: const Text('피드'),
                            ),
                          ),
                          _CreateMode.livespace: Padding(
                            padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _createMode == _CreateMode.livespace
                                    ? segmentSelectedTextColor
                                    : segmentTextColor,
                              ),
                              child: const Text('라이브스페이스'),
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CommonInkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.close,
                          key: ValueKey(primaryTextColor),
                          color: primaryTextColor,
                          size: 24,
                        ),
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
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                        child: Text(_currentAlbum?.name ?? 'Recents'),
                      ),
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          key: ValueKey(primaryTextColor),
                          color: primaryTextColor,
                          size: 20,
                        ),
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
                    isFeedMode: isFeed,
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
                      cacheExtent: 600,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
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
                              color: isFeed
                                  ? const Color(0xFF1E1E1E)
                                  : const Color(0xFFF2F2F2),
                              child: Center(
                                child: Icon(
                                  PhosphorIconsFill.camera,
                                  color: secondaryTextColor,
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
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _selected.isNotEmpty ? 1 : 0.5,
                child: CommonRoundedButton(
                  title: _selected.isNotEmpty
                      ? '다음 (${_selected.length})'
                      : '다음',
                  onTap: _selected.isNotEmpty ? _goNext : null,
                  height: 50,
                  radius: 12,
                  backgroundColor:
                      isFeed ? Colors.white : Colors.black,
                  textColor:
                      isFeed ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    ),
    );
  }
}

enum _CreateMode { feed, livespace }

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.onOpenSettings,
    required this.onRetry,
    required this.isFeedMode,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  final bool isFeedMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '사진 접근 권한이 필요합니다.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isFeedMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          CommonInkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFeedMode ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '설정에서 허용',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CommonInkWell(
            onTap: onRetry,
            child: Text(
              '다시 시도',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isFeedMode
                    ? const Color(0xFFBDBDBD)
                    : const Color(0xFF8E8E8E),
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
