import 'package:flutter/material.dart';

import 'common_image_view.dart';

class CommonProfileView extends StatelessWidget {
  const CommonProfileView({
    super.key,
    this.networkUrl,
    this.assetPath,
    this.size = 56,
  });

  final String? networkUrl;
  final String? assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CommonImageView(
          networkUrl: networkUrl,
          assetPath: assetPath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

