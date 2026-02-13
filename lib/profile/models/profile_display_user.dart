class ProfileDisplayUser {
  const ProfileDisplayUser({
    required this.id,
    required this.nickname,
    this.introduction,
    this.email,
    this.profileImageUrl,
    this.feedCount,
    this.followingCount,
    this.followerCount,
    this.activityLevel,
    this.isFollowing,
    this.isFollowedByMe,
  });

  final String id;
  final String nickname;
  final String? introduction;
  final String? email;
  final String? profileImageUrl;
  final int? feedCount;
  final int? followingCount;
  final int? followerCount;
  final int? activityLevel;
  final bool? isFollowing;
  final bool? isFollowedByMe;

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == 'y' || normalized == 'yes' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'n' || normalized == 'no' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  factory ProfileDisplayUser.fromJson(Map<String, dynamic> json) {
    final profileImage = json['profileImage'];
    String? profileImageUrl;
    if (profileImage is Map<String, dynamic>) {
      profileImageUrl =
          profileImage['cdnUrl'] as String? ?? profileImage['fileUrl'] as String?;
    }

    final relation = json['relation'];
    final follow = json['follow'];
    final relationMap = relation is Map<String, dynamic> ? relation : null;
    final followMap = follow is Map<String, dynamic> ? follow : null;

    final parsedIsFollowing = _asBool(json['isFollowing']) ??
        _asBool(json['followed']) ??
        _asBool(json['isFollowed']) ??
        _asBool(json['following']) ??
        _asBool(json['followYn']) ??
        _asBool(json['isFollowingByMe']) ??
        _asBool(relationMap?['isFollowing']) ??
        _asBool(relationMap?['following']) ??
        _asBool(followMap?['isFollowing']) ??
        _asBool(followMap?['following']);

    final parsedIsFollowedByMe = _asBool(json['isFollowedByMe']) ??
        _asBool(json['isFollower']) ??
        _asBool(json['followedByMe']) ??
        _asBool(json['followBack']) ??
        _asBool(relationMap?['isFollowedByMe']) ??
        _asBool(relationMap?['isFollower']) ??
        _asBool(followMap?['isFollowedByMe']) ??
        _asBool(followMap?['isFollower']);

    return ProfileDisplayUser(
      id: json['userId'] as String? ?? json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      introduction: json['introduction'] as String?,
      email: (json['email'] as String?) ?? (json['contact'] as String?),
      profileImageUrl: profileImageUrl,
      feedCount: (json['feedCount'] as num?)?.toInt() ??
          (json['postCount'] as num?)?.toInt(),
      followingCount: (json['followingCount'] as num?)?.toInt(),
      followerCount: (json['followerCount'] as num?)?.toInt(),
      activityLevel: (json['activityLevel'] as num?)?.toInt(),
      isFollowing: parsedIsFollowing,
      isFollowedByMe: parsedIsFollowedByMe,
    );
  }
}
