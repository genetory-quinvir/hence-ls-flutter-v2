class FollowUser {
  const FollowUser({
    required this.id,
    required this.nickname,
    this.name,
    this.profileImageUrl,
    this.isFollowing = false,
  });

  final String id;
  final String nickname;
  final String? name;
  final String? profileImageUrl;
  final bool isFollowing;

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
      isFollowing: _asBool(json['isFollowing']) ??
          _asBool(json['following']) ??
          _asBool(json['followed']) ??
          _asBool(json['followYn']) ??
          _asBool((json['relation'] as Map<String, dynamic>?)?['following']) ??
          _asBool((json['follow'] as Map<String, dynamic>?)?['isFollowing']) ??
          false,
    );
  }

  FollowUser copyWith({
    String? id,
    String? nickname,
    String? name,
    String? profileImageUrl,
    bool? isFollowing,
  }) {
    return FollowUser(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'y' ||
          normalized == 'yes' ||
          normalized == 'true' ||
          normalized == '1') {
        return true;
      }
      if (normalized == 'n' ||
          normalized == 'no' ||
          normalized == 'false' ||
          normalized == '0') {
        return false;
      }
    }
    return null;
  }
}
