import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/styles/app_shadows.dart';
import '../../common/widgets/common_inkwell.dart';

class PlacebookEmptyView extends StatelessWidget {
  const PlacebookEmptyView({
    super.key,
    required this.themeTitle,
    this.onTap,
  });

  final String themeTitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 72,
        child: AspectRatio(
          aspectRatio: 1,
          child: Transform.rotate(
            angle: _degreesToRadians(_rotationDegrees(themeTitle)),
            child: Container(
              decoration: ShapeDecoration(
                color: const Color(0xFFF7F7F7),
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: 12,
                    cornerSmoothing: 1,
                  ),
                  side: const BorderSide(color: Colors.white, width: 4),
                ),
                shadows: AppShadows.card,
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsBold.plus,
                  size: 28,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _rotationDegrees(String seed) {
    final value = seed.hashCode;
    final magnitude = 2 + (value.abs() % 4); // 2~5
    final sign = value.isEven ? 1 : -1;
    return magnitude * sign.toDouble();
  }

  double _degreesToRadians(double degrees) =>
      degrees * (3.141592653589793 / 180);
}
