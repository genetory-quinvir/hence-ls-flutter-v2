import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_navigation_view.dart';
import '../placebook_list/placebook_list_view.dart';

class CategoryDetailView extends StatefulWidget {
  const CategoryDetailView({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    this.categorySubtitle,
  });

  final String categoryId;
  final String categoryTitle;
  final String? categorySubtitle;

  @override
  State<CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<CategoryDetailView> {
  static const double _fallbackLatitude = 37.4979;
  static const double _fallbackLongitude = 127.0276;
  final ScrollController _themeScrollController = ScrollController();
  final Map<String, GlobalKey> _themeChipKeys = {};
  bool _loading = true;
  List<Map<String, dynamic>> _themes = const [];
  String _selectedThemeId = '';
  String _selectedThemeTitle = '';

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  @override
  void dispose() {
    _themeScrollController.dispose();
    super.dispose();
  }

  void _scrollThemeChipToCenter(String themeId) {
    final key = _themeChipKeys[themeId];
    final context = key?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadThemes() async {
    try {
      final response = await ApiClient.fetchPlacebookHome();
      final data = response['data'];
      final filtered = <Map<String, dynamic>>[];
      final candidates = <dynamic>[];
      if (data is Map<String, dynamic>) {
        candidates.add(data['allThemes']);
        candidates.add(data['themes']);
        candidates.add(data['items']);
      }
      candidates.add(response['allThemes']);
      candidates.add(response['themes']);
      candidates.add(response['items']);

      for (final candidate in candidates) {
        if (candidate is! List) continue;
        for (final entry in candidate.whereType<Map<String, dynamic>>()) {
          final themeRaw = entry['theme'] is Map<String, dynamic>
              ? entry['theme']
              : entry;
          if (themeRaw is! Map<String, dynamic>) continue;
          final category = themeRaw['category'];
          final categoryId = category is Map<String, dynamic>
              ? (category['id'] ?? '').toString()
              : '';
          if (categoryId != widget.categoryId) continue;
          filtered.add({'theme': themeRaw});
        }
        if (filtered.isNotEmpty) break;
      }

      if (filtered.isEmpty) {
        final themes = await ApiClient.fetchPlacebookThemes(
          orderBy: 'sortOrder',
        );
        for (final theme in themes) {
          final category = theme['category'];
          final categoryId = category is Map<String, dynamic>
              ? (category['id'] ?? '').toString()
              : '';
          if (categoryId != widget.categoryId) continue;
          filtered.add({'theme': theme});
        }
      }

      filtered.sort((a, b) {
        final aTheme = a['theme'] as Map<String, dynamic>? ?? const {};
        final bTheme = b['theme'] as Map<String, dynamic>? ?? const {};
        final aOrder = (aTheme['sortOrder'] as num?)?.toInt() ?? 0;
        final bOrder = (bTheme['sortOrder'] as num?)?.toInt() ?? 0;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        final aTitle = (aTheme['title'] ?? '').toString().toLowerCase();
        final bTitle = (bTheme['title'] ?? '').toString().toLowerCase();
        return aTitle.compareTo(bTitle);
      });
      if (!mounted) return;
      setState(() {
        _themes = filtered;
        _themeChipKeys
          ..clear()
          ..addEntries(
            filtered.map((item) {
              final theme =
                  item['theme'] as Map<String, dynamic>? ??
                  const <String, dynamic>{};
              final id = (theme['id'] ?? '').toString();
              return MapEntry(id, GlobalKey());
            }).where((entry) => entry.key.isNotEmpty),
          );
        if (filtered.isNotEmpty) {
          final firstTheme =
              filtered.first['theme'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
          _selectedThemeId = (firstTheme['id'] ?? '').toString();
          _selectedThemeTitle = (firstTheme['title'] ?? '').toString();
        } else {
          _selectedThemeId = '';
          _selectedThemeTitle = '';
        }
        _loading = false;
      });
      if (_selectedThemeId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollThemeChipToCenter(_selectedThemeId);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
              height: 50,
              backgroundColor: Colors.white,
              left: const Icon(
                PhosphorIconsBold.caretLeft,
                size: 24,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              title: widget.categoryTitle,
            ),
            if ((widget.categorySubtitle ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.categorySubtitle!.trim(),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8E8E8E),
                    ),
                  ),
                ),
              ),
            if (_loading)
              const Expanded(
                child: Center(child: CommonActivityIndicator(size: 24)),
              )
            else if (_themes.isEmpty)
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  children: const [
                    CommonEmptyView(
                      message: '표시할 테마가 없습니다.',
                      showButton: false,
                    ),
                  ],
                ),
              )
            else ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  controller: _themeScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _themes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final theme =
                        _themes[index]['theme'] as Map<String, dynamic>? ??
                        const <String, dynamic>{};
                    final themeId = (theme['id'] ?? '').toString();
                    final themeTitle = (theme['title'] ?? '').toString();
                    final selected = themeId == _selectedThemeId;
                    final chipKey = _themeChipKeys[themeId] ?? GlobalKey();
                    _themeChipKeys[themeId] = chipKey;
                    return CommonInkWell(
                      key: chipKey,
                      onTap: () {
                        if (themeId.isEmpty) return;
                        if (selected) return;
                        setState(() {
                          _selectedThemeId = themeId;
                          _selectedThemeTitle = themeTitle;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _scrollThemeChipToCenter(themeId);
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.black
                              : const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          themeTitle.isEmpty ? '테마' : themeTitle,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF424242),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PlacebookListView(
                  key: ValueKey(_selectedThemeId),
                  showNavigation: false,
                  themeId: _selectedThemeId,
                  themeTitle: _selectedThemeTitle,
                  latitude: _fallbackLatitude,
                  longitude: _fallbackLongitude,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
