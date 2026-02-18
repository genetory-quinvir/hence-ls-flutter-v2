import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../feed_list/models/feed_models.dart';
import '../utils/time_format.dart';
import 'common_image_view.dart';
import 'common_inkwell.dart';
import 'common_profile_modal.dart';
import '../../profile/models/profile_display_user.dart';

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
    final authorName =
        feed.author.nickname.isNotEmpty ? feed.author.nickname : feed.author.name;
    final createdAt = formatRelativeTime(feed.createdAt);
    final authorImageUrl = feed.author.profileImageUrl;
    final placeName = feed.space?.placeName ?? '';
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
                child: CommonImageView(
                  networkUrl: imageUrl,
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
                    content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CommonInkWell(
                        onTap: () {
                          if (feed.author.userId.isEmpty) return;
                          final displayUser = ProfileDisplayUser(
                            id: feed.author.userId,
                            nickname: authorName,
                            profileImageUrl: authorImageUrl,
                          );
                          showProfileModal(context, user: displayUser);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: ClipSmoothRect(
                          radius: SmoothBorderRadius(
                            cornerRadius: 5,
                            cornerSmoothing: 1,
                          ),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CommonImageView(
                              networkUrl: authorImageUrl,
                              fit: BoxFit.cover,
                              backgroundColor: const Color(0xFFF2F2F2),
                              placeholderLogoSize: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CommonInkWell(
                          onTap: () {
                            if (feed.author.userId.isEmpty) return;
                            final displayUser = ProfileDisplayUser(
                              id: feed.author.userId,
                              nickname: authorName,
                              profileImageUrl: authorImageUrl,
                            );
                            showProfileModal(context, user: displayUser);
                          },
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    createdAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF616161),
                    ),
                  ),
                  if (placeName.isNotEmpty) ...[
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
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (distanceText != null && distanceText!.isNotEmpty) ...[
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
                        '${feed.commentCount}',
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
                        '${feed.likeCount}',
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
