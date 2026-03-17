import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_place_list_item_view.dart';
import '../placebook_detail/placebook_detail_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _nextCursor;
  String? _requestedCursor;
  String? _errorMessage;
  List<Map<String, dynamic>> _results = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.extentAfter < 220) {
      _search(loadMore: true);
    }
  }

  Future<void> _search({bool loadMore = false}) async {
    final trimmed = _searchController.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _query = '';
        _nextCursor = null;
        _requestedCursor = null;
        _hasMore = false;
        _errorMessage = null;
      });
      return;
    }

    if (loadMore) {
      final cursor = _nextCursor;
      if (cursor == null || cursor.isEmpty) return;
      if (_requestedCursor == cursor) return;
      setState(() => _isLoadingMore = true);
      _requestedCursor = cursor;
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _query = trimmed;
        _nextCursor = null;
        _requestedCursor = null;
        _hasMore = false;
      });
    }

    try {
      final response = await ApiClient.fetchPlacebookPlacesList(
        query: _query,
        limit: _pageSize,
        cursor: loadMore ? _nextCursor : null,
        cursorOnly: loadMore,
      );
      final items = _extractPlaceListItems(response)
          .map(_normalizePlaceListItem)
          .toList(growable: false);
      final nextCursor = _extractNextCursor(response);
      final hasMore = _extractHasMore(response, nextCursor);
      if (!mounted) return;
      setState(() {
        _results = loadMore ? [..._results, ...items] : items;
        _nextCursor = nextCursor;
        _hasMore = hasMore;
        _errorMessage = null;
        _requestedCursor = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _requestedCursor = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extractPlaceListItems(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final nestedItems = data['items'] ?? data['places'];
      if (nestedItems is List) {
        return nestedItems.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  String? _extractNextCursor(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final meta = data['meta'];
      if (meta is Map<String, dynamic>) {
        final next = meta['nextCursor']?.toString();
        if (next != null && next.isNotEmpty) return next;
      }
      final next = data['nextCursor']?.toString();
      if (next != null && next.isNotEmpty) return next;
    }
    final meta = json['meta'];
    if (meta is Map<String, dynamic>) {
      final next = meta['nextCursor']?.toString();
      if (next != null && next.isNotEmpty) return next;
    }
    final next = json['nextCursor']?.toString();
    if (next != null && next.isNotEmpty) return next;
    return null;
  }

  bool _extractHasMore(Map<String, dynamic> json, String? nextCursor) {
    bool? value;
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final meta = data['meta'];
      if (meta is Map<String, dynamic>) {
        value ??= meta['hasMore'] as bool?;
        value ??= meta['hasNext'] as bool?;
      }
      value ??= data['hasMore'] as bool?;
      value ??= data['hasNext'] as bool?;
    }
    final meta = json['meta'];
    if (meta is Map<String, dynamic>) {
      value ??= meta['hasMore'] as bool?;
      value ??= meta['hasNext'] as bool?;
    }
    value ??= json['hasMore'] as bool?;
    value ??= json['hasNext'] as bool?;
    return value ?? (nextCursor != null && nextCursor.isNotEmpty);
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

  String _resolvePlaceImageUrl(Map<String, dynamic> place) {
    final image = place['image'];
    if (image is Map<String, dynamic>) return _firstValidImageUrl(image);
    if (image is String && image.trim().isNotEmpty) return image.trim();
    final thumbnail = place['thumbnail'];
    if (thumbnail is Map<String, dynamic>) return _firstValidImageUrl(thumbnail);
    if (thumbnail is String && thumbnail.trim().isNotEmpty) {
      return thumbnail.trim();
    }
    final imageId = place['imageId'];
    if (imageId is Map<String, dynamic>) return _firstValidImageUrl(imageId);
    final direct = place['thumbnailUrl'] ?? place['imageUrl'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    return '';
  }

  String _firstValidImageUrl(Map<String, dynamic> image) {
    final cdn = image['cdnUrl']?.toString().trim();
    if (cdn != null && cdn.isNotEmpty) return cdn;
    final thumb = image['thumbnailUrl']?.toString().trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final file = image['fileUrl']?.toString().trim();
    if (file != null && file.isNotEmpty) return file;
    return '';
  }

  String _placeIdOf(Map<String, dynamic> place) {
    final placeId = place['placeId'];
    if (placeId is String && placeId.isNotEmpty) return placeId;
    final id = place['id'];
    if (id is String && id.isNotEmpty) return id;
    return '';
  }

  String _titleOf(Map<String, dynamic> place) {
    final title = (place['title'] ?? place['name'] ?? '').toString().trim();
    return title.isEmpty ? '장소' : title;
  }

  String _addressOf(Map<String, dynamic> place) {
    final address = (place['address'] ?? place['placeName'] ?? '')
        .toString()
        .trim();
    return address;
  }

  String? _themeTextOf(Map<String, dynamic> place) {
    String? titleFrom(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        final title = raw['title'] ?? raw['name'];
        if (title is String && title.trim().isNotEmpty) return title.trim();
      }
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return null;
    }

    return titleFrom(place['theme']) ?? titleFrom(place['themeTitle']);
  }

  int _toIntCount(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  int _readCount(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final count = _toIntCount(json[key]);
      if (count > 0) return count;
    }
    for (final key in keys) {
      if (json.containsKey(key)) return _toIntCount(json[key]);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  CommonInkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        PhosphorIconsBold.caretLeft,
                        size: 22,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.magnifyingGlass,
                            size: 20,
                            color: Color(0xFF9E9E9E),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              onChanged: (value) {
                                if (value.trim().isEmpty &&
                                    (_results.isNotEmpty || _errorMessage != null)) {
                                  setState(() {
                                    _results = const [];
                                    _query = '';
                                    _nextCursor = null;
                                    _requestedCursor = null;
                                    _hasMore = false;
                                    _errorMessage = null;
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                hintText: '장소를 검색하세요',
                                hintStyle: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF9E9E9E),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => _search(),
                      child: const Text(
                        '검색',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (_isLoading && _results.isEmpty) {
                    return const Center(child: CommonActivityIndicator(size: 24));
                  }
                  if (_errorMessage != null) {
                    return ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    );
                  }
                  if (_results.isEmpty) {
                    return ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      children: [
                        CommonEmptyView(
                          message: _query.isEmpty
                              ? '장소를 검색해보세요.'
                              : '검색 결과가 없습니다.',
                          showButton: false,
                          height: _query.isEmpty ? 200 : null,
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: _results.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      if (index >= _results.length) {
                        return Center(
                          child: _isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        );
                      }
                      final place = _results[index];
                      final placeId = _placeIdOf(place);
                      final commentCount = _readCount(place, const [
                        'commentCount',
                        'commentsCount',
                        'comments',
                      ]);
                      final likeCount = _readCount(place, const [
                        'helpfulCount',
                        'verificationCount',
                        'likeCount',
                        'favoriteCount',
                      ]);
                      final favorited = (place['favorited'] as bool?) ??
                          (place['isFavorited'] as bool?) ??
                          false;
                      return CommonPlaceListItemView(
                        thumbnailUrl: _resolvePlaceImageUrl(place),
                        title: _titleOf(place),
                        address: _addressOf(place),
                        commentCount: commentCount,
                        likeCount: likeCount,
                        themeText: _themeTextOf(place),
                        favorited: favorited,
                        onTap: () async {
                          if (placeId.isEmpty) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlacebookDetailView(space: place),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
