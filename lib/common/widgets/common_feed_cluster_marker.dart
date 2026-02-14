import 'package:flutter/material.dart';

class CommonFeedClusterMarker extends StatelessWidget {
  const CommonFeedClusterMarker({
    super.key,
    required this.count,
    this.width = 30,
  });

  final int count;
  final double width;

  @override
  Widget build(BuildContext context) {
    const double outerRadius = 8;
    const double borderWidth = 2;
    final height = width * 5 / 4;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
