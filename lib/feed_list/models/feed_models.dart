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
    this.space,
    required this.isLiked,
    required this.hashtags,
    this.placeName = '',
    this.address = '',
  });

  final String id;
  final String content;
  final String createdAt;
  final int likeCount;
  final int commentCount;
  final FeedAuthor author;
  final List<FeedImage> images;
  final FeedSpace? space;
  final bool isLiked;
  final List<String> hashtags;
  final String placeName;
  final String address;

  Feed copyWith({
    String? id,
    String? content,
    String? createdAt,
    int? likeCount,
    int? commentCount,
    FeedAuthor? author,
    List<FeedImage>? images,
    FeedSpace? space,
    bool? isLiked,
    List<String>? hashtags,
    String? placeName,
    String? address,
  }) {
    return Feed(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      author: author ?? this.author,
      images: images ?? this.images,
      space: space ?? this.space,
      isLiked: isLiked ?? this.isLiked,
      hashtags: hashtags ?? this.hashtags,
      placeName: placeName ?? this.placeName,
      address: address ?? this.address,
    );
  }

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
      space: json['space'] is Map<String, dynamic>
          ? FeedSpace.fromJson(json['space'] as Map<String, dynamic>)
          : null,
      isLiked: _parseIsLiked(json),
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      placeName: json['placeName'] as String? ??
          json['place_name'] as String? ??
          '',
      address: json['address'] as String? ??
          json['addressName'] as String? ??
          '',
    );
  }

  static bool _parseIsLiked(Map<String, dynamic> json) {
    final direct = json['isLiked'];
    if (direct is bool) return direct;
    if (direct is num) return direct > 0;
    final alt = json['liked'];
    if (alt is bool) return alt;
    if (alt is num) return alt > 0;
    return false;
  }
}

class FeedSpace {
  const FeedSpace({
    required this.spaceId,
    required this.title,
    required this.placeName,
  });

  final String spaceId;
  final String title;
  final String placeName;

  factory FeedSpace.fromJson(Map<String, dynamic> json) {
    return FeedSpace(
      spaceId: json['spaceId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      placeName: json['placeName'] as String? ?? '',
    );
  }
}
