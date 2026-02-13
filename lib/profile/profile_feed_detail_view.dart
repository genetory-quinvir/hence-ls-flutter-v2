import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_feed_item_view.dart';
import '../common/widgets/common_inkwell.dart';
import '../feed_list/models/feed_models.dart';

class ProfileFeedDetailView extends StatelessWidget {
  const ProfileFeedDetailView({
    super.key,
    required this.feeds,
    required this.initialIndex,
  });

  final List<Feed> feeds;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              scrollDirection: Axis.vertical,
              controller: PageController(initialPage: initialIndex),
              itemCount: feeds.length,
              itemBuilder: (context, index) {
                return CommonFeedItemView(
                  key: ValueKey(feeds[index].id),
                  feed: feeds[index],
                  padding: EdgeInsets.zero,
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

class ProfileFeedListView extends StatefulWidget {
  const ProfileFeedListView({
    super.key,
    required this.feeds,
    required this.initialIndex,
  });

  final List<Feed> feeds;
  final int initialIndex;

  @override
  State<ProfileFeedListView> createState() => _ProfileFeedListViewState();
}

class _ProfileFeedListViewState extends State<ProfileFeedListView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
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
              itemCount: widget.feeds.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CommonFeedItemView(
                    key: ValueKey(widget.feeds[index].id),
                    feed: widget.feeds[index],
                    padding: EdgeInsets.zero,
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
