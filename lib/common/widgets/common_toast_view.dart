import 'package:flutter/material.dart';

class CommonToastView extends StatelessWidget {
  const CommonToastView({
    super.key,
    required this.visible,
    required this.message,
    required this.sequence,
    this.skipOutAnimation = false,
  });

  final bool visible;
  final String message;
  final int sequence;
  final bool skipOutAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 900),
      reverseDuration:
          skipOutAnimation ? Duration.zero : const Duration(milliseconds: 350),
      switchInCurve: Curves.elasticOut,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, -3.0),
          end: Offset.zero,
        );
        return SlideTransition(
          position: offsetTween.animate(animation),
          child: child,
        );
      },
      child: visible
          ? Container(
              key: ValueKey('toast-$sequence'),
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const ShapeDecoration(
                color: Colors.black,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
