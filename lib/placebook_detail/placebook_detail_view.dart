import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hence_ls_flutter_v2/placebook_create/placebook_create_view.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_toast_view.dart';
import '../common/network/api_client.dart';
import '../common/auth/auth_store.dart';
import '../common/widgets/common_empty_view.dart';
import '../common/widgets/common_activity.dart';
import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_login_guard.dart';
import '../common/widgets/common_refresh_view.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_title_actionsheet.dart';
import '../common/widgets/common_alert_view.dart';
import '../common/widgets/common_place_carousel_list_item_view.dart';
import '../report/report_view.dart';
import '../common/permissions/media_permission_service.dart';
import '../common/media/media_picker_service.dart';
import '../common/media/media_conversion_service.dart';
import 'widgets/placebook_detail_profile_view.dart';
import 'widgets/placebook_detail_info_view.dart';
import '../feed_comment/models/feed_comment_model.dart';
import '../feed_comment/widgets/feed_comment_list_item_view.dart';

class PlacebookDetailView extends StatefulWidget {
  const PlacebookDetailView({super.key, required this.space});

  final Map<String, dynamic> space;

  @override
  State<PlacebookDetailView> createState() => _PlacebookDetailViewState();
}

class _PlacebookDetailViewState extends State<PlacebookDetailView> {
  late Map<String, dynamic> _space;
  bool _isLoading = false;
  bool _isLoadingComments = false;
  bool _isLoadingMoreComments = false;
  bool _hasMoreComments = false;
  String? _nextCommentCursor;
  bool _isCheckingIn = false;
  bool _hasCheckedIn = false;
  bool _didInitialReveal = false;
  int _commentCount = 0;
  List<FeedCommentItem> _commentPreview = const [];
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSendingComment = false;
  String _selectedCommentSort = 'latest';
  final ScrollController _scrollController = ScrollController();
  double? _pendingScrollOffset;
  bool _isPullRefreshing = false;
  File? _commentImageFile;
  bool _showFloatingNav = false;
  final Set<String> _togglingCommentLikeIds = {};
  final Map<String, List<FeedCommentItem>> _repliesByCommentId = {};
  final Set<String> _expandedReplies = {};
  final Set<String> _loadingReplies = {};
  final Set<String> _togglingReplyLikeIds = {};
  FeedCommentItem? _replyTarget;
  String? _mentionBadgeName;
  Timer? _favoriteToastTimer;
  bool _isFavoriteToastVisible = false;
  String _favoriteToastMessage = '';
  bool _skipFavoriteToastOut = false;
  int _favoriteToastSequence = 0;
  bool _isLoadingTrust = false;
  bool _isSubmittingTrustVote = false;
  int _helpfulCount = 0;
  int _suspiciousCount = 0;
  int _totalVotes = 0;
  int _helpfulRate = 0;
  String? _trustLabel;
  String? _userVote;

  @override
  void initState() {
    super.initState();
    _space = Map<String, dynamic>.from(widget.space);
    _refreshAll();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _favoriteToastTimer?.cancel();
    super.dispose();
  }

  void _showFavoriteToast(String message) {
    _favoriteToastTimer?.cancel();
    if (_isFavoriteToastVisible) {
      setState(() {
        _skipFavoriteToastOut = true;
        _isFavoriteToastVisible = false;
      });
      Future.microtask(() {
        if (!mounted) return;
        setState(() {
          _skipFavoriteToastOut = false;
          _favoriteToastMessage = message;
          _isFavoriteToastVisible = true;
          _favoriteToastSequence += 1;
        });
      });
    } else {
      setState(() {
        _favoriteToastMessage = message;
        _isFavoriteToastVisible = true;
        _favoriteToastSequence += 1;
      });
    }
    _favoriteToastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _isFavoriteToastVisible = false);
    });
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
            if (!mounted) return;
            setState(() => _commentImageFile = File(picked.path));
            break;
          case 'camera':
            if (!await MediaPermissionService.ensureCamera()) {
              _showPermissionSnack('카메라 권한이 필요합니다.');
              return;
            }
            final picked = await MediaPickerService.pickFromCamera();
            if (picked == null) return;
            if (!mounted) return;
            setState(() => _commentImageFile = File(picked.path));
            break;
        }
      },
    );
  }

  void _showPermissionSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _intFromAny(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  void _applyTrustPayload(Map<String, dynamic> payload) {
    final helpful = _intFromAny(payload['helpfulCount']);
    final suspicious = _intFromAny(payload['suspiciousCount']);
    final totalRaw = _intFromAny(
      payload['totalVotes'],
      fallback: helpful + suspicious,
    );
    final total = totalRaw > 0 ? totalRaw : helpful + suspicious;
    final rateRaw = _intFromAny(payload['helpfulRate'], fallback: 0);
    final nextRate = total > 0 ? rateRaw.clamp(0, 100).toInt() : 0;
    setState(() {
      _helpfulCount = helpful;
      _suspiciousCount = suspicious;
      _totalVotes = total;
      _helpfulRate = nextRate;
      _trustLabel = _stringOrEmpty(payload['trustLabel']);
      _userVote = _stringOrEmpty(payload['userVote']);
    });
  }

  Future<void> _loadPlaceTrust({bool silent = false}) async {
    final placeId = _extractPlaceId(_space) ?? '';
    if (placeId.isEmpty) return;
    if (_isLoadingTrust) return;
    if (!silent) {
      setState(() => _isLoadingTrust = true);
    }
    try {
      final trust = await ApiClient.fetchPlacebookPlaceTrust(placeId);
      if (!mounted) return;
      _applyTrustPayload(trust);
    } catch (_) {
      // ignore
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoadingTrust = false);
      }
    }
  }

  Future<void> _submitTrustVote(String voteType) async {
    if (_isSubmittingTrustVote) return;
    if (_userVote == voteType) {
      _showFavoriteToast('이미 같은 의견에 투표했어요.');
      return;
    }
    final placeId = _extractPlaceId(_space) ?? '';
    if (placeId.isEmpty) return;
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '장소 평가를 남기려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() => _isSubmittingTrustVote = true);
    try {
      final result = await ApiClient.votePlacebookPlace(
        placeId: placeId,
        voteType: voteType,
      );
      if (!mounted) return;
      _applyTrustPayload(result);
      final message = _stringOrEmpty(result['message']);
      if (message != null) {
        _showFavoriteToast(message);
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _isSubmittingTrustVote = false);
      }
    }
  }

  Future<void> _loadDetail({bool silent = false}) async {
    final placeId = _extractPlaceId(_space) ?? '';
    if (placeId.isEmpty) return;
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final detail = await ApiClient.fetchPlacebookPlaceDetail(placeId);
      if (!mounted) return;
      setState(() {
        _space = detail;
        _commentCount = (detail['commentCount'] as num?)?.toInt() ?? 0;
        _hasCheckedIn = _isSpaceFavorited(detail);
      });
    } catch (_) {
      // ignore for now, keep initial data
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshAll({bool fromPull = false, bool silent = false}) async {
    if (fromPull) {
      setState(() => _isPullRefreshing = true);
    }
    try {
      await _loadDetail(silent: silent);
      await _loadPlaceTrust(silent: silent);
      await _loadCommentPreview(silent: silent);
    } finally {
      if (mounted && fromPull) {
        setState(() => _isPullRefreshing = false);
      }
    }
  }

  Future<void> _loadCommentPreview({bool silent = false}) async {
    final placeId = _extractPlaceId(_space) ?? '';
    if (placeId.isEmpty) return;
    if (_isLoadingComments) return;
    if (!silent) {
      setState(() => _isLoadingComments = true);
    }
    try {
      final page = await ApiClient.fetchEntityComments(
        entityType: 'PLACEBOOK',
        entityId: placeId,
        limit: 50,
        orderBy: _selectedCommentSort,
      );
      if (!mounted) return;
      setState(() {
        _commentPreview = page.comments;
        _hasMoreComments = page.hasNext;
        _nextCommentCursor = page.nextCursor;
        if (page.totalCount != null) {
          _commentCount = page.totalCount!;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commentPreview = const [];
        _hasMoreComments = false;
        _nextCommentCursor = null;
      });
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoadingComments = false);
      }
      if (!mounted || _pendingScrollOffset == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final maxExtent = _scrollController.position.maxScrollExtent;
        final target = _pendingScrollOffset!.clamp(0.0, maxExtent);
        _scrollController.jumpTo(target);
        _pendingScrollOffset = null;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    final placeId = _extractPlaceId(_space) ?? '';
    if (placeId.isEmpty) return;
    if (_isLoadingMoreComments || !_hasMoreComments) return;
    final cursor = _nextCommentCursor;
    if (cursor == null || cursor.isEmpty) return;
    setState(() => _isLoadingMoreComments = true);
    try {
      final page = await ApiClient.fetchEntityComments(
        entityType: 'PLACEBOOK',
        entityId: placeId,
        cursor: cursor,
        limit: 50,
        orderBy: _selectedCommentSort,
      );
      if (!mounted) return;
      setState(() {
        _commentPreview = List.of(_commentPreview)..addAll(page.comments);
        _hasMoreComments = page.hasNext;
        _nextCommentCursor = page.nextCursor;
        if (page.totalCount != null) {
          _commentCount = page.totalCount!;
        }
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoadingMoreComments = false);
    }
  }

  Future<void> _sendPlacebookComment(String placeId) async {
    if (_isSendingComment) return;
    final content = _commentController.text.trim();
    final hasImage = _commentImageFile != null;
    if (content.isEmpty && !hasImage) return;
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '댓글을 작성하려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() => _isSendingComment = true);
    try {
      String? imageId;
      if (hasImage && _commentImageFile != null) {
        final webp = await MediaConversionService.toWebp(
          _commentImageFile!,
          quality: 85,
        );
        imageId = await ApiClient.uploadCommentImage(webp);
      }
      final target = _replyTarget;
      final badgeName = _mentionBadgeName?.trim();
      final mentionPrefix = badgeName != null && badgeName.isNotEmpty
          ? '@$badgeName '
          : '';
      final payloadContent =
          mentionPrefix.isNotEmpty && !content.startsWith(mentionPrefix)
          ? '$mentionPrefix$content'.trimRight()
          : content;
      await ApiClient.createEntityComment(
        entityType: 'PLACEBOOK',
        entityId: placeId,
        content: payloadContent,
        parentId: target?.id,
        imageId: imageId,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() => _commentImageFile = null);
      setState(() {
        _replyTarget = null;
        _mentionBadgeName = null;
      });
      _refreshAll(silent: true);
    } catch (_) {
      // Ignore send errors for now.
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _handleReplyTap(FeedCommentItem target) async {
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '답글을 작성하려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() {
      _replyTarget = target;
      _mentionBadgeName = target.authorName.trim().isEmpty
          ? null
          : target.authorName.trim();
    });
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  Future<void> _handleMentionTap(FeedCommentItem target) async {
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '멘션하려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() {
      _replyTarget = null;
      _mentionBadgeName = target.authorName.trim().isEmpty
          ? null
          : target.authorName.trim();
    });
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  Future<void> _toggleCommentLikeAt(int index) async {
    if (index < 0 || index >= _commentPreview.length) return;
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '좋아요를 누르려면 로그인해주세요.',
    )) {
      return;
    }
    final comment = _commentPreview[index];
    if (_togglingCommentLikeIds.contains(comment.id)) return;
    final nextLiked = !comment.isLiked;
    final nextCount = comment.likeCount + (nextLiked ? 1 : -1);
    setState(() {
      _togglingCommentLikeIds.add(comment.id);
      _commentPreview = List.of(_commentPreview)
        ..[index] = FeedCommentItem(
          id: comment.id,
          content: comment.content,
          createdAt: comment.createdAt,
          authorName: comment.authorName,
          authorId: comment.authorId,
          authorProfileUrl: comment.authorProfileUrl,
          authorDeletedAt: comment.authorDeletedAt,
          imageId: comment.imageId,
          imageUrl: comment.imageUrl,
          isLiked: nextLiked,
          likeCount: nextCount < 0 ? 0 : nextCount,
          replyCount: comment.replyCount,
        );
    });
    try {
      await ApiClient.setCommentLike(commentId: comment.id, isLiked: nextLiked);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commentPreview = List.of(_commentPreview)..[index] = comment;
      });
    } finally {
      if (!mounted) return;
      setState(() => _togglingCommentLikeIds.remove(comment.id));
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
      final replies = await ApiClient.fetchCommentReplies(commentId: commentId);
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
    if (_togglingReplyLikeIds.contains(reply.id)) return;
    final nextLiked = !reply.isLiked;
    final nextCount = reply.likeCount + (nextLiked ? 1 : -1);
    setState(() {
      _togglingReplyLikeIds.add(reply.id);
      final nextReplies = List<FeedCommentItem>.from(replies);
      nextReplies[index] = FeedCommentItem(
        id: reply.id,
        content: reply.content,
        createdAt: reply.createdAt,
        authorName: reply.authorName,
        authorId: reply.authorId,
        authorProfileUrl: reply.authorProfileUrl,
        authorDeletedAt: reply.authorDeletedAt,
        imageId: reply.imageId,
        imageUrl: reply.imageUrl,
        isLiked: nextLiked,
        likeCount: nextCount < 0 ? 0 : nextCount,
        replyCount: reply.replyCount,
      );
      _repliesByCommentId[parentId] = nextReplies;
    });
    try {
      await ApiClient.setCommentLike(commentId: reply.id, isLiked: nextLiked);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final restored = List<FeedCommentItem>.from(replies);
        restored[index] = reply;
        _repliesByCommentId[parentId] = restored;
      });
    } finally {
      if (mounted) {
        setState(() => _togglingReplyLikeIds.remove(reply.id));
      }
    }
  }

  Future<void> _toggleFavorite() async {
    await _handleCheckin();
  }

  void _showPlaceMoreSheet({required bool isMine, required String placeId}) {
    final items = isMine
        ? const [
            CommonTitleActionSheetItem(label: '수정하기', value: 'edit'),
            CommonTitleActionSheetItem(
              label: '삭제하기',
              value: 'delete',
              isDestructive: true,
            ),
          ]
        : const [
            CommonTitleActionSheetItem(
              label: '신고하기',
              value: 'report',
              isDestructive: true,
            ),
            CommonTitleActionSheetItem(label: '공유하기', value: 'share'),
          ];
    CommonTitleActionSheet.show(
      context,
      title: '더보기',
      items: items,
      onSelected: (item) {
        switch (item.value) {
          case 'edit':
            // TODO: place edit flow
            debugPrint('[PLACEBOOK] edit place');
            break;
          case 'delete':
            if (placeId.isEmpty) return;
            showDialog<void>(
              context: context,
              barrierDismissible: true,
              barrierColor: const Color(0x99000000),
              builder: (_) {
                return Material(
                  type: MaterialType.transparency,
                  child: CommonAlertView(
                    title: '장소를 삭제할까요?',
                    subTitle: '삭제하면 되돌릴 수 없어요.',
                    primaryButtonTitle: '삭제하기',
                    secondaryButtonTitle: '취소',
                    onPrimaryTap: () async {
                      Navigator.of(context).pop();
                      try {
                        await ApiClient.deletePlacebookPlace(placeId);
                        if (!mounted) return;
                        Navigator.of(context).maybePop(true);
                      } catch (e) {
                        debugPrint('[PLACEBOOK] delete failed: $e');
                      }
                    },
                    onSecondaryTap: () => Navigator.of(context).pop(),
                  ),
                );
              },
            );
            break;
          case 'report':
            if (placeId.isEmpty) return;
            ReportView.show(context, placeId: placeId);
            break;
          case 'share':
            // TODO: share flow
            debugPrint('[PLACEBOOK] share place');
            break;
          default:
            break;
        }
      },
    );
  }

  Widget _buildNavActions({
    required bool isMine,
    required bool isFavorited,
    required Color iconColor,
    required String placeId,
  }) {
    Widget navIcon({required IconData icon, required VoidCallback onTap}) {
      return CommonInkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: Icon(icon, size: 24, color: iconColor)),
        ),
      );
    }

    if (isMine) {
      return navIcon(
        icon: PhosphorIconsBold.dotsThree,
        onTap: () => _showPlaceMoreSheet(isMine: true, placeId: placeId),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        navIcon(
          icon: isFavorited
              ? PhosphorIconsFill.bookmarkSimple
              : PhosphorIconsBold.bookmarkSimple,
          onTap: _toggleFavorite,
        ),
        navIcon(
          icon: PhosphorIconsBold.dotsThree,
          onTap: () => _showPlaceMoreSheet(isMine: false, placeId: placeId),
        ),
      ],
    );
  }

  Widget _buildCommentInput(
    String placeId, {
    EdgeInsetsGeometry padding = const EdgeInsets.only(top: 12),
  }) {
    const inputHeight = 50.0;
    final replyLabel = _mentionBadgeName?.trim().isNotEmpty == true
        ? _mentionBadgeName
        : null;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyLabel != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '@$replyLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 6),
                      CommonInkWell(
                        onTap: () {
                          setState(() {
                            _replyTarget = null;
                            _mentionBadgeName = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Icon(
                          PhosphorIconsRegular.x,
                          size: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_commentImageFile == null)
                CommonInkWell(
                  onTap: _showCommentImageActionSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: inputHeight,
                    height: inputHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      PhosphorIconsRegular.camera,
                      size: 20,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                )
              else
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                        onTap: () => setState(() => _commentImageFile = null),
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
                    controller: _commentController,
                    focusNode: _commentFocusNode,
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
              const SizedBox(width: 10),
              SizedBox(
                width: inputHeight,
                height: inputHeight,
                child: CommonRoundedButton(
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
                  onTap: _isSendingComment
                      ? null
                      : () => _sendPlacebookComment(placeId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckin() async {
    if (_isCheckingIn) return;
    final placeId = _extractPlaceId(_space) ?? '';
    if (placeId.isEmpty) return;
    if (!await CommonLoginGuard.ensureSignedIn(
      context,
      title: '로그인이 필요합니다.',
      subTitle: '도감 등록하려면 로그인해주세요.',
    )) {
      return;
    }
    setState(() => _isCheckingIn = true);
    try {
      final currentUser = AuthStore.instance.currentUser.value;
      final userId = currentUser?.id ?? '';
      final nextUsers = List<dynamic>.from(_extractFavoriteUsers(_space));
      if (nextUsers.isEmpty && _space['checkinUsers'] is List) {
        nextUsers.addAll(_space['checkinUsers'] as List);
      }
      final hasCheckedIn = _hasCheckedIn || _isSpaceFavorited(_space);
      if (hasCheckedIn) {
        await ApiClient.unfavoritePlace(placeId);
        if (userId.isNotEmpty) {
          nextUsers.removeWhere((u) => _extractUserId(u) == userId);
        }
        if (!mounted) return;
        setState(() {
          _hasCheckedIn = false;
          _space = {
            ..._space,
            'favorited': false,
            'favoriteUsers': nextUsers,
            'favoriteCount': nextUsers.length,
            'favoritesCount': nextUsers.length,
            'checkinUsers': nextUsers,
            'checkinCount': nextUsers.length,
            'participantCount': nextUsers.length,
          };
        });
        _showFavoriteToast('즐겨찾기에서 제거했어요');
        return;
      }

      await ApiClient.favoritePlace(placeId);
      if (!mounted) return;
      if (userId.isNotEmpty &&
          !nextUsers.any((u) => _extractUserId(u) == userId)) {
        nextUsers.insert(0, {
          'userId': userId,
          'profileImageUrl': currentUser?.profileImageUrl,
          'nickname': currentUser?.nickname,
        });
      }
      setState(() {
        _hasCheckedIn = true;
        _space = {
          ..._space,
          'favorited': true,
          'favoriteUsers': nextUsers,
          'favoriteCount': nextUsers.length,
          'favoritesCount': nextUsers.length,
          'checkinUsers': nextUsers,
          'checkinCount': nextUsers.length,
          'participantCount': nextUsers.length,
        };
      });
      _showFavoriteToast('즐겨찾기에 추가했어요');
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isReady = !_isLoading && !_isLoadingComments;
    final showContent = isReady || _didInitialReveal;
    if (isReady && !_didInitialReveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didInitialReveal) return;
        setState(() => _didInitialReveal = true);
      });
    }
    final title =
        (_space['title'] as String?) ??
        (_space['spaceTitle'] as String?) ??
        (_space['name'] as String?) ??
        '도감';
    final imageUrls = _extractImageUrls(_space);
    final thumbnail = imageUrls.isNotEmpty ? imageUrls.first : '';
    final user = _space['createdByUser'] is Map<String, dynamic>
        ? _space['createdByUser'] as Map<String, dynamic>
        : _space['creator'] is Map<String, dynamic>
        ? _space['creator'] as Map<String, dynamic>
        : _space['createdBy'] is Map<String, dynamic>
        ? _space['createdBy'] as Map<String, dynamic>
        : _space['author'] is Map<String, dynamic>
        ? _space['author'] as Map<String, dynamic>
        : _space['user'] is Map<String, dynamic>
        ? _space['user'] as Map<String, dynamic>
        : _space['host'] is Map<String, dynamic>
        ? _space['host'] as Map<String, dynamic>
        : null;
    final profileImageUrl =
        _extractProfileImageUrl(user?['profileImage']) ??
        _stringOrEmpty(user?['profileImageUrl']) ??
        _stringOrEmpty(user?['thumbnailUrl']) ??
        _stringOrEmpty(user?['avatarUrl']);
    final nickname =
        _stringOrEmpty(user?['nickname']) ??
        _stringOrEmpty(_space['creatorNickname']) ??
        _stringOrEmpty(_space['authorNickname']) ??
        '-';
    final categoryLabel = _extractCategoryTitle(_space);
    final themeLabel = _extractThemeTitle(_space);
    final themeId = _extractThemeId(_space);
    final userId =
        _stringOrEmpty(user?['userId']) ?? _stringOrEmpty(user?['id']) ?? '';
    final currentUserId = AuthStore.instance.currentUser.value?.id;
    final isMine =
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        currentUserId == userId;
    final isDeletedUser =
        _stringOrEmpty(user?['deletedAt'])?.trim().isNotEmpty == true;
    final place =
        _stringOrEmpty(_space['address']) ??
        _stringOrEmpty(_space['placeName']) ??
        '-';
    final latitude =
        _toDouble(_space['latitude']) ??
        _toDouble(_space['lat']) ??
        _toDouble(_space['locationLat']) ??
        _toDouble((_space['location'] as Map?)?['lat']) ??
        _toDouble((_space['location'] as Map?)?['latitude']);
    final longitude =
        _toDouble(_space['longitude']) ??
        _toDouble(_space['lng']) ??
        _toDouble(_space['locationLng']) ??
        _toDouble((_space['location'] as Map?)?['lng']) ??
        _toDouble((_space['location'] as Map?)?['longitude']);
    final time = _formatTime(
      _stringOrEmpty(_space['time']) ??
          _stringOrEmpty(_space['startAt']) ??
          _stringOrEmpty(_space['startTime']) ??
          _stringOrEmpty(_space['date']) ??
          _stringOrEmpty(_space['createdAt']),
    );
    final status =
        _stringOrEmpty(_space['status']) ??
        _stringOrEmpty(_space['liveStatus']) ??
        _stringOrEmpty(_space['state']) ??
        '-';
    if (_commentCount == 0) {
      _commentCount = (_space['commentCount'] as num?)?.toInt() ?? 0;
    }
    final favoriteUsers = _extractFavoriteUsers(_space);
    final displayUsers = favoriteUsers.isNotEmpty
        ? favoriteUsers
        : (_space['checkinUsers'] is List
              ? _space['checkinUsers'] as List
              : const []);
    final hasCheckedIn = _hasCheckedIn || _isSpaceFavorited(_space);
    final participantCount = displayUsers.length > 0
        ? displayUsers.length
        : (_space['participantCount'] as num?)?.toInt() ??
              (_space['participantsCount'] as num?)?.toInt() ??
              (_space['favoriteCount'] as num?)?.toInt() ??
              (_space['favoritesCount'] as num?)?.toInt() ??
              (_space['checkinCount'] as num?)?.toInt() ??
              (_space['checkins'] as num?)?.toInt() ??
              0;
    final relatedPlaces = _extractRelatedPlaces(_space);
    final placeId = _extractPlaceId(_space) ?? '';
    const commentInputHeight = 50.0;
    const commentInputPadding = EdgeInsets.fromLTRB(16, 8, 16, 8);
    final commentInputTotalHeight =
        commentInputHeight + commentInputPadding.vertical;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _showFloatingNav
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: placeId.isNotEmpty
            ? AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                    commentInputPadding.horizontal / 2,
                    commentInputPadding.vertical / 2,
                    commentInputPadding.horizontal / 2,
                    (commentInputPadding.vertical / 2) +
                        (MediaQuery.of(context).viewInsets.bottom > 0
                            ? 0
                            : safeBottom),
                  ),
                  child: _buildCommentInput(placeId, padding: EdgeInsets.zero),
                ),
              )
            : null,
        body: Stack(
          children: [
            CommonRefreshView(
              onRefresh: () => _refreshAll(fromPull: true, silent: true),
              topPadding: MediaQuery.of(context).padding.top + 8,
              notificationPredicate: (notification) => notification.depth == 0,
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: showContent ? 1 : 0,
                    duration: _didInitialReveal
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: IgnorePointer(
                      ignoring: !showContent,
                      child: Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.axis != Axis.vertical) {
                                return false;
                              }
                              if (notification is ScrollUpdateNotification ||
                                  notification is ScrollEndNotification) {
                                final shouldShow =
                                    notification.metrics.extentBefore > 0;
                                if (shouldShow != _showFloatingNav) {
                                  setState(() => _showFloatingNav = shouldShow);
                                }
                                if (notification.metrics.extentAfter < 300) {
                                  _loadMoreComments();
                                }
                              }
                              return false;
                            },
                            child: CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                SliverAppBar(
                                  automaticallyImplyLeading: false,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  systemOverlayStyle: _showFloatingNav
                                      ? SystemUiOverlayStyle.dark
                                      : SystemUiOverlayStyle.light,
                                  pinned: false,
                                  stretch: true,
                                  expandedHeight: 385,
                                  collapsedHeight: 385,
                                  toolbarHeight: 0,
                                  flexibleSpace: FlexibleSpaceBar(
                                    stretchModes: const [
                                      StretchMode.zoomBackground,
                                    ],
                                    background: PlacebookDetailProfileView(
                                      title: title,
                                      locationTitle: place,
                                      imageUrls: imageUrls.isNotEmpty
                                          ? imageUrls
                                          : [thumbnail],
                                      profileImageUrl: profileImageUrl,
                                      nickname: nickname,
                                      userId: userId,
                                      categoryLabel: categoryLabel,
                                      themeLabel: themeLabel,
                                      isDeletedUser: isDeletedUser,
                                      participantCount: participantCount,
                                      checkinUsers: displayUsers,
                                      isCheckedIn: hasCheckedIn,
                                      isCheckingIn: _isCheckingIn,
                                      onCheckinTap: _handleCheckin,
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: PlacebookDetailInfoView(
                                    title: title,
                                    place: place,
                                    latitude: latitude,
                                    longitude: longitude,
                                    time: time,
                                    status: status,
                                    profileImageUrl: profileImageUrl,
                                    nickname: nickname,
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: _PlacebookTrustVoteSection(
                                    isLoading: _isLoadingTrust,
                                    isSubmitting: _isSubmittingTrustVote,
                                    helpfulCount: _helpfulCount,
                                    suspiciousCount: _suspiciousCount,
                                    totalVotes: _totalVotes,
                                    helpfulRate: _helpfulRate,
                                    trustLabel: _trustLabel,
                                    userVote: _userVote,
                                    onHelpfulTap: () =>
                                        _submitTrustVote('HELPFUL'),
                                    onSuspiciousTap: () =>
                                        _submitTrustVote('SUSPICIOUS'),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: _NearbyPlacesSection(
                                    isLoading: false,
                                    places: relatedPlaces,
                                    themeId: themeId,
                                    themeTitle: themeLabel,
                                  ),
                                ),
                                const SliverToBoxAdapter(
                                  child: _SectionDivider(),
                                ),
                                SliverToBoxAdapter(
                                  child: _PlacebookDetailCommentsSection(
                                    commentCount: _commentCount,
                                    comments: _commentPreview,
                                    isLoading: _isLoadingComments,
                                    selectedSort: _selectedCommentSort,
                                    onLikeTap: _toggleCommentLikeAt,
                                    onReplyTap: _handleReplyTap,
                                    onMentionTap: _handleMentionTap,
                                    onToggleReplies: _toggleReplies,
                                    onReplyLikeTap: _toggleReplyLike,
                                    repliesByCommentId: _repliesByCommentId,
                                    expandedReplies: _expandedReplies,
                                    isLoadingMore: _isLoadingMoreComments,
                                    onSortSelected: (next) {
                                      if (next == _selectedCommentSort) return;
                                      _pendingScrollOffset =
                                          _scrollController.hasClients
                                          ? _scrollController.offset
                                          : null;
                                      setState(
                                        () => _selectedCommentSort = next,
                                      );
                                      _loadCommentPreview();
                                    },
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height:
                                        commentInputTotalHeight +
                                        safeBottom +
                                        (hasCheckedIn ? 16.0 : 24.0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SafeArea(
                            bottom: false,
                            child: CommonNavigationView(
                              backgroundColor: Colors.transparent,
                              left: const Icon(
                                PhosphorIconsBold.caretLeft,
                                size: 24,
                                color: Colors.white,
                              ),
                              onLeftTap: () => Navigator.of(context).maybePop(),
                              right: _buildNavActions(
                                isMine: isMine,
                                isFavorited: hasCheckedIn,
                                iconColor: Colors.white,
                                placeId: placeId,
                              ),
                              onRightTap: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!showContent)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  if (showContent && _isLoadingComments && !_isPullRefreshing)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x80FFFFFF),
                        child: Center(
                          child: CommonActivityIndicator(
                            size: 28,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: IgnorePointer(
                      ignoring: !_showFloatingNav,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        offset: _showFloatingNav
                            ? Offset.zero
                            : const Offset(0, -1),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: _showFloatingNav ? 1 : 0,
                          child: Container(
                            color: Colors.white,
                            child: SafeArea(
                              bottom: false,
                              child: CommonNavigationView(
                                backgroundColor: Colors.white,
                                title: title,
                                left: const Icon(
                                  PhosphorIconsBold.caretLeft,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                right: _buildNavActions(
                                  isMine: isMine,
                                  isFavorited: hasCheckedIn,
                                  iconColor: Colors.black,
                                  placeId: placeId,
                                ),
                                onLeftTap: () =>
                                    Navigator.of(context).maybePop(),
                                onRightTap: null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.of(context).padding.top + 8,
              child: IgnorePointer(
                ignoring: true,
                child: CommonToastView(
                  visible: _isFavoriteToastVisible,
                  message: _favoriteToastMessage,
                  sequence: _favoriteToastSequence,
                  skipOutAnimation: _skipFavoriteToastOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _stringOrEmpty(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      final name = value['name'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
      final address = value['address'];
      if (address is String && address.trim().isNotEmpty) {
        return address.trim();
      }
    }
    return value.toString();
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final two = (int value) => value.toString().padLeft(2, '0');
    final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final meridiem = parsed.hour < 12 ? 'AM' : 'PM';
    return '${parsed.year}. ${two(parsed.month)}. ${two(parsed.day)} '
        '$meridiem $hour12:${two(parsed.minute)}';
  }

  static String? _extractProfileImageUrl(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return _stringOrEmpty(raw['cdnUrl']) ??
          _stringOrEmpty(raw['fileUrl']) ??
          _stringOrEmpty(raw['thumbnailUrl']);
    }
    return null;
  }

  static String? _extractCategoryTitle(Map<String, dynamic> space) {
    final category = space['category'];
    if (category is Map<String, dynamic>) {
      return _stringOrEmpty(category['name']) ??
          _stringOrEmpty(category['title']);
    }
    final place = space['place'];
    if (place is Map<String, dynamic>) {
      final nested = place['category'];
      if (nested is Map<String, dynamic>) {
        return _stringOrEmpty(nested['name']) ??
            _stringOrEmpty(nested['title']);
      }
    }
    return null;
  }

  static String? _extractThemeTitle(Map<String, dynamic> space) {
    final theme = space['theme'];
    if (theme is Map<String, dynamic>) {
      return _stringOrEmpty(theme['name']) ?? _stringOrEmpty(theme['title']);
    }
    final themes = space['themes'];
    if (themes is List) {
      for (final item in themes) {
        if (item is Map<String, dynamic>) {
          final name =
              _stringOrEmpty(item['name']) ?? _stringOrEmpty(item['title']);
          if (name != null) return name;
        }
      }
    }
    final place = space['place'];
    if (place is Map<String, dynamic>) {
      final nested = place['theme'];
      if (nested is Map<String, dynamic>) {
        return _stringOrEmpty(nested['name']) ??
            _stringOrEmpty(nested['title']);
      }
    }
    return null;
  }

  static String? _extractThemeId(Map<String, dynamic> space) {
    final theme = space['theme'];
    if (theme is Map<String, dynamic>) {
      final id = theme['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    final themeId = space['themeId'];
    if (themeId is String && themeId.isNotEmpty) return themeId;
    final place = space['place'];
    if (place is Map<String, dynamic>) {
      final nestedTheme = place['theme'];
      if (nestedTheme is Map<String, dynamic>) {
        final id = nestedTheme['id'];
        if (id is String && id.isNotEmpty) return id;
      }
      final nestedId = place['themeId'];
      if (nestedId is String && nestedId.isNotEmpty) return nestedId;
    }
    return null;
  }

  static String? _extractPlaceId(Map<String, dynamic> space) {
    final direct = space['placeId'] ?? space['id'] ?? space['entityId'];
    if (direct is String && direct.isNotEmpty) return direct;
    final place = space['place'];
    if (place is Map<String, dynamic>) {
      final nested = place['id'] ?? place['placeId'];
      if (nested is String && nested.isNotEmpty) return nested;
    }
    return null;
  }

  static List<dynamic> _extractFavoriteUsers(Map<String, dynamic> space) {
    final keys = [
      'favoriteUsers',
      'favorites',
      'favoritedUsers',
      'bookmarkUsers',
      'bookmarkedUsers',
      'collectorUsers',
      'collectUsers',
    ];
    for (final key in keys) {
      final raw = space[key];
      if (raw is List) return raw;
    }
    final place = space['place'];
    if (place is Map<String, dynamic>) {
      for (final key in keys) {
        final raw = place[key];
        if (raw is List) return raw;
      }
    }
    return const [];
  }

  bool _isSpaceFavorited(Map<String, dynamic> space) {
    final raw =
        space['favorited'] ??
        space['isFavorite'] ??
        space['isFavorited'] ??
        space['isBookmarked'] ??
        space['isCollected'];
    if (raw is bool) return raw;
    final users = _extractFavoriteUsers(space);
    if (users.isNotEmpty) return _isCurrentUserCheckedIn(users);
    return false;
  }

  bool _isCurrentUserCheckedIn(List<dynamic> users) {
    final currentUserId = AuthStore.instance.currentUser.value?.id;
    if (currentUserId == null || currentUserId.isEmpty) return false;
    return users.any((user) => _extractUserId(user) == currentUserId);
  }

  String? _extractUserId(dynamic user) {
    if (user is Map<String, dynamic>) {
      final id = user['userId'] ?? user['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  static List<String> _extractImageUrls(Map<String, dynamic> space) {
    final urls = <String>[];
    final imageIdRaw = space['imageId'];
    if (imageIdRaw is Map<String, dynamic>) {
      final url =
          imageIdRaw['cdnUrl'] as String? ??
          imageIdRaw['fileUrl'] as String? ??
          imageIdRaw['thumbnailUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        urls.add(url.trim());
      }
    }
    final imageRaw = space['image'];
    if (imageRaw is Map<String, dynamic>) {
      final url =
          imageRaw['cdnUrl'] as String? ??
          imageRaw['fileUrl'] as String? ??
          imageRaw['thumbnailUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        urls.add(url.trim());
      }
    }
    final imagesRaw = space['images'];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is String) {
          if (item.trim().isNotEmpty) urls.add(item.trim());
        } else if (item is Map<String, dynamic>) {
          final url =
              item['cdnUrl'] as String? ??
              item['fileUrl'] as String? ??
              item['thumbnailUrl'] as String?;
          if (url != null && url.trim().isNotEmpty) {
            urls.add(url.trim());
          }
        }
      }
    }
    final thumbRaw = space['thumbnail'];
    if (thumbRaw is String && thumbRaw.trim().isNotEmpty) {
      urls.add(thumbRaw.trim());
    } else if (thumbRaw is Map<String, dynamic>) {
      final url =
          thumbRaw['cdnUrl'] as String? ??
          thumbRaw['fileUrl'] as String? ??
          thumbRaw['thumbnailUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        urls.add(url.trim());
      }
    }
    final fallback =
        space['thumbnailUrl'] as String? ?? space['imageUrl'] as String?;
    if (fallback != null && fallback.trim().isNotEmpty) {
      urls.add(fallback.trim());
    }
    final deduped = <String>[];
    for (final url in urls) {
      if (!deduped.contains(url)) deduped.add(url);
    }
    return deduped;
  }
}

List<Map<String, dynamic>> _extractRelatedPlaces(Map<String, dynamic> space) {
  final raw = space['relatedPlaces'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(_normalizePlaceListItem)
      .toList(growable: false);
}

Map<String, dynamic> _normalizePlaceListItem(Map<String, dynamic> item) {
  final next = Map<String, dynamic>.from(item);
  final idRaw = item['id'];
  if (idRaw is Map<String, dynamic>) {
    next.remove('id');
    next.addAll(idRaw);
    final nestedId = idRaw['id'];
    if (nestedId != null) {
      next['id'] = nestedId.toString();
      next['placeId'] ??= nestedId.toString();
    }
  }
  return next;
}

String _resolvePlaceImageUrl(Map<String, dynamic> place) {
  final idRaw = place['id'];
  final idMap = idRaw is Map<String, dynamic> ? idRaw : null;
  final thumbnailRaw = place['thumbnail'];
  final thumbnailMap = thumbnailRaw is Map<String, dynamic>
      ? thumbnailRaw
      : null;
  final imageIdRaw = place['imageId'];
  final imageIdMap = imageIdRaw is Map<String, dynamic> ? imageIdRaw : null;
  final imageRaw = place['image'];
  final imageMap = imageRaw is Map<String, dynamic> ? imageRaw : null;
  final idImageRaw = idMap?['image'];
  final idImageMap = idImageRaw is Map<String, dynamic> ? idImageRaw : null;
  final feed = place['feed'];
  final feedMap = feed is Map<String, dynamic> ? feed : null;
  final images = feedMap?['images'] ?? place['images'];
  Map<String, dynamic>? firstImageMap;
  String? firstImageString;
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is Map<String, dynamic>) {
      firstImageMap = first;
    } else if (first is String) {
      firstImageString = first;
    }
  }

  return _firstValidImageUrl([
    thumbnailRaw is String ? thumbnailRaw : null,
    place['thumbnailUrl'] as String?,
    place['imageUrl'] as String?,
    idMap?['thumbnailUrl'] as String?,
    idMap?['imageUrl'] as String?,
    thumbnailMap?['thumbnailUrl'] as String?,
    thumbnailMap?['cdnUrl'] as String?,
    thumbnailMap?['fileUrl'] as String?,
    imageIdMap?['thumbnailUrl'] as String?,
    imageIdMap?['cdnUrl'] as String?,
    imageIdMap?['fileUrl'] as String?,
    imageMap?['thumbnailUrl'] as String?,
    imageMap?['cdnUrl'] as String?,
    imageMap?['fileUrl'] as String?,
    idImageMap?['thumbnailUrl'] as String?,
    idImageMap?['cdnUrl'] as String?,
    idImageMap?['fileUrl'] as String?,
    firstImageMap?['thumbnailUrl'] as String?,
    firstImageMap?['cdnUrl'] as String?,
    firstImageMap?['fileUrl'] as String?,
    firstImageString,
  ]);
}

String _firstValidImageUrl(List<String?> candidates) {
  for (final url in candidates) {
    if (url != null && url.trim().isNotEmpty) return url.trim();
  }
  return '';
}

class _PlacebookTrustVoteSection extends StatelessWidget {
  const _PlacebookTrustVoteSection({
    required this.isLoading,
    required this.isSubmitting,
    required this.helpfulCount,
    required this.suspiciousCount,
    required this.totalVotes,
    required this.helpfulRate,
    required this.trustLabel,
    required this.userVote,
    required this.onHelpfulTap,
    required this.onSuspiciousTap,
  });

  final bool isLoading;
  final bool isSubmitting;
  final int helpfulCount;
  final int suspiciousCount;
  final int totalVotes;
  final int helpfulRate;
  final String? trustLabel;
  final String? userVote;
  final VoidCallback onHelpfulTap;
  final VoidCallback onSuspiciousTap;

  @override
  Widget build(BuildContext context) {
    final label = trustLabel == 'HELPFUL'
        ? '도움됨'
        : trustLabel == 'SUSPICIOUS'
        ? '의심됨'
        : '검증 대기';
    final trustMetaText = '$label · 도움률 $helpfulRate% · 총 $totalVotes표';
    final helpfulSelected = userVote == 'HELPFUL';
    final suspiciousSelected = userVote == 'SUSPICIOUS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '장소 검증',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (helpfulCount > 0)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$helpfulCount',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '명의 유저들이 도움을 받았어요!'),
                ],
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            )
          else
            const Text(
              '아직 첫 검증을 기다리고 있어요.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            trustMetaText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CommonActivityIndicator(size: 20))
          else
            Row(
              children: [
                Expanded(
                  child: _TrustVoteButton(
                    emoji: '😊',
                    label: '도움돼요',
                    count: helpfulCount,
                    selected: helpfulSelected,
                    enabled: !isSubmitting && !helpfulSelected,
                    onTap: onHelpfulTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TrustVoteButton(
                    emoji: '😟',
                    label: '의심돼요',
                    count: suspiciousCount,
                    selected: suspiciousSelected,
                    enabled: !isSubmitting && !suspiciousSelected,
                    onTap: onSuspiciousTap,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TrustVoteButton extends StatelessWidget {
  const _TrustVoteButton({
    required this.emoji,
    required this.label,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF222222) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF222222) : const Color(0xFFE4E4E4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: const Color(0xFFF5F5F5));
  }
}

class _NearbyPlacesSection extends StatelessWidget {
  const _NearbyPlacesSection({
    required this.isLoading,
    required this.places,
    this.themeId,
    this.themeTitle,
  });

  final bool isLoading;
  final List<Map<String, dynamic>> places;
  final String? themeId;
  final String? themeTitle;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CommonActivityIndicator(size: 22)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '같은 테마를 가지고 있는 장소',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          if (places.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CommonEmptyView(
                height: 100,
                message: '근처에 등록된 장소가 없습니다.',
                showButton: true,
                buttonText: '장소 등록하기',
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (_) => SizedBox.expand(
                      child: PlacebookCreateView(
                        themeId: themeId,
                        themeTitle: themeTitle,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 12,
                ),
                itemCount: places.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final place = places[index];
                  final title = (place['title'] as String?) ?? '장소';
                  final address = (place['address'] as String?) ?? '';
                  final commentCount =
                      (place['commentCount'] as num?)?.toInt() ??
                      (place['verificationCount'] as num?)?.toInt() ??
                      0;
                  final likeCount =
                      (place['likeCount'] as num?)?.toInt() ??
                      (place['favoriteCount'] as num?)?.toInt() ??
                      0;
                  final favorited =
                      (place['favorited'] as bool?) ??
                      (place['isFavorited'] as bool?) ??
                      false;
                  final distanceKm = place['distanceKm'];
                  final distanceText = distanceKm is num
                      ? '${distanceKm.toStringAsFixed(distanceKm < 1 ? 2 : 1)}km'
                      : null;
                  final themeText =
                      _PlacebookDetailViewState._extractThemeTitle(place);
                  return SizedBox(
                    width: 320,
                    child: CommonPlaceCarouselListItemView(
                      thumbnailUrl: _resolvePlaceImageUrl(place),
                      title: title,
                      address: address,
                      commentCount: commentCount,
                      likeCount: likeCount,
                      themeText: themeText,
                      distanceText: distanceText,
                      favorited: favorited,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlacebookDetailView(space: place),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PlacebookDetailCommentsSection extends StatelessWidget {
  const _PlacebookDetailCommentsSection({
    required this.commentCount,
    required this.comments,
    required this.isLoading,
    required this.selectedSort,
    required this.onSortSelected,
    required this.onLikeTap,
    required this.onReplyTap,
    required this.onMentionTap,
    required this.onToggleReplies,
    required this.onReplyLikeTap,
    required this.repliesByCommentId,
    required this.expandedReplies,
    required this.isLoadingMore,
  });

  final int commentCount;
  final List<FeedCommentItem> comments;
  final bool isLoading;
  final String selectedSort;
  final ValueChanged<String> onSortSelected;
  final ValueChanged<int> onLikeTap;
  final ValueChanged<FeedCommentItem> onReplyTap;
  final ValueChanged<FeedCommentItem> onMentionTap;
  final ValueChanged<FeedCommentItem> onToggleReplies;
  final void Function(String parentId, int index) onReplyLikeTap;
  final Map<String, List<FeedCommentItem>> repliesByCommentId;
  final Set<String> expandedReplies;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    const minBodyHeight = 120.0;
    const sortOptions = [
      {'label': '최신순', 'value': 'latest'},
      {'label': '인기순', 'value': 'popular'},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '댓글',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  for (var i = 0; i < sortOptions.length; i++) ...[
                    if (i != 0)
                      Container(
                        width: 1,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: const Color(0x33000000),
                      ),
                    GestureDetector(
                      onTap: () => onSortSelected(sortOptions[i]['value']!),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        sortOptions[i]['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selectedSort == sortOptions[i]['value']
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedSort == sortOptions[i]['value']
                              ? Colors.black
                              : const Color(0x88000000),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minBodyHeight),
            child: Builder(
              builder: (_) {
                if (comments.isEmpty) {
                  return Center(
                    child: CommonEmptyView(
                      message: '아직 댓글이 없어요.',
                      showButton: false,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < comments.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: FeedCommentListItemView(
                          comment: comments[i],
                          onLikeTap: () => onLikeTap(i),
                          onReplyTap: () => onReplyTap(comments[i]),
                          onMentionTap: () => onMentionTap(comments[i]),
                          onToggleReplies:
                              comments[i].replyCount != null &&
                                  comments[i].replyCount! > 0
                              ? () => onToggleReplies(comments[i])
                              : null,
                          hasReplies: (comments[i].replyCount ?? 0) > 0,
                          repliesExpanded: expandedReplies.contains(
                            comments[i].id,
                          ),
                        ),
                      ),
                      if (expandedReplies.contains(comments[i].id))
                        _CommentRepliesList(
                          parentId: comments[i].id,
                          replies:
                              repliesByCommentId[comments[i].id] ?? const [],
                          onLikeTap: onReplyLikeTap,
                          onMentionTap: onMentionTap,
                        ),
                    ],
                    if (isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        child: CommonActivityIndicator(
                          size: 20,
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRepliesList extends StatelessWidget {
  const _CommentRepliesList({
    required this.parentId,
    required this.replies,
    required this.onLikeTap,
    required this.onMentionTap,
  });

  final String parentId;
  final List<FeedCommentItem> replies;
  final void Function(String parentId, int index) onLikeTap;
  final ValueChanged<FeedCommentItem> onMentionTap;

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 16),
      child: Column(
        children: [
          for (var i = 0; i < replies.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FeedCommentListItemView(
                comment: replies[i],
                onLikeTap: () => onLikeTap(parentId, i),
                onMentionTap: () => onMentionTap(replies[i]),
              ),
            ),
        ],
      ),
    );
  }
}
