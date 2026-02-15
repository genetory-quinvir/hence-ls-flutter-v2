import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_image_view.dart';

class CommonProfileView extends StatelessWidget {
  const CommonProfileView({
    super.key,
    this.networkUrl,
    this.assetPath,
    this.size = 56,
    this.placeholder,
  });

  final String? networkUrl;
  final String? assetPath;
  final double size;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final hasImage = (networkUrl != null && networkUrl!.trim().isNotEmpty) ||
        (assetPath != null && assetPath!.trim().isNotEmpty);
    return SizedBox(
      width: size,
      height: size,
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
          cornerRadius: size * 0.34,
          cornerSmoothing: 1,
        ),
        child: !hasImage
            ? (placeholder ??
                const ColoredBox(
                  color: Color(0xFFF2F2F2),
                  child: Center(
                    child: Icon(
                      PhosphorIconsFill.user,
                      size: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ))
            : CommonImageView(
                networkUrl: networkUrl,
                assetPath: assetPath,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
