import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../common/state/home_tab_controller.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_profile_view.dart';
import '../settings/settings_view.dart';
import 'widgets/profile_not_signed_view.dart';
import 'widgets/profile_signed_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final VoidCallback _tabListener;
  late final VoidCallback _profileReloadListener;
  bool _isRefreshingMe = false;
  bool _showCompactProfileInNav = false;

  @override
  void initState() {
    super.initState();
    _tabListener = () {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 4) {
        _refreshMe();
      }
    };
    _profileReloadListener = () {
      if (!mounted) return;
      _refreshMe();
    };
    HomeTabController.currentIndex.addListener(_tabListener);
    HomeTabController.profileReloadSignal.addListener(_profileReloadListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (HomeTabController.currentIndex.value == 4) {
        _refreshMe();
      }
    });
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    HomeTabController.profileReloadSignal.removeListener(_profileReloadListener);
    super.dispose();
  }

  Future<void> _refreshMe() async {
    if (_isRefreshingMe) return;
    if (!AuthStore.instance.isSignedIn.value) return;
    _isRefreshingMe = true;
    try {
      final me = await ApiClient.fetchMe();
      await AuthStore.instance.setUser(me);
    } catch (_) {
      // Ignore refresh failures; existing cached user remains visible.
    } finally {
      _isRefreshingMe = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            SafeArea(
              bottom: true,
              child: ValueListenableBuilder(
                valueListenable: AuthStore.instance.currentUser,
                builder: (context, user, _) {
                  final nickname = (user?.nickname.trim().isNotEmpty ?? false)
                      ? user!.nickname.trim()
                      : '사용자';
                  return CommonNavigationView(
                    left: AnimatedOpacity(
                      opacity: _showCompactProfileInNav ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: IgnorePointer(
                        ignoring: true,
                        child: _ProfileNavigationIdentity(
                          nickname: nickname,
                          profileImageUrl: user?.profileImageUrl,
                        ),
                      ),
                    ),
                    right: const Icon(
                      PhosphorIconsRegular.gear,
                      size: 24,
                      color: Colors.black,
                    ),
                    onRightTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsView()),
                      );
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: AuthStore.instance.isSignedIn,
                builder: (context, isSignedIn, _) {
                  if (!isSignedIn) {
                    if (_showCompactProfileInNav) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _showCompactProfileInNav = false);
                      });
                    }
                    return const ProfileNotSignedView();
                  }
                  return ProfileSignedView(
                    onHeaderCollapsedChanged: (isCollapsed) {
                      if (_showCompactProfileInNav == isCollapsed) return;
                      setState(() => _showCompactProfileInNav = isCollapsed);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileNavigationIdentity extends StatelessWidget {
  const _ProfileNavigationIdentity({
    required this.nickname,
    required this.profileImageUrl,
  });

  final String nickname;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CommonProfileView(
          size: 24,
          networkUrl: profileImageUrl,
          placeholder: Container(
            color: const Color(0xFFF2F2F2),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsRegular.user,
              size: 12,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
