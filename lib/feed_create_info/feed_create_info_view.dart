import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../common/widgets/common_inkwell.dart';

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
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    CommonInkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '선택 ${widget.selectedAssets.length}장',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                childAspectRatio: 1,
              ),
              itemCount: widget.selectedAssets.length,
              itemBuilder: (context, index) {
                final asset = widget.selectedAssets[index];
                return _AssetThumbnail(asset: asset);
              },
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
      future: asset.thumbnailDataWithSize(const ThumbnailSize(600, 600)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(color: const Color(0xFFE0E0E0));
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
