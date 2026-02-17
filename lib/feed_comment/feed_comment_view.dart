import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math' as math;

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_rounded_button.dart';
import 'models/feed_comment_model.dart';
import 'models/mention_user.dart';
import 'widgets/feed_comment_list_item_view.dart';

class FeedCommentView extends StatefulWidget {
  const FeedCommentView({
    super.key,
    required this.feedId,
    this.spaceId,
    required this.comments,
    this.onCommentAdded,
  });

  final String feedId;
  final String? spaceId;
  final List<FeedCommentItem> comments;
  final VoidCallback? onCommentAdded;

  @override
  State<FeedCommentView> createState() => _FeedCommentViewState();
}

class _FeedCommentViewState extends State<FeedCommentView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isTogglingLike = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  String? _nextCursor;
  List<FeedCommentItem> _comments = const [];
  List<MentionUser> _mentionCandidates = const [];
  List<MentionUser> _filteredMentions = const [];
  bool _showMentions = false;
  FeedCommentItem? _replyTarget;
  final Map<String, List<FeedCommentItem>> _repliesByCommentId = {};
  final Set<String> _expandedReplies = {};
  final Set<String> _loadingReplies = {};

  @override
  void initState() {
    super.initState();
    _comments = widget.comments;
    _loadComments();
    _controller.addListener(_handleMentionChanged);
    _loadMentions();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final page = await ApiClient.fetchFeedComments(feedId: widget.feedId);
      if (!mounted) return;
      setState(() {
        _comments = page.comments;
        _hasNext = page.hasNext;
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      // Keep existing comments on failure.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasNext) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ApiClient.fetchFeedComments(
        feedId: widget.feedId,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _comments = List.of(_comments)..addAll(page.comments);
        _hasNext = page.hasNext;
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      // Ignore load more errors.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleMentionChanged);
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMentions() async {
    final spaceId = widget.spaceId;
    if (spaceId == null || spaceId.isEmpty) return;
    try {
      final users = await ApiClient.fetchSpaceParticipants(spaceId: spaceId);
      if (!mounted) return;
      setState(() => _mentionCandidates = users);
    } catch (_) {
      // No mention suggestions on failure.
    }
  }

  void _handleMentionChanged() {
    final selection = _controller.selection;
    if (!selection.isValid) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final cursor = selection.baseOffset;
    if (cursor < 0) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final text = _controller.text;
    final range = _findMentionRange(text, cursor);
    if (range == null) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final query = text.substring(range.$1 + 1, cursor);
    final next = _filterMentions(query);
    setState(() {
      _filteredMentions = next;
      _showMentions = next.isNotEmpty;
    });
  }

  List<MentionUser> _filterMentions(String query) {
    final normalized = query.toLowerCase();
    if (normalized.isEmpty) {
      return _mentionCandidates;
    }
    return _mentionCandidates
        .where((user) => user.displayName.toLowerCase().contains(normalized))
        .toList();
  }

  (int, int)? _findMentionRange(String text, int cursor) {
    if (text.isEmpty || cursor == 0) return null;
    final atIndex = text.lastIndexOf('@', cursor - 1);
    if (atIndex == -1) return null;
    if (atIndex > 0) {
      final prev = text[atIndex - 1];
      if (prev.trim().isNotEmpty) return null;
    }
    final fragment = text.substring(atIndex + 1, cursor);
    if (fragment.contains(RegExp(r'\s'))) return null;
    final allowed = RegExp(r'^[a-zA-Z0-9_가-힣]{0,50}$');
    if (!allowed.hasMatch(fragment)) return null;
    return (atIndex, cursor);
  }

  void _prefillMention(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final mention = '@$trimmed ';
    _controller.value = TextEditingValue(
      text: mention,
      selection: TextSelection.collapsed(offset: mention.length),
    );
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final target = _replyTarget;
      if (target == null) {
        await ApiClient.createFeedComment(
          feedId: widget.feedId,
          content: content,
          fileId: null,
        );
        widget.onCommentAdded?.call();
      } else {
        await ApiClient.createCommentReply(
          commentId: target.id,
          feedId: widget.feedId,
          content: content,
          fileId: null,
        );
      }
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _replyTarget = null;
        _showMentions = false;
      });
      await _loadComments();
    } catch (_) {
      // Ignore send errors for now.
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleLikeAt(int index) async {
    if (_isTogglingLike) return;
    final comment = _comments[index];
    final nextLiked = !comment.isLiked;
    final nextCount = comment.likeCount + (nextLiked ? 1 : -1);
    setState(() {
      _isTogglingLike = true;
      _comments = List.of(_comments)
        ..[index] = FeedCommentItem(
          id: comment.id,
          content: comment.content,
          createdAt: comment.createdAt,
          authorName: comment.authorName,
          authorProfileUrl: comment.authorProfileUrl,
          isLiked: nextLiked,
          likeCount: nextCount < 0 ? 0 : nextCount,
        );
    });
    try {
      await ApiClient.toggleFeedCommentLike(comment.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = List.of(_comments)..[index] = comment;
      });
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  Future<void> _toggleReplies(FeedCommentItem comment) async {
    final commentId = comment.id;
    final isExpanded = _expandedReplies.contains(commentId);
    if (isExpanded) {
      setState(() => _expandedReplies.remove(commentId));
      return;
    }
    setState(() => _expandedReplies.add(commentId));
    if (_repliesByCommentId.containsKey(commentId)) return;
    if (_loadingReplies.contains(commentId)) return;
    setState(() => _loadingReplies.add(commentId));
    try {
      final replies = await ApiClient.fetchCommentReplies(
        commentId: commentId,
      );
      if (!mounted) return;
      setState(() => _repliesByCommentId[commentId] = replies);
    } catch (_) {
      // Ignore load errors for now.
    } finally {
      if (mounted) {
        setState(() => _loadingReplies.remove(commentId));
      }
    }
  }

  void _insertMention(MentionUser user) {
    final selection = _controller.selection;
    final cursor = selection.baseOffset;
    final text = _controller.text;
    if (cursor < 0) return;
    final range = _findMentionRange(text, cursor);
    if (range == null) return;
    final before = text.substring(0, range.$1);
    final after = text.substring(range.$2);
    final mention = '@${user.displayName} ';
    final nextText = '$before$mention$after';
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: before.length + mention.length),
    );
    setState(() => _showMentions = false);
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - (media.padding.top + 44 + 64);
    const minHeight = 240.0;
    const itemHeight = 88.0;
    const itemGap = 12.0;
    const inputHeight = 50.0;
    const headerHeight = 32.0;
    const headerGap = 12.0;
    const inputGap = 12.0;
    const mentionItemHeight = 40.0;
    const mentionMaxHeight = 160.0;
    final mentionHeight = _showMentions
        ? math.min(_filteredMentions.length * mentionItemHeight, mentionMaxHeight)
        : 0.0;
    final listHeight = _comments.isEmpty
        ? 0.0
        : (_comments.length * itemHeight) + ((_comments.length - 1) * itemGap);
    final contentHeight = headerHeight +
        headerGap +
        listHeight +
        mentionHeight +
        (_showMentions ? 8.0 : 0.0) +
        inputGap +
        inputHeight +
        44; // vertical padding (24 + 20)
    final bottomInset = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;
    final effectiveMaxHeight = math.max(
      minHeight,
      maxHeight - bottomInset - safeBottom,
    );
    final height = contentHeight < minHeight
        ? minHeight
        : (contentHeight > effectiveMaxHeight ? effectiveMaxHeight : contentHeight);

    final canScroll =
        contentHeight > maxHeight || _expandedReplies.isNotEmpty || _hasNext;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + safeBottom),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Text(
                          '댓글',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      CommonInkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(
                            PhosphorIconsRegular.x,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: headerGap),
                  Expanded(
                    child: _comments.isEmpty
                        ? const CommonEmptyView(
                            message: '댓글이 없습니다.',
                            showButton: false,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                          final list = NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.extentAfter == 0) {
                                _loadMoreComments();
                              }
                              return false;
                            },
                            child: ListView.separated(
                              shrinkWrap: !canScroll,
                              physics: canScroll
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length + (_hasNext ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: itemGap),
                              itemBuilder: (context, index) {
                                if (index >= _comments.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CommonActivityIndicator(size: 20),
                                    ),
                                  );
                                }
                                final comment = _comments[index];
                                final replies =
                                    _repliesByCommentId[comment.id] ?? const [];
                                final replyCount = comment.replyCount ?? 0;
                                final hasReplies = replyCount > 0;
                                final isExpanded =
                                    _expandedReplies.contains(comment.id);
                                final isLoading =
                                    _loadingReplies.contains(comment.id);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FeedCommentListItemView(
                                      comment: comment,
                                      onLikeTap: () => _toggleLikeAt(index),
                                      onReplyTap: () {
                                        setState(() => _replyTarget = comment);
                                        _prefillMention(comment.authorName);
                                      },
                                      onToggleReplies: () =>
                                          _toggleReplies(comment),
                                      hasReplies: hasReplies || replies.isNotEmpty,
                                      repliesExpanded: isExpanded,
                                    ),
                                    if (isExpanded) ...[
                                      const SizedBox(height: 8),
                                      if (isLoading)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 42),
                                          child: CommonActivityIndicator(size: 20),
                                        )
                                      else
                                        Column(
                                          children: replies
                                              .map(
                                                (reply) => Padding(
                                                  padding: const EdgeInsets.only(
                                                    left: 42,
                                                    bottom: 12,
                                                  ),
                                                  child: FeedCommentListItemView(
                                                    comment: reply,
                                                    onLikeTap: () {},
                                                    onReplyTap: () {
                                                      setState(
                                                        () => _replyTarget = comment,
                                                      );
                                                      _prefillMention(
                                                        reply.authorName,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          );
                              return Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: list,
                                ),
                              );
                            },
                          ),
                  ),
                  if (_showMentions) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: mentionMaxHeight),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredMentions.length,
                        itemBuilder: (context, index) {
                          final user = _filteredMentions[index];
                          return CommonInkWell(
                            onTap: () => _insertMention(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFE0E0E0),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: CommonImageView(
                                      networkUrl: user.profileUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      user.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: inputGap),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: inputHeight,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: TextField(
                                controller: _controller,
                                focusNode: _inputFocusNode,
                                textInputAction: TextInputAction.newline,
                                keyboardType: TextInputType.multiline,
                                minLines: 1,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: '댓글을 입력하세요',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: 52,
                            height: inputHeight,
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _controller,
                              builder: (context, value, _) {
                                final canSend =
                                    value.text.trim().isNotEmpty && !_isSending;
                                return CommonRoundedButton(
                                  title: '',
                                  height: inputHeight,
                                  radius: 12,
                                  leadingCentered: true,
                                  leadingGap: 0,
                                  leading: const Icon(
                                    PhosphorIconsFill.paperPlaneRight,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onTap: canSend ? _handleSend : null,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              if (_isLoading)
                const Positioned.fill(
                  child: Center(
                    child: CommonActivityIndicator(size: 28),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
