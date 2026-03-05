import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_image_view.dart';
import 'common_inkwell.dart';

class CommonPlaceListItemView extends StatelessWidget {
  const CommonPlaceListItemView({
    super.key,
    required this.thumbnailUrl,
    required this.title,
    required this.address,
    required this.commentCount,
    required this.likeCount,
    this.categoryText,
    this.themeText,
    this.distanceText,
    this.onTap,
  });

  final String thumbnailUrl;
  final String title;
  final String address;
  final int commentCount;
  final int likeCount;
  final String? categoryText;
  final String? themeText;
  final String? distanceText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? '장소' : title.trim();
    final safeAddress = address.trim();
    final safeCategory = categoryText?.trim() ?? '';
    final safeTheme = themeText?.trim() ?? '';
    final hasMetaLine = safeCategory.isNotEmpty || safeTheme.isNotEmpty;
    const metaStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFF757575),
    );
    return CommonInkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipSmoothRect(
              radius: SmoothBorderRadius(
                cornerRadius: 12,
                cornerSmoothing: 1,
              ),
              child: SizedBox(
                width: 72,
                height: 72,
                child: CommonImageView(
                  networkUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  backgroundColor: const Color(0xFFF2F2F2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                  if (hasMetaLine)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        safeCategory.isNotEmpty && safeTheme.isNotEmpty
                            ? '$safeCategory · $safeTheme'
                            : (safeCategory.isNotEmpty ? safeCategory : safeTheme),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                  if (safeAddress.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        safeAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                  const SizedBox(height: 6),
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
                        PhosphorIconsRegular.chatCircle,
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
                        PhosphorIconsRegular.heart,
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
          ],
        ),
      ),
    );
  }
}
