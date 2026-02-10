import 'package:flutter/material.dart';

import 'common_inkwell.dart';

class CommonEmptyView extends StatelessWidget {
  const CommonEmptyView({
    super.key,
    this.message = '현재 피드가 없습니다.',
    this.buttonText = '피드 작성하기',
    this.onTap,
  });

  final String message;
  final String buttonText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 12),
          CommonInkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: IntrinsicWidth(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
