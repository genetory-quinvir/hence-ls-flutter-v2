import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:hence_ls_flutter_v2/main.dart';

import '../styles/app_shadows.dart';
import 'common_image_view.dart';
import 'common_inkwell.dart';

class CommonPlaceCarouselListItemView extends StatelessWidget {
  const CommonPlaceCarouselListItemView({
    super.key,
    required this.thumbnailUrl,
    required this.title,
    required this.address,
    required this.commentCount,
    required this.likeCount,
    this.themeText,
    this.distanceText,
    this.favorited = false,
    this.onTap,
    this.height = 128,
  });

  final String thumbnailUrl;
  final String title;
  final String address;
  final int commentCount;
  final int likeCount;
  final String? themeText;
  final String? distanceText;
  final bool favorited;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? '장소' : title.trim();
    final safeAddress =
        address.trim().isEmpty ? '장소 등록 안됨' : address.trim();
    final safeTheme = themeText?.trim() ?? '';
    final hasTheme = safeTheme.isNotEmpty;
    final rotationDegrees = _thumbnailRotationDegrees(safeTitle, safeAddress);
    const metaStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFF757575),
    );

    return CommonInkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Container(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: 18,
                cornerSmoothing: 1,
              ),
            ),
            shadows: AppShadows.card,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 24),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Transform.rotate(
                    angle: _degreesToRadians(rotationDegrees),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: ShapeDecoration(
                            shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                cornerRadius: 12,
                                cornerSmoothing: 1,
                              ),
                              side: const BorderSide(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            shadows: AppShadows.card,
                          ),
                          child: ClipSmoothRect(
                            radius: SmoothBorderRadius(
                              cornerRadius: 8,
                              cornerSmoothing: 1,
                            ),
                            child: CommonImageView(
                              networkUrl: thumbnailUrl,
                              cacheKey: thumbnailUrl,
                              fit: BoxFit.cover,
                              backgroundColor: const Color(0xFFF2F2F2),
                              memCacheWidth: 96,
                              memCacheHeight: 96,
                              replayNetworkFade: false,
                              enableFade: true,
                              disableFadeAfterFirstLoad: true,
                              preferFadeOverMemoryCache: false,
                            ),
                          ),
                        ),
                        if (favorited)
                          Positioned(
                            top: -6,
                            right: -6,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                PhosphorIconsFill.bookmarkSimple,
                                size: 12,
                                color: MyApp.primary200,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (hasTheme)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            safeTheme,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          safeAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (distanceText != null && distanceText!.isNotEmpty)
                            Text(
                              '~ ${distanceText!}',
                              style: metaStyle,
                            ),
                          if (distanceText != null && distanceText!.isNotEmpty)
                            const SizedBox(width: 12),
                          const Icon(
                            PhosphorIconsBold.chatCircle,
                            size: 15,
                            color: Color(0xFF757575),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$commentCount',
                            style: metaStyle,
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            PhosphorIconsBold.sealCheck,
                            size: 15,
                            color: Color(0xFF757575),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount',
                            style: metaStyle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _thumbnailRotationDegrees(String title, String address) {
    final seed = title.hashCode ^ address.hashCode;
    final magnitude = 2 + (seed.abs() % 4); // 2~5
    final sign = seed.isEven ? 1 : -1;
    return magnitude * sign.toDouble();
  }

  double _degreesToRadians(double degrees) =>
      degrees * (3.141592653589793 / 180);
}
