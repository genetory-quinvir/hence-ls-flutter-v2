import 'package:flutter/material.dart';

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
      child: ClipOval(
        child: !hasImage && placeholder != null
            ? placeholder
            : CommonImageView(
                networkUrl: networkUrl,
                assetPath: assetPath,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
