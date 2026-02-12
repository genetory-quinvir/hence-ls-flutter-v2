import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'common_image_view.dart';

class CommonFeedMarker extends StatelessWidget {
  const CommonFeedMarker({
    super.key,
    required this.imageBytes,
    this.width = 44,
  });

  final Uint8List imageBytes;
  final double width;

  @override
  Widget build(BuildContext context) {
    const double outerRadius = 6;
    const double borderWidth = 2;
    final height = width * 5 / 4;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerRadius - borderWidth),
        child: CommonImageView(
          memoryBytes: imageBytes,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
