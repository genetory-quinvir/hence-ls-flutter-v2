import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_image_view.dart';
import 'common_inkwell.dart';

class CommonLivespaceListItemView extends StatelessWidget {
  const CommonLivespaceListItemView({
    super.key,
    required this.thumbnailUrl,
    required this.title,
    required this.dateText,
    required this.placeName,
    required this.commentCount,
    required this.likeCount,
    this.distanceText,
    this.onTap,
  });

  final String thumbnailUrl;
  final String title;
  final String dateText;
  final String placeName;
  final int commentCount;
  final int likeCount;
  final String? distanceText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String normalizeDate(String raw) {
      if (raw.isEmpty) return raw;
      final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (parsed == null) return raw;
      final yyyy = parsed.year.toString().padLeft(4, '0');
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      return '$yyyy. $mm. $dd';
    }
    return CommonInkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipSmoothRect(
              radius: SmoothBorderRadius(
                cornerRadius: 10,
                cornerSmoothing: 1,
              ),
              child: SizedBox(
                width: 72,
                height: 90,
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    normalizeDate(dateText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.mapPin,
                        size: 13,
                        color: Color(0xFF757575),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (distanceText != null && distanceText!.isNotEmpty) ...[
                        // const Icon(
                        //   PhosphorIconsFill.mapPin,
                        //   size: 13,
                        //   color: Color(0xFF757575),
                        // ),
                        // const SizedBox(width: 4),
                        Text(
                          '~ ${distanceText!}',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF616161),
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(
                        PhosphorIconsRegular.chatCircle,
                        size: 15,
                        color: Color(0xFF757575),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$commentCount',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF616161),
                        ),
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
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF616161),
                        ),
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
