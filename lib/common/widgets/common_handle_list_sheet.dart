import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'common_inkwell.dart';

class CommonHandleListSheet extends StatelessWidget {
  const CommonHandleListSheet({
    super.key,
    this.title,
    this.trailing,
    this.items = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.initialChildSize = 0.55,
    this.minChildSize = 0.35,
    this.maxChildSize = 0.92,
  });

  final String? title;
  final Widget? trailing;
  final List<Widget> items;
  final EdgeInsets padding;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    Widget? trailing,
    List<Widget> items = const [],
    EdgeInsets padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    double initialChildSize = 0.55,
    double minChildSize = 0.35,
    double maxChildSize = 0.92,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CommonHandleListSheet(
          title: title,
          trailing: trailing,
          items: items,
          padding: padding,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        snap: true,
        snapSizes: const [0.35, 0.55, 0.92],
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        builder: (context, scrollController) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Transform.translate(
                offset: const Offset(0, -50),
                child: SizedBox(
                  height: constraints.maxHeight + 50,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        if (title != null || trailing != null) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                if (title != null)
                                  Expanded(
                                    child: Text(
                                      title!,
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  )
                                else
                                  const Spacer(),
                                ?trailing,
                              ],
                            ),
                          ),
                        ],
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            padding: padding,
                            itemBuilder: (context, index) => items[index],
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemCount: items.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CommonHandleListOverlay extends StatefulWidget {
  const CommonHandleListOverlay({
    super.key,
    this.title,
    this.trailing,
    this.count,
    this.items = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.peekHeight = 50,
    this.initialChildSize = 0.35,
    this.maxChildSize = 0.93,
    this.useBottomSafeArea = true,
    this.cacheExtent,
    this.onSizeChanged,
    this.onHeightChanged,
  });

  final String? title;
  final Widget? trailing;
  final int? count;
  final List<Widget> items;
  final EdgeInsets padding;
  final double peekHeight;
  final double initialChildSize;
  final double maxChildSize;
  final bool useBottomSafeArea;
  final double? cacheExtent;
  final ValueChanged<double>? onSizeChanged;
  final ValueChanged<double>? onHeightChanged;

  @override
  State<CommonHandleListOverlay> createState() =>
      _CommonHandleListOverlayState();
}

class _HandleListTitle extends StatelessWidget {
  const _HandleListTitle({
    required this.title,
    required this.count,
  });

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final text = count != null ? '$title $count' : title;
    final match = RegExp(r'^(\d+)( 개의 장소를 발견했어요!?)$').firstMatch(text);
    if (match != null) {
      final number = match.group(1) ?? '';
      final suffix = match.group(2) ?? '';
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: number,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: suffix,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CommonHandleListOverlayState extends State<CommonHandleListOverlay> {
  late final DraggableScrollableController _controller;
  double _minChildSize = 0.1;
  double _maxChildSize = 1.0;
  double _sheetMaxHeight = 0;
  double? _lastSnapTarget;

  void _handleSheetSizeChanged() {
    if (!_controller.isAttached) return;
    final current = _controller.size;
    widget.onSizeChanged?.call(current);
    if (_sheetMaxHeight > 0) {
      widget.onHeightChanged?.call(current * _sheetMaxHeight);
    }
    if ((current - _minChildSize).abs() < 0.02) {
      _lastSnapTarget = _minChildSize;
    } else if ((current - _maxChildSize).abs() < 0.02) {
      _lastSnapTarget = _maxChildSize;
    }
  }

  void _animateToTarget(double target) {
    if (!_controller.isAttached) return;
    final current = _controller.size;
    if ((current - target).abs() < 0.01) return;
    if (_lastSnapTarget != null &&
        (_lastSnapTarget! - target).abs() < 0.001) {
      return;
    }
    _lastSnapTarget = target;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = DraggableScrollableController();
    _controller.addListener(_handleSheetSizeChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleSheetSizeChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sheetMaxHeight = constraints.maxHeight;
        _minChildSize =
            (widget.peekHeight / constraints.maxHeight).clamp(0.08, 0.4);
        final extra = 8 / constraints.maxHeight;
        final maxSize =
            (widget.maxChildSize + extra).clamp(_minChildSize, 1.0);
        _maxChildSize = maxSize;
        final initialSize =
            widget.initialChildSize.clamp(_minChildSize, maxSize);
        return SafeArea(
          top: false,
          bottom: widget.useBottomSafeArea,
          child: DraggableScrollableSheet(
            controller: _controller,
            snap: true,
            minChildSize: _minChildSize,
            initialChildSize: initialSize,
            maxChildSize: maxSize,
            snapSizes: [_minChildSize, maxSize],
            builder: (context, scrollController) {
              final isMinimized = _controller.isAttached
                  ? (_controller.size - _minChildSize).abs() < 0.02
                  : (initialSize - _minChildSize).abs() < 0.02;
              final listPadding = widget.padding.copyWith(bottom: 28);
              final listController = scrollController;
              void handleDragUpdate(DragUpdateDetails details) {
                if (!_controller.isAttached) return;
                _lastSnapTarget = null;
                final delta = details.primaryDelta ?? 0;
                final next = (_controller.size - (delta / constraints.maxHeight))
                    .clamp(_minChildSize, maxSize);
                _controller.jumpTo(next);
              }

              void handleDragEnd(DragEndDetails details) {
                if (!_controller.isAttached) return;
                final velocity = details.primaryVelocity ?? 0;
                final target = velocity.abs() > 200
                    ? (velocity < 0 ? maxSize : _minChildSize)
                    : ((_controller.size - _minChildSize) <
                            (maxSize - _controller.size)
                        ? _minChildSize
                        : maxSize);
                _animateToTarget(target);
              }

              void handleToggleTap() {
                void run() {
                  if (!_controller.isAttached) return;
                  final current = _controller.size;
                  final distToMin = (current - _minChildSize).abs();
                  final distToMax = (current - maxSize).abs();
                  final target =
                      distToMin <= distToMax ? maxSize : _minChildSize;
                  _animateToTarget(target);
                }

                run();
                WidgetsBinding.instance.addPostFrameCallback((_) => run());
              }

              void handleMinimize() {
                void run() {
                  if (!_controller.isAttached) return;
                  _animateToTarget(_minChildSize);
                }

                run();
                WidgetsBinding.instance.addPostFrameCallback((_) => run());
              }

              void handleMaximize() {
                void run() {
                  if (!_controller.isAttached) return;
                  _animateToTarget(maxSize);
                }

                run();
                WidgetsBinding.instance.addPostFrameCallback((_) => run());
              }

              const headerHeight = 72.0;
              Widget buildListView() {
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is UserScrollNotification &&
                        notification.direction != ScrollDirection.idle) {
                      if (notification.direction == ScrollDirection.forward) {
                        if (!listController.hasClients) return false;
                        final atTop = listController.position.extentBefore <= 0;
                        if (atTop) {
                          handleMinimize();
                        }
                      } else if (notification.direction ==
                          ScrollDirection.reverse) {
                        handleMaximize();
                      }
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: listController,
                    padding: listPadding,
                    primary: false,
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: widget.cacheExtent,
                    itemBuilder: (context, index) => widget.items[index],
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 2),
                    itemCount: widget.items.length,
                  ),
                );
              }
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(top: headerHeight),
                        child: isMinimized
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_controller.isAttached) {
                                    _controller.animateTo(
                                      maxSize,
                                      duration:
                                          const Duration(milliseconds: 320),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                                child: buildListView(),
                              )
                            : buildListView(),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          handleToggleTap();
                        },
                        child: Container(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onVerticalDragUpdate: handleDragUpdate,
                                onVerticalDragEnd: handleDragEnd,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 44,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.title != null ||
                                  widget.trailing != null ||
                                  widget.count != null) ...[
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      if (widget.title != null)
                                        Expanded(
                                          child: _HandleListTitle(
                                            title: widget.title!,
                                            count: widget.count,
                                          ),
                                        )
                                      else
                                        const Spacer(),
                                      if (widget.trailing != null)
                                        widget.trailing!,
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
