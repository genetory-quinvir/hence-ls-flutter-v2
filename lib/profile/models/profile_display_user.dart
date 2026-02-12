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

  factory ProfileDisplayUser.fromJson(Map<String, dynamic> json) {
    final profileImage = json['profileImage'];
    String? profileImageUrl;
    if (profileImage is Map<String, dynamic>) {
      profileImageUrl =
          profileImage['cdnUrl'] as String? ?? profileImage['fileUrl'] as String?;
    }

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
      isFollowing: json['isFollowing'] as bool? ??
          json['followed'] as bool? ??
          json['isFollowed'] as bool?,
      isFollowedByMe: json['isFollowedByMe'] as bool? ??
          json['isFollower'] as bool? ??
          json['isFollowed'] as bool?,
    );
  }
}
