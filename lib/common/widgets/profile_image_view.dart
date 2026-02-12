import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_image_view.dart';

class ProfileImageView extends StatelessWidget {
  const ProfileImageView({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.size = 120,
    this.backgroundColor = const Color(0xFFF2F2F2),
  });

  final File? imageFile;
  final String? imageUrl;
  final double size;
  final Color backgroundColor;

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
                child: const Icon(
                  PhosphorIconsRegular.user,
                  size: 52,
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
      child: ClipOval(
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
      ),
    );
  }
}
