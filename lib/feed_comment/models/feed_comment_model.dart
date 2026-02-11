class FeedCommentItem {
  const FeedCommentItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorName,
    this.authorProfileUrl,
    this.isLiked = false,
    this.likeCount = 0,
    this.replyCount = 0,
  });

  final String id;
  final String content;
  final String createdAt;
  final String authorName;
  final String? authorProfileUrl;
  final bool isLiked;
  final int likeCount;
  final int? replyCount;

  factory FeedCommentItem.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    String authorName = '';
    String? profileUrl;
    if (author is Map<String, dynamic>) {
      final nickname = author['nickname'] as String? ?? '';
      final name = author['name'] as String? ?? '';
      authorName = nickname.isNotEmpty ? nickname : name;
      final profileImage = author['profileImage'];
      if (profileImage is Map<String, dynamic>) {
        profileUrl =
            profileImage['cdnUrl'] as String? ?? profileImage['fileUrl'] as String?;
      }
    }
    return FeedCommentItem(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      authorName: authorName,
      authorProfileUrl: profileUrl,
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
  });

  final List<FeedCommentItem> comments;
  final bool hasNext;
  final String? nextCursor;
}
