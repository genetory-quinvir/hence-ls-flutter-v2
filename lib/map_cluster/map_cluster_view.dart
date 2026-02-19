import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../common/widgets/common_feed_list_item_view.dart';
import '../common/widgets/common_livespace_list_item_view.dart';
import '../feed_list/models/feed_models.dart';
import '../livespace_detail/livespace_detail_view.dart';
import '../profile/profile_feed_detail_view.dart';

class MapClusterView extends StatefulWidget {
  const MapClusterView({
    super.key,
    required this.type,
    required this.items,
    required this.parentContext,
    this.currentCenter,
  });

  final String type;
  final List<Map<String, dynamic>> items;
  final BuildContext parentContext;
  final ({double lat, double lng})? currentCenter;

  static Future<void> show({
    required BuildContext context,
    required String type,
    required List<Map<String, dynamic>> items,
    ({double lat, double lng})? currentCenter,
  }) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - (media.padding.top + 44 + 64);
    const minHeight = 200.0;
    final bottomInset = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;
    final effectiveMaxHeight = math.max(
      minHeight,
      maxHeight - bottomInset - safeBottom,
    );
    final preferredHeight = media.size.height * 0.82;
    final sheetHeight = preferredHeight < minHeight
        ? minHeight
        : (preferredHeight > effectiveMaxHeight
            ? effectiveMaxHeight
            : preferredHeight);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SizedBox(
          height: sheetHeight,
          child: MapClusterView(
            type: type,
            items: items,
            parentContext: context,
            currentCenter: currentCenter,
          ),
        );
      },
    );
  }

  @override
  State<MapClusterView> createState() => _MapClusterViewState();
}

class _MapClusterViewState extends State<MapClusterView> {
  final Map<String, Feed> _feedOverrides = {};

  bool get _isFeedType => widget.type.toUpperCase() == 'FEED';

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
    final center = widget.currentCenter;
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

  Feed? _feedFromItem(Map<String, dynamic> item) {
    final raw = item['feed'];
    if (raw is Map<String, dynamic>) {
      final feed = Feed.fromJson(raw);
      if (feed.id.isNotEmpty) return feed;
    }
    final directType = (item['type'] as String?)?.toUpperCase();
    if (directType == 'FEED' || item.containsKey('content') || item.containsKey('images')) {
      final feed = Feed.fromJson(item);
      if (feed.id.isNotEmpty) return feed;
    }
    return null;
  }

  String _thumbnailForLivespace(Map<String, dynamic> item) {
    final thumbnailRaw = item['thumbnail'];
    final thumbnailMap = thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
    final feedRaw = item['feed'];
    final feedMap = feedRaw is Map<String, dynamic> ? feedRaw : null;
    final imagesRaw = (feedMap?['images'] ?? item['images']);
    Map<String, dynamic>? firstImage;
    if (imagesRaw is List) {
      for (final entry in imagesRaw) {
        if (entry is Map<String, dynamic>) {
          firstImage = entry;
          break;
        }
      }
    }
    return (thumbnailRaw is String ? thumbnailRaw : null) ??
        thumbnailMap?['cdnUrl'] as String? ??
        thumbnailMap?['fileUrl'] as String? ??
        item['thumbnailUrl'] as String? ??
        item['imageUrl'] as String? ??
        firstImage?['thumbnailUrl'] as String? ??
        firstImage?['cdnUrl'] as String? ??
        firstImage?['fileUrl'] as String? ??
        '';
  }

  String _titleForLivespace(Map<String, dynamic> item) {
    return item['title'] as String? ??
        item['name'] as String? ??
        item['placeName'] as String? ??
        '라이브 스페이스';
  }

  String _dateForLivespace(Map<String, dynamic> item) {
    return item['date'] as String? ??
        item['startAt'] as String? ??
        item['createdAt'] as String? ??
        '오늘';
  }

  String _placeForLivespace(Map<String, dynamic> item) {
    return item['placeName'] as String? ??
        item['address'] as String? ??
        item['location'] as String? ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final feedEntries = widget.items
        .map((item) => (item: item, feed: _feedFromItem(item)))
        .where((entry) => entry.feed != null)
        .map((entry) {
          final feed = entry.feed!;
          return (
            item: entry.item,
            feed: _feedOverrides[feed.id] ?? feed,
          );
        })
        .toList();
    final feeds = feedEntries.map((entry) => entry.feed).toList();
    final title = _isFeedType
        ? '피드 ${feedEntries.length}개'
        : '라이브스페이스 ${widget.items.length}개';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD8D8D8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isFeedType
                ? ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: feedEntries.length,
                    separatorBuilder: (_, __) => const SizedBox.shrink(),
                    itemBuilder: (context, index) {
                      final feed = feedEntries[index].feed;
                      final source = feedEntries[index].item;
                      final rawFeed = source['feed'];
                      final feedMap =
                          rawFeed is Map<String, dynamic> ? rawFeed : source;
                      final lat = (source['latitude'] as num?)?.toDouble() ??
                          (feedMap['latitude'] as num?)?.toDouble();
                      final lng = (source['longitude'] as num?)?.toDouble() ??
                          (feedMap['longitude'] as num?)?.toDouble();
                      return CommonFeedListItemView(
                        feed: feed,
                        distanceText: _distanceLabel(lat: lat, lng: lng),
                        onTap: () {
                          Navigator.of(context).pop();
                          showCupertinoModalPopup(
                            context: widget.parentContext,
                            builder: (_) => SizedBox.expand(
                              child: ProfileFeedDetailView(
                                feeds: feeds,
                                initialIndex: index,
                                onFeedUpdated: (updated) {
                                  setState(() => _feedOverrides[updated.id] = updated);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, __) => const SizedBox.shrink(),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final commentCount = (item['commentCount'] as num?)?.toInt() ??
                          (item['comments'] as num?)?.toInt() ??
                          0;
                      final likeCount = (item['likeCount'] as num?)?.toInt() ??
                          (item['likes'] as num?)?.toInt() ??
                          0;
                      final lat = (item['latitude'] as num?)?.toDouble();
                      final lng = (item['longitude'] as num?)?.toDouble();
                      return CommonLivespaceListItemView(
                        thumbnailUrl: _thumbnailForLivespace(item),
                        title: _titleForLivespace(item),
                        dateText: _dateForLivespace(item),
                        placeName: _placeForLivespace(item),
                        commentCount: commentCount,
                        likeCount: likeCount,
                        distanceText: _distanceLabel(lat: lat, lng: lng),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(widget.parentContext).push(
                            MaterialPageRoute(
                              builder: (_) => LivespaceDetailView(space: item),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
