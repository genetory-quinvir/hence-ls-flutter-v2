import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/utils/time_format.dart';
import '../../common/widgets/common_image_view.dart';
import '../../common/widgets/common_inkwell.dart';
import '../models/feed_comment_model.dart';

class FeedCommentListItemView extends StatelessWidget {
  const FeedCommentListItemView({
    super.key,
    required this.comment,
    this.onLikeTap,
    this.onReplyTap,
    this.onToggleReplies,
    this.hasReplies = false,
    this.repliesExpanded = false,
  });

  final FeedCommentItem comment;
  final VoidCallback? onLikeTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onToggleReplies;
  final bool hasReplies;
  final bool repliesExpanded;

  @override
  Widget build(BuildContext context) {
    final createdAt = formatRelativeTime(comment.createdAt);
    final isLiked = comment.isLiked;
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_가-힣]{1,50})');
    final spans = <TextSpan>[];
    var lastIndex = 0;
    for (final match in mentionRegex.allMatches(comment.content)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: comment.content.substring(lastIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: Color(0xFF1E88E5),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < comment.content.length) {
      spans.add(TextSpan(text: comment.content.substring(lastIndex)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE0E0E0),
          ),
          clipBehavior: Clip.antiAlias,
          child: CommonImageView(
            networkUrl: comment.authorProfileUrl,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          createdAt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                        children: spans,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (hasReplies)
                          CommonInkWell(
                            onTap: onToggleReplies,
                            child: Text(
                              repliesExpanded
                                  ? '답글 숨기기'
                                  : '답글 ${comment.replyCount ?? 0}개 보기',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color.fromRGBO(100, 100, 100, 1),
                              ),
                            ),
                          ),
                        if (hasReplies) const SizedBox(width: 12),
                        CommonInkWell(
                          onTap: onReplyTap,
                          child: const Text(
                            '답글 달기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CommonInkWell(
                    onTap: onLikeTap,
                    child: Icon(
                      isLiked ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                      color: isLiked ? const Color(0xFFE53935) : const Color(0xFF9E9E9E),
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${comment.likeCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
