import 'package:flutter/material.dart';

import '../common/widgets/common_navigation_view.dart';
import 'widgets/livespace_detail_profile_view.dart';
import 'widgets/livespace_detail_info_view.dart';

class LivespaceDetailView extends StatelessWidget {
  const LivespaceDetailView({
    super.key,
    required this.space,
  });

  final Map<String, dynamic> space;

  @override
  Widget build(BuildContext context) {
    final title = (space['title'] as String?) ??
        (space['spaceTitle'] as String?) ??
        (space['name'] as String?) ??
        '라이브 스페이스';
    final thumbnailRaw = space['thumbnail'];
    final thumbnailMap =
        thumbnailRaw is Map<String, dynamic> ? thumbnailRaw : null;
    final thumbnail = (thumbnailRaw is String ? thumbnailRaw : null) ??
        thumbnailMap?['cdnUrl'] as String? ??
        thumbnailMap?['fileUrl'] as String? ??
        (space['thumbnailUrl'] as String?) ??
        (space['imageUrl'] as String?) ??
        '';
    final user = space['user'] is Map<String, dynamic>
        ? space['user'] as Map<String, dynamic>
        : space['creator'] is Map<String, dynamic>
            ? space['creator'] as Map<String, dynamic>
            : space['host'] is Map<String, dynamic>
                ? space['host'] as Map<String, dynamic>
                : null;
    final profileImageUrl = _stringOrEmpty(user?['profileImageUrl']) ??
        _stringOrEmpty(user?['profileImage']) ??
        _stringOrEmpty(user?['thumbnailUrl']) ??
        _stringOrEmpty(user?['avatarUrl']);
    final nickname = _stringOrEmpty(user?['nickname']) ??
        _stringOrEmpty(user?['name']) ??
        _stringOrEmpty(space['nickname']) ??
        _stringOrEmpty(space['userName']) ??
        '-';
    final place = _stringOrEmpty(space['address']) ??
        _stringOrEmpty(space['place']) ??
        _stringOrEmpty(space['locationName']) ??
        _stringOrEmpty(space['roadAddress']) ??
        _stringOrEmpty(space['region']) ??
        _stringOrEmpty(space['location']) ??
        '-';
    final time = _formatTime(
      _stringOrEmpty(space['time']) ??
          _stringOrEmpty(space['startAt']) ??
          _stringOrEmpty(space['startTime']) ??
          _stringOrEmpty(space['date']) ??
          _stringOrEmpty(space['createdAt']),
    );
    final status = _stringOrEmpty(space['status']) ??
        _stringOrEmpty(space['liveStatus']) ??
        _stringOrEmpty(space['state']) ??
        '-';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: false,
                stretch: true,
                expandedHeight: 385,
                collapsedHeight: 385,
                toolbarHeight: 0,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                  ],
                  background: LivespaceDetailProfileView(
                    title: title,
                    thumbnailUrl: thumbnail,
                    profileImageUrl: profileImageUrl,
                    nickname: nickname,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: LivespaceDetailInfoView(
                  title: title,
                  place: place,
                  time: time,
                  status: status,
                ),
              ),
            ],
          ),
          SafeArea(
            bottom: false,
            child: CommonNavigationView(
              backgroundColor: Colors.transparent,
              left: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  static String? _stringOrEmpty(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      final name = value['name'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
      final address = value['address'];
      if (address is String && address.trim().isNotEmpty) {
        return address.trim();
      }
    }
    return value.toString();
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${parsed.year}.${two(parsed.month)}.${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }
}
