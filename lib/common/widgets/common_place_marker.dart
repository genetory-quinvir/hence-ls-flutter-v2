import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hence_ls_flutter_v2/main.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../styles/app_shadows.dart';
import 'common_image_view.dart';

class CommonPlaceMarker extends StatelessWidget {
  const CommonPlaceMarker({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.title,
    this.size = 44,
    this.isFavorited = false,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final String? title;
  final double size;
  final bool isFavorited;

  @override
  Widget build(BuildContext context) {
    const borderWidth = 1.5;
    final marker = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const ShapeDecoration(
            color: Colors.white,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              side: BorderSide(color: Colors.white, width: borderWidth),
            ),
            shadows: AppShadows.card,
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
        ),
        if (isFavorited)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                PhosphorIconsFill.bookmarkSimple,
                size: 10,
                color: MyApp.primary200,
              ),
            ),
          ),
      ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4
                  ..color = Colors.white,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                height: 1.2,
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
