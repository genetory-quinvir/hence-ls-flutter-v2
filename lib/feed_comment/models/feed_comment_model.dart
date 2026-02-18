class FeedCommentItem {
  const FeedCommentItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorName,
    required this.authorId,
    this.authorProfileUrl,
    this.imageId,
    this.imageUrl,
    this.isLiked = false,
    this.likeCount = 0,
    this.replyCount = 0,
  });

  final String id;
  final String content;
  final String createdAt;
  final String authorName;
  final String authorId;
  final String? authorProfileUrl;
  final String? imageId;
  final String? imageUrl;
  final bool isLiked;
  final int likeCount;
  final int? replyCount;

  factory FeedCommentItem.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    String authorName = '';
    String authorId = '';
    String? profileUrl;
    if (author is Map<String, dynamic>) {
      final id = author['userId'] ?? author['id'];
      if (id is String) authorId = id;
      final nickname = author['nickname'] as String? ?? '';
      final name = author['name'] as String? ?? '';
      authorName = nickname.isNotEmpty ? nickname : name;
      final profileImage = author['profileImage'];
      if (profileImage is Map<String, dynamic>) {
        profileUrl =
            profileImage['cdnUrl'] as String? ?? profileImage['fileUrl'] as String?;
      }
    }
    final image = json['image'];
    String? imageId;
    String? imageUrl;
    if (image is Map<String, dynamic>) {
      imageId = image['id'] as String?;
      imageUrl = image['cdnUrl'] as String? ??
          image['fileUrl'] as String? ??
          image['thumbnailUrl'] as String?;
    }
    return FeedCommentItem(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      authorName: authorName,
      authorId: authorId,
      authorProfileUrl: profileUrl,
      imageId: imageId,
      imageUrl: imageUrl,
      isLiked: (json['isLiked'] as bool?) ?? false,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ??
          (json['repliesCount'] as num?)?.toInt() ??
          (json['childCount'] as num?)?.toInt() ??
          0,
    );
  }
}

class FeedCommentPage {
  const FeedCommentPage({
    required this.comments,
    required this.hasNext,
    this.nextCursor,
    this.totalCount,
  });

  final List<FeedCommentItem> comments;
  final bool hasNext;
  final String? nextCursor;
  final int? totalCount;
}
