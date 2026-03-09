import 'package:flutter/material.dart';

import '../../common/widgets/common_inkwell.dart';

class PlacebookSearchItemView extends StatelessWidget {
  const PlacebookSearchItemView({
    super.key,
    required this.title,
    required this.address,
    this.onTap,
  });

  final String title;
  final String address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? '장소' : title.trim();
    final safeAddress = address.trim().isEmpty ? '주소 정보 없음' : address.trim();
    return CommonInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              safeTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              safeAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
