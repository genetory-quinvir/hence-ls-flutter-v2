import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/utils/time_format.dart';
import '../../common/widgets/common_image_view.dart';
import '../../common/widgets/common_profile_image_view.dart';
import '../../common/widgets/common_profile_modal.dart';
import '../../common/widgets/common_alert_view.dart';
import '../../profile/models/profile_display_user.dart';
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
    const avatarSpacing = 12.0;
    const headerBottomSpacing = 6.0;
    const contentBottomSpacing = 8.0;
    const actionsTopSpacing = 8.0;
    const likeColumnSpacing = 14.0;
    const likeCountTopSpacing = 6.0;

    void showDeletedUserAlert() {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: const Color(0x99000000),
        builder: (_) {
          return Material(
            type: MaterialType.transparency,
            child: CommonAlertView(
              title: '삭제된 사용자입니다.',
              subTitle: '탈퇴한 사용자의 프로필은 확인할 수 없습니다.',
              primaryButtonTitle: '확인',
              onPrimaryTap: () => Navigator.of(context).pop(),
            ),
          );
        },
      );
    }

    void openProfile() {
      if (comment.authorId.isEmpty) return;
      if ((comment.authorDeletedAt ?? '').trim().isNotEmpty) {
        showDeletedUserAlert();
        return;
      }
      final displayUser = ProfileDisplayUser(
        id: comment.authorId,
        nickname: comment.authorName,
        profileImageUrl: comment.authorProfileUrl,
      );
      showProfileModal(
        context,
        user: displayUser,
        allowCurrentUser: true,
      );
    }

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
        CommonInkWell(
          onTap: openProfile,
          borderRadius: BorderRadius.circular(12),
          child: CommonProfileImageView(
            size: 32,
            imageUrl: comment.authorProfileUrl,
            useSquircle: true,
            placeholderIconSize: 15,
          ),
        ),
        const SizedBox(width: avatarSpacing),
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
                          child: CommonInkWell(
                            onTap: openProfile,
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
                    const SizedBox(height: headerBottomSpacing),
                    if (comment.imageUrl != null &&
                        comment.imageUrl!.trim().isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                comment.imageUrl!,
                                width: width,
                                fit: BoxFit.fitWidth,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 140,
                                    color: const Color(0xFFF2F2F2),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 140,
                                  color: const Color(0xFFF2F2F2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: contentBottomSpacing),
                    ],
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                        children: spans,
                      ),
                    ),
                    const SizedBox(height: actionsTopSpacing),
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
              const SizedBox(width: likeColumnSpacing),
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
                  const SizedBox(height: likeCountTopSpacing),
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
