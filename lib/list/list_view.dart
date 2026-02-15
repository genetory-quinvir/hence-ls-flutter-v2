import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_livespace_list_item_view.dart';
import '../common/widgets/common_feed_list_item_view.dart';
import '../feed_list/models/feed_models.dart';
import '../livespace_detail/livespace_detail_view.dart';
import '../profile/profile_feed_detail_view.dart';

class MapListView extends StatelessWidget {
  const MapListView({
    super.key,
    this.topPadding = 0,
    this.items = const <Map<String, dynamic>>[],
    this.isLoading = false,
    this.currentCenter,
    this.onRefresh,
  });

  final double topPadding;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final ({double lat, double lng})? currentCenter;
  final Future<void> Function()? onRefresh;

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            (math.sin(dLng / 2) * math.sin(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

  String? _distanceLabel({
    required double? lat,
    required double? lng,
  }) {
    final center = currentCenter;
    if (center == null || lat == null || lng == null) return null;
    final meters = _distanceMeters(
      lat1: center.lat,
      lng1: center.lng,
      lat2: lat,
      lng2: lng,
    );
    if (meters.isNaN || meters.isInfinite) return null;
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)}km';
  }

  static const _thumbnails = <String>[
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e',
    'https://images.unsplash.com/photo-1491553895911-0055eca6402d',
    'https://images.unsplash.com/photo-1467269204594-9661b134dd2b',
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
  ];

  @override
  Widget build(BuildContext context) {
    final feeds = <Feed>[];
    for (final item in items) {
      final purpose = (item['purpose'] as String?)?.toUpperCase();
      if (purpose != 'FEED') continue;
      final rawFeed = item['feed'];
      final feedMap = rawFeed is Map<String, dynamic> ? rawFeed : item;
      feeds.add(Feed.fromJson(feedMap));
    }
    final content = isLoading && items.isEmpty
        ? Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : items.isEmpty
            ? const CommonEmptyView(
                message: '표시할 항목이 없습니다.',
                showButton: false,
              )
            : ListView.separated(
                padding: EdgeInsets.only(
                  top: topPadding + 8,
                  left: 16,
                  right: 16,
                  bottom: 24,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final purpose = (item['purpose'] as String?)?.toUpperCase();
          if (purpose == 'FEED') {
            final rawFeed = item['feed'];
            final feedMap =
                rawFeed is Map<String, dynamic> ? rawFeed : item;
            final feed = Feed.fromJson(feedMap);
            final lat = (item['latitude'] as num?)?.toDouble() ??
                (feedMap['latitude'] as num?)?.toDouble();
            final lng = (item['longitude'] as num?)?.toDouble() ??
                (feedMap['longitude'] as num?)?.toDouble();
            return CommonFeedListItemView(
              feed: feed,
              distanceText: _distanceLabel(lat: lat, lng: lng),
              onTap: () {
                if (feeds.isEmpty) return;
                final initialIndex =
                    feeds.indexWhere((entry) => entry.id == feed.id);
                if (initialIndex < 0) return;
                showCupertinoModalPopup(
                  context: context,
                  builder: (_) => SizedBox.expand(
                    child: ProfileFeedDetailView(
                      feeds: feeds,
                      initialIndex: initialIndex,
                    ),
                  ),
                );
              },
            );
          }
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
                  final likeCount = (item['likeCount'] as num?)?.toInt() ??
                      (item['likes'] as num?)?.toInt() ??
                      0;
                  final lat = (item['latitude'] as num?)?.toDouble();
                  final lng = (item['longitude'] as num?)?.toDouble();
                  return CommonLivespaceListItemView(
                    thumbnailUrl: thumbnail,
                    title: title,
                    dateText: dateText,
                    placeName: placeName,
                    commentCount: commentCount,
                    likeCount: likeCount,
                    distanceText: _distanceLabel(lat: lat, lng: lng),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LivespaceDetailView(space: item),
                        ),
                      );
                    },
                  );
                },
              );
    return Container(
      color: Colors.white,
      child: onRefresh == null
          ? content
          : CustomRefreshIndicator(
              onRefresh: onRefresh!,
              builder: (context, child, controller) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    child,
                    Positioned(
                      top: 12 + topPadding,
                      child: Opacity(
                        opacity: controller.value.clamp(0.0, 1.0),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: content is ListView
                  ? content
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: content,
                        ),
                      ],
                    ),
            ),
    );
  }
}
