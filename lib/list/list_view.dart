import 'package:flutter/material.dart';

import '../common/widgets/common_livespace_item_view.dart';

class MapListView extends StatelessWidget {
  const MapListView({
    super.key,
    this.topPadding = 0,
    this.items = const <Map<String, dynamic>>[],
    this.isLoading = false,
  });

  final double topPadding;
  final List<Map<String, dynamic>> items;
  final bool isLoading;

  static const _thumbnails = <String>[
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e',
    'https://images.unsplash.com/photo-1491553895911-0055eca6402d',
    'https://images.unsplash.com/photo-1467269204594-9661b134dd2b',
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
  ];

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: ListView.separated(
        padding: EdgeInsets.only(
          top: topPadding + 8,
          left: 16,
          right: 16,
          bottom: 24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFEAEAEA),
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final thumbnailRaw = item['thumbnail'];
          final thumbnailMap =
              thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
          final thumbnail = (thumbnailRaw is String ? thumbnailRaw : null) ??
              thumbnailMap?['cdnUrl'] as String? ??
              thumbnailMap?['fileUrl'] as String? ??
              item['thumbnailUrl'] as String? ??
              item['imageUrl'] as String? ??
              '${_thumbnails[index % _thumbnails.length]}?w=800';
          final title = item['title'] as String? ??
              item['name'] as String? ??
              '라이브 스페이스';
          final dateText = item['date'] as String? ??
              item['startAt'] as String? ??
              item['createdAt'] as String? ??
              '오늘';
          final placeName = item['placeName'] as String? ??
              item['address'] as String? ??
              item['location'] as String? ??
              '';
          final commentCount = (item['commentCount'] as num?)?.toInt() ??
              (item['comments'] as num?)?.toInt() ??
              0;
          final likeCount =
              (item['likeCount'] as num?)?.toInt() ?? (item['likes'] as num?)?.toInt() ?? 0;
          return CommonLivespaceItemView(
            thumbnailUrl: thumbnail,
            title: title,
            dateText: dateText,
            placeName: placeName,
            commentCount: commentCount,
            likeCount: likeCount,
            onTap: () {},
          );
        },
      ),
    );
  }
}
