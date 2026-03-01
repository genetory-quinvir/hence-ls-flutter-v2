import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class CommonPlaceClusterMarker extends StatelessWidget {
  const CommonPlaceClusterMarker({
    super.key,
    required this.count,
    this.imageUrl,
    this.title,
    this.size = 44,
  });

  final int count;
  final String? imageUrl;
  final String? title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = (title?.trim().isNotEmpty ?? false) ? title!.trim() : '$count';
    const borderWidth = 2.0;
    final effectiveSize = size * 1.2;
    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: Container(
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
        child: Center(
          child: Stack(
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
                    ..strokeWidth = 2
                    ..color = Colors.black,
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
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
