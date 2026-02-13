class AuthUser {
  const AuthUser({
    required this.id,
    required this.nickname,
    this.introduction,
    this.email,
    this.provider,
    this.profileImageUrl,
    this.gender,
    this.dateOfBirth,
    this.activityLevel,
    this.feedCount,
    this.followerCount,
    this.followingCount,
  });

  final String id;
  final String nickname;
  final String? introduction;
  final String? email;
  final String? provider;
  final String? profileImageUrl;
  final String? gender;
  final String? dateOfBirth;
  final int? activityLevel;
  final int? feedCount;
  final int? followerCount;
  final int? followingCount;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final profileImage = json['profileImage'];
    String? profileImageUrl;
    if (profileImage is Map<String, dynamic>) {
      profileImageUrl = profileImage['cdnUrl'] as String? ?? profileImage['fileUrl'] as String?;
    }

    return AuthUser(
      id: json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      introduction: json['introduction'] as String?,
      email: (json['email'] as String?) ?? (json['contact'] as String?),
      provider: (json['provider'] as String?)?.toLowerCase(),
      profileImageUrl: profileImageUrl,
      gender: (json['gender'] as String?)?.toLowerCase(),
      dateOfBirth: json['dateOfBirth'] as String?,
      activityLevel: (json['activityLevel'] as num?)?.toInt(),
      feedCount: (json['feedCount'] as num?)?.toInt() ??
          (json['postCount'] as num?)?.toInt(),
      followerCount: (json['followerCount'] as num?)?.toInt(),
      followingCount: (json['followingCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'introduction': introduction,
      'email': email,
      'provider': provider,
      'profileImageUrl': profileImageUrl,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'activityLevel': activityLevel,
      'feedCount': feedCount,
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }

  factory AuthUser.fromStoredJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      introduction: json['introduction'] as String?,
      email: json['email'] as String?,
      provider: (json['provider'] as String?)?.toLowerCase(),
      profileImageUrl: json['profileImageUrl'] as String?,
      gender: (json['gender'] as String?)?.toLowerCase(),
      dateOfBirth: json['dateOfBirth'] as String?,
      activityLevel: (json['activityLevel'] as num?)?.toInt(),
      feedCount: (json['feedCount'] as num?)?.toInt() ??
          (json['postCount'] as num?)?.toInt(),
      followerCount: (json['followerCount'] as num?)?.toInt(),
      followingCount: (json['followingCount'] as num?)?.toInt(),
    );
  }
}
