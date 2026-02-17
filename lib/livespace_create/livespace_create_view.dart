import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../common/widgets/common_navigation_view.dart';

class LivespaceCreateView extends StatelessWidget {
  const LivespaceCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            CommonNavigationView(
              left: const Icon(Icons.close, size: 22, color: Colors.black),
              onLeftTap: () => Navigator.of(context).pop(),
              title: '라이브스페이스 만들기',
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 52,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'TODO: 라이브스페이스 생성 화면',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
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
