import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/widgets/common_tab_view.dart';
import '../feed_list/feed_list_view.dart';
import '../map/map_view.dart';
import '../profile/profile_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _applyStatusBarStyle(_currentIndex);
  }

  void _applyStatusBarStyle(int index) {
    final style = index == 1 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          MapView(),
          FeedListView(),
          SafeArea(bottom: true, child: SizedBox.shrink()),
          SafeArea(bottom: true, child: SizedBox.shrink()),
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
              setState(() => _currentIndex = index);
              _applyStatusBarStyle(index);
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
