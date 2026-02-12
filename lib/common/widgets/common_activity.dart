import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';

class CommonActivityIndicator extends StatelessWidget {
  const CommonActivityIndicator({
    super.key,
    this.size = 40,
    this.color = Colors.black,
    this.strokeWidth = 4,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(
        indicatorType: Indicator.circleStrokeSpin,
        colors: [color],
        strokeWidth: strokeWidth,
      ),
    );
  }
}
