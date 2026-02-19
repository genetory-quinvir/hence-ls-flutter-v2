import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../feed_list/models/feed_models.dart';
import '../utils/time_format.dart';
import 'common_image_view.dart';
import 'common_inkwell.dart';

class CommonFeedListItemView extends StatelessWidget {
  const CommonFeedListItemView({
    super.key,
    required this.feed,
    this.distanceText,
    this.onTap,
  });

  final Feed feed;
  final String? distanceText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = feed.images.isNotEmpty ? feed.images.first : null;
    final imageUrl = image?.thumbnailUrl ?? image?.cdnUrl ?? image?.fileUrl;
    final createdAt = formatRelativeTime(feed.createdAt);
    final placeName = feed.placeName.isNotEmpty
        ? feed.placeName
        : (feed.space?.placeName ?? feed.address);
    final content = feed.content.trim().isEmpty ? '피드' : feed.content.trim();

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
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CommonImageView(
                        networkUrl: imageUrl,
                        fit: BoxFit.cover,
                        backgroundColor: const Color(0xFFF2F2F2),
                      ),
                    ),
                  ],
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
                        content,
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
                                createdAt,
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
                                '${feed.commentCount}',
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
                                '${feed.likeCount}',
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
