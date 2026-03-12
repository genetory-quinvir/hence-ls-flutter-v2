import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_navigation_view.dart';

class AchievementView extends StatefulWidget {
  const AchievementView({super.key});

  @override
  State<AchievementView> createState() => _AchievementViewState();
}

class _AchievementViewState extends State<AchievementView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.fetchAchievements();
      final data = response['data'];
      List<Map<String, dynamic>> items = const [];
      if (data is List) {
        items = data.whereType<Map<String, dynamic>>().toList();
      } else if (data is Map<String, dynamic>) {
        final list = data['items'] ?? data['achievements'] ?? data['data'];
        if (list is List) {
          items = list.whereType<Map<String, dynamic>>().toList();
        }
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _resolveTitle(Map<String, dynamic> item) {
    for (final key in ['title', 'name', 'label']) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '업적';
  }

  String _resolveImageUrl(Map<String, dynamic> item) {
    final image = item['image'] ?? item['icon'] ?? item['thumbnail'];
    if (image is Map<String, dynamic>) {
      for (final key in ['cdnUrl', 'thumbnailUrl', 'fileUrl', 'url']) {
        final value = image[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    final direct = item['imageUrl']?.toString().trim() ?? '';
    return direct;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              CommonNavigationView(
                left: const Icon(
                  PhosphorIconsBold.caretLeft,
                  size: 24,
                  color: Colors.black,
                ),
                onLeftTap: () => Navigator.of(context).maybePop(),
                title: '나의 업적',
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CommonActivityIndicator(size: 28),
                      )
                    : _items.isEmpty
                        ? const Center(
                            child: CommonEmptyView(
                              message: '업적이 없습니다.',
                              showButton: false,
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 0,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final title = _resolveTitle(item);
                              final imageUrl = _resolveImageUrl(item);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipSmoothRect(
                                    radius: SmoothBorderRadius(
                                      cornerRadius: 18,
                                      cornerSmoothing: 1,
                                    ),
                                    child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                    ),
                                    child: ClipSmoothRect(
                                      radius: SmoothBorderRadius(
                                        cornerRadius: 18,
                                        cornerSmoothing: 1,
                                      ),
                                      child: imageUrl.isEmpty
                                          ? const Icon(
                                              PhosphorIconsBold.medal,
                                              size: 26,
                                              color: Color(0xFF9E9E9E),
                                            )
                                          : CommonImageView(
                                              networkUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              backgroundColor:
                                                  const Color(0xFFF5F5F5),
                                            ),
                                    ),
                                  ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
