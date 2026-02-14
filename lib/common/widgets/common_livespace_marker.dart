import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'common_image_view.dart';

class CommonLivespaceMarker extends StatelessWidget {
  const CommonLivespaceMarker({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.size = 44,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    const borderWidth = 1.0;
    final hasMemory = imageBytes != null && imageBytes!.isNotEmpty;
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final hasThumbnail = hasMemory || hasUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Padding(
        padding: const EdgeInsets.all(borderWidth),
        child: ClipOval(
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
  }
}
