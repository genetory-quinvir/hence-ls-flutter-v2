import 'package:flutter/material.dart';
import 'package:hence_ls_flutter_v2/common/widgets/common_inkwell.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/widgets/common_empty_view.dart';
import '../../common/widgets/common_navigation_view.dart';
import '../../common/widgets/common_rounded_button.dart';
import '../../common/widgets/common_textfield_view.dart';
import '../../common/state/placebook_cache.dart';
import 'widgets/map_filter_theme_item_view.dart';

class MapFilterView extends StatefulWidget {
  const MapFilterView({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    this.selectedThemeIds = const [],
  });

  final List<Map<String, dynamic>> categories;
  final String? selectedCategoryId;
  final List<String> selectedThemeIds;

  @override
  State<MapFilterView> createState() => _MapFilterViewState();
}

class _MapFilterViewState extends State<MapFilterView> {
  String? _selectedId;
  final Set<String> _selectedThemeIds = <String>{};
  List<Map<String, dynamic>> _themes = const [];
  String _query = '';
  late final TextEditingController _queryController;
  late final FocusNode _queryFocusNode;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedCategoryId;
    _selectedThemeIds
      ..clear()
      ..addAll(widget.selectedThemeIds);
    _queryController = TextEditingController(text: _query);
    _queryFocusNode = FocusNode();
    _loadThemes();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadThemes() async {
    final themes = await PlacebookCache.loadThemes();
    if (!mounted) return;
    setState(() {
      _themes = themes.map(_resolveThemeData).toList()
        ..sort((a, b) {
          final aOrder = (a['sortOrder'] as num?)?.toInt() ?? 0;
          final bOrder = (b['sortOrder'] as num?)?.toInt() ?? 0;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          final aTitle = a['title']?.toString() ?? '';
          final bTitle = b['title']?.toString() ?? '';
          return aTitle.compareTo(bTitle);
        });
      if (_selectedThemeIds.isEmpty) {
        _selectedThemeIds
          ..clear()
          ..addAll(_themes
              .map((e) => e['id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty));
      }
    });
  }

  Map<String, dynamic> _resolveThemeData(Map<String, dynamic> theme) {
    final next = Map<String, dynamic>.from(theme);
    final category = theme['category'];
    if (category is Map<String, dynamic>) {
      next['categoryId'] ??= category['id'];
      next['categoryTitle'] ??= category['title'];
      next['categorySubtitle'] ??= category['subtitle'];
    }
    return next;
  }

  List<Map<String, dynamic>> _themesForCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return const [];
    final filtered = _themes
        .whereType<Map<String, dynamic>>()
        .where((item) => item['categoryId']?.toString() == categoryId)
        .toList()
      ..sort((a, b) {
        final aOrder = (a['sortOrder'] as num?)?.toInt() ?? 0;
        final bOrder = (b['sortOrder'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });
    if (_query.trim().isEmpty) return filtered;
    final q = _query.trim().toLowerCase();
    return filtered.where((item) {
      final title = item['title']?.toString().toLowerCase() ?? '';
      final subtitle = item['subtitle']?.toString().toLowerCase() ?? '';
      return title.contains(q) || subtitle.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _searchThemes() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = _themes
        .whereType<Map<String, dynamic>>()
        .where((item) {
          final title = item['title']?.toString().toLowerCase() ?? '';
          final subtitle = item['subtitle']?.toString().toLowerCase() ?? '';
          return title.contains(q) || subtitle.contains(q);
        })
        .toList()
      ..sort((a, b) {
        final aOrder = (a['sortOrder'] as num?)?.toInt() ?? 0;
        final bOrder = (b['sortOrder'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });
    return results;
  }

  ({String? categoryId, List<String> themeIds}) _buildSelectionResult() {
    final allThemeIds = _themes
        .map((e) => e['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    // 전체: 모든 테마가 선택된 상태면 필터 없이 반환
    if (_selectedThemeIds.isEmpty || _selectedThemeIds.length == allThemeIds.length) {
      return (categoryId: null, themeIds: const []);
    }

    // 선택된 테마가 모두 같은 카테고리에 속하는지 확인
    String? categoryId;
    final selectedThemesByCategory = <String, List<String>>{};
    for (final item in _themes) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (!_selectedThemeIds.contains(id)) continue;
      final nextCategory = item['categoryId']?.toString();
      if (nextCategory == null || nextCategory.isEmpty) continue;
      selectedThemesByCategory.putIfAbsent(nextCategory, () => []).add(id);
    }
    if (selectedThemesByCategory.length == 1) {
      categoryId = selectedThemesByCategory.keys.first;
      final categoryThemeIds = _themesForCategory(categoryId)
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final selectedIds = _selectedThemeIds.toSet();
      if (selectedIds.length == categoryThemeIds.length &&
          selectedIds.containsAll(categoryThemeIds)) {
        // 해당 카테고리의 테마가 모두 선택됨: categoryId만 전달
        return (categoryId: categoryId, themeIds: const []);
      }
      return (categoryId: categoryId, themeIds: selectedIds.toList());
    }

    // 여러 카테고리 혼합 선택: themeIds만 전달
    return (categoryId: null, themeIds: _selectedThemeIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final searchResults =
        _query.trim().isNotEmpty ? _searchThemes() : const <Map<String, dynamic>>[];
    final displayThemes = _query.trim().isNotEmpty ? searchResults : _themes;
    final categoryTitles = <String, String>{
      for (final item in _themes)
        if ((item['categoryId']?.toString() ?? '').isNotEmpty)
          item['categoryId'].toString(): item['categoryTitle']?.toString() ?? '',
    };
    final allThemeIds = _themes
        .map((e) => e['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final isAllSelected =
        allThemeIds.isNotEmpty && _selectedThemeIds.length == allThemeIds.length;
    final height = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;
    final sheetHeight = isKeyboardVisible ? height : height * 0.75;
    return SafeArea(
      top: false,
      child: AnimatedContainer(
        height: sheetHeight,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        '필터',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const Spacer(),
                      CommonInkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(999),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Icon(
                              PhosphorIconsBold.x,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: CommonTextFieldView(
                    controller: _queryController,
                    focusNode: _queryFocusNode,
                    hintText: '테마 검색',
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    enableSuggestions: false,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 18,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                  const SizedBox(height: 12),
                  if (_query.trim().isNotEmpty && searchResults.isEmpty)
                    const CommonEmptyView(
                      message: '검색 결과가 없습니다.',
                      showButton: false,
                      height: 200,
                    )
                  else ...[
                    if (_query.trim().isNotEmpty) ...[
                      _BulkActionButton(
                        title: '결과만 선택',
                        onTap: () => setState(() {
                          _selectedId = null;
                          _selectedThemeIds
                            ..clear()
                            ..addAll(searchResults
                                .map((e) => e['id']?.toString())
                                .whereType<String>()
                                .where((id) => id.isNotEmpty));
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...displayThemes.map((theme) {
                      final id = theme['id']?.toString() ?? '';
                      final name = theme['title']?.toString() ?? '';
                      final categoryId = theme['categoryId']?.toString() ?? '';
                      final categoryTitle =
                          categoryTitles[categoryId]?.trim() ?? '';
                      final subtitle = categoryTitle.isNotEmpty
                          ? categoryTitle
                          : (theme['subtitle']?.toString() ?? '');
                      if (id.isEmpty || name.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final displayTitle = name;
                      final selected = _selectedThemeIds.contains(id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MapFilterThemeItemView(
                          title: displayTitle,
                          subtitle: subtitle,
                          selected: selected,
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedThemeIds.remove(id);
                            } else {
                              _selectedThemeIds.add(id);
                            }
                          }),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: CommonRoundedButton(
                      title: isAllSelected ? '전체해제' : '전체선택',
                      backgroundColor: const Color(0xFFF2F2F2),
                      textColor: Colors.black,
                      onTap: () => setState(() {
                        if (allThemeIds.isEmpty) return;
                        if (isAllSelected) {
                          _selectedThemeIds.clear();
                        } else {
                          _selectedThemeIds
                            ..clear()
                            ..addAll(allThemeIds);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 5,
                    child: CommonRoundedButton(
                      title: '적용 (${_selectedThemeIds.length})',
                      onTap: () {
                        final result = _buildSelectionResult();
                        Navigator.of(context).pop({
                          'categoryId': result.categoryId,
                          'themeIds': result.themeIds,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  const _BulkActionButton({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _CategoryAccordion extends StatelessWidget {
  const _CategoryAccordion({
    required this.title,
    required this.children,
    this.count,
    this.selectedCount,
    this.onSelectAll,
    this.onClearAll,
    this.initiallyExpanded = false,
    this.onHeaderTap,
  });

  final String title;
  final List<Widget> children;
  final int? count;
  final int? selectedCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearAll;
  final bool initiallyExpanded;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: (_) => onHeaderTap?.call(),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null && selectedCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAEA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${selectedCount!}/${count!}',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(
                PhosphorIconsRegular.caretDown,
                size: 16,
                color: Colors.black,
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: onSelectAll,
                  child: const Text(
                    '전체선택',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClearAll,
                  child: const Text(
                    '전체해제',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              selected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
              size: 16,
              color: selected ? Colors.black : const Color(0xFFBDBDBD),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.black : const Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
