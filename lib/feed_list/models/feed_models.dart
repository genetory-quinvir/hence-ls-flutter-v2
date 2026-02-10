class FeedAuthor {
  const FeedAuthor({
    required this.userId,
    required this.nickname,
    required this.name,
    this.profileImageUrl,
  });

  final String userId;
  final String nickname;
  final String name;
  final String? profileImageUrl;

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    final profileImage = json['profileImage'];
    String? profileUrl;
    if (profileImage is Map<String, dynamic>) {
      profileUrl = profileImage['cdnUrl'] as String? ?? profileImage['fileUrl'] as String?;
    }
    return FeedAuthor(
      userId: json['userId'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileImageUrl: profileUrl,
    );
  }
}

class FeedImage {
  const FeedImage({
    required this.id,
    required this.fileUrl,
    required this.cdnUrl,
    required this.thumbnailUrl,
    required this.displayOrder,
  });

  final String id;
  final String? fileUrl;
  final String? cdnUrl;
  final String? thumbnailUrl;
  final int displayOrder;

  factory FeedImage.fromJson(Map<String, dynamic> json) {
    return FeedImage(
      id: json['id'] as String? ?? '',
      fileUrl: json['fileUrl'] as String?,
      cdnUrl: json['cdnUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class Feed {
  const Feed({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.author,
    required this.images,
  });

  final String id;
  final String content;
  final String createdAt;
  final int likeCount;
  final int commentCount;
  final FeedAuthor author;
  final List<FeedImage> images;

  factory Feed.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(FeedImage.fromJson)
        .toList();
    return Feed(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      author: FeedAuthor.fromJson((json['author'] as Map<String, dynamic>?) ?? const {}),
      images: images,
    );
  }
}
