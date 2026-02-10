import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';

class CommonActivityIndicator extends StatelessWidget {
  const CommonActivityIndicator({
    super.key,
    this.size = 40,
    this.color = Colors.black,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(
        indicatorType: Indicator.circleStrokeSpin,
        colors: [color],
      ),
    );
  }
}
