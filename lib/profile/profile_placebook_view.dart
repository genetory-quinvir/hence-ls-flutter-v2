import 'package:flutter/material.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_place_list_item_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../placebook_detail/placebook_detail_view.dart';

class ProfilePlacebookView extends StatefulWidget {
  const ProfilePlacebookView({super.key});

  @override
  State<ProfilePlacebookView> createState() => _ProfilePlacebookViewState();
}

class _ProfilePlacebookViewState extends State<ProfilePlacebookView> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasNext = true;
  String? _nextCursor;
  String? _requestedCursor;
  final String _selectedPlaceSort = 'latest';
  List<Map<String, dynamic>> _places = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadPlaces();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 120 &&
        !_isLoadingMore &&
        _hasNext) {
      _loadPlaces(loadMore: true);
    }
  }

  Future<void> _loadPlaces({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasNext) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isRefreshing = !_isLoading;
        _isLoading = _places.isEmpty;
      });
      _nextCursor = null;
      _hasNext = true;
      _requestedCursor = null;
    }

    if (!_hasNext && loadMore) {
      if (mounted) setState(() => _isLoadingMore = false);
      return;
    }
    final placeOrderBy = _placeOrderBy(_selectedPlaceSort);
    final placeOrder = _placeOrder(_selectedPlaceSort);
    final requestCursor = loadMore ? _nextCursor : null;
    if (loadMore && _requestedCursor == requestCursor) {
      if (mounted) setState(() => _isLoadingMore = false);
      return;
    }
    _requestedCursor = requestCursor;

    final response = await ApiClient.fetchPlacebookPlacesList(
      filter: _placeListFilter('mine'),
      limit: 20,
      orderBy: loadMore ? null : placeOrderBy,
      order: loadMore ? null : placeOrder,
      cursor: requestCursor,
      cursorOnly: loadMore,
    );
    final items = _extractPlaceListItems(response)
        .map(_normalizePlaceListItem)
        .toList(growable: false);
    final dataNode = response['data'];
    final meta = dataNode is Map<String, dynamic> ? dataNode['meta'] : response['meta'];
    final hasNext = meta is Map<String, dynamic>
        ? (meta['hasNext'] as bool?) ?? false
        : false;
    final nextCursor = meta is Map<String, dynamic>
        ? meta['nextCursor']?.toString()
        : null;
    if (!mounted) return;
    setState(() {
      if (loadMore) {
        _places = _mergeUniquePlaces(_places, items);
      } else {
        _places = items;
      }
      _isLoading = false;
      _isRefreshing = false;
      _isLoadingMore = false;
      _requestedCursor = null;
      final hasValidCursor = nextCursor?.isNotEmpty ?? false;
      final isSameCursor = hasValidCursor && nextCursor == _nextCursor;
      _hasNext = hasNext && hasValidCursor && !isSameCursor;
      _nextCursor = nextCursor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      cacheExtent: 720,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: _isLoading
          ? 1
          : _places.isEmpty
              ? 1
              : _places.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: CommonActivityIndicator(size: 24),
            ),
          );
        }
        if (_places.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: CommonEmptyView(
                message: '찜한 장소가 없습니다.',
                showButton: false,
              ),
            ),
          );
        }
        if (_isLoadingMore && index == _places.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CommonActivityIndicator(size: 22),
            ),
          );
        }
        final place = _places[index];
        final title = (place['title'] as String?) ?? '장소';
        final address = _extractAddressTitle(place);
        final commentCount = _readPlaceCount(place, const [
          'commentCount',
          'commentsCount',
          'comments',
        ]);
        final likeCount = _readPlaceCount(place, const [
          'helpfulCount',
          'verificationCount',
          'likeCount',
          'favoriteCount',
        ]);
        final themeText = _extractThemeTitle(place);
        final favorited = (place['favorited'] as bool?) ??
            (place['isFavorited'] as bool?) ??
            false;
        return CommonPlaceListItemView(
          thumbnailUrl: _resolvePlaceImageUrl(place),
          title: title,
          address: address,
          commentCount: commentCount,
          likeCount: likeCount,
          themeText: themeText,
          favorited: favorited,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlacebookDetailView(space: place),
              ),
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              left: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              title: '나의 장소',
              backgroundColor: Colors.white,
            ),
            Expanded(
              child: CommonRefreshView(
                onRefresh: () => _loadPlaces(loadMore: false),
                topPadding: 8,
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _extractPlaceListItems(Map<String, dynamic> json) {
  final items = json['items'];
  if (items is List) {
    return items.whereType<Map<String, dynamic>>().toList();
  }
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    final nestedItems = data['items'];
    if (nestedItems is List) {
      return nestedItems.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

Map<String, dynamic> _normalizePlaceListItem(Map<String, dynamic> item) {
  final next = Map<String, dynamic>.from(item);
  final idRaw = item['id'];
  if (idRaw is Map<String, dynamic>) {
    next.remove('id');
    next.addAll(idRaw);
    final nestedId = idRaw['id'];
    if (nestedId != null) {
      next['id'] = nestedId.toString();
      next['placeId'] ??= nestedId.toString();
    }
  }
  return next;
}

List<Map<String, dynamic>> _mergeUniquePlaces(
  List<Map<String, dynamic>> current,
  List<Map<String, dynamic>> incoming,
) {
  if (incoming.isEmpty) return current;
  final merged = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final item in current) {
    final id = (item['id'] ?? item['placeId'] ?? '').toString();
    if (id.isEmpty) continue;
    if (seen.add(id)) merged.add(item);
  }
  for (final item in incoming) {
    final id = (item['id'] ?? item['placeId'] ?? '').toString();
    if (id.isEmpty) continue;
    if (seen.add(id)) merged.add(item);
  }
  return merged;
}

String _resolvePlaceImageUrl(Map<String, dynamic> place) {
  final idRaw = place['id'];
  final idMap = idRaw is Map<String, dynamic> ? idRaw : null;
  final thumbnailRaw = place['thumbnail'];
  final thumbnailMap = thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
  final imageIdRaw = place['imageId'];
  final imageIdMap = imageIdRaw is Map<String, dynamic> ? imageIdRaw : null;
  final imageRaw = place['image'];
  final imageMap = imageRaw is Map<String, dynamic> ? imageRaw : null;
  final idImageRaw = idMap?['image'];
  final idImageMap =
      idImageRaw is Map<String, dynamic> ? idImageRaw : null;
  final feed = place['feed'];
  final feedMap = feed is Map<String, dynamic> ? feed : null;
  final images = feedMap?['images'] ?? place['images'];
  Map<String, dynamic>? firstImageMap;
  String? firstImageString;
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is Map<String, dynamic>) {
      firstImageMap = first;
    } else if (first is String) {
      firstImageString = first;
    }
  }

  return _firstValidImageUrl([
    thumbnailRaw is String ? thumbnailRaw : null,
    place['thumbnailUrl'] as String?,
    place['imageUrl'] as String?,
    idMap?['thumbnailUrl'] as String?,
    idMap?['imageUrl'] as String?,
    thumbnailMap?['thumbnailUrl'] as String?,
    thumbnailMap?['cdnUrl'] as String?,
    thumbnailMap?['fileUrl'] as String?,
    imageIdMap?['thumbnailUrl'] as String?,
    imageIdMap?['cdnUrl'] as String?,
    imageIdMap?['fileUrl'] as String?,
    imageMap?['thumbnailUrl'] as String?,
    imageMap?['cdnUrl'] as String?,
    imageMap?['fileUrl'] as String?,
    idImageMap?['thumbnailUrl'] as String?,
    idImageMap?['cdnUrl'] as String?,
    idImageMap?['fileUrl'] as String?,
    firstImageMap?['thumbnailUrl'] as String?,
    firstImageMap?['cdnUrl'] as String?,
    firstImageMap?['fileUrl'] as String?,
    firstImageString,
  ]);
}

String _firstValidImageUrl(List<String?> candidates) {
  for (final url in candidates) {
    if (url != null && url.trim().isNotEmpty) return url.trim();
  }
  return '';
}

String _placeOrderBy(String key) {
  switch (key) {
    case 'popular':
      return 'popularity';
    case 'latest':
    default:
      return 'createdAt';
  }
}

String _placeOrder(String key) {
  switch (key) {
    case 'popular':
      return 'DESC';
    case 'latest':
    default:
      return 'DESC';
  }
}

String _placeListFilter(String key) {
  switch (key) {
    case 'all':
      return 'all';
    case 'mine':
    default:
      return 'mine';
  }
}

int _toPlaceCount(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

int _readPlaceCount(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final count = _toPlaceCount(json[key]);
    if (count > 0) return count;
  }
  for (final key in keys) {
    if (json.containsKey(key)) return _toPlaceCount(json[key]);
  }
  return 0;
}

String _extractThemeTitle(Map<String, dynamic> place) {
  final theme = place['theme'];
  if (theme is Map<String, dynamic>) {
    final title = theme['title'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
  }
  final themeTitle = place['themeTitle'];
  if (themeTitle is String && themeTitle.trim().isNotEmpty) {
    return themeTitle.trim();
  }
  return '';
}

String _extractAddressTitle(Map<String, dynamic> place) {
  String? pick(dynamic raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty &&
          trimmed != '{}' &&
          trimmed.toLowerCase() != 'null') {
        return trimmed;
      }
    }
    if (raw is Map<String, dynamic>) {
      return pick(raw['address']) ??
          pick(raw['roadAddress']) ??
          pick(raw['roadAddressName']) ??
          pick(raw['fullAddress']) ??
          pick(raw['name']) ??
          pick(raw['title']) ??
          pick(raw['text']);
    }
    return null;
  }

  return pick(place['address']) ??
      pick(place['roadAddress']) ??
      pick(place['placeAddress']) ??
      pick(place['location']) ??
      '';
}
