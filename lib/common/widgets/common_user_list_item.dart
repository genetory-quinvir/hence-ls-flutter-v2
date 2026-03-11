import 'package:flutter/material.dart';
import 'package:hence_ls_flutter_v2/main.dart';

import 'common_profile_view.dart';

class CommonUserListItem extends StatelessWidget {
  const CommonUserListItem({
    super.key,
    required this.rank,
    required this.title,
    this.pointsText,
    this.subtitle,
    this.imageUrl,
    this.onTap,
  });

  final int rank;
  final String title;
  final String? pointsText;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$rank',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        CommonProfileView(
          size: 44,
          networkUrl: imageUrl,
          placeholder: Container(
            color: const Color(0xFFF2F2F2),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person,
              size: 20,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (pointsText != null && pointsText!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: const ShapeDecoration(
                          color: Colors.black,
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                        child: Text(
                          pointsText!.trim(),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: MyApp.primary200,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8E8E8E),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: content,
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: content,
      ),
    );
  }
}
