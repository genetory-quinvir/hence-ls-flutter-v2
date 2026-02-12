import 'package:flutter/material.dart';

import '../../common/widgets/common_image_view.dart';

class ProfileFeedListItemView extends StatelessWidget {
  const ProfileFeedListItemView({
    super.key,
    required this.imageUrl,
    this.imageCount = 0,
  });

  final String imageUrl;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CommonImageView(
            backgroundColor: const Color(0xFFF2F2F2),
            networkUrl: imageUrl,
            fit: BoxFit.cover,
          ),
          if (imageCount > 1)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.collections,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$imageCount',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
