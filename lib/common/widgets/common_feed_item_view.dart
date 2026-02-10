import 'package:flutter/material.dart';

import '../../feed_list/models/feed_models.dart';
import 'common_image_view.dart';

class CommonFeedItemView extends StatelessWidget {
  const CommonFeedItemView({
    super.key,
    required this.feed,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Feed feed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final images = feed.images;
    return Container(
      height: screenHeight,
      padding: padding,
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
            _FeedImagePager(images: images),
        ],
      ),
    );
  }
}

class _FeedImagePager extends StatefulWidget {
  const _FeedImagePager({required this.images});

  final List<FeedImage> images;

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
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          itemBuilder: (context, index) {
            final image = widget.images[index];
            return _ZoomableImageView(url: image.cdnUrl ?? image.fileUrl);
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (index) {
              final isActive = index == _currentIndex;
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
        ),
      ],
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
