import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hence_ls_flutter_v2/main.dart';
import 'package:hence_ls_flutter_v2/placebook_create/placebook_create_view.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_models.dart';
import '../common/auth/auth_store.dart';
import '../common/state/home_tab_controller.dart';
import '../common/network/api_client.dart';
import '../common/permissions/location_permission_service.dart';
import '../common/styles/app_shadows.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_alert_view.dart';
import '../common/widgets/common_place_list_item_view.dart';
import '../common/widgets/common_place_carousel_list_item_view.dart';
import '../common/widgets/common_profile_view.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_user_list_item.dart';
import '../category_detail/category_detail_view.dart';
import '../placebook_list/placebook_list_view.dart';
import '../placebook_detail/placebook_detail_view.dart';
import '../profile_info/profile_info_view.dart';
import '../profile/models/profile_display_user.dart';
import '../search/search_view.dart';
import '../sign/sign_view.dart';

class FeaturedView extends StatefulWidget {
  const FeaturedView({super.key});

  @override
  State<FeaturedView> createState() => _FeaturedViewState();
}

class _FeaturedViewState extends State<FeaturedView> {
  static const double _fallbackLatitude = 37.4979;
  static const double _fallbackLongitude = 127.0276;
  late Future<Map<String, dynamic>> _featuredFuture;
  Map<String, dynamic>? _featuredData;
  bool _isRefreshing = false;
  static const double _kTabBarHeight = 50;
  double? _lastLatitude;
  double? _lastLongitude;
  int _featuredRequestCount = 0;
  bool _didLogInitialRenderPerf = false;
  DateTime? _lastFeaturedSuccessAt;
  bool _didBackgroundPreciseRefresh = false;

  @override
  void initState() {
    super.initState();
    _featuredFuture = _requestFeatured();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWithPreciseLocationInBackground();
    });
  }

  Future<Map<String, dynamic>> _requestFeatured({
    bool forceRefresh = false,
    bool preferPreciseLocation = false,
  }) async {
    _featuredRequestCount += 1;
    debugPrint('[PERF][FEATURED] request_count=$_featuredRequestCount');
    double? latitude;
    double? longitude;
    try {
      if (_lastLatitude != null && _lastLongitude != null) {
        latitude = _lastLatitude;
        longitude = _lastLongitude;
      } else {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        final granted = await LocationPermissionService.isGranted();
        if (serviceEnabled && granted) {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            latitude = lastKnown.latitude;
            longitude = lastKnown.longitude;
          } else if (preferPreciseLocation) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 2),
              ),
            );
            latitude = position.latitude;
            longitude = position.longitude;
          }
          _lastLatitude = latitude;
          _lastLongitude = longitude;
        }
      }
    } on Exception {
      // Ignore location failures and fall back to non-location request.
    }
    latitude ??= _fallbackLatitude;
    longitude ??= _fallbackLongitude;
    _lastLatitude ??= latitude;
    _lastLongitude ??= longitude;
    try {
      final data =
          await ApiClient.fetchFeatured(
            latitude: latitude,
            longitude: longitude,
            forceRefresh: forceRefresh,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => <String, dynamic>{},
          );
      if (data.isNotEmpty) {
        _lastFeaturedSuccessAt = DateTime.now();
      }
      return data;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _refreshWithPreciseLocationInBackground() async {
    if (!mounted || _didBackgroundPreciseRefresh) return;
    _didBackgroundPreciseRefresh = true;
    final data = await _requestFeatured(
      forceRefresh: true,
      preferPreciseLocation: true,
    );
    if (!mounted || data.isEmpty) return;
    setState(() {
      _featuredData = data;
      _featuredFuture = Future.value(data);
    });
  }

  Future<void> _reloadFeatured() async {
    setState(() => _isRefreshing = true);
    try {
      final data = await _requestFeatured(
        forceRefresh: true,
        preferPreciseLocation: true,
      );
      if (!mounted) return;
      setState(() {
        if (data.isNotEmpty) {
          _featuredData = data;
          _lastFeaturedSuccessAt = DateTime.now();
        }
        _featuredFuture = Future.value(_featuredData ?? data);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastFeaturedSuccessAt == null) return;
        final frameMs = DateTime.now()
            .difference(_lastFeaturedSuccessAt!)
            .inMilliseconds;
        debugPrint('[PERF][FEATURED] api_to_frame_ms=$frameMs source=refresh');
      });
    } catch (_) {
      // Keep current data when refresh fails.
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _removeFeaturedPlace(String placeId) {
    if (placeId.isEmpty || _featuredData == null) return;
    final root = _featuredData!;
    final data = root['data'] is Map<String, dynamic>
        ? root['data'] as Map<String, dynamic>
        : root;
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
        return {...entry, 'places': filtered};
      }
      return entry;
    }).toList();
    if (!changed) return;
    setState(() {
      if (root['data'] is Map<String, dynamic>) {
        _featuredData = {
          ...root,
          'data': {...data, 'themes': nextThemes},
        };
      } else {
        _featuredData = {...data, 'themes': nextThemes};
      }
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
                _lastFeaturedSuccessAt ??= DateTime.now();
              } else if (snapshot.connectionState != ConnectionState.done &&
                  _featuredData == null) {
                return const Center(child: CommonActivityIndicator(size: 28));
              }
            }
            Map<String, dynamic>? data;
            final raw = _featuredData;
            if (raw is Map<String, dynamic>) {
              final nested = raw['data'];
              if (nested is Map<String, dynamic>) {
                data = nested;
              } else {
                data = raw;
              }
            }
            final banners = data is Map<String, dynamic>
                ? (data['banners'] as List<dynamic>?) ?? const []
                : const [];
            final themes = data is Map<String, dynamic>
                ? (data['themes'] as List<dynamic>?) ?? const []
                : const [];
            final nearbyPlaces = data is Map<String, dynamic>
                ? _extractFeaturedNearbyPlaces(data)
                : const <Map<String, dynamic>>[];
            final topEngagedPlaces = data is Map<String, dynamic>
                ? (data['topEngagedPlaces'] as List<dynamic>?) ?? const []
                : const [];
            final rankingUsers = data is Map<String, dynamic>
                ? (data['rankingUsers'] as List<dynamic>?) ?? const []
                : const [];
            final categories = data is Map<String, dynamic>
                ? ((data['categories'] as List<dynamic>?) ?? const [])
                      .whereType<Map<String, dynamic>>()
                      .where((item) => item['isActive'] != false)
                      .toList(growable: false)
                : const <Map<String, dynamic>>[];
            categories.sort((a, b) {
              final aOrder = (a['sortOrder'] as num?)?.toInt() ?? 0;
              final bOrder = (b['sortOrder'] as num?)?.toInt() ?? 0;
              if (aOrder != bOrder) return aOrder.compareTo(bOrder);
              final aTitle = (a['title'] ?? '').toString().toLowerCase();
              final bTitle = (b['title'] ?? '').toString().toLowerCase();
              return aTitle.compareTo(bTitle);
            });
            final bottomInset = MediaQuery.of(context).padding.bottom;
            if (!_didLogInitialRenderPerf && snapshot.hasData) {
              _didLogInitialRenderPerf = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _lastFeaturedSuccessAt == null) return;
                final frameMs = DateTime.now()
                    .difference(_lastFeaturedSuccessAt!)
                    .inMilliseconds;
                debugPrint(
                  '[PERF][FEATURED] api_to_frame_ms=$frameMs source=initial',
                );
              });
            }
            return CommonRefreshView(
              onRefresh: _reloadFeatured,
              topPadding: 16,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.vertical,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  16,
                  0,
                  _kTabBarHeight + bottomInset,
                ),
                children: [
                  _FeaturedHeader(
                    onSearchTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchView(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _FeaturedBannerSection(items: banners),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _FeaturedCategorySection(items: categories),
                  ],
                  const SizedBox(height: 32),
                  _FeaturedNearestPlacesSection(
                    places: nearbyPlaces,
                    latitude: _lastLatitude,
                    longitude: _lastLongitude,
                  ),
                  if (rankingUsers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _FeaturedRankingSection(
                        items: rankingUsers
                            .whereType<Map<String, dynamic>>()
                            .toList(),
                      ),
                    ),
                  _FeaturedTopEngagedPlacesSection(
                    places: topEngagedPlaces
                        .whereType<Map<String, dynamic>>()
                        .toList(),
                  ),
                  const _FeaturedSingleCardBannerSection(
                    title: '장소를 등록하고 친구들과 공유해보세요',
                    subtitle: '장소를 등록하고 친구들과 공유해보세요',
                  ),
                  const SizedBox(height: 32),
                  ...themes.map((entry) {
                    final item = entry is Map<String, dynamic>
                        ? entry
                        : <String, dynamic>{};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _FeaturedThemeSection(
                        item: item,
                        onPlaceDeleted: _removeFeaturedPlace,
                        latitude: _lastLatitude,
                        longitude: _lastLongitude,
                      ),
                    );
                  }),
                  if (themes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _FeaturedEmptySection(title: '표시할 테마가 없습니다.'),
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
  const _FeaturedBannerSection({required this.items});

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
            separatorBuilder: (_, _) => const SizedBox(width: 16),
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

class _FeaturedRankingSection extends StatelessWidget {
  const _FeaturedRankingSection({required this.items});

  final List<Map<String, dynamic>> items;

  String _resolveName(Map<String, dynamic> user) {
    final name = (user['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final nickname = (user['nickname'] ?? '').toString().trim();
    if (nickname.isNotEmpty) return nickname;
    return '사용자';
  }

  String? _resolveSubtitle(Map<String, dynamic> user) {
    final rawCount =
        user['createdPlaceCount'] ??
        user['placeCreatedCount'] ??
        user['createdPlacesCount'];
    final count = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '');
    final createdText = count != null ? '저장한 장소 $count' : null;
    if (createdText != null) return createdText;
    final info = user['representativeTitleInfo'];
    if (info is Map<String, dynamic>) {
      final rawTitle = (info['name'] ?? '').toString().trim();
      if (rawTitle.isNotEmpty) return rawTitle;
    }
    return null;
  }

  String? _resolveImageUrl(Map<String, dynamic> user) {
    final profile = user['profileImage'];
    if (profile is Map<String, dynamic>) {
      return (profile['cdnUrl'] ??
              profile['thumbnailUrl'] ??
              profile['fileUrl'])
          ?.toString();
    }
    return user['profileImageUrl']?.toString();
  }

  String? _resolvePointsText(Map<String, dynamic> user) {
    final raw =
        user['rewardScore'] ?? user['point'] ?? user['points'] ?? user['score'];
    if (raw is num) {
      return '${raw.toInt()}P';
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final parsed = int.tryParse(trimmed);
      return parsed != null ? '${parsed}P' : trimmed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final top5 = items.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '장소 전문가 Top5',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...top5.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          final userId = (user['id'] ?? user['userId'] ?? '').toString().trim();
          return CommonUserListItem(
            rank: index + 1,
            title: _resolveName(user),
            subtitle: _resolveSubtitle(user),
            imageUrl: _resolveImageUrl(user),
            pointsText: _resolvePointsText(user),
            onTap: userId.isEmpty
                ? null
                : () {
                    showCupertinoModalPopup<void>(
                      context: context,
                      builder: (_) => ProfileInfoView(
                        user: ProfileDisplayUser.fromJson(user),
                      ),
                    );
                  },
          );
        }),
      ],
    );
  }
}

class _FeaturedSingleCardBannerSection extends StatelessWidget {
  const _FeaturedSingleCardBannerSection({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 156,
        decoration: ShapeDecoration(
          color: const Color(0xFFF2F2F2),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(48),
            side: const BorderSide(color: Color(0x14000000)),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 180,
                child: Image.asset(
                  'assets/images/img_my_place.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF0E0E0E),
                        const Color(0xFF0E0E0E),
                        const Color(0x000E0E0E),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8E8E8E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (_) => const SizedBox.expand(
                            child: PlacebookCreateView(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        backgroundColor: MyApp.primary200,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        textStyle: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text(
                        '지금 장소 등록하기',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedNearestPlacesSection extends StatelessWidget {
  const _FeaturedNearestPlacesSection({
    required this.places,
    this.latitude,
    this.longitude,
  });

  final List<Map<String, dynamic>> places;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '내 근처에는 이런 장소가 있어요',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              CommonInkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlacebookListView(
                        latitude: latitude,
                        longitude: longitude,
                        orderBy: 'distance',
                        themeTitle: '내 근처에는 이런 장소가 있어요',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: const [
                    Text(
                      '더보기',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
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
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '지금 가장 핫한 장소는 어딜까요?',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (places.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CommonEmptyView(
              message: '근처에 등록된 장소가 없습니다.',
              showButton: false,
              height: 140,
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final place = places[index];
                final title = (place['title'] as String?) ?? '장소';
                final address = _placeAddress(place);
                final commentCount =
                    (place['commentCount'] as num?)?.toInt() ?? 0;
                final likeCount = (place['likeCount'] as num?)?.toInt() ?? 0;
                final favorited =
                    (place['favorited'] as bool?) ??
                    (place['isFavorited'] as bool?) ??
                    false;
                final distanceKm = place['distanceKm'];
                final distanceText = distanceKm is num
                    ? '${distanceKm.toStringAsFixed(distanceKm < 1 ? 2 : 1)}km'
                    : null;
                final themeText = _placeThemeTitle(place);
                return SizedBox(
                  width: 320,
                  child: CommonPlaceCarouselListItemView(
                    thumbnailUrl: _placeImageUrl(place),
                    title: title,
                    address: address,
                    commentCount: commentCount,
                    likeCount: likeCount,
                    themeText: themeText,
                    distanceText: distanceText,
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
              },
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FeaturedTopEngagedPlacesSection extends StatelessWidget {
  const _FeaturedTopEngagedPlacesSection({required this.places});

  final List<Map<String, dynamic>> places;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '지금 가장 핫한 장소는 어딜까요?',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (places.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CommonEmptyView(message: '표시할 장소가 없습니다.', showButton: false),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final place = places[index];
                final title = (place['title'] as String?) ?? '장소';
                final address = _placeAddress(place);
                final commentCount =
                    (place['commentCount'] as num?)?.toInt() ?? 0;
                final likeCount =
                    (place['helpfulCount'] as num?)?.toInt() ??
                    (place['verificationCount'] as num?)?.toInt() ??
                    0;
                final favorited =
                    (place['favorited'] as bool?) ??
                    (place['isFavorited'] as bool?) ??
                    false;
                final distanceKm = place['distanceKm'];
                final distanceText = distanceKm is num
                    ? '${distanceKm.toStringAsFixed(distanceKm < 1 ? 2 : 1)}km'
                    : null;
                final themeText = _placeThemeTitle(place);
                return SizedBox(
                  width: 320,
                  child: CommonPlaceCarouselListItemView(
                    thumbnailUrl: _placeImageUrl(place),
                    title: title,
                    address: address,
                    commentCount: commentCount,
                    likeCount: likeCount,
                    themeText: themeText,
                    distanceText: distanceText,
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
              },
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FeaturedCategorySection extends StatelessWidget {
  const _FeaturedCategorySection({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final category = items[index];
              final title = (category['title'] ?? '').toString().trim();
              final categoryId = (category['id'] ?? '').toString();
              final subtitle = (category['subtitle'] ?? '').toString();
              final sortOrder = (category['sortOrder'] as num?)?.toInt();
              final imageIndex = sortOrder != null
                  ? (sortOrder - 1).clamp(0, 5)
                  : (index % 6);
              final safeTitle = title.isEmpty ? '카테고리' : title;
              return CommonInkWell(
                onTap: categoryId.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CategoryDetailView(
                              categoryId: categoryId,
                              categoryTitle: safeTitle,
                              categorySubtitle: subtitle,
                            ),
                          ),
                        );
                      },
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Image.asset(
                            'assets/images/img_category_$imageIndex.webp',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        safeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedHeader extends StatelessWidget {
  const _FeaturedHeader({
    required this.onSearchTap,
  });

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ValueListenableBuilder<AuthUser?>(
        valueListenable: AuthStore.instance.currentUser,
        builder: (context, user, _) {
          final isSignedIn = user != null && user.id.isNotEmpty;
          final nickname = user?.nickname.trim() ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                                        text: '오늘은 어디를 가볼까요?',
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
                        networkUrl: user.profileImageUrl,
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF424242),
                        ),
                        onTap: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (_) =>
                                const SizedBox.expand(child: SignView()),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              CommonInkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 20,
                        color: Color(0xFF8E8E93),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '장소를 검색해보세요',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
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
  const _FeaturedBannerCard({required this.item});

  final Map<String, dynamic> item;

  void _showPreparingAlert(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      builder: (_) {
        return Material(
          type: MaterialType.transparency,
          child: CommonAlertView(
            title: '준비중입니다.',
            subTitle: '곧 만나보실 수 있어요.',
            primaryButtonTitle: '확인',
            onPrimaryTap: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String?) ?? '';
    final subtitle = (item['subtitle'] as String?) ?? '';
    final imageUrl = _bannerImageUrl(item);
    return CommonInkWell(
      onTap: () => _showPreparingAlert(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CommonImageView(
                networkUrl: imageUrl,
                fit: BoxFit.cover,
                replayNetworkFade: true,
                backgroundColor: const Color(0xFF1E1E1E),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.58),
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.0, 0.46, 1.0],
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
                    const SizedBox(height: 2),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '지금 보기',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
    this.latitude,
    this.longitude,
  });

  final Map<String, dynamic> item;
  final ValueChanged<String> onPlaceDeleted;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final theme = item['theme'] is Map<String, dynamic>
        ? item['theme'] as Map<String, dynamic>
        : <String, dynamic>{};
    final places = item['places'] as List<dynamic>? ?? const [];
    final title = (theme['title'] as String?) ?? '테마';
    final description =
        (theme['description'] as String?) ??
        (theme['subtitle'] as String?) ??
        '';
    final themeId = (theme['id'] as String?) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
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
                              builder: (_) => PlacebookListView(
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
                          fontSize: 20,
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
                        builder: (_) => PlacebookListView(
                          themeId: themeId,
                          themeTitle: title,
                          latitude: latitude,
                          longitude: longitude,
                          orderBy: 'distance',
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
                          fontWeight: FontWeight.w400,
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
            child: _FeaturedEmptySection(title: '표시할 장소가 없습니다.'),
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
                final placeAddress = _placeAddress(place);
                final commentCount =
                    (place['commentCount'] as num?)?.toInt() ?? 0;
                final likeCount = (place['likeCount'] as num?)?.toInt() ?? 0;
                final favorited =
                    (place['favorited'] as bool?) ??
                    (place['isFavorited'] as bool?) ??
                    false;
                final distanceKm = place['distanceKm'];
                final distanceText = distanceKm is num
                    ? '${distanceKm.toStringAsFixed(distanceKm < 1 ? 2 : 1)}km'
                    : null;
                return CommonPlaceListItemView(
                  thumbnailUrl: _placeImageUrl(place),
                  title: placeTitle,
                  address: placeAddress,
                  commentCount: commentCount,
                  likeCount: likeCount,
                  themeText: title,
                  distanceText: distanceText,
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
  const _FeaturedEmptySection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 160,
              child: Image.asset(
                'assets/images/img_my_place.webp',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFFF5F5F5),
                      const Color(0xFFF5F5F5),
                      const Color(0x00F5F5F5),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _bannerImageUrl(Map<String, dynamic> banner) {
  final onImage = banner['onImage'];
  final offImage = banner['offImage'];
  final thumbnail = banner['thumbnail'];
  final image = banner['image'];
  final onMap = onImage is Map<String, dynamic> ? onImage : null;
  final offMap = offImage is Map<String, dynamic> ? offImage : null;
  final thumbnailMap = thumbnail is Map<String, dynamic> ? thumbnail : null;
  final imageMap = image is Map<String, dynamic> ? image : null;
  final thumbnailString = thumbnail is String ? thumbnail.trim() : null;
  final imageString = image is String ? image.trim() : null;
  return (onMap?['cdnUrl'] as String?) ??
      (onMap?['fileUrl'] as String?) ??
      (onMap?['thumbnailUrl'] as String?) ??
      (offMap?['cdnUrl'] as String?) ??
      (offMap?['fileUrl'] as String?) ??
      (offMap?['thumbnailUrl'] as String?) ??
      (imageMap?['cdnUrl'] as String?) ??
      (imageMap?['fileUrl'] as String?) ??
      (imageMap?['thumbnailUrl'] as String?) ??
      (thumbnailMap?['cdnUrl'] as String?) ??
      (thumbnailMap?['fileUrl'] as String?) ??
      (thumbnailMap?['thumbnailUrl'] as String?) ??
      (banner['imageUrl'] as String?) ??
      (banner['thumbnailUrl'] as String?) ??
      ((thumbnailString?.isNotEmpty ?? false) ? thumbnailString : null) ??
      ((imageString?.isNotEmpty ?? false) ? imageString : null) ??
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
  final themeTitle = place['themeTitle'];
  if (themeTitle is String && themeTitle.trim().isNotEmpty) {
    return themeTitle.trim();
  }
  return '';
}

String _placeAddress(Map<String, dynamic> place) {
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

String _placeImageUrl(Map<String, dynamic> place) {
  String? pickFromMap(Map<String, dynamic>? map) {
    return map?['thumbnailUrl'] as String? ??
        map?['cdnUrl'] as String? ??
        map?['fileUrl'] as String? ??
        map?['url'] as String?;
  }

  final thumbnail = place['thumbnail'];
  if (thumbnail is String && thumbnail.trim().isNotEmpty) {
    return thumbnail.trim();
  }
  if (thumbnail is Map<String, dynamic>) {
    final value = pickFromMap(thumbnail);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }

  final thumbnailUrlRaw = place['thumbnailUrl'];
  if (thumbnailUrlRaw is String && thumbnailUrlRaw.trim().isNotEmpty) {
    return thumbnailUrlRaw.trim();
  }
  if (thumbnailUrlRaw is Map<String, dynamic>) {
    final value = pickFromMap(thumbnailUrlRaw);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }

  final thumbnailImage = place['thumbnailImage'];
  if (thumbnailImage is String && thumbnailImage.trim().isNotEmpty) {
    return thumbnailImage.trim();
  }
  if (thumbnailImage is Map<String, dynamic>) {
    final value = pickFromMap(thumbnailImage);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }

  final imageUrl = place['imageUrl'];
  if (imageUrl is String && imageUrl.trim().isNotEmpty) {
    return imageUrl.trim();
  }

  final image = place['image'];
  if (image is String && image.trim().isNotEmpty) {
    return image.trim();
  }
  if (image is Map<String, dynamic>) {
    final value = pickFromMap(image);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }

  final representative = place['representativeImage'];
  if (representative is String && representative.trim().isNotEmpty) {
    return representative.trim();
  }
  if (representative is Map<String, dynamic>) {
    final value = pickFromMap(representative);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }

  final imageCandidates = <dynamic>[
    place['mainImageUrl'],
    place['coverImageUrl'],
    place['thumbnailImageUrl'],
    place['representativeImageUrl'],
  ];
  for (final candidate in imageCandidates) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }

  final thumbnailUrls = place['thumbnailUrls'];
  if (thumbnailUrls is List) {
    for (final entry in thumbnailUrls) {
      if (entry is String && entry.trim().isNotEmpty) {
        return entry.trim();
      }
      if (entry is Map<String, dynamic>) {
        final value = pickFromMap(entry);
        if (value != null && value.trim().isNotEmpty) return value.trim();
      }
    }
  }

  final images = place['images'];
  if (images is List) {
    for (final entry in images) {
      if (entry is String && entry.trim().isNotEmpty) {
        return entry.trim();
      }
      if (entry is Map<String, dynamic>) {
        final value = pickFromMap(entry);
        if (value != null && value.trim().isNotEmpty) return value.trim();
      }
    }
  }

  return '';
}

List<Map<String, dynamic>> _extractFeaturedNearbyPlaces(
  Map<String, dynamic> data,
) {
  List<Map<String, dynamic>> asPlaceList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  final directCandidates = <dynamic>[
    data['nearbyPlaces'],
    data['nearby'],
    data['nearestPlaces'],
    data['nearPlaces'],
    data['places'],
    data['items'],
  ];
  for (final candidate in directCandidates) {
    final parsed = asPlaceList(candidate);
    if (parsed.isNotEmpty) return parsed;
  }

  final nearbyNode = data['nearby'];
  if (nearbyNode is Map<String, dynamic>) {
    final nestedCandidates = <dynamic>[
      nearbyNode['items'],
      nearbyNode['places'],
      nearbyNode['nearbyPlaces'],
      nearbyNode['data'],
    ];
    for (final candidate in nestedCandidates) {
      final parsed = asPlaceList(candidate);
      if (parsed.isNotEmpty) return parsed;
    }
    final nestedData = nearbyNode['data'];
    if (nestedData is Map<String, dynamic>) {
      final parsed = asPlaceList(
        nestedData['items'] ??
            nestedData['places'] ??
            nestedData['nearbyPlaces'],
      );
      if (parsed.isNotEmpty) return parsed;
    }
  }

  return const <Map<String, dynamic>>[];
}
