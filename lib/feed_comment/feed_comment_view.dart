import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_image_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_title_actionsheet.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/permissions/media_permission_service.dart';
import '../common/media/media_picker_service.dart';
import '../common/media/media_conversion_service.dart';
import 'models/feed_comment_model.dart';
import 'models/mention_user.dart';
import 'widgets/feed_comment_list_item_view.dart';
import '../common/widgets/common_login_guard.dart';

class FeedCommentView extends StatefulWidget {
  const FeedCommentView({
    super.key,
    required this.feedId,
    this.spaceId,
    required this.comments,
    this.onCommentAdded,
    this.initialTotalCount,
    this.initialCommentId,
  });

  final String feedId;
  final String? spaceId;
  final List<FeedCommentItem> comments;
  final VoidCallback? onCommentAdded;
  final int? initialTotalCount;
  final String? initialCommentId;

  @override
  State<FeedCommentView> createState() => _FeedCommentViewState();
}

class _FeedCommentViewState extends State<FeedCommentView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isSending = false;
  bool _sendingDialogVisible = false;
  bool _isTogglingLike = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  String? _nextCursor;
  int _totalCount = 0;
  List<FeedCommentItem> _comments = const [];
  File? _commentImageFile;
  String _selectedSort = '최신순';
  static const List<String> _commentSorts = <String>['최신순', '인기순'];
  final ScrollController _listController = ScrollController();
  final Map<String, GlobalKey> _commentKeys = {};
  String? _pendingCommentId;
  List<MentionUser> _mentionCandidates = const [];
  List<MentionUser> _filteredMentions = const [];
  bool _showMentions = false;
  FeedCommentItem? _replyTarget;
  String? _mentionBadgeName;
  final Map<String, List<FeedCommentItem>> _repliesByCommentId = {};
  final Set<String> _expandedReplies = {};
  final Set<String> _loadingReplies = {};
  final Set<String> _togglingReplyIds = {};

  @override
  void initState() {
    super.initState();
    _comments = widget.comments;
    _totalCount = widget.initialTotalCount ?? widget.comments.length;
    _pendingCommentId = widget.initialCommentId;
    _loadComments();
    _controller.addListener(_handleMentionChanged);
    _loadMentions();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final page = await ApiClient.fetchFeedComments(
        feedId: widget.feedId,
        orderBy: _orderBy,
      );
      if (!mounted) return;
      setState(() {
        _comments = page.comments;
        _hasNext = page.hasNext;
        _nextCursor = page.nextCursor;
        if (page.totalCount != null) {
          _totalCount = page.totalCount!;
        } else {
          _totalCount = page.comments.length;
        }
      });
      _scheduleScrollToPendingComment();
    } catch (_) {
      // Keep existing comments on failure.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshComments() async {
    try {
      final page = await ApiClient.fetchFeedComments(
        feedId: widget.feedId,
        orderBy: _orderBy,
      );
      if (!mounted) return;
      setState(() {
        _comments = page.comments;
        _hasNext = page.hasNext;
        _nextCursor = page.nextCursor;
        if (page.totalCount != null) {
          _totalCount = page.totalCount!;
        } else {
          _totalCount = page.comments.length;
        }
      });
      _scheduleScrollToPendingComment();
    } catch (_) {
      // ignore refresh errors
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasNext) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ApiClient.fetchFeedComments(
        feedId: widget.feedId,
        cursor: _nextCursor,
        orderBy: _orderBy,
      );
      if (!mounted) return;
      setState(() {
        _comments = List.of(_comments)..addAll(page.comments);
        _hasNext = page.hasNext;
        _nextCursor = page.nextCursor;
        if (page.totalCount != null) {
          _totalCount = page.totalCount!;
        }
      });
      _scheduleScrollToPendingComment();
    } catch (_) {
      // Ignore load more errors.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _scheduleScrollToPendingComment() {
    if (_pendingCommentId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToPendingComment();
    });
  }

  void _scrollToPendingComment() {
    final targetId = _pendingCommentId;
    if (targetId == null) return;
    final key = _commentKeys[targetId];
    final context = key?.currentContext;
    if (context != null) {
      _pendingCommentId = null;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
      return;
    }
    if (_hasNext && !_isLoadingMore) {
      _loadMoreComments();
    }
  }

  String get _orderBy {
    switch (_selectedSort) {
      case '인기순':
        return 'popular';
      default:
        return 'latest';
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleMentionChanged);
    _controller.dispose();
    _inputFocusNode.dispose();
    _listController.dispose();
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

  Future<void> _showCommentImageActionSheet() async {
    await CommonTitleActionSheet.show(
      context,
      title: '사진 추가',
      items: const [
        CommonTitleActionSheetItem(label: '앨범에서 가져오기', value: 'album'),
        CommonTitleActionSheetItem(label: '카메라로 촬영하기', value: 'camera'),
      ],
      onSelected: (item) async {
        switch (item.value) {
          case 'album':
            if (!await MediaPermissionService.ensurePhotoLibrary()) {
              _showPermissionSnack('사진 접근 권한이 필요합니다.');
              return;
            }
            final picked = await MediaPickerService.pickFromGallery();
            if (picked == null) return;
            setState(() => _commentImageFile = File(picked.path));
            break;
          case 'camera':
            if (!await MediaPermissionService.ensureCamera()) {
              _showPermissionSnack('카메라 권한이 필요합니다.');
              return;
            }
            final picked = await MediaPickerService.pickFromCamera();
            if (picked == null) return;
            setState(() => _commentImageFile = File(picked.path));
            break;
        }
      },
    );
  }

  void _showPermissionSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    setState(() => _mentionBadgeName = trimmed);
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    final content = _controller.text.trim();
    final hasImage = _commentImageFile != null;
    if (content.isEmpty && !hasImage) return;
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '댓글을 작성하려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() => _isSending = true);
    _sendingDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (_) => const Center(
        child: CommonActivityIndicator(size: 28),
      ),
    );
    try {
      String? imageId;
      if (hasImage && _commentImageFile != null) {
        final webp =
            await MediaConversionService.toWebp(_commentImageFile!, quality: 85);
        imageId = await ApiClient.uploadCommentImage(webp);
      }
      final target = _replyTarget;
      final badgeName = _mentionBadgeName;
      final mentionPrefix =
          badgeName != null && badgeName.isNotEmpty ? '@$badgeName ' : '';
      final payloadContent = mentionPrefix.isNotEmpty &&
              !content.startsWith(mentionPrefix)
          ? '$mentionPrefix$content'
          : content;
      if (target == null) {
        await ApiClient.createFeedComment(
          feedId: widget.feedId,
          content: payloadContent,
          imageId: imageId,
        );
        widget.onCommentAdded?.call();
      } else {
        await ApiClient.createCommentReply(
          commentId: target.id,
          feedId: widget.feedId,
          content: payloadContent,
          imageId: imageId,
        );
      }
      if (!mounted) return;
      _controller.clear();
      setState(() => _commentImageFile = null);
      setState(() {
        _replyTarget = null;
        _mentionBadgeName = null;
        _showMentions = false;
      });
      await _loadComments();
      _scrollToTop();
    } catch (_) {
      // Ignore send errors for now.
    } finally {
      if (mounted && _sendingDialogVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        _sendingDialogVisible = false;
      }
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToTop() {
    if (!_listController.hasClients) return;
    _listController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleLikeAt(int index) async {
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '좋아요를 누르려면 로그인해주세요.',
    )) {
      return;
    }
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
          authorId: comment.authorId,
          authorProfileUrl: comment.authorProfileUrl,
          imageId: comment.imageId,
          imageUrl: comment.imageUrl,
          isLiked: nextLiked,
          likeCount: nextCount < 0 ? 0 : nextCount,
          replyCount: comment.replyCount,
        );
    });
    try {
      await ApiClient.setCommentLike(
        commentId: comment.id,
        isLiked: nextLiked,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = List.of(_comments)..[index] = comment;
      });
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  Future<void> _toggleReplyLike(String parentId, int index) async {
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '좋아요를 누르려면 로그인해주세요.',
    )) {
      return;
    }
    final replies = _repliesByCommentId[parentId];
    if (replies == null || index < 0 || index >= replies.length) return;
    final reply = replies[index];
    if (_togglingReplyIds.contains(reply.id)) return;
    final nextLiked = !reply.isLiked;
    final nextCount = reply.likeCount + (nextLiked ? 1 : -1);
    setState(() {
      _togglingReplyIds.add(reply.id);
      final updated = List<FeedCommentItem>.from(replies);
      updated[index] = FeedCommentItem(
        id: reply.id,
        content: reply.content,
        createdAt: reply.createdAt,
        authorName: reply.authorName,
        authorId: reply.authorId,
        authorProfileUrl: reply.authorProfileUrl,
        imageId: reply.imageId,
        imageUrl: reply.imageUrl,
        isLiked: nextLiked,
        likeCount: nextCount < 0 ? 0 : nextCount,
        replyCount: reply.replyCount,
      );
      _repliesByCommentId[parentId] = updated;
    });
    try {
      await ApiClient.setCommentLike(
        commentId: reply.id,
        isLiked: nextLiked,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final restored = List<FeedCommentItem>.from(replies);
        restored[index] = reply;
        _repliesByCommentId[parentId] = restored;
      });
    } finally {
      if (mounted) {
        setState(() => _togglingReplyIds.remove(reply.id));
      }
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

  Future<void> _handleReplyTap(
    FeedCommentItem target, {
    String? mention,
  }) async {
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '답글을 작성하려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() => _replyTarget = target);
    final name = mention ?? target.authorName;
    if (name.trim().isNotEmpty) {
      _prefillMention(name);
    }
  }

  Widget _buildSortBar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Spacer(),
          ...List.generate(_commentSorts.length, (index) {
            final label = _commentSorts[index];
            final selected = _selectedSort == label;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index > 0)
                  Container(
                    width: 1,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: const Color(0x33000000),
                  ),
                GestureDetector(
                  onTap: () {
                    if (_selectedSort == label) return;
                    setState(() => _selectedSort = label);
                    _loadComments();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? Colors.black : const Color(0x88000000),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
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
                      Expanded(
                        child: Text(
                          '댓글 ($_totalCount)',
                          style: const TextStyle(
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
                  _buildSortBar(),
                  const SizedBox(height: 12),
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
                            child: CommonRefreshView(
                              onRefresh: _refreshComments,
                              topPadding: 12,
                              child: ListView.separated(
                                controller: _listController,
                                shrinkWrap: false,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
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
                                  final key = _commentKeys.putIfAbsent(
                                    comment.id,
                                    () => GlobalKey(),
                                  );
                                  final replies =
                                      _repliesByCommentId[comment.id] ?? const [];
                                  final replyCount = comment.replyCount ?? 0;
                                  final hasReplies = replyCount > 0;
                                  final isExpanded =
                                      _expandedReplies.contains(comment.id);
                                  final isLoading =
                                      _loadingReplies.contains(comment.id);
                                  return KeyedSubtree(
                                    key: key,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FeedCommentListItemView(
                                          comment: comment,
                                          onLikeTap: () => _toggleLikeAt(index),
                                          onReplyTap: () {
                                            _handleReplyTap(comment);
                                          },
                                          onToggleReplies: () =>
                                              _toggleReplies(comment),
                                          hasReplies:
                                              hasReplies || replies.isNotEmpty,
                                          repliesExpanded: isExpanded,
                                        ),
                                        if (isExpanded) ...[
                                          const SizedBox(height: 8),
                                          if (isLoading)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 42),
                                              child: CommonActivityIndicator(
                                                size: 20,
                                              ),
                                            )
                                          else
                                            Column(
                                              children: replies
                                                  .map(
                                                    (reply) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        left: 42,
                                                        bottom: 12,
                                                      ),
                                                      child:
                                                          FeedCommentListItemView(
                                                        comment: reply,
                                                        onLikeTap: () {
                                                          _toggleReplyLike(
                                                            comment.id,
                                                            replies.indexOf(reply),
                                                          );
                                                        },
                                                        onReplyTap: () {
                                                          _handleReplyTap(
                                                            comment,
                                                            mention:
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
                                    ),
                                  );
                                },
                              ),
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
                  if (_mentionBadgeName != null &&
                      _mentionBadgeName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@${_mentionBadgeName!}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 6),
                            CommonInkWell(
                              onTap: () {
                                setState(() => _mentionBadgeName = null);
                              },
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: Icon(
                                  PhosphorIconsRegular.x,
                                  size: 14,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: inputGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CommonInkWell(
                        onTap: _showCommentImageActionSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: inputHeight,
                          height: inputHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _commentImageFile == null
                              ? const Icon(
                                  PhosphorIconsRegular.image,
                                  size: 20,
                                  color: Color(0xFF616161),
                                )
                              : Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        _commentImageFile!,
                                        width: inputHeight,
                                        height: inputHeight,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: CommonInkWell(
                                        onTap: () {
                                          setState(() => _commentImageFile = null);
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            PhosphorIconsRegular.x,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: inputHeight),
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
                      const SizedBox(width: 12),
                      SizedBox(
                        width: inputHeight,
                        height: inputHeight,
                        child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _controller,
                              builder: (context, value, _) {
                                final canSend =
                                    (value.text.trim().isNotEmpty ||
                                        _commentImageFile != null) &&
                                    !_isSending;
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
                    ],
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
