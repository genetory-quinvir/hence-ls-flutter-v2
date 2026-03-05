import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/state/placebook_cache.dart';
import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../placebook/widgets/placebook_list_item_view.dart';
import '../placebook/widgets/placebook_list_empty_view.dart';
import '../placebook_create/placebook_create_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import '../common/widgets/common_inkwell.dart';

class PlacebookListView extends StatefulWidget {
  const PlacebookListView({super.key});

  @override
  State<PlacebookListView> createState() => _PlacebookListViewState();
}

class _PlacebookListViewState extends State<PlacebookListView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _themes = const [];
  List<Map<String, dynamic>> _registeredPlaces = const [];
  int _createdCount = 0;
  int _favoriteCount = 0;
  int _totalCount = 0;
  String _selectedThemeSort = 'asc';
  late final VoidCallback _tabListener;
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPlacebookData();
    _tabListener = () {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _loadPlacebookInfo();
        });
      }
    };
    HomeTabController.currentIndex.addListener(_tabListener);
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    _listController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_listController.hasClients) return;
    _listController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }


  Future<void> _loadPlacebookData() async {
    final categories = await PlacebookCache.loadCategories();
    final themes = await ApiClient.fetchPlacebookThemesSimple();
    final places = await ApiClient.fetchMyPlacebookMyPlaces();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _themes = themes;
      _registeredPlaces = places;
      _isLoading = false;
    });
    await _loadPlacebookInfo();
  }

  Future<void> _loadPlacebookInfo() async {
    debugPrint('[PLACEBOOK] load my-places/info');
    final info = await ApiClient.fetchMyPlacebookMyPlacesInfo();
    if (!mounted) return;
    setState(() {
      _createdCount = (info['createdCount'] as num?)?.toInt() ?? 0;
      _favoriteCount = (info['favoriteCount'] as num?)?.toInt() ?? 0;
      _totalCount = (info['totalCount'] as num?)?.toInt() ?? 0;
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupPlacesByTheme() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final place in _registeredPlaces) {
      final themeId = place['themeId']?.toString() ??
          (place['theme'] is Map
              ? (place['theme'] as Map)['id']?.toString()
              : '') ??
          '';
      if (themeId.isEmpty) continue;
      grouped.putIfAbsent(themeId, () => []).add(place);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final themes = _themes
        .whereType<Map<String, dynamic>>()
        .where((item) => item['isActive'] != false)
        .toList()
      ..sort((a, b) {
        final aTitle = _themeTitle(a).toLowerCase();
        final bTitle = _themeTitle(b).toLowerCase();
        final compare = aTitle.compareTo(bTitle);
        return _selectedThemeSort == 'asc' ? compare : -compare;
      });
    final placesByTheme = _groupPlacesByTheme();

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ListView(
                controller: _listController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          '내 도감',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: 'Pretendard',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(
                          text: '$_createdCount',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: ' 개의 장소를 '),
                        const TextSpan(
                          text: '등록',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: '했고,'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(
                          text: '$_favoriteCount',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: ' 개의 장소를 '),
                        const TextSpan(
                          text: '즐겨찾기',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: ' 했어요!'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        '테마 리스트',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_selectedThemeSort == 'asc') return;
                              setState(() => _selectedThemeSort = 'asc');
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              '가나다순',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: _selectedThemeSort == 'asc'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedThemeSort == 'asc'
                                    ? Colors.black
                                    : const Color(0x88000000),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: const Color(0x33000000),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (_selectedThemeSort == 'desc') return;
                              setState(() => _selectedThemeSort = 'desc');
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              '다나가순',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: _selectedThemeSort == 'desc'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedThemeSort == 'desc'
                                    ? Colors.black
                                    : const Color(0x88000000),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final theme in themes) ...[
                    _ThemeSection(
                      theme: theme,
                      places: placesByTheme[theme['id']?.toString() ?? ''] ??
                          const [],
                      onCreated: (created) async {
                        if (!mounted || created == null) return;
                        await _loadPlacebookData();
                        if (!mounted) return;
                        _scrollToTop();
                        if (!mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlacebookDetailView(space: created),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
      ),
    );
  }
}

String _resolvePlaceImageUrl(Map<String, dynamic> place) {
  final thumbnailRaw = place['thumbnail'];
  final thumbnailMap =
      thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
  final imageIdRaw = place['imageId'];
  final imageIdMap = imageIdRaw is Map<String, dynamic> ? imageIdRaw : null;
  final imageRaw = place['image'];
  final imageMap = imageRaw is Map<String, dynamic> ? imageRaw : null;
  final images = place['images'];
  final firstImage =
      images is List && images.isNotEmpty && images.first is Map<String, dynamic>
          ? images.first as Map<String, dynamic>
          : null;

  return (place['thumbnailUrl'] as String?) ??
      (place['imageUrl'] as String?) ??
      (thumbnailMap?['cdnUrl'] as String?) ??
      (thumbnailMap?['fileUrl'] as String?) ??
      (thumbnailMap?['thumbnailUrl'] as String?) ??
      (imageIdMap?['cdnUrl'] as String?) ??
      (imageIdMap?['fileUrl'] as String?) ??
      (imageIdMap?['thumbnailUrl'] as String?) ??
      (imageMap?['cdnUrl'] as String?) ??
      (imageMap?['fileUrl'] as String?) ??
      (imageMap?['thumbnailUrl'] as String?) ??
      (firstImage?['cdnUrl'] as String?) ??
      (firstImage?['fileUrl'] as String?) ??
      (firstImage?['thumbnailUrl'] as String?) ??
      '';
}

String _themeTitle(Map<String, dynamic> theme) {
  return (theme['title'] as String?) ??
      (theme['name'] as String?) ??
      '테마';
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({
    required this.theme,
    required this.places,
    required this.onCreated,
  });

  final Map<String, dynamic> theme;
  final List<Map<String, dynamic>> places;
  final ValueChanged<Map<String, dynamic>?> onCreated;

  @override
  Widget build(BuildContext context) {
    final title = _themeTitle(theme);
    final subtitle = (theme['subtitle'] as String?)?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (places.isEmpty)
          PlacebookListEmptyView(
            themeTitle: title,
            onTap: () async {
              final result = await showCupertinoModalPopup<Map<String, dynamic>>(
                context: context,
                builder: (_) => SizedBox.expand(
                  child: PlacebookCreateView(
                    categoryTitle: '',
                    themeTitle: title,
                    themeId: theme['id']?.toString(),
                  ),
                ),
              );
              onCreated(result);
            },
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: places.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final place = places[index];
                final title = (place['title'] as String?) ??
                    (place['name'] as String?) ??
                    '장소';
                final thumbnailUrl = _resolvePlaceImageUrl(place);
                final favoriteCount =
                    (place['favoriteCount'] as num?)?.toInt() ?? 0;
                final commentCount =
                    (place['commentCount'] as num?)?.toInt() ?? 0;
                final address = (place['address'] as String?) ??
                    (place['placeName'] as String?) ??
                    '';
                return PlacebookListItemView(
                  title: title,
                  thumbnailUrl: thumbnailUrl,
                  favoriteCount: favoriteCount,
                  commentCount: commentCount,
                  address: address,
                  onTap: () {},
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF616161),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$value',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
