import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_tab_view.dart';
import '../map/map_view.dart';
import '../profile/profile_view.dart';
import '../common/state/home_tab_controller.dart';
import '../common/auth/auth_store.dart';
import '../sign/sign_view.dart';
import '../notification/notification_view.dart';
import '../featured/featured_view.dart';
import '../placebook/placebook_list_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  late final VoidCallback _tabListener;

  @override
  void initState() {
    super.initState();
    _currentIndex = HomeTabController.currentIndex.value;
    _tabListener = () {
      final next = HomeTabController.currentIndex.value;
      if (next == _currentIndex) return;
      setState(() => _currentIndex = next);
    };
    HomeTabController.currentIndex.addListener(_tabListener);
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarStyle =
        _currentIndex == 0 ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            FeaturedView(),
            MapView(),
            _PlacebookListWrapper(),
            SafeArea(top: true, bottom: true, child: NotificationView()),
            SafeArea(bottom: true, child: ProfileView()),
          ],
        ),
        bottomNavigationBar: Container(
          color: Colors.white,
          child: SafeArea(
            bottom: true,
            child: CommonTabView(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == 4 && _currentIndex == 4) {
                  HomeTabController.requestProfileReload();
                }
                if (index == 3 || index == 2) {
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
                }
                HomeTabController.switchTo(index);
              },
              backgroundColor: Colors.white,
              activeColor: Colors.black,
              inactiveColor: const Color(0xFF9E9E9E),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlacebookListWrapper extends StatelessWidget {
  const _PlacebookListWrapper();

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        padding: data.padding.copyWith(bottom: 0),
        viewPadding: data.viewPadding.copyWith(bottom: 0),
      ),
      child: const PlacebookListView(),
    );
  }
}
