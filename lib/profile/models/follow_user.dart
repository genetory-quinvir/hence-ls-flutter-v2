class FollowUser {
  const FollowUser({
    required this.id,
    required this.nickname,
    this.name,
    this.profileImageUrl,
  });

  final String id;
  final String nickname;
  final String? name;
  final String? profileImageUrl;

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    final profileImage = json['profileImage'];
    String? profileImageUrl;
    if (profileImage is Map<String, dynamic>) {
      profileImageUrl = profileImage['cdnUrl'] as String? ??
          profileImage['fileUrl'] as String?;
    }

    return FollowUser(
      id: json['userId'] as String? ?? json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      name: json['name'] as String?,
      profileImageUrl: profileImageUrl,
    );
  }
}
