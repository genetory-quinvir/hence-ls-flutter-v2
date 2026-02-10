import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_rounded_button.dart';

class SignSuccessView extends StatelessWidget {
  const SignSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            CommonNavigationView(
              left: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Icon(
                  PhosphorIconsRegular.x,
                  size: 24,
                  color: Colors.black,
                ),
              ),
              title: '회원가입 완료',
            ),
            const Expanded(
              child: Center(
                child: Text(
                  '회원가입이 완료되었습니다.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: CommonRoundedButton(
                title: '확인',
                onTap: () => Navigator.of(context).pop(),
                height: 50,
                radius: 25,
                backgroundColor: Colors.black,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

