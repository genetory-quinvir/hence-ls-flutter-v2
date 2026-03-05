import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'common_image_view.dart';

class CommonPlaceMarker extends StatelessWidget {
  const CommonPlaceMarker({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.title,
    this.size = 44,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final String? title;
  final double size;

  @override
  Widget build(BuildContext context) {
    const borderWidth = 1.5;
    final marker = Container(
      width: size,
      height: size,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: Colors.white, width: borderWidth),
        ),
        shadows: [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(borderWidth),
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: CommonImageView(
            memoryBytes: imageBytes,
            networkUrl: imageUrl,
            fit: BoxFit.cover,
            backgroundColor: const Color(0xFFF2F2F2),
            placeholderLogoSize: 14,
          ),
        ),
      ),
    );
    final label = title?.trim() ?? '';
    if (label.isEmpty) return marker;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4
                  ..color = Colors.white,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
