import 'package:flutter/material.dart';
import 'package:hence_ls_flutter_v2/main.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    final subtitleText = subtitle?.trim() ?? '';
    final hasBadge = pointsText != null && pointsText!.trim().isNotEmpty;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontStyle: FontStyle.italic,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          CommonProfileView(
            size: 50,
            networkUrl: imageUrl,
            placeholder: Container(
              color: const Color(0xFFF2F2F2),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsRegular.user,
                size: 20,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (subtitleText.isNotEmpty)
                        const SizedBox(height: 4),
                      if (subtitleText.isNotEmpty)
                        _SubtitleText(text: subtitleText),
                    ],
                  ),
                ),
                if (hasBadge)
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
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
              ],
            ),
          ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: content,
      );
    }
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: content,
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText({
    required this.text,
    this.textAlign,
  });

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(.*?)(\d+)\s*$').firstMatch(text);
    final hasSavedPlacePrefix =
        match != null && (match.group(1)?.contains('저장한 장소') ?? false);
    if (!hasSavedPlacePrefix) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF8E8E8E),
        ),
      );
    }

    final prefix = match.group(1) ?? '';
    final count = match.group(2) ?? '';
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E8E),
            ),
          ),
          TextSpan(
            text: count,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
