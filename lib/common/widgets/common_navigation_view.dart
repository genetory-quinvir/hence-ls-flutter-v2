import 'package:flutter/material.dart';

class CommonNavigationView extends StatelessWidget {
  const CommonNavigationView({
    super.key,
    this.left,
    this.right,
    this.title,
    this.subTitle,
    this.titleWidget,
    this.subTitleWidget,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.height = 44,
  });

  final Widget? left;
  final Widget? right;
  final String? title;
  final String? subTitle;
  final Widget? titleWidget;
  final Widget? subTitleWidget;
  final EdgeInsetsGeometry padding;
  final double height;

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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: left ?? const SizedBox.shrink(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: right ?? const SizedBox.shrink(),
            ),
            if (resolvedTitle != null || resolvedSubTitle != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (resolvedTitle != null) resolvedTitle,
                    if (resolvedSubTitle != null) resolvedSubTitle,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
