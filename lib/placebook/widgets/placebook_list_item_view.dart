import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../../common/widgets/common_image_view.dart';
import '../../common/widgets/common_inkwell.dart';
import '../../common/widgets/common_rounded_button.dart';

class PlacebookListItemView extends StatelessWidget {
  const PlacebookListItemView({
    super.key,
    required this.title,
    required this.placeCount,
    this.thumbnails = const [],
    this.hasPlaces = false,
    this.onTap,
    this.onAddTap,
  });

  final String title;
  final int placeCount;
  final List<String> thumbnails;
  final bool hasPlaces;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? '테마' : title.trim();
    final safeCount = placeCount < 0 ? 0 : placeCount;
    final normalizedThumbs =
        thumbnails.map((url) => url.trim()).toList(growable: true);
    final desiredThumbs =
        hasPlaces ? math.min(3, safeCount) : 0;
    if (normalizedThumbs.length > desiredThumbs) {
      normalizedThumbs.length = desiredThumbs;
    } else if (normalizedThumbs.length < desiredThumbs) {
      normalizedThumbs.addAll(
        List.filled(desiredThumbs - normalizedThumbs.length, ''),
      );
    }
    final maxThumbs = normalizedThumbs;
    return CommonInkWell(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 160.0;
          final cardHeight =
              constraints.maxHeight.isFinite ? constraints.maxHeight : 124.0;
          final thumbSize = width * 0.32;
          final thumbOverlap = thumbSize * 0.5;
          final thumbTop = -thumbSize * 0.65;
          return SizedBox(
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (maxThumbs.isNotEmpty)
                  for (var i = 0; i < maxThumbs.length; i++)
                    Positioned(
                      left: 14 + (thumbOverlap * i),
                      top: thumbTop + (i % 2 == 0 ? 0 : 6),
                      child: _ThumbnailPeek(
                        url: maxThumbs[i],
                        size: thumbSize,
                        rotationDegrees: i.isEven ? -3.5 : 3.0,
                      ),
                    ),
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                safeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$safeCount개의 장소',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CommonRoundedButton(
                          title: '장소 추가하기',
                          onTap: onAddTap,
                          height: 32,
                          radius: 8,
                          backgroundColor: Colors.grey.shade200,
                          textColor: Colors.black,
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ThumbnailPeek extends StatelessWidget {
  const _ThumbnailPeek({
    required this.url,
    required this.size,
    required this.rotationDegrees,
  });

  final String url;
  final double size;
  final double rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
          cornerRadius: 10,
          cornerSmoothing: 1,
        ),
        child: CommonImageView(
          networkUrl: url,
          fit: BoxFit.cover,
          backgroundColor: const Color(0xFFF2F2F2),
        ),
      ),
    );
    return Transform.rotate(
      angle: rotationDegrees * (3.141592653589793 / 180),
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 0.66,
          child: content,
        ),
      ),
    );
  }
}
