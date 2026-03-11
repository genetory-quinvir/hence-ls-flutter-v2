import 'package:flutter/material.dart';

import 'common_inkwell.dart';

class CommonRoundedButton extends StatelessWidget {
  const CommonRoundedButton({
    super.key,
    required this.title,
    required this.onTap,
    this.height = 50,
    this.backgroundColor = Colors.black,
    this.textColor = Colors.white,
    this.textStyle,
    this.radius = 12,
    this.borderColor,
    this.borderWidth = 1,
    this.leading,
    this.leadingPadding = const EdgeInsets.only(left: 16),
    this.leadingCentered = false,
    this.leadingGap = 12,
    this.trailing,
    this.trailingPadding = const EdgeInsets.only(right: 16),
    this.trailingCentered = false,
    this.trailingGap = 8,
    this.contentPadding = EdgeInsets.zero,
  });

  final String title;
  final VoidCallback? onTap;
  final double height;
  final Color backgroundColor;
  final Color textColor;
  final TextStyle? textStyle;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Widget? leading;
  final EdgeInsetsGeometry leadingPadding;
  final bool leadingCentered;
  final double leadingGap;
  final Widget? trailing;
  final EdgeInsetsGeometry trailingPadding;
  final bool trailingCentered;
  final double trailingGap;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle = (textStyle ??
            const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ))
        .copyWith(color: textStyle?.color ?? textColor);

    return SizedBox(
      height: height,
      child: CommonInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(radius),
            border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
          ),
          child: (leading == null && trailing == null)
              ? Padding(
                  padding: contentPadding,
                  child: Center(
                    child: Text(
                      title,
                      style: effectiveTextStyle,
                    ),
                  ),
                )
              : (leadingCentered || trailingCentered
                  ? Center(
                      child: Padding(
                        padding: contentPadding,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (leading != null) ...[
                              leading!,
                              SizedBox(width: leadingGap),
                            ],
                            Text(
                              title,
                              style: effectiveTextStyle,
                            ),
                            if (trailing != null) ...[
                              SizedBox(width: trailingGap),
                              trailing!,
                            ],
                          ],
                        ),
                      ),
                    )
                  : IntrinsicWidth(
                      child: Stack(
                        fit: StackFit.loose,
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: contentPadding,
                            child: Center(
                              child: Text(
                                title,
                                style: effectiveTextStyle,
                              ),
                            ),
                          ),
                          if (leading != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: leadingPadding,
                                child: leading!,
                              ),
                            ),
                          if (trailing != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: trailingPadding,
                                child: trailing!,
                              ),
                            ),
                        ],
                      ),
                    )),
        ),
      ),
    );
  }
}
