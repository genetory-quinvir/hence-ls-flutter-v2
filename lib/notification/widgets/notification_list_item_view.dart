import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/widgets/common_image_view.dart';

class NotificationListItemView extends StatelessWidget {
  const NotificationListItemView({
    super.key,
    required this.item,
  });

  final Map<String, dynamic> item;

  String _formatCreatedAt(String? value) {
    if (value == null || value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '';
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y. $m. $d';
  }

  String? _notificationIconPath(String? template) {
    if (template == null || template.isEmpty) return null;
    if (template == 'POINTS_SAVED' ||
        template == 'POINTS_USED_REWARD' ||
        template == 'POINTS_USED_GACHA' ||
        template == 'POINTS_USED_ENTRY' ||
        template == 'POINTS_USED_ITEM') {
      return 'lib/assets/images/icon_noti_point.svg';
    } else if (template == 'REPORT_ACCEPTED' ||
        template == 'CONTENTS_DELETED' ||
        template == 'WRITER_WARNING' ||
        template == 'USER_BLOCKED' ||
        template == 'SPACE_SHUT_DOWN') {
      return 'lib/assets/images/icon_noti_report.svg';
    } else if (template == 'NEW_COMMENT' || template == 'WELCOME_SIGNUP') {
      return 'lib/assets/images/icon_noti_system.svg';
    } else if (template == 'NEW_FEED' ||
        template == 'SPACE_10_MIN_CLOSE' ||
        template == 'FEED_LIKED') {
      return null;
    } else {
      return 'lib/assets/images/icon_noti_notice.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        (item['title'] as String?) ?? (item['message'] as String?) ?? '알림';
    final body = (item['body'] as String?) ?? (item['content'] as String?) ?? '';
    final createdAt = _formatCreatedAt(item['createdAt'] as String?);
    final readAt = item['readAt'] as String?;
    final template = item['template'] as String?;
    final imageJson = item['image'] as Map<String, dynamic>?;
    final imageUrl = (imageJson?['cdnUrl'] as String?) ??
        (imageJson?['thumbnailUrl'] as String?) ??
        (imageJson?['fileUrl'] as String?);
    final iconPath = _notificationIconPath(template);

    final isUnread = readAt == null;

    return Container(
      color: isUnread ? const Color(0xFFF7F8FA) : Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: iconPath == null
                  ? CommonImageView(
                      networkUrl: imageUrl,
                      fit: BoxFit.cover,
                      backgroundColor: const Color(0xFFF2F2F2),
                    )
                  : Container(
                      color: const Color(0xFFF2F2F2),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        iconPath,
                        width: 24,
                        height: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isUnread ? FontWeight.w500 : FontWeight.w500,
                    color:
                        isUnread ? const Color(0xFF111111) : const Color(0xFF7A7A7A),
                  ),
                ),
                if (body.isNotEmpty) ...[
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E8E),
                    ),
                  ),
                ],
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    createdAt,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
