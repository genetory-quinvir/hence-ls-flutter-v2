import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommonImageView extends StatelessWidget {
  const CommonImageView({
    super.key,
    this.networkUrl,
    this.assetPath,
    this.fit = BoxFit.contain,
    this.blurSigma = 8,
    this.backgroundColor = const Color(0xFFF2F2F2),
  });

  final String? networkUrl;
  final String? assetPath;
  final BoxFit fit;
  final double blurSigma;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (image == null) return _placeholder();

    return Container(
      color: backgroundColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: image,
      ),
    );
  }

  Widget? _buildImage() {
    if (networkUrl != null && networkUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
        placeholderFadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    if (assetPath != null && assetPath!.trim().isNotEmpty) {
      return Image.asset(
        assetPath!,
        key: ValueKey(assetPath),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return null;
  }

  Widget _placeholder() {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'lib/assets/images/icon_logo.svg',
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          const Color(0xFF9E9E9E),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
