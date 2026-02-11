class MentionUser {
  const MentionUser({
    required this.id,
    required this.displayName,
    this.profileUrl,
  });

  final String id;
  final String displayName;
  final String? profileUrl;

  factory MentionUser.fromJson(Map<String, dynamic> json) {
    final nickname = json['nickname'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final displayName = nickname.isNotEmpty ? nickname : name;
    String? profileUrl;
    final profileImage = json['profileImage'];
    if (profileImage is Map<String, dynamic>) {
      profileUrl = profileImage['cdnUrl'] as String? ?? profileImage['fileUrl'] as String?;
    }
    return MentionUser(
      id: json['userId'] as String? ?? json['id'] as String? ?? '',
      displayName: displayName,
      profileUrl: profileUrl,
    );
  }
}
