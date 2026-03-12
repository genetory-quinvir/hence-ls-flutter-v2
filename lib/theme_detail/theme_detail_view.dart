import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_navigation_view.dart';
import '../placebook_list/placebook_list_view.dart';

class ThemeDetailView extends StatefulWidget {
  const ThemeDetailView({
    super.key,
    required this.themeId,
    required this.themeTitle,
  });

  final String themeId;
  final String themeTitle;

  @override
  State<ThemeDetailView> createState() => _ThemeDetailViewState();
}

class _ThemeDetailViewState extends State<ThemeDetailView> {
  Map<String, dynamic> _themeEntry = const {};
  bool _loadingHeader = true;

  @override
  void initState() {
    super.initState();
    _loadThemeHeader();
  }

  Future<void> _loadThemeHeader() async {
    try {
      final response = await ApiClient.fetchPlacebookHome();
      final data = response['data'];
      final allThemes = data is Map<String, dynamic> ? data['allThemes'] : null;
      if (allThemes is List) {
        for (final item in allThemes.whereType<Map<String, dynamic>>()) {
          final theme = item['theme'];
          final id = theme is Map<String, dynamic>
              ? theme['id']?.toString()
              : item['id']?.toString();
          if (id == widget.themeId) {
            if (!mounted) return;
            setState(() {
              _themeEntry = item;
              _loadingHeader = false;
            });
            return;
          }
        }
      }
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() => _loadingHeader = false);
  }

  Map<String, dynamic> get _theme {
    final theme = _themeEntry['theme'];
    if (theme is Map<String, dynamic>) return theme;
    return const {};
  }

  int get _savedCount => (_themeEntry['savedCount'] as num?)?.toInt() ?? 0;

  String get _categoryTitle {
    final category = _theme['category'];
    if (category is Map<String, dynamic>) {
      return (category['title'] ?? '').toString();
    }
    return '';
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
              title: widget.themeTitle,
            ),
            Expanded(
              child: PlacebookListView(
                themeId: widget.themeId,
                themeTitle: widget.themeTitle,
                showNavigation: false,
                headerScrollable: true,
                scrollHeader: _loadingHeader
                    ? const SizedBox(
                        height: 98,
                        child: Center(
                          child: CommonActivityIndicator(size: 22),
                        ),
                      )
                    : _ThemeInfoCard(
                        title: (_theme['title'] ?? widget.themeTitle).toString(),
                        categoryTitle: _categoryTitle,
                        savedCount: _savedCount,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeInfoCard extends StatelessWidget {
  const _ThemeInfoCard({
    required this.title,
    required this.categoryTitle,
    required this.savedCount,
  });

  final String title;
  final String categoryTitle;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryTitle.isNotEmpty)
            Text(
              categoryTitle,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF757575),
              ),
            ),
          if (categoryTitle.isNotEmpty) const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$savedCount',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const TextSpan(
                      text: '개 저장됨',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
