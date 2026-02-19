import 'dart:io';

import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_image_view.dart';

class CommonProfileImageView extends StatelessWidget {
  const CommonProfileImageView({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.size = 120,
    this.backgroundColor = const Color(0xFFFAFAFA),
    this.useSquircle = false,
    this.squircleCornerRadius,
    this.placeholderIconSize,
  });

  final File? imageFile;
  final String? imageUrl;
  final double size;
  final Color backgroundColor;
  final bool useSquircle;
  final double? squircleCornerRadius;
  final double? placeholderIconSize;

  @override
  Widget build(BuildContext context) {
    final hasFile = imageFile != null;
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final Widget child = hasFile
        ? Image.file(
            imageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : hasUrl
            ? SizedBox.expand(
                child: CommonImageView(
                  networkUrl: imageUrl,
                  fit: BoxFit.cover,
                  backgroundColor: backgroundColor,
                ),
              )
            : Container(
                color: backgroundColor,
                alignment: Alignment.center,
                child: Icon(
                  PhosphorIconsRegular.user,
                  size: placeholderIconSize ?? (size * 0.45),
                  color: Color(0xFF9E9E9E),
                ),
              );

    final String keyValue = hasFile
        ? 'file_${imageFile!.path}'
        : hasUrl
            ? 'url_$imageUrl'
            : 'empty';

    return SizedBox(
      width: size,
      height: size,
      child: (useSquircle
          ? ClipSmoothRect(
              radius: SmoothBorderRadius(
                cornerRadius: squircleCornerRadius ?? (size * 0.34),
                cornerSmoothing: 1,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (widget, animation) => FadeTransition(
                  opacity: animation,
                  child: widget,
                ),
                child: KeyedSubtree(
                  key: ValueKey<String>(keyValue),
                  child: SizedBox.expand(child: child),
                ),
              ),
            )
          : ClipOval(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (widget, animation) => FadeTransition(
                  opacity: animation,
                  child: widget,
                ),
                child: KeyedSubtree(
                  key: ValueKey<String>(keyValue),
                  child: SizedBox.expand(child: child),
                ),
              ),
            )),
    );
  }
}
