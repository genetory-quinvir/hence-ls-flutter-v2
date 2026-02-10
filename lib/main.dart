import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';

import 'common/auth/auth_store.dart';
import 'splash/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterNaverMap().init(clientId: 'e2m4s9kqcr');
  await NaverLoginSDK.initialize(
    urlScheme: 'naverlogin',
    clientId: 'ID_k_BsZBjdg1eeK9w2Q',
    clientSecret: 'ued7WXTlVk',
    clientName: 'Hence',
  );
  KakaoSdk.init(
    nativeAppKey: '953283b12d3126b851a6b33164a2790a',
    javaScriptAppKey: '5e4b6ed85d22e8855fc77e1d56ae6bde',
  );
  await AuthStore.instance.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Empty App',
      theme: ThemeData(
        fontFamily: 'Pretendard',
      ),
      home: const SplashView(),
    );
  }
}

// HomeScreen moved to lib/home/home_screen.dart
