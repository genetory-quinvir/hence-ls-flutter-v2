import 'package:flutter/material.dart';

import 'common_inkwell.dart';

class CommonNavigationView extends StatelessWidget {
  const CommonNavigationView({
    super.key,
    this.left,
    this.right,
    this.onLeftTap,
    this.onRightTap,
    this.title,
    this.subTitle,
    this.titleWidget,
    this.subTitleWidget,
    this.backgroundColor = Colors.transparent,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.height = 44,
  });

  final Widget? left;
  final Widget? right;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final String? title;
  final String? subTitle;
  final Widget? titleWidget;
  final Widget? subTitleWidget;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final double height;

  bool _isIconLike(Widget child) {
    return child is Icon || child is ImageIcon;
  }

  Widget _slot({
    required Widget child,
    required VoidCallback? onTap,
    required Alignment alignment,
  }) {
    final area = _isIconLike(child)
        ? SizedBox(
            width: 44,
            height: 44,
            child: Center(child: child),
          )
        : Align(
            alignment: alignment,
            widthFactor: 1,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: child,
            ),
          );
    return onTap == null
        ? area
        : CommonInkWell(
            onTap: onTap,
            child: area,
          );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 16,
      fontWeight: FontWeight.w600
    );
    final TextStyle subTitleStyle = const TextStyle(
      fontFamily: 'Pretendard',
    );
    final Widget? resolvedTitle = titleWidget ??
        (title == null
            ? null
            : Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ));
    final Widget? resolvedSubTitle = subTitleWidget ??
        (subTitle == null
            ? null
            : Text(
                subTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subTitleStyle,
              ));

    return SizedBox(
      height: height,
      child: Padding(
        padding: padding,
        child: DecoratedBox(
          decoration: BoxDecoration(color: backgroundColor),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: left == null
                    ? const SizedBox.shrink()
                    : _slot(
                        child: left!,
                        onTap: onLeftTap,
                        alignment: Alignment.centerLeft,
                      ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: right == null
                    ? const SizedBox.shrink()
                    : _slot(
                        child: right!,
                        onTap: onRightTap,
                        alignment: Alignment.centerRight,
                      ),
              ),
              if (resolvedTitle != null || resolvedSubTitle != null)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (resolvedTitle != null) resolvedTitle,
                        if (resolvedSubTitle != null) resolvedSubTitle,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
