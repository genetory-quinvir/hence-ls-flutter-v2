import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/widgets/common_inkwell.dart';
import '../../common/widgets/common_image_view.dart';

class PlacebookListItemView extends StatelessWidget {
  const PlacebookListItemView({
    super.key,
    required this.title,
    this.thumbnailUrl,
    this.address,
    this.commentCount,
    this.favoriteCount,
    this.onTap,
  });

  final String title;
  final String? thumbnailUrl;
  final String? address;
  final int? commentCount;
  final int? favoriteCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if ((address ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                  if ((commentCount ?? 0) > 0 || (favoriteCount ?? 0) > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if ((favoriteCount ?? 0) > 0) ...[
                          Icon(
                            PhosphorIconsRegular.heart,
                            size: 12,
                            color: const Color(0xFF9E9E9E),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${favoriteCount ?? 0}',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                        if ((favoriteCount ?? 0) > 0 && (commentCount ?? 0) > 0)
                          const SizedBox(width: 10),
                        if ((commentCount ?? 0) > 0) ...[
                          Icon(
                            PhosphorIconsRegular.chatText,
                            size: 12,
                            color: const Color(0xFF9E9E9E),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${commentCount ?? 0}',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
