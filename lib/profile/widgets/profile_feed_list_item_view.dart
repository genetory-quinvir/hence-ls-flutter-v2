import 'package:flutter/material.dart';

import '../../common/widgets/common_image_view.dart';

class ProfileFeedListItemView extends StatelessWidget {
  const ProfileFeedListItemView({
    super.key,
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CommonImageView(
        backgroundColor: const Color(0xFFF2F2F2),
        networkUrl: imageUrl,
        fit: BoxFit.cover,
      ),
    );
  }
}
