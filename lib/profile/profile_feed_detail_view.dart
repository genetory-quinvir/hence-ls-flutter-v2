import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_feed_item_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../feed_list/models/feed_models.dart';

class ProfileFeedDetailView extends StatefulWidget {
  const ProfileFeedDetailView({
    super.key,
    required this.feeds,
    required this.initialIndex,
    this.onFeedUpdated,
    this.openCommentsOnAppear = false,
    this.safeAreaBottom = false,
    this.extraBottomPadding = 0,
  });

  final List<Feed> feeds;
  final int initialIndex;
  final void Function(Feed updated)? onFeedUpdated;
  final bool openCommentsOnAppear;
  final bool safeAreaBottom;
  final double extraBottomPadding;

  @override
  State<ProfileFeedDetailView> createState() => _ProfileFeedDetailViewState();
}

class _ProfileFeedDetailViewState extends State<ProfileFeedDetailView> {
  late final List<Feed> _feeds;

  @override
  void initState() {
    super.initState();
    _feeds = List.of(widget.feeds);
  }

  void _applyFeedLikeUpdate(String feedId, bool isLiked, int likeCount) {
    final index = _feeds.indexWhere((f) => f.id == feedId);
    if (index < 0) return;
    setState(() {
      _feeds[index] = _feeds[index].copyWith(
        isLiked: isLiked,
        likeCount: likeCount,
      );
    });
    widget.onFeedUpdated?.call(_feeds[index]);
  }

  void _applyFeedCommentCount(String feedId, int commentCount) {
    final index = _feeds.indexWhere((f) => f.id == feedId);
    if (index < 0) return;
    setState(() {
      _feeds[index] = _feeds[index].copyWith(
        commentCount: commentCount,
      );
    });
    widget.onFeedUpdated?.call(_feeds[index]);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: (widget.safeAreaBottom
                      ? MediaQuery.of(context).padding.bottom
                      : 0) +
                  widget.extraBottomPadding,
            ),
            child: Stack(
              children: [
                PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: PageController(initialPage: widget.initialIndex),
                  itemCount: _feeds.length,
                  itemBuilder: (context, index) {
                    return CommonFeedItemView(
                      key: ValueKey(_feeds[index].id),
                      feed: _feeds[index],
                      padding: EdgeInsets.zero,
                      autoOpenComments:
                          widget.openCommentsOnAppear && index == widget.initialIndex,
                      onLikeChanged: _applyFeedLikeUpdate,
                      onCommentCountChanged: _applyFeedCommentCount,
                    );
                  },
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: CommonInkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileFeedListView extends StatefulWidget {
  const ProfileFeedListView({
    super.key,
    required this.feeds,
    required this.initialIndex,
    this.onFeedUpdated,
  });

  final List<Feed> feeds;
  final int initialIndex;
  final void Function(Feed updated)? onFeedUpdated;

  @override
  State<ProfileFeedListView> createState() => _ProfileFeedListViewState();
}

class _ProfileFeedListViewState extends State<ProfileFeedListView> {
  late final PageController _pageController;
  late final List<Feed> _feeds;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _feeds = List.of(widget.feeds);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _feeds.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CommonFeedItemView(
                    key: ValueKey(_feeds[index].id),
                    feed: _feeds[index],
                    padding: EdgeInsets.zero,
                    onLikeChanged: (feedId, isLiked, likeCount) {
                      final i = _feeds.indexWhere((f) => f.id == feedId);
                      if (i < 0) return;
                      setState(() {
                        _feeds[i] = _feeds[i].copyWith(
                          isLiked: isLiked,
                          likeCount: likeCount,
                        );
                      });
                      widget.onFeedUpdated?.call(_feeds[i]);
                    },
                    onCommentCountChanged: (feedId, commentCount) {
                      final i = _feeds.indexWhere((f) => f.id == feedId);
                      if (i < 0) return;
                      setState(() {
                        _feeds[i] = _feeds[i].copyWith(
                          commentCount: commentCount,
                        );
                      });
                      widget.onFeedUpdated?.call(_feeds[i]);
                    },
                  ),
                );
              },
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CommonInkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
