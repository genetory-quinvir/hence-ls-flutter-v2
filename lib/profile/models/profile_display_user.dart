class ProfileDisplayUser {
  const ProfileDisplayUser({
    required this.id,
    required this.nickname,
    this.name,
    this.introduction,
    this.email,
    this.profileImageUrl,
    this.feedCount,
    this.placebookTotalCount,
    this.createdPlaceCount,
    this.favoritePlaceCount,
    this.followingCount,
    this.followerCount,
    this.activityLevel,
    this.rewardLevel,
    this.isFollowing,
    this.isFollowedByMe,
    this.representativeTitleInfoName,
    this.representativeTitleInfoCode,
  });

  final String id;
  final String nickname;
  final String? name;
  final String? introduction;
  final String? email;
  final String? profileImageUrl;
  final int? feedCount;
  final int? placebookTotalCount;
  final int? createdPlaceCount;
  final int? favoritePlaceCount;
  final int? followingCount;
  final int? followerCount;
  final int? activityLevel;
  final int? rewardLevel;
  final bool? isFollowing;
  final bool? isFollowedByMe;
  final String? representativeTitleInfoName;
  final String? representativeTitleInfoCode;

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

    final representativeInfo = json['representativeTitleInfo'];
    final representativeName = representativeInfo is Map<String, dynamic>
        ? representativeInfo['name'] as String?
        : null;
    final representativeCode = representativeInfo is Map<String, dynamic>
        ? representativeInfo['code'] as String?
        : null;

    return ProfileDisplayUser(
      id: json['userId'] as String? ?? json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      name: json['name'] as String?,
      introduction: json['introduction'] as String?,
      email: (json['email'] as String?) ?? (json['contact'] as String?),
      profileImageUrl: profileImageUrl,
      feedCount: (json['feedCount'] as num?)?.toInt() ??
          (json['postCount'] as num?)?.toInt(),
      placebookTotalCount:
          (json['placebookTotalCount'] as num?)?.toInt(),
      createdPlaceCount: (json['createdPlaceCount'] as num?)?.toInt() ??
          (json['placeCreatedCount'] as num?)?.toInt() ??
          (json['createdPlacesCount'] as num?)?.toInt(),
      favoritePlaceCount: (json['favoritePlaceCount'] as num?)?.toInt() ??
          (json['favoriteCount'] as num?)?.toInt() ??
          (json['placeFavoriteCount'] as num?)?.toInt() ??
          (json['favoritePlacebookCount'] as num?)?.toInt(),
      followingCount: (json['followingCount'] as num?)?.toInt(),
      followerCount: (json['followerCount'] as num?)?.toInt(),
      activityLevel: (json['activityLevel'] as num?)?.toInt(),
      rewardLevel: (json['rewardLevel'] as num?)?.toInt(),
      isFollowing: parsedIsFollowing,
      isFollowedByMe: parsedIsFollowedByMe,
      representativeTitleInfoName: representativeName,
      representativeTitleInfoCode: representativeCode,
    );
  }
}
