import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/auth/auth_store.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';
import '../home/home_screen.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final platform = Platform.isIOS ? 'ios' : 'aos';
    const version = '1.0.0';
    await ApiClient.fetchConfig(platform: platform, version: version);
    try {
      await AuthStore.instance.refreshSession(
        refresher: (refreshToken) => ApiClient.refreshSession(refreshToken: refreshToken),
      );
      if (AuthStore.instance.isSignedIn.value) {
        final me = await ApiClient.fetchMe();
        await AuthStore.instance.setUser(me);
      }
    } catch (_) {
      await AuthStore.instance.clear();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            return const Center(
              child: CommonActivityIndicator(color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}
