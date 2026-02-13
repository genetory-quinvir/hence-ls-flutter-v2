import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_store.dart';
import '../common/notifications/fcm_service.dart';
import '../common/widgets/common_alert_view.dart';
import '../common/widgets/common_navigation_view.dart';
import '../web/web_view.dart';
import 'widgets/settings_menu_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool? _pushEnabled;

  @override
  void initState() {
    super.initState();
    _loadPushStatus();
  }

  Future<void> _loadPushStatus() async {
    final enabled = await FcmService.getAppPushEnabled();
    if (!mounted) return;
    setState(() => _pushEnabled = enabled);
  }

  Future<void> _handlePushToggle(bool next) async {
    setState(() => _pushEnabled = next);
    if (next) {
      final granted = await FcmService.requestPermission();
      if (!granted) {
        await FcmService.setAppPushEnabled(false);
        if (mounted) setState(() => _pushEnabled = false);
        return;
      }
      await FcmService.refreshTokenAndRegister();
      await FcmService.setAppPushEnabled(true);
      if (mounted) setState(() => _pushEnabled = true);
      return;
    }
    await FcmService.deleteTokenAndExpire();
    await FcmService.setAppPushEnabled(false);
    if (mounted) setState(() => _pushEnabled = false);
  }

  @override
  Widget build(BuildContext context) {
    const version = '1.0.0';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
          SafeArea(
            bottom: false,
            child: CommonNavigationView(
              left: const Icon(
                PhosphorIconsRegular.caretLeft,
                size: 24,
                color: Colors.black,
              ),
              onLeftTap: () => Navigator.of(context).maybePop(),
              title: '설정',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: AuthStore.instance.isSignedIn,
              builder: (context, isSignedIn, _) {
                void showLogoutAlert() {
                  showDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    barrierColor: const Color(0x99000000),
                    builder: (_) {
                      return Material(
                        type: MaterialType.transparency,
                        child: CommonAlertView(
                          title: '로그아웃',
                          subTitle: '정말 로그아웃 하시겠어요?',
                          primaryButtonTitle: '로그아웃',
                          secondaryButtonTitle: '취소',
                          onPrimaryTap: () async {
                            try {
                              await NaverLoginSDK.logout();
                            } catch (_) {
                              // Ignore SDK logout failures; local session clear is the source of truth.
                            }
                            await AuthStore.instance.clear();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          onSecondaryTap: () => Navigator.of(context).pop(),
                        ),
                      );
                    },
                  );
                }

                final sections = <({String title, List<Widget> rows})>[
                  (
                    title: '알림 설정',
                    rows: [
                      SettingsMenuRow(
                        title: '앱 푸시 알림',
                        trailing: CupertinoSwitch(
                          value: _pushEnabled ?? false,
                          onChanged: _pushEnabled == null ? null : _handlePushToggle,
                          activeTrackColor: Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _pushEnabled == true
                              ? '앱 설정에서 권한을 관리할 수 있습니다.'
                              : '알림이 꺼져 있습니다. 설정에서 허용해주세요.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  if (isSignedIn)
                    (
                      title: '계정 관리',
                      rows: [
                        SettingsMenuRow.action(title: '로그아웃', onTap: showLogoutAlert),
                        SettingsMenuRow.action(title: '회원탈퇴', onTap: () {}),
                      ],
                    ),
                  (
                    title: '일반',
                    rows: [
                      SettingsMenuRow.action(
                        title: '서비스 이용약관',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WebViewPage(
                                title: '서비스 이용약관',
                                url: WebUrls.termsUrl,
                              ),
                            ),
                          );
                        },
                      ),
                      SettingsMenuRow.action(
                        title: '개인정보 처리방침',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WebViewPage(
                                title: '개인정보 처리방침',
                                url: WebUrls.privacyUrl,
                              ),
                            ),
                          );
                        },
                      ),
                      SettingsMenuRow.action(
                        title: '마케팅 정보 수신 동의',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WebViewPage(
                                title: '마케팅 정보 수신 동의',
                                url: WebUrls.marketingUrl,
                                showRevokeButton: true,
                                onRevokeTap: () {},
                              ),
                            ),
                          );
                        },
                      ),
                      SettingsMenuRow.action(
                        title: '개발자에게 연락하기',
                        onTap: () {},
                      ),
                    ],
                  ),
                  (
                    title: '정보',
                    rows: [
                      SettingsMenuRow.value(title: '서비스 버전', value: version),
                    ],
                  ),
                  (
                    title: '개발자 옵션',
                    rows: [
                      SettingsMenuRow.segment(
                        title: '서버 설정',
                        segments: const ['운영', '개발'],
                        selectedIndex: 1,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ];

                final children = <Widget>[];
                for (var i = 0; i < sections.length; i++) {
                  final section = sections[i];
                  children.add(SettingsSectionTitle(title: section.title));
                  children.addAll(section.rows);
                  if (i != sections.length - 1) {
                    children.add(const SettingsSectionDivider());
                  }
                }

                return ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 32),
                  children: children,
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
