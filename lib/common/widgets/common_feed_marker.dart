import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';

import 'common_image_view.dart';

class CommonFeedMarker extends StatelessWidget {
  const CommonFeedMarker({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.width = 44,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    const double borderWidth = 2;
    final height = width * 5 / 4;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
          cornerRadius: 8 - borderWidth,
          cornerSmoothing: 1,
        ),
        child: CommonImageView(
          memoryBytes: imageBytes,
          networkUrl: imageUrl,
          fit: BoxFit.cover,
          backgroundColor: const Color(0xFFF2F2F2),
          placeholderLogoSize: 14,
        ),
      ),
    );
  }
}
