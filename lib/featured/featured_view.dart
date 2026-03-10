import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_models.dart';
import '../common/auth/auth_store.dart';
import '../common/state/home_tab_controller.dart';
import '../common/network/api_client.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_place_list_item_view.dart';
import '../common/widgets/common_profile_image_view.dart';
import '../common/widgets/common_profile_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../placebook_collect/placebook_collect_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import '../sign/sign_view.dart';
import '../web/web_view.dart';

class FeaturedView extends StatefulWidget {
  const FeaturedView({super.key});

  @override
  State<FeaturedView> createState() => _FeaturedViewState();
}

class _FeaturedViewState extends State<FeaturedView> {
  late Future<Map<String, dynamic>> _featuredFuture;
  Map<String, dynamic>? _featuredData;
  bool _isRefreshing = false;
  static const double _kTabBarHeight = 50;

  @override
  void initState() {
    super.initState();
    _featuredFuture = _requestFeatured();
  }

  Future<Map<String, dynamic>> _requestFeatured() async {
    double? latitude;
    double? longitude;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final granted = await LocationPermissionService.isGranted();
      if (serviceEnabled && granted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }
    } on Exception {
      // Ignore location failures and fall back to non-location request.
    }
    return ApiClient.fetchFeatured(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _reloadFeatured() async {
    setState(() => _isRefreshing = true);
    try {
      final data = await _requestFeatured();
      if (!mounted) return;
      setState(() {
        _featuredData = data;
        _featuredFuture = Future.value(data);
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _removeFeaturedPlace(String placeId) {
    if (placeId.isEmpty || _featuredData == null) return;
    final root = _featuredData!;
    final data = root['data'];
    if (data is! Map<String, dynamic>) return;
    final themes = data['themes'];
    if (themes is! List) return;
    var changed = false;
    final nextThemes = themes.map((entry) {
      if (entry is! Map<String, dynamic>) return entry;
      final places = entry['places'];
      if (places is! List) return entry;
      final filtered = places.where((raw) {
        if (raw is! Map<String, dynamic>) return true;
        final id = _featuredPlaceId(raw);
        return id != placeId;
      }).toList();
      if (filtered.length != places.length) {
        changed = true;
        return {
          ...entry,
          'places': filtered,
        };
      }
      return entry;
    }).toList();
    if (!changed) return;
    setState(() {
      _featuredData = {
        ...root,
        'data': {
          ...data,
          'themes': nextThemes,
        },
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _featuredFuture,
          builder: (context, snapshot) {
            if (!_isRefreshing) {
              if (snapshot.hasData) {
                _featuredData = snapshot.data;
              } else if (snapshot.connectionState != ConnectionState.done &&
                  _featuredData == null) {
                return const Center(
                  child: CommonActivityIndicator(size: 28),
                );
              }
            }
            final data = _featuredData?['data'];
            final banners = data is Map<String, dynamic>
                ? (data['banners'] as List<dynamic>?) ?? const []
                : const [];
            final themes = data is Map<String, dynamic>
                ? (data['themes'] as List<dynamic>?) ?? const []
                : const [];
            final nearestPlaces = data is Map<String, dynamic>
                ? (data['nearestPlaces'] as List<dynamic>?) ?? const []
                : const [];
            final bottomInset = MediaQuery.of(context).padding.bottom;
            return CommonRefreshView(
              onRefresh: _reloadFeatured,
              topPadding: 16,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.vertical,
              child: ListView(
                padding:
                    EdgeInsets.fromLTRB(0, 16, 0, _kTabBarHeight + bottomInset),
                children: [
                  const _FeaturedHeader(),
                  const SizedBox(height: 14),
                  _FeaturedBannerSection(items: banners),
                  const _FeaturedSingleCardBannerSection(),
                  if (nearestPlaces.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _FeaturedNearestPlacesSection(
                      places: nearestPlaces
                          .whereType<Map<String, dynamic>>()
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ...themes.map((entry) {
                    final item = entry is Map<String, dynamic>
                        ? entry
                        : <String, dynamic>{};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _FeaturedThemeSection(
                        item: item,
                        onPlaceDeleted: _removeFeaturedPlace,
                      ),
                    );
                  }).toList(),
                  if (themes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _FeaturedEmptySection(
                        title: '표시할 테마가 없습니다.',
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeaturedBannerSection extends StatelessWidget {
  const _FeaturedBannerSection({
    required this.items,
  });

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final banner = items[index] is Map<String, dynamic>
                  ? items[index] as Map<String, dynamic>
                  : <String, dynamic>{};
              return _FeaturedBannerCard(item: banner);
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedSingleCardBannerSection extends StatelessWidget {
  const _FeaturedSingleCardBannerSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x14000000)),
        ),
      ),
    );
  }
}

class _FeaturedNearestPlacesSection extends StatelessWidget {
  const _FeaturedNearestPlacesSection({
    required this.places,
  });

  final List<Map<String, dynamic>> places;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 근처에는 이런 장소가 있어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: places.map((place) {
              final title = (place['title'] as String?) ?? '장소';
              final address = (place['address'] as String?) ?? '';
              final commentCount =
                  (place['commentCount'] as num?)?.toInt() ?? 0;
              final likeCount = (place['likeCount'] as num?)?.toInt() ?? 0;
              final favorited = (place['favorited'] as bool?) ??
                  (place['isFavorited'] as bool?) ??
                  false;
              final themeText = _placeThemeTitle(place);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CommonPlaceListItemView(
                  thumbnailUrl: _placeImageUrl(place),
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
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FeaturedHeader extends StatelessWidget {
  const _FeaturedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ValueListenableBuilder<AuthUser?>(
        valueListenable: AuthStore.instance.currentUser,
        builder: (context, user, _) {
          final isSignedIn = user != null && user.id.isNotEmpty;
          final nickname = user?.nickname.trim() ?? '';
          return Row(
            children: [
              Expanded(
                child: isSignedIn
                    ? (nickname.isNotEmpty
                        ? Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$nickname님,\n',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                                const TextSpan(
                                  text: '안녕하세요 👋🏻',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Text(
                            '안녕하세요',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ))
                    : Text.rich(
                        TextSpan(
                          children: const [
                            TextSpan(
                              text: '지금 로그인하고',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: '\n더 많은 정보를 얻어보세요!',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (isSignedIn)
                CommonInkWell(
                  onTap: () => HomeTabController.switchTo(4),
                  borderRadius: BorderRadius.circular(999),
                  child: CommonProfileView(
                    size: 48,
                    networkUrl: user?.profileImageUrl,
                    placeholder: Container(
                      color: const Color(0xFFF2F2F2),
                      alignment: Alignment.center,
                      child: const Icon(
                        PhosphorIconsRegular.user,
                        size: 24,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 40,
                  child: CommonRoundedButton(
                    title: '로그인하기',
                    height: 40,
                    radius: 8,
                    backgroundColor: const Color(0xFFF2F2F2),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                    onTap: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (_) => const SizedBox.expand(
                          child: SignView(),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeaturedBannerCard extends StatelessWidget {
  const _FeaturedBannerCard({
    required this.item,
  });

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String?) ?? '';
    final subtitle = (item['subtitle'] as String?) ?? '';
    final imageUrl = _bannerImageUrl(item);
    final linkUrl = (item['linkUrl'] as String?) ?? '';
    final hasLink = linkUrl.trim().isNotEmpty;
    return CommonInkWell(
      onTap: hasLink
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WebViewPage(title: title, url: linkUrl),
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CommonImageView(
                networkUrl: imageUrl,
                fit: BoxFit.cover,
                backgroundColor: const Color(0xFF1E1E1E),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE0E0E0),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '지금 보기',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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

class _FeaturedThemeSection extends StatelessWidget {
  const _FeaturedThemeSection({
    required this.item,
    required this.onPlaceDeleted,
  });

  final Map<String, dynamic> item;
  final ValueChanged<String> onPlaceDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = item['theme'] is Map<String, dynamic>
        ? item['theme'] as Map<String, dynamic>
        : <String, dynamic>{};
    final places = item['places'] as List<dynamic>? ?? const [];
    final title = (theme['title'] as String?) ?? '테마';
    final description = (theme['description'] as String?) ??
        (theme['subtitle'] as String?) ??
        '';
    final themeId = (theme['id'] as String?) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CommonInkWell(
                  onTap: themeId.trim().isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlacebookCollectView(
                                themeId: themeId,
                                themeTitle: title,
                              ),
                            ),
                          );
                        },
                  child: Column(
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
                      if (description.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E8E),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (themeId.trim().isNotEmpty)
                CommonInkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlacebookCollectView(
                          themeId: themeId,
                          themeTitle: title,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: const [
                      Text(
                        '더보기',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 14,
                        color: Color(0xFF9E9E9E),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (places.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _FeaturedEmptySection(
              title: '표시할 장소가 없습니다.',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: places.map((raw) {
                final place = raw is Map<String, dynamic>
                    ? raw
                    : <String, dynamic>{};
                final placeTitle = (place['title'] as String?) ?? '장소';
                final placeAddress = (place['address'] as String?) ?? '';
                final commentCount =
                    (place['commentCount'] as num?)?.toInt() ?? 0;
                final likeCount = (place['likeCount'] as num?)?.toInt() ?? 0;
                final favorited = (place['favorited'] as bool?) ??
                    (place['isFavorited'] as bool?) ??
                    false;
                return CommonPlaceListItemView(
                  thumbnailUrl: _placeImageUrl(place),
                  title: placeTitle,
                  address: placeAddress,
                  commentCount: commentCount,
                  likeCount: likeCount,
                  themeText: title,
                  favorited: favorited,
                  onTap: () async {
                    final deleted = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlacebookDetailView(space: place),
                      ),
                    );
                    if (deleted == true) {
                      final placeId = _featuredPlaceId(place);
                      if (placeId.isNotEmpty) {
                        onPlaceDeleted(placeId);
                      }
                    }
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _FeaturedEmptySection extends StatelessWidget {
  const _FeaturedEmptySection({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF9E9E9E),
        ),
      ),
    );
  }
}

String _bannerImageUrl(Map<String, dynamic> banner) {
  final onImage = banner['onImage'];
  final offImage = banner['offImage'];
  final onMap = onImage is Map<String, dynamic> ? onImage : null;
  final offMap = offImage is Map<String, dynamic> ? offImage : null;
  return (onMap?['thumbnailUrl'] as String?) ??
      (onMap?['cdnUrl'] as String?) ??
      (onMap?['fileUrl'] as String?) ??
      (offMap?['thumbnailUrl'] as String?) ??
      (offMap?['cdnUrl'] as String?) ??
      (offMap?['fileUrl'] as String?) ??
      '';
}

String _featuredPlaceId(Map<String, dynamic> place) {
  final id = place['id'] ?? place['placeId'];
  if (id is String) return id;
  return id?.toString() ?? '';
}

String _placeThemeTitle(Map<String, dynamic> place) {
  final theme = place['theme'];
  if (theme is Map<String, dynamic>) {
    final title = theme['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }
  }
  return '';
}

String _placeImageUrl(Map<String, dynamic> place) {
  final image = place['image'];
  final imageMap = image is Map<String, dynamic> ? image : null;
  return (place['thumbnailUrl'] as String?) ??
      (place['imageUrl'] as String?) ??
      (imageMap?['thumbnailUrl'] as String?) ??
      (imageMap?['cdnUrl'] as String?) ??
      (imageMap?['fileUrl'] as String?) ??
      '';
}
