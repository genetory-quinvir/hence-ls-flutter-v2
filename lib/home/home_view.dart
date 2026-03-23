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
import '../placebook_create/placebook_create_view.dart';
import '../placebook/placebook_view.dart';
import '../common/network/api_client.dart';

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
    Future<void>.microtask(() async {
      try {
        await ApiClient.fetchFeatured();
      } catch (_) {
        // ignore prefetch failures
      }
    });
  }

  @override
  void dispose() {
    HomeTabController.currentIndex.removeListener(_tabListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarStyle = _currentIndex == 0
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.dark;
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
            _PlacebookWrapper(),
            SafeArea(bottom: true, child: ProfileView()),
            SafeArea(top: true, bottom: true, child: NotificationView()),
          ],
        ),
        bottomNavigationBar: Container(
          color: Colors.white,
          child: SafeArea(
            bottom: true,
            child: CommonTabView(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == 3 && _currentIndex == 3) {
                  HomeTabController.requestProfileReload();
                }
                if (index == 2 && !AuthStore.instance.isSignedIn.value) {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) {
                      return const SizedBox.expand(child: SignView());
                    },
                  );
                  return;
                }
                HomeTabController.switchTo(index);
              },
              onCenterTap: () {
                if (!AuthStore.instance.isSignedIn.value) {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) {
                      return const SizedBox.expand(child: SignView());
                    },
                  );
                  return;
                }
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) {
                    return const SizedBox.expand(child: PlacebookCreateView());
                  },
                );
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

class _PlacebookWrapper extends StatelessWidget {
  const _PlacebookWrapper();

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        padding: data.padding.copyWith(bottom: 0),
        viewPadding: data.viewPadding.copyWith(bottom: 0),
      ),
      child: const PlacebookView(),
    );
  }
}
