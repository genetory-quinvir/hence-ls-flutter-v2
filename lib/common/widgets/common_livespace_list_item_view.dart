import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../utils/time_format.dart';
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
    String relativeDate(String raw) {
      if (raw.isEmpty) return raw;
      final direct = formatRelativeTime(raw);
      if (direct != raw) return direct;
      final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
      return formatRelativeTime(normalized);
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  height: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                PhosphorIconsRegular.clock,
                                size: 15,
                                color: Color(0xFF757575),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                relativeDate(dateText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF616161),
                                ),
                              ),
                              if (placeName.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  PhosphorIconsRegular.mapPin,
                                  size: 15,
                                  color: Color(0xFF757575),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    placeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (distanceText != null && distanceText!.isNotEmpty) ...[
                                Text(
                                  '~ ${distanceText!}',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF616161),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
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
                                  fontSize: 13,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF616161),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
