import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CommonImageView extends StatelessWidget {
  const CommonImageView({
    super.key,
    this.networkUrl,
    this.assetPath,
    this.fit = BoxFit.contain,
    this.blurSigma = 8,
  });

  final String? networkUrl;
  final String? assetPath;
  final BoxFit fit;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (image == null) return _placeholder();

    return Container(
      color: Colors.black,
      child: image,
    );
  }

  Widget? _buildImage() {
    if (networkUrl != null && networkUrl!.trim().isNotEmpty) {
      return Image.network(
        networkUrl!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (assetPath != null && assetPath!.trim().isNotEmpty) {
      return Image.asset(
        assetPath!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return null;
  }

  Widget _placeholder() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'lib/assets/images/icon_logo.svg',
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
