import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:http/http.dart' as http;

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_textfield_view.dart';
import '../common/widgets/common_empty_view.dart';
import '../place_select/place_select_view.dart';
import 'widgets/placebook_search_item_view.dart';

class PlacebookSearchView extends StatefulWidget {
  const PlacebookSearchView({super.key});

  @override
  State<PlacebookSearchView> createState() => _PlacebookSearchViewState();
}

class _PlacebookSearchViewState extends State<PlacebookSearchView> {
  static const int _pageSize = 15;
  static const String _kakaoHost = 'dapi.kakao.com';
  static const String _kakaoPath = '/v2/local/search/keyword.json';
  static const String _apiKey = 'c6f99d1ae0f4ac630e87d1026c4d0bf5';

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  int _page = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isEnd = false;
  String? _errorMessage;
  List<_KakaoPlace> _results = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || _isLoading || _isEnd) return;
    if (_scrollController.position.extentAfter < 200) {
      _search(loadMore: true);
    }
  }

  Future<void> _search({bool loadMore = false}) async {
    if (_apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'KAKAO_REST_API_KEY가 설정되지 않았습니다.';
      });
      return;
    }

    final trimmed = _searchController.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _query = '';
        _page = 1;
        _isEnd = false;
        _errorMessage = null;
      });
      return;
    }

    if (loadMore) {
      if (_isEnd) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
        _isEnd = false;
        _query = trimmed;
      });
    }

    final uri = Uri(
      scheme: 'https',
      host: _kakaoHost,
      path: _kakaoPath,
      queryParameters: <String, String>{
        'query': _query,
        'page': '$_page',
        'size': '$_pageSize',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('검색에 실패했습니다. (${response.statusCode})');
      }
      final json = jsonDecode(response.body);
      final meta = json is Map<String, dynamic> ? json['meta'] : null;
      final isEnd = meta is Map<String, dynamic>
          ? (meta['is_end'] as bool?) ?? false
          : true;
      final docs = json is Map<String, dynamic> ? json['documents'] : null;
      final nextResults = docs is List
          ? docs
              .whereType<Map<String, dynamic>>()
              .map(_KakaoPlace.fromJson)
              .toList()
          : <_KakaoPlace>[];

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _results = [..._results, ...nextResults];
        } else {
          _results = nextResults;
        }
        _isEnd = isEnd;
        _errorMessage = null;
        if (!isEnd) _page += 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommonNavigationView(
              left: const Icon(
                PhosphorIconsRegular.x,
                size: 22,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              title: '장소 검색',
              backgroundColor: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: CommonTextFieldView(
                      controller: _searchController,
                      hintText: '장소를 검색하세요',
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      prefixIcon: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 18,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 50,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => _search(),
                      child: const Text(
                        '검색',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading && _results.isEmpty
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _errorMessage != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            const SizedBox(height: 24),
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
                        )
                      : _results.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: const [
                                CommonEmptyView(
                                  message: '검색 결과가 없습니다.',
                                  showButton: false,
                                ),
                              ],
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _results.length +
                                  (_isEnd ? 0 : 1),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index >= _results.length) {
                                  return Center(
                                    child: _isLoadingMore
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  );
                                }
                                final place = _results[index];
                                return PlacebookSearchItemView(
                                  title: place.name,
                                  address: place.address,
                                  onTap: () {
                                    Navigator.of(context).pop(
                                      PlaceSelection(
                                        placeName: place.name,
                                        latitude: place.latitude,
                                        longitude: place.longitude,
                                      ),
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

class _KakaoPlace {
  const _KakaoPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  factory _KakaoPlace.fromJson(Map<String, dynamic> json) {
    final name = json['place_name'] as String? ?? '';
    final road = json['road_address_name'] as String? ?? '';
    final address = json['address_name'] as String? ?? '';
    final lat = double.tryParse(json['y']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(json['x']?.toString() ?? '') ?? 0.0;
    return _KakaoPlace(
      id: json['id']?.toString() ?? '',
      name: name.trim().isEmpty ? '장소' : name.trim(),
      address: road.trim().isNotEmpty ? road.trim() : address.trim(),
      latitude: lat,
      longitude: lng,
    );
  }
}
