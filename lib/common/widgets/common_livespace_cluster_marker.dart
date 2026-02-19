import 'package:flutter/material.dart';

import 'common_image_view.dart';

class CommonLiveClusterMarker extends StatelessWidget {
  const CommonLiveClusterMarker({
    super.key,
    required this.count,
    this.imageUrl,
    this.size = 44,
  });

  final int count;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    const borderWidth = 2.0;
    final hasLeft = count >= 2;
    final hasRight = count >= 3;

    Widget markerCircle({
      required double angle,
      required Offset offset,
      double scale = 1,
    }) {
      final circleSize = size * scale;
      return Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: borderWidth),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: CommonImageView(
                networkUrl: imageUrl,
                fit: BoxFit.cover,
                backgroundColor: const Color(0xFF2A2A2A),
                placeholderLogoSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasLeft)
            markerCircle(
              angle: -0.22,
              offset: Offset(-size * 0.22, size * 0.04),
              scale: 0.9,
            ),
          if (hasRight)
            markerCircle(
              angle: 0.22,
              offset: Offset(size * 0.22, size * 0.04),
              scale: 0.9,
            ),
          markerCircle(
            angle: 0,
            offset: Offset.zero,
          ),
        ],
      ),
    );
  }
}
