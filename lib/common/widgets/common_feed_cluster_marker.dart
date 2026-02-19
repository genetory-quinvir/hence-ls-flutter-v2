import 'package:flutter/material.dart';

import 'common_image_view.dart';

class CommonFeedClusterMarker extends StatelessWidget {
  const CommonFeedClusterMarker({
    super.key,
    required this.count,
    this.imageUrl,
    this.width = 30,
  });

  final int count;
  final String? imageUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    const double outerRadius = 10;
    const double borderWidth = 2;
    final height = width * 5 / 4;
    final hasLeft = count >= 2;
    final hasRight = count >= 3;

    Widget markerCard({
      required double angle,
      required Offset offset,
      required bool isFront,
      double scale = 1,
    }) {
      final cardWidth = width * scale;
      final cardHeight = height * scale;
      return Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(color: Colors.white, width: borderWidth),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CommonImageView(
                    networkUrl: imageUrl,
                    fit: BoxFit.cover,
                    backgroundColor: const Color(0xFF2A2A2A),
                    placeholderLogoSize: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasLeft)
            markerCard(
              angle: -0.24,
              offset: Offset(-width * 0.22, height * 0.04),
              isFront: false,
              scale: 0.9,
            ),
          if (hasRight)
            markerCard(
              angle: 0.24,
              offset: Offset(width * 0.22, height * 0.04),
              isFront: false,
              scale: 0.9,
            ),
          markerCard(
            angle: 0,
            offset: Offset.zero,
            isFront: true,
          ),
        ],
      ),
    );
  }
}
