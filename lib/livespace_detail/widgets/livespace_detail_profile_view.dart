import 'package:flutter/material.dart';
import '../../common/widgets/common_image_view.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../../common/widgets/common_profile_view.dart';

class LivespaceDetailProfileView extends StatelessWidget {
  const LivespaceDetailProfileView({
    super.key,
    required this.title,
    required this.thumbnailUrl,
  });

  final String title;
  final String thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _HeaderSection.defaultHeight + _HeaderSection.titleBlockHeight;
        final extra = (totalHeight -
                (_HeaderSection.defaultHeight + _HeaderSection.titleBlockHeight))
            .clamp(0.0, double.infinity)
            .toDouble();
        final headerHeight = _HeaderSection.defaultHeight + extra;
        final imageHeight = (headerHeight -
                _HeaderSection.bottomPadding -
                _HeaderSection.overlap)
            .clamp(0.0, headerHeight)
            .toDouble();
        return SizedBox(
          height: totalHeight,
          child: Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: _HeaderSection(
                  thumbnailUrl: thumbnailUrl,
                  imageHeight: imageHeight,
                  totalHeight: headerHeight,
                ),
              ),
              SizedBox(
                height: _HeaderSection.titleBlockHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.thumbnailUrl,
    required this.imageHeight,
    required this.totalHeight,
  });

  final String thumbnailUrl;
  final double imageHeight;
  final double totalHeight;

  static const double overlap = 25;
  static const double bottomPadding = 12;
  static const double defaultHeight = 317;
  static const double titleBlockHeight = 48;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: CommonImageView(
              networkUrl: thumbnailUrl,
              fit: BoxFit.cover,
              backgroundColor: const Color(0xFFF2F2F2),
            ),
          ),
          Positioned(
            bottom: bottomPadding,
            left: 64,
            right: 64,
            child: Container(
              height: 50,
              padding: const EdgeInsets.only(left: 12, right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28 + (28 - 10) * 2,
                    height: 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: const [
                        _OverlayProfileDot(index: 0),
                        _OverlayProfileDot(index: 1),
                        _OverlayProfileDot(index: 2),
                      ],
                    ),
                  ),
                  SizedBox(width: 4),
                  const Text(
                    '+3명',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF616161),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '체크인',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayProfileDot extends StatelessWidget {
  const _OverlayProfileDot({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const double size = 28;
    const double overlap = 10;
    return Positioned(
      left: index * (size - overlap),
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
          cornerRadius: size * 0.34,
          cornerSmoothing: 1,
        ),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(2),
          child: ClipSmoothRect(
            radius: SmoothBorderRadius(
              cornerRadius: (size - 4) * 0.34,
              cornerSmoothing: 1,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              child: const CommonProfileView(
                size: size - 4,
                placeholder: ColoredBox(
                  color: const Color(0xFFF2F2F2),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
