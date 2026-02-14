import 'package:flutter/material.dart';

class CommonDotMarker extends StatelessWidget {
  const CommonDotMarker({
    super.key,
    this.size = 12,
    this.borderWidth = 2,
  });

  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: borderWidth,
          ),
        ),
      ),
    );
  }
}
