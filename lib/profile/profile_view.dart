import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_store.dart';
import '../common/widgets/common_navigation_view.dart';
import '../settings/settings_view.dart';
import 'widgets/profile_not_signed_view.dart';
import 'widgets/profile_signed_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: CommonNavigationView(
              right: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsView()),
                  );
                },
                child: Icon(
                  PhosphorIconsRegular.gear,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: AuthStore.instance.isSignedIn,
              builder: (context, isSignedIn, _) {
                return isSignedIn
                    ? const ProfileSignedView()
                    : const ProfileNotSignedView();
              },
            ),
          ),
        ],
      ),
    );
  }
}
