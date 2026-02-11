import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

import '../common/widgets/common_tab_view.dart';
import '../feed_list/feed_list_view.dart';
import '../map/map_view.dart';
import '../profile/profile_view.dart';
import '../notification/notification_view.dart';
import '../feed_create_photo/feed_create_photo_view.dart';
import '../common/state/home_tab_controller.dart';
import '../common/auth/auth_store.dart';
import '../sign/sign_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _currentIndex = HomeTabController.currentIndex.value;
    _applyStatusBarStyle(_currentIndex);
    _tabListener = () {
      final next = HomeTabController.currentIndex.value;
      if (next == _currentIndex) return;
      setState(() => _currentIndex = next);
      _applyStatusBarStyle(next);
    };
    HomeTabController.currentIndex.addListener(_tabListener);
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    super.dispose();
  }

  void _applyStatusBarStyle(int index) {
    final style = index == 1 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          MapView(),
          FeedListView(),
          SafeArea(top: true, bottom: true, child: SizedBox.shrink()),
          SafeArea(top: true, bottom: true, child: NotificationView()),
          SafeArea(bottom: true, child: ProfileView()),
        ],
      ),
      bottomNavigationBar: Container(
        color: _currentIndex == 1 ? Colors.black : Colors.white,
        child: SafeArea(
          bottom: true,
          child: CommonTabView(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == 2) {
                if (!AuthStore.instance.isSignedIn.value) {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) {
                      return const SizedBox.expand(
                        child: SignView(),
                      );
                    },
                  );
                  return;
                }
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: false,
                  backgroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  builder: (_) {
                    final height = MediaQuery.of(context).size.height;
                    return SizedBox(
                      height: height,
                      child: const FeedCreatePhotoView(),
                    );
                  },
                );
                return;
              }
              HomeTabController.switchTo(index);
            },
            backgroundColor: _currentIndex == 1 ? Colors.black : Colors.white,
            activeColor: _currentIndex == 1 ? Colors.white : Colors.black,
            inactiveColor: _currentIndex == 1 ? const Color(0xB3FFFFFF) : const Color(0xFF9E9E9E),
          ),
        ),
      ),
    );
  }
}
