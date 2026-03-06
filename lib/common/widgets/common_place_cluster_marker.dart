import 'package:flutter/material.dart';

import 'common_place_marker.dart';

class CommonPlaceClusterMarker extends StatelessWidget {
  const CommonPlaceClusterMarker({
    super.key,
    required this.count,
    this.imageUrls = const [],
    this.title,
    this.size = 44,
  });

  static const double stackScale = 1.7;
  static double stackSizeFor(double size) => size * stackScale;
  static const Map<int, List<Offset>> _offsetsByCount = <int, List<Offset>>{
    1: [Offset(0, 0)],
    2: [Offset(0, 0), Offset(12, -10)],
    3: [Offset(0, 0), Offset(12, -12), Offset(-10, 12)],
    4: [Offset(0, 0), Offset(14, -12), Offset(-12, 12), Offset(-16, -6)],
    5: [Offset(0, 0), Offset(14, -12), Offset(-12, 12), Offset(-16, -6), Offset(10, 16)],
  };
  static Offset visualCenterOffset(int count) {
    final clamped = count.clamp(1, 5);
    final offsets = _offsetsByCount[clamped] ?? const [Offset.zero];
    double sumX = 0;
    double sumY = 0;
    for (final offset in offsets) {
      sumX += offset.dx;
      sumY += offset.dy;
    }
    return Offset(sumX / offsets.length, sumY / offsets.length);
  }

  final int count;
  final List<String?> imageUrls;
  final String? title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = (title?.trim().isNotEmpty ?? false) ? title!.trim() : '$count';
    final validImages = imageUrls
        .whereType<String>()
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    final clusterCount = count.clamp(1, 5);
    final imagesForStack = List<String>.generate(
      clusterCount,
      (index) => index < validImages.length ? validImages[index] : '',
    );
    final sizes = [
      size * 1.0,
      size * 0.9,
      size * 0.82,
      size * 0.74,
      size * 0.66,
    ];
    final offsetsByCount = _offsetsByCount;
    final anglesByCount = <int, List<double>>{
      1: const [0.0],
      2: const [0.0, 0.08],
      3: const [0.0, 0.1, -0.08],
      4: const [0.0, 0.12, -0.1, 0.08],
      5: const [0.0, 0.12, -0.1, 0.08, -0.06],
    };
    final offsets = offsetsByCount[clusterCount]!;
    final angles = anglesByCount[clusterCount]!;
    final stackSize = stackSizeFor(size);
    final centerOffset = visualCenterOffset(clusterCount);

    final leadSize = sizes[0];
    return SizedBox(
      width: stackSize,
      height: stackSize,
      child: Transform.translate(
        offset: Offset(-centerOffset.dx, -centerOffset.dy),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            for (var i = clusterCount - 1; i >= 0; i--)
              Transform.translate(
                offset: offsets[i],
                child: Transform.rotate(
                  angle: angles[i],
                  child: CommonPlaceMarker(
                    imageUrl:
                        imagesForStack[i].isNotEmpty ? imagesForStack[i] : null,
                    size: sizes[i],
                  ),
                ),
              ),
            Positioned(
              left: (stackSize - leadSize) / 2 + leadSize - 14,
              top: (stackSize - leadSize) / 2 - 8,
              child: _ClusterCountBadge(label: label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterCountBadge extends StatelessWidget {
  const _ClusterCountBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final isSingle = label.length <= 1;
    return Container(
      width: isSingle ? 24 : null,
      height: 24,
      padding: isSingle
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
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
