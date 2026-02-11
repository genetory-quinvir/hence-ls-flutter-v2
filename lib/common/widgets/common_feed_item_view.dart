import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../feed_list/models/feed_models.dart';
import '../network/api_client.dart';
import '../utils/time_format.dart';
import 'common_inkwell.dart';
import 'common_image_view.dart';
import '../../feed_comment/feed_comment_view.dart';

class CommonFeedItemView extends StatefulWidget {
  const CommonFeedItemView({
    super.key,
    required this.feed,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Feed feed;
  final EdgeInsetsGeometry padding;

  @override
  State<CommonFeedItemView> createState() => _CommonFeedItemViewState();
}

class _CommonFeedItemViewState extends State<CommonFeedItemView> {
  bool _expanded = false;
  bool _isOverflowing = false;
  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);
  bool _isTogglingLike = false;
  late bool _liked;
  late int _likeCount;
  int _commentCount = 0;

  @override
  void dispose() {
    _pageIndex.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _liked = widget.feed.isLiked;
    _likeCount = widget.feed.likeCount;
    _commentCount = widget.feed.commentCount;
  }

  @override
  void didUpdateWidget(covariant CommonFeedItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed.id != widget.feed.id ||
        oldWidget.feed.isLiked != widget.feed.isLiked ||
        oldWidget.feed.likeCount != widget.feed.likeCount ||
        oldWidget.feed.commentCount != widget.feed.commentCount) {
      _liked = widget.feed.isLiked;
      _likeCount = widget.feed.likeCount;
      _commentCount = widget.feed.commentCount;
    }
  }

  Future<void> _toggleLike() async {
    if (_isTogglingLike) return;
    final nextLiked = !_liked;
    final nextCount = _likeCount + (nextLiked ? 1 : -1);
    setState(() {
      _isTogglingLike = true;
      _liked = nextLiked;
      _likeCount = nextCount < 0 ? 0 : nextCount;
    });
    try {
      await ApiClient.toggleFeedLike(widget.feed.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likeCount = widget.feed.likeCount;
        });
      }
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FeedCommentView(
        feedId: widget.feed.id,
        spaceId: widget.feed.space?.spaceId,
        comments: const [],
        onCommentAdded: () {
          if (!mounted) return;
          setState(() => _commentCount += 1);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final images = widget.feed.images;
    final content = widget.feed.content.trim();
    final author = widget.feed.author;
    final authorName = author.nickname.isNotEmpty ? author.nickname : author.name;
    final createdAt = formatRelativeTime(widget.feed.createdAt);
    final placeName = widget.feed.space?.placeName ?? '';
    final maxTextWidth = MediaQuery.of(context).size.width - 32;
    final textStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Colors.white,
    );
    if (content.isNotEmpty) {
      final span = TextSpan(text: content, style: textStyle);
      final painter = TextPainter(
        text: span,
        maxLines: 2,
        textDirection: TextDirection.ltr,
      );
      painter.layout(maxWidth: maxTextWidth);
      _isOverflowing = painter.didExceedMaxLines;
    } else {
      _isOverflowing = false;
    }
    return Container(
      height: screenHeight,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      alignment: Alignment.centerLeft,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.length <= 1)
            _ZoomableImageView(
              url: images.isNotEmpty ? (images.first.cdnUrl ?? images.first.fileUrl) : null,
            )
          else
            _FeedImagePager(
              images: images,
              onIndexChanged: (index) => _pageIndex.value = index,
            ),
          if (images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 66,
              left: 0,
              right: 0,
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _pageIndex,
                  builder: (context, index, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(images.length, (i) {
                          final isActive = i == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 8 : 6,
                            height: isActive ? 8 : 6,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : const Color(0x66FFFFFF),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xCC000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (content.isNotEmpty)
            Positioned(
              left: 16,
              right: 64,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF212121),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CommonImageView(
                          networkUrl: author.profileImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Text(
                                  createdAt,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xCCFFFFFF),
                                  ),
                                ),
                                if (placeName.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.place,
                                    size: 12,
                                    color: Color(0xCCFFFFFF),
                                  ),
                                  const SizedBox(width: 1),
                                  Flexible(
                                    child: Text(
                                      placeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xCCFFFFFF),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    content,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                  if (_isOverflowing) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded ? '숨기기' : '더보기',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionIcon(
                  icon: _liked ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                  color: _liked ? const Color(0xFFE53935) : Colors.white,
                  count: _likeCount,
                  onTap: _isTogglingLike ? null : _toggleLike,
                ),
                const SizedBox(height: 24),
                _ActionIcon(
                  icon: PhosphorIconsRegular.chatCircle,
                  count: _commentCount,
                  onTap: () => _openComments(context),
                ),
                const SizedBox(height: 24),
                _ActionIcon(
                  icon: PhosphorIconsRegular.shareNetwork,
                  count: 0,
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                _ActionIcon(
                  icon: PhosphorIconsRegular.star,
                  count: 0,
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                CommonInkWell(
                  onTap: () {},
                  child: const Icon(
                    PhosphorIconsRegular.dotsThree,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.count,
    this.color = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommonInkWell(
          onTap: onTap,
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _FeedImagePager extends StatefulWidget {
  const _FeedImagePager({
    required this.images,
    this.onIndexChanged,
  });

  final List<FeedImage> images;
  final ValueChanged<int>? onIndexChanged;

  @override
  State<_FeedImagePager> createState() => _FeedImagePagerState();
}

class _FeedImagePagerState extends State<_FeedImagePager> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.images.length,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
        widget.onIndexChanged?.call(index);
      },
      itemBuilder: (context, index) {
        final image = widget.images[index];
        return _ZoomableImageView(url: image.cdnUrl ?? image.fileUrl);
      },
    );
  }
}

class _ZoomableImageView extends StatefulWidget {
  const _ZoomableImageView({required this.url});

  final String? url;

  @override
  State<_ZoomableImageView> createState() => _ZoomableImageViewState();
}

class _ZoomableImageViewState extends State<_ZoomableImageView>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startFocal = Offset.zero;
  Offset _startOffset = Offset.zero;
  double _startScale = 1.0;
  late final AnimationController _resetController;
  Animation<double>? _scaleAnim;
  Animation<Offset>? _offsetAnim;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          _scale = _scaleAnim?.value ?? _scale;
          _offset = _offsetAnim?.value ?? _offset;
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _animateReset() {
    _resetController.stop();
    _scaleAnim = Tween<double>(begin: _scale, end: 1.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _offsetAnim = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _startFocal = details.focalPoint;
        _startOffset = _offset;
        _startScale = _scale;
      },
      onScaleUpdate: (details) {
        final nextScale = (_startScale * details.scale).clamp(1.0, 3.0);
        final focalDelta = details.focalPoint - _startFocal;
        setState(() {
          _scale = nextScale;
          if (details.scale != 1.0 || nextScale > 1.0) {
            _offset = _startOffset + focalDelta;
          }
        });
      },
      onScaleEnd: (_) => _animateReset(),
      child: Transform(
        transform: Matrix4.identity()
          ..translate(_offset.dx, _offset.dy)
          ..scale(_scale),
        alignment: Alignment.center,
        child: CommonImageView(networkUrl: widget.url),
      ),
    );
  }
}
