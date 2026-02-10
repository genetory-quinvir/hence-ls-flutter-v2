import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/widgets/common_navigation_view.dart';

class ProfileEditView extends StatelessWidget {
  const ProfileEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: CommonNavigationView(
              left: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  PhosphorIconsRegular.caretLeft,
                  size: 24,
                  color: Colors.black,
                ),
              ),
              title: '프로필 편집',
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
