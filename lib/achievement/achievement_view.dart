import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';

class AchievementView extends StatelessWidget {
  const AchievementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              CommonNavigationView(
                left: const Icon(
                  PhosphorIconsBold.caretLeft,
                  size: 24,
                  color: Colors.black,
                ),
                onLeftTap: () => Navigator.of(context).maybePop(),
                title: '나의 업적',
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '업적 화면 준비 중',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
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
